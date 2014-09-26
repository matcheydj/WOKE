//
//  EWSync.m
//  Woke
//
//  Created by Lee on 9/24/14.
//  Copyright (c) 2014 WokeAlarm.com. All rights reserved.
//

#import "EWSync.h"
#import "EWUIUtil.h"
#import "EWServerObject.h"
//#import "EWUserManagement.h"
#import "EWPersonStore.h"
#import "EWMediaStore.h"
#import "EWTaskStore.h"
#import "EWAlarmManager.h"

#define kPFQueryCacheLife		60*60;


//============ Global shortcut to main context ===========
NSManagedObjectContext *mainContext;
//=======================================================

@interface EWSync(){
	NSMutableDictionary *workingChangedRecords;
}
@property NSManagedObjectContext *context; //the main context(private)
@property NSMutableDictionary *parseSaveCallbacks;
@property (nonatomic) NSTimer *saveToServerDelayTimer;
@end


@implementation EWSync
@synthesize parseSaveCallbacks;
@synthesize isUploading = _isUploading;

+ (EWSync *)sharedInstance{
    
    static EWSync *sharedInstance_ = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance_ = [[EWSync alloc] init];
    });
    return sharedInstance_;
}

- (void)setup{
    
    //server: enable alert when offline
    [Parse errorMessagesEnabled:YES];
    
    //Access Control: enable public read access while disabling public write access.
    PFACL *defaultACL = [PFACL ACL];
    [defaultACL setPublicReadAccess:YES];
    [PFACL setDefaultACL:defaultACL withAccessForCurrentUser:YES];
    
    //core data
    [MagicalRecord setupCoreDataStackWithAutoMigratingSqliteStoreNamed:@"Woke"];
    [MagicalRecord setLoggingLevel:MagicalRecordLoggingLevelWarn];
    _context = [NSManagedObjectContext defaultContext];
    mainContext = _context;
    
    //observe context change to update the modifiedData of that MO. (Only observe the main context)
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preSaveAction:) name:NSManagedObjectContextWillSaveNotification object:_context];
    
    //Observe background context saves so main context can perform upload
    //We don't need to merge child context change to main context
    //It will cause errors when main and child context access same MO
    [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextDidSaveNotification object:_context queue:nil usingBlock:^(NSNotification *note) {
        
        [_saveToServerDelayTimer invalidate];
        _saveToServerDelayTimer = [NSTimer scheduledTimerWithTimeInterval:kUploadLag target:self selector:@selector(updateToServer) userInfo:nil repeats:NO];
    }];
    
    //Reachability
    self.reachability = [Reachability reachabilityForInternetConnection];
    self.reachability.reachableBlock = ^(Reachability *reachability) {
        NSLog(@"====== Network is reachable. Start upload. ======");
        //in background thread
        [[EWSync sharedInstance] resumeUploadToServer];
        
        //resume refresh MO
        NSSet *MOs = [[EWSync sharedInstance] getObjectFromQueue:kParseQueueRefresh];
        for (NSManagedObject *MO in MOs) {
            [MO refreshInBackgroundWithCompletion:^{
                NSLog(@"%@(%@) refreshed after network resumed.", MO.entity.name, MO.serverID);
            }];
        }
    };
    self.reachability.unreachableBlock = ^(Reachability * reachability){
        NSLog(@"====== Network is unreachable ======");
        [EWUIUtil showHUDWithString:@"Offline"];
    };
    
    //facebook
    [PFFacebookUtils initializeFacebook];
    
    //initial property
    self.parseSaveCallbacks = [NSMutableDictionary dictionary];
    self.saveCallbacks = [NSMutableArray new];
    self.saveToLocalItems = [NSMutableArray new];
    self.deleteToLocalItems = [NSMutableArray new];
    self.serverObjectPool = [NSMutableDictionary new];
    self.changeRecords = [NSMutableDictionary new];
    
}


#pragma mark - connectivity
+ (BOOL)isReachable{
    return [EWSync sharedInstance].reachability.isReachable;
}

- (BOOL)isReachable{
    return self.reachability.isReachable;
}

#pragma mark - ============== Parse Server methods ==============
- (BOOL)isUploading{
    return _isUploading;
}

- (void)setIsUploading:(BOOL)isUploading{
    @synchronized(self){
        _isUploading = isUploading;
    }
}

- (void)updateToServer{
    //make sure it is called on main thread
    NSParameterAssert([NSThread isMainThread]);
    if([mainContext hasChanges]){
        NSLog(@"There is still some change, save and do it later");
        [EWSync save];
        return;
    }
    
    if (self.isUploading) {
        NSLog(@"Data Store is uploading, delay for 30s");
        static NSTimer *uploadDelay;
        [uploadDelay invalidate];
        uploadDelay = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(updateToServer) userInfo:nil repeats:NO];
        return;
    }
    self.isUploading = YES;
    
    //determin network reachability
    if (!self.isReachable) {
        NSLog(@"Network not reachable, skip uploading");
        return;
    }
    
    NSLog(@"Start update to server");
    
    //only ManagedObjectID is thread safe
    NSSet *insertedManagedObjects = [self insertQueue];
    NSSet *updatedManagedObjects = [self updateQueue];
    NSSet *deletedServerObjects = self.deleteQueue;
    NSMutableSet *workingObjects = [NSMutableSet new];
    
    //copy the list to working queue
    [workingObjects unionSet:updatedManagedObjects];
    [workingObjects unionSet:insertedManagedObjects];
    for (NSManagedObject *mo in workingObjects) {
        [self appendObject:mo toQueue:kParseQueueWorking];
    }
    
    //save to local items
    NSArray *saveToLocalItemAlreadyInWorkingQueue = [self.saveToLocalItems filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF IN %@", [workingObjects valueForKey:@"objectID"]]];
    if (saveToLocalItemAlreadyInWorkingQueue.count) {
        DDLogError(@"There are items in saveToLocal queue but also appeared in working queue, please check the code!%@", saveToLocalItemAlreadyInWorkingQueue);
        for (NSManagedObjectID *ID in saveToLocalItemAlreadyInWorkingQueue) {
            [self.saveToLocalItems removeObject:ID];
        }
    }
    
    //clear save/delete to local items
    self.saveToLocalItems = [NSMutableArray new];
    self.deleteToLocalItems = [NSMutableArray new];
    
    //clear queues
    [self clearQueue:kParseQueueInsert];
    [self clearQueue:kParseQueueUpdate];
    workingChangedRecords = _changeRecords;
    _changeRecords = [NSMutableDictionary new];
    
	if (workingObjects.count == 0 && deletedServerObjects.count == 0) return;
    NSLog(@"============ Start updating to server =============== \n Inserts:%@, \n Updates:%@ \n and Deletes:%@ ", [insertedManagedObjects valueForKeyPath:@"entity.name"], [updatedManagedObjects valueForKey:kParseObjectID], deletedServerObjects);
    NSLog(@"Change records:\n%@", workingChangedRecords);
    
    
    NSArray *callbacks = [self.saveCallbacks copy];
    [_saveCallbacks removeAllObjects];
    
    //start background update
    [mainContext saveWithBlock:^(NSManagedObjectContext *localContext) {
        for (NSManagedObject *MO in workingObjects) {
            NSManagedObject *localMO = [MO inContext:localContext];
            if (!localMO) {
                NSLog(@"*** MO %@(%@) to upload haven't saved", MO.entity.name, MO.serverID);
                continue;
            }
            [self updateParseObjectFromManagedObject:localMO];
            
            //remove changed record
            NSArray *changes = workingChangedRecords[localMO.objectID];
            [workingChangedRecords removeObjectForKey:localMO.objectID];
            NSLog(@"===> MO %@(%@) uploaded to server with changes applied: %@. %lu to go.", localMO.serverClassName, localMO.serverID, changes, (unsigned long)workingChangedRecords.allKeys.count);
            
            //remove from queue
            [self removeObjectFromWorkingQueue:localMO];
        }
        
        for (PFObject *po in deletedServerObjects) {
            [self deleteParseObject:po];
        }
        
    } completion:^(BOOL success, NSError *error) {
        
        //completion block
        if (callbacks.count) {
            NSLog(@"=========== Start running completion block (%lu) =============", (unsigned long)callbacks.count);
            for (EWSavingCallback block in callbacks){
                block();
            }
        }
        
        NSLog(@"=========== Finished uploading to saver ===============");
        NSSet *reminningWorkingObjects = [self getObjectFromQueue:kParseQueueWorking];
        if (reminningWorkingObjects.count > 0) {
            NSLog(@"*** With failures: (ID)%@(Entity)%@", [reminningWorkingObjects valueForKey:@"objectId"], [reminningWorkingObjects valueForKeyPath: @"entity.name"]);
            
            [self clearQueue:kParseQueueWorking];
        }
        if (workingChangedRecords.count) {
            NSLog(@"*** With remaining changed records: %@", workingChangedRecords);
        }
        
        self.isUploading = NO;
    }];
    
}

- (void)resumeUploadToServer{
    NSSet *workingMOs = [self workingQueue];
    NSSet *deletePOs = [self deleteQueue];
    if (workingMOs.count > 0 || deletePOs.count > 0) {
        NSLog(@"There are %lu MOs need to upload or %lu MOs need to delete", (unsigned long)workingMOs.count, (unsigned long)deletePOs.count);
        for (NSManagedObject *MO in workingMOs) {
            if (MO.serverID) {
                NSLog(@"MO %@(%@) resumed to UPDATE queue", MO.entity.name, MO.serverID);
                [self appendUpdateQueue:MO];
            }else{
                NSLog(@"MO %@(%@) resumed to INSERT queue", MO.entity.name, MO.objectID);
                [self appendInsertQueue:MO];
            }
            
            [self removeObjectFromWorkingQueue:MO];
        }
        NSParameterAssert([self workingQueue].count == 0);
        
        [self updateToServer];
    }
}

//observe main context
- (void)preSaveAction:(NSNotification *)notification{
    if (![NSThread isMainThread]) {
        DDLogError(@"Skip pre-save check on background thread");
    }
    
    NSManagedObjectContext *localContext = (NSManagedObjectContext *)[notification object];
    
    [self enqueueChangesInContext:localContext];
}

- (void)enqueueChangesInContext:(NSManagedObjectContext *)context{
    //BOOL hasChange = NO;
    
    NSSet *updatedObjects = context.updatedObjects;
    NSSet *insertedObjects = context.insertedObjects;
    NSSet *deletedObjects = context.deletedObjects;
    NSSet *objects = [updatedObjects setByAddingObjectsFromSet:insertedObjects];
    
    //for updated mo
    for (NSManagedObject *MO in objects) {
        //check if it's our guy
        if (![MO isKindOfClass:[EWServerObject class]]) {
            continue;
        }
        //First test MO exist
        if (![context existingObjectWithID:MO.objectID error:NULL]) {
            DDLogError(@"*** MO you are trying to modify doesn't exist in the sqlite: %@", MO.objectID);
            continue;
        }
        
        
        //skip if marked save to local
        if ([self.saveToLocalItems containsObject:MO.objectID]) {
            [self.saveToLocalItems removeObject:MO.objectID];
            continue;
        }
		
		//Pre-save validate
		BOOL good = [EWSync validateMO:MO];
		if (!good) {
			continue;
		}
		
        BOOL mine = [EWSync checkAccess:MO];
        if (!mine) {
            DDLogWarn(@"!!! Skip updating other's object %@ with changes %@", MO.serverID, MO.changedKeys);
            continue;
        }
        
        //if last updated doesn't exist, skip
        if (![MO valueForKey:kUpdatedDateKey]){
            //this is MY VALID UPDATED MO but doesn't have updatedAt, should check the cause if it.
            DDLogError(@"*** MO %@(%@) doesn't have updatedAt, check how this object is being updated. Updated keys: %@", MO.entity.name, MO.serverID, MO.changedValues);
        }
        
        if ([insertedObjects containsObject:MO]) {
            //enqueue to insertQueue
            [self appendInsertQueue:MO];
            
            //*** we should not add updatedAt here. Two Inserts could be possible: downloaded from server or created here. Therefore we need to add createdAt at local creation point.
            //change updatedAt
            //[MO setValue:[NSDate date] forKeyPath:kUpdatedDateKey];
            continue;
        }
        
        //additional check for updated object
        if ([updatedObjects containsObject:MO]) {
            
            //check if updated keys exist
            NSArray *changedKeys = MO.changedKeys;
            if (changedKeys.count > 0) {
                
                //add changed keys to record
                NSSet *changed = [self.changeRecords objectForKey:MO.serverID] ?:[NSSet new];
                changed = [changed setByAddingObjectsFromArray:changedKeys];
                [self.changeRecords setObject:changed forKey:MO.objectID];
                
                //add to queue
                [self appendUpdateQueue:MO];
                
                //change updatedAt
                [MO setValue:[NSDate date] forKeyPath:kUpdatedDateKey];
            }
        }
        
        
    }
    
    for (NSManagedObject *MO in deletedObjects) {
        //check if it's our guy
        if (![MO isKindOfClass:[EWServerObject class]]) {
            continue;
        }
        if ([self.deleteToLocalItems containsObject:MO.serverID]) {
            [self removeObjectFromDeleteQueue:[PFObject objectWithoutDataWithClassName:MO.serverClassName objectId:MO.serverID]];
            continue;
        }
        if (MO.serverID) {
            NSLog(@"~~~> MO %@(%@) is going to be DELETED, enqueue PO to delete queue.", MO.entity.name, [MO valueForKey:kParseObjectID]);
            
            PFObject *PO = [PFObject objectWithoutDataWithClassName:MO.serverClassName objectId:MO.serverID];
            
            [self.serverObjectPool removeObjectForKey:MO.serverID];
            
            [self appendObjectToDeleteQueue:PO];
        }
    }
    
}



#pragma mark - Upload worker


- (void)updateParseObjectFromManagedObject:(NSManagedObject *)managedObject{
    NSError *error;
    
    //validation
    if (![EWSync validateMO:managedObject]) {
        NSLog(@"!!! Validation failed for %@(%@), skip upload. Detail: \n%@", managedObject.entity.name, managedObject.serverID, managedObject);
        return;
    }
    
    //skip if updating other PFUser
    //make sure the value is the latest from store
    //[managedObject.managedObjectContext refreshObject:managedObject mergeChanges:NO];
    
    NSString *parseObjectId = managedObject.serverID;
    PFObject *object;
    if (parseObjectId) {
        //download
        object =[managedObject getParseObjectWithError:&error];
        
        if (!object || error) {
            if ([error code] == kPFErrorObjectNotFound) {
                NSLog(@"PO %@ couldn't be found!", managedObject.serverClassName);
            } else if ([error code] == kPFErrorConnectionFailed) {
                NSLog(@"Uh oh, we couldn't even connect to the Parse Cloud!");
                [managedObject updateEventually];
                return;
            } else if (error) {
                NSLog(@"*** Error in getting related parse object from MO (%@). \n Error: %@", managedObject.entity.name, [error userInfo][@"error"]);
                [managedObject updateEventually];
                return;
            }
            object = nil;
            error = nil;
        }
        
    }
    
    if (!object) {
        //insert
        object = [PFObject objectWithClassName:managedObject.serverClassName];
        
        [object save:&error];//need to save before working on PFRelation
        if (!error) {
            NSLog(@"+++> CREATED PO %@(%@)", object.parseClassName, object.objectId);
            [managedObject setValue:object.objectId forKey:kParseObjectID];
            [managedObject setValue:object.updatedAt forKeyPath:kUpdatedDateKey];
        }else{
            [managedObject updateEventually];
            return;
        }
    }
    
    
    //==========set Parse value/relation and callback block===========
    [object updateFromManagedObject:managedObject];
    //================================================================
    
    [object saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (error) {
            if (error.code == kPFErrorObjectNotFound){
                NSLog(@"*** PO not found for %@(%@), set to nil.", managedObject.entity.name, managedObject.serverID);
                NSManagedObject *trueMO = [managedObject.managedObjectContext existingObjectWithID:managedObject.objectID error:NULL];
                if (trueMO) {
                    //need to check if the object is available
                    [managedObject setValue:nil forKey:kParseObjectID];
                }
            }else{
                NSLog(@"*** Failed to save server object: %@", error.description);
            }
            [managedObject updateEventually];
        }else{
            //assign connection between MO and PO
            [self performSaveCallbacksWithParseObject:object andManagedObjectID:managedObject.objectID];
        }
    }];
    
    
    
    //time stamp for updated date. This is very important, otherwise mo might seems to be outdated
    if (managedObject.hasChanges) {
        [managedObject setValue:[NSDate date] forKey:kUpdatedDateKey];
    }else{
        [managedObject setValue:[NSDate date] forKey:kUpdatedDateKey];
        [managedObject saveToLocal];
    }
    
}

- (void)deleteParseObject:(PFObject *)parseObject{
    [parseObject deleteInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        
        if (succeeded) {
            //Good
            NSLog(@"~~~> PO %@(%@) deleted from server", parseObject.parseClassName, parseObject.objectId);
            [self removeObjectFromDeleteQueue:parseObject];
            
        }else if (error.code == kPFErrorObjectNotFound){
            //fine
            NSLog(@"~~~> Trying to deleted PO %@(%@) but not found", parseObject.parseClassName, parseObject.objectId);
            [self removeObjectFromDeleteQueue:parseObject];
            
        }else{
            //not good
            [self removeObjectFromDeleteQueue:parseObject];
        }
    }];
}


- (void)addSaveCallback:(PFObjectResultBlock)callback forManagedObjectID:(NSManagedObjectID *)objectID{
    //get global save callback
    NSMutableDictionary *saveCallbacks = self.parseSaveCallbacks;
    NSMutableArray *callbacks = [saveCallbacks objectForKey:objectID]?:[NSMutableArray array];
    [callbacks addObject:callback];
    //save
    [saveCallbacks setObject:callbacks forKey:objectID];
}


- (void)performSaveCallbacksWithParseObject:(PFObject *)parseObject andManagedObjectID:(NSManagedObjectID *)managedObjectID{
    NSArray *saveCallbacks = [[self parseSaveCallbacks] objectForKey:managedObjectID];
    if (saveCallbacks) {
        for (PFObjectResultBlock callback in saveCallbacks) {
            NSError *err;
            callback(parseObject, err);
        }
        [self.parseSaveCallbacks removeObjectForKey:managedObjectID];
    }
}


#pragma mark - Server Updating Queue methods
//update queue
- (NSSet *)updateQueue{
    return [self getObjectFromQueue:kParseQueueUpdate];
}

- (void)appendUpdateQueue:(NSManagedObject *)mo{
    //queue
    [self appendObject:mo toQueue:kParseQueueUpdate];
}

- (void)removeObjectFromUpdateQueue:(NSManagedObject *)mo{
    [self removeObject:mo fromQueue:kParseQueueUpdate];
}

//insert queue
- (NSSet *)insertQueue{
    return [self getObjectFromQueue:kParseQueueInsert];
}

- (void)appendInsertQueue:(NSManagedObject *)mo{
    [self appendObject:mo toQueue:kParseQueueInsert];
}

- (void)removeObjectFromInsertQueue:(NSManagedObject *)mo{
    [self removeObject:mo fromQueue:kParseQueueInsert];
}

//uploading queue
- (NSSet *)workingQueue{
    return [self getObjectFromQueue:kParseQueueWorking];
}

- (void)appendObjectToWorkingQueue:(NSManagedObject *)mo{
    [self appendObject:mo toQueue:kParseQueueWorking];
}

- (void)removeObjectFromWorkingQueue:(NSManagedObject *)mo{
    [self removeObject:mo fromQueue:kParseQueueWorking];
}

//queue functions
- (NSSet *)getObjectFromQueue:(NSString *)queue{
    NSParameterAssert([NSThread isMainThread]);
    NSArray *array = [[NSUserDefaults standardUserDefaults] valueForKey:queue];
    NSMutableArray *validMOs = [array mutableCopy];
    NSMutableSet *set = [NSMutableSet new];
    for (NSString *str in array) {
        NSURL *url = [NSURL URLWithString:str];
        NSManagedObjectID *ID = [self.context.persistentStoreCoordinator managedObjectIDForURIRepresentation:url];
        if (!ID) {
            NSLog(@"@@@ ManagedObjectID not found: %@", url);
            //remove from queue
            [validMOs removeObject:str];
            [[NSUserDefaults standardUserDefaults] setObject:[validMOs copy] forKey:queue];
            continue;
        }
        NSError *error;
        NSManagedObject *MO = [self.context existingObjectWithID:ID error:&error];
        if (!error && MO) {
            [set addObject:MO];
        }else{
            NSLog(@"*** Serious error: trying to fetch MO from queue %@ failed. %@", queue, error.description);
            //remove from the queue
            MO = [self.context objectWithID:ID];
            [self removeObject:MO fromQueue:queue];
        }
        
    }
    return [set copy];
}

- (void)appendObject:(NSManagedObject *)mo toQueue:(NSString *)queue{
    //	//check owner
    //	if(![queue isEqualToString:kParseQueueRefresh]/* && ![self checkAccess:mo]*/){
    //		NSLog(@"*** MO %@(%@) doesn't owned by me, skip adding to %@", mo.entity.name, mo.serverID, queue);
    //		return;
    //	}
    
    NSArray *array = [[NSUserDefaults standardUserDefaults] valueForKey:queue];
    NSMutableSet *set = [[NSMutableSet setWithArray:array] mutableCopy]?:[NSMutableSet new];
    NSManagedObjectID *objectID = mo.objectID;
    if ([objectID isTemporaryID]) {
        [mo.managedObjectContext obtainPermanentIDsForObjects:@[mo] error:NULL];
        objectID = mo.objectID;
    }
    NSString *str = objectID.URIRepresentation.absoluteString;
    if (![set containsObject:str]) {
        [set addObject:str];
        [[NSUserDefaults standardUserDefaults] setObject:[set allObjects] forKey:queue];
        if ([queue isEqualToString:kParseQueueInsert]) {
            NSLog(@"+++> MO %@(%@) added to INSERT queue", mo.entity.name, mo.objectID);
        }else if([queue isEqualToString:kParseQueueUpdate]){
            NSLog(@"===> MO %@(%@) added to UPDATED queue with changes: %@", mo.entity.name, [mo valueForKey:kParseObjectID], mo.changedKeys);
        }
        
    }
    
}

- (void)removeObject:(NSManagedObject *)mo fromQueue:(NSString *)queue{
    NSMutableArray *array = [[[NSUserDefaults standardUserDefaults] valueForKey:queue] mutableCopy];
    NSManagedObjectID *objectID = mo.objectID;
    NSString *str = objectID.URIRepresentation.absoluteString;
    if ([array containsObject:str]) {
        [array removeObject:str];
        [[NSUserDefaults standardUserDefaults] setValue:[array copy] forKey:queue];
        //NSLog(@"Removed object %@ from insert queue", mo.entity.name);
    }
}

- (void)clearQueue:(NSString *)queue{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:queue];
}

- (BOOL)contains:(NSManagedObject *)mo inQueue:(NSString *)queue{
    NSMutableArray *array = [[[NSUserDefaults standardUserDefaults] valueForKey:queue] mutableCopy];
    NSString *str = mo.objectID.URIRepresentation.absoluteString;
    BOOL contain = [array containsObject:str];
    return contain;
}

//DeletedQueue underlying is a dictionary of objectId:className
- (NSSet *)deleteQueue{
    NSDictionary *dic = [[[NSUserDefaults standardUserDefaults] valueForKey:kParseQueueDelete] mutableCopy];
    NSParameterAssert(!dic || [dic isKindOfClass:[NSDictionary class]]);
    NSMutableSet *set = [NSMutableSet new];
    [dic enumerateKeysAndObjectsUsingBlock:^(NSString *ID, NSString *className, BOOL *stop) {
        [set addObject:[PFObject objectWithoutDataWithClassName:className objectId:ID]];
    }];
    return [set copy];
}

- (void)appendObjectToDeleteQueue:(PFObject *)object{
    if (!object) return;
    NSMutableDictionary *dic = [[[NSUserDefaults standardUserDefaults] valueForKey:kParseQueueDelete] mutableCopy]?:[NSMutableDictionary new];;
    [dic setObject:object.parseClassName forKey:object.objectId];
    [[NSUserDefaults standardUserDefaults] setObject:[dic copy] forKey:kParseQueueDelete];
}

- (void)removeObjectFromDeleteQueue:(PFObject *)object{
    if (!object) return;
    NSMutableDictionary *dic = [[[NSUserDefaults standardUserDefaults] valueForKey:kParseQueueDelete] mutableCopy];
    [dic removeObjectForKey:object.objectId];
    [[NSUserDefaults standardUserDefaults] setObject:[dic copy] forKey:kParseQueueDelete];
}


#pragma mark - Core Data
+ (NSManagedObject *)managedObjectWithClass:(NSString *)className withID:(NSString *)serverID{
	NSParameterAssert([NSThread isMainThread]);
    if (serverID == nil) {
        NSLog(@"!!! Passed in nil to get current MO");
        return nil;
    }
    
    NSError *error;
    NSManagedObject * MO = [NSClassFromString(className) MR_findFirstByAttribute:kParseObjectID withValue:serverID];
    if (!MO) {
		PFObject *PO = [[EWSync sharedInstance] getParseObjectWithClass:className.serverClass ID:serverID error:NULL];
		MO = [PO managedObjectInContext:mainContext];
		[MO refresh];
		if (!MO) {
			DDLogError(@"Failed getting exsiting MO(%@): %@", className, error.description);
		}
    }
    return MO;
}

+ (void)save{
	NSAssert([NSThread isMainThread], @"Calling +[self save] on background context is not allowed. Use [context saveToPersistantStoreAndSave] instead");
	if (mainContext.hasChanges) {
		[mainContext saveToPersistentStoreAndWait];
	}
}

+ (void)saveWithCompletion:(EWSavingCallback)block{
    [[EWSync sharedInstance].saveCallbacks addObject:block];
    [self save];
}

+ (void)saveAllToLocal:(NSArray *)MOs{
	if (MOs.count == 0) {
		return;
	}
	
	NSManagedObject *anyMO = MOs[0];
    [anyMO.managedObjectContext obtainPermanentIDsForObjects:MOs error:NULL];
	
	//mark MO as save to local
	for (NSManagedObject *mo in MOs) {
		[[EWSync sharedInstance].saveToLocalItems addObject:mo.objectID];
	}
	
	//remove from queue
	for (NSManagedObject *mo in MOs) {
		//remove from the update queue
		[[EWSync sharedInstance] removeObjectFromInsertQueue:mo];
		[[EWSync sharedInstance] removeObjectFromUpdateQueue:mo];
	}
}


+ (BOOL)validateMO:(NSManagedObject *)mo{
    //validate MO, only used when uploading MO to PO
    BOOL good = [EWSync validateMO:mo andTryToFix:NO];
    
    return good;
}

+ (BOOL)validateMO:(NSManagedObject *)mo andTryToFix:(BOOL)tryFix{
    if (!mo) {
        return NO;
    }
    //validate MO, only used when uploading MO to PO
    BOOL good = YES;
    
    if (![mo valueForKey:kUpdatedDateKey] && mo.serverID) {
        NSLog(@"The %@(%@) you are trying to validate haven't been downloaded fully. Skip validating.", mo.entity.name, mo.serverID);
        return NO;
    }
    
    NSString *type = mo.entity.name;
    if ([type isEqualToString:@"EWTaskItem"]) {
        good = [EWTaskStore validateTask:(EWTaskItem *)mo];
        if (!good) {
            if (!tryFix) {
                return NO;
            }
            [mo refresh];
            good = [EWTaskStore validateTask:(EWTaskItem *)mo];
            
        }
    } else if([type isEqualToString:@"EWMediaItem"]){
        good = [EWMediaStore validateMedia:(EWMediaItem *)mo];
        if (!good) {
            if (!tryFix) {
                return NO;
            }
            [mo refresh];
            good = [EWMediaStore validateMedia:(EWMediaItem *)mo];
        }
    }else if ([type isEqualToString:@"EWPerson"]){
        good = [EWPersonStore validatePerson:(EWPerson *)mo];
        if (!good) {
            if (!tryFix) {
                return NO;
            }
            [mo refresh];
            good = [EWMediaStore validateMedia:(EWMediaItem *)mo];
        }
    }else if ([type isEqualToString:@"EWAlarmItem"]){
        good = [EWAlarmManager validateAlarm:(EWAlarmItem *)mo];
        if (!good) {
            if (!tryFix) {
                return NO;
            }
            [mo refresh];
            good = [EWAlarmManager validateAlarm:(EWAlarmItem *)mo];
        }
    }
    if (!good) {
        NSLog(@"*** %@(%@) failed in validation after trying to fix", mo.entity.name, mo.serverID);
    }
    
    return good;
    
}



+ (BOOL)checkAccess:(NSManagedObject *)mo{
    if (!mo.serverID) {
        return YES;
    }
    
    //first see if cached PO exist
    PFObject *po = [[EWSync sharedInstance] getCachedParseObjectForID:mo.serverID];
    if (po.ACL != nil) {
        BOOL write = [po.ACL getWriteAccessForUser:[PFUser currentUser]] || [po.ACL getPublicWriteAccess];
        return write;
    }
    
    //if no ACL, use MO to determine
    EWPerson *p;
    if ([mo respondsToSelector:@selector(owner)]) {
        p = [mo valueForKey:@"owner"];
        if (!p && [mo respondsToSelector:@selector(pastOwner)]) {
            p = [mo valueForKey:@"pastOwner"];
        }
    }else if ([mo respondsToSelector:@selector(author)]){
        //check author
        p = [mo valueForKey:@"author"];
        
    }else if ([mo isKindOfClass:[EWPerson class]]) {
        p = (EWPerson *)mo;
    }else{
        //if not, use PO from server
        return YES;
    }
    
    if (p.isMe){
        return YES;
    }
    return NO;
}


#pragma mark - Parse helper methods
+ (NSArray *)findServerObjectWithQuery:(PFQuery *)query{
	return [EWSync findServerObjectWithQuery:query error:NULL];
}

+ (NSArray *)findServerObjectWithQuery:(PFQuery *)query error:(NSError **)error{
	//cache query
	query.cachePolicy = kPFCachePolicyCacheElseNetwork;
	query.maxCacheAge = kPFQueryCacheLife;
	//find
	NSArray *result = [query findObjects:error];
	for (PFObject *PO in result) {
		[[EWSync sharedInstance] setCachedParseObject:PO];
	}
	return result;
}

+ (void)findServerObjectInBackgroundWithQuery:(PFQuery *)query completion:(PFArrayResultBlock)block{//cache query
	query.cachePolicy = kPFCachePolicyCacheElseNetwork;
	query.maxCacheAge = kPFQueryCacheLife;
	[query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
		
		for (PFObject *PO in objects) {
			[[EWSync sharedInstance] setCachedParseObject:PO];
		}
		if (block) {
			block(objects, error);
		}
	}];
}

- (PFObject *)getCachedParseObjectForID:(NSString *)objectId{
    return [self.serverObjectPool valueForKey:objectId];
}

- (void)setCachedParseObject:(PFObject *)PO {
    [self.serverObjectPool setObject:PO forKey:PO.objectId];
}

- (PFObject *)getParseObjectWithClass:(NSString *)class ID:(NSString *)ID error:(NSError **)error{
    if (ID) {
        //try to find PO in the pool first
        PFObject *object = [self getCachedParseObjectForID:ID];
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:class inManagedObjectContext:mainContext];
        
        //if not found, then download
        if (!object || !object.isDataAvailable) {
            //fetch from server if not found
            //or if PO doesn't have data avaiable
            //or if PO is older than MO
            PFQuery *q = [PFQuery queryWithClassName:class.serverClass];
            [q whereKey:kParseObjectID equalTo:ID];
            
            [entity.relationshipsByName enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSRelationshipDescription *obj, BOOL *stop) {
                if (obj.isToMany && !obj.inverseRelationship) {
                    [q includeKey:key];
                }
            }];
			
			//find on server
			object = [[EWSync findServerObjectWithQuery:q] firstObject];

        }
        
        return object;
    }
    
    DDLogError(@"!!! passed in empty ID, upload first!");
    return nil;
    
}

@end


@implementation NSString (EWSync)

- (NSString *)serverType{
    NSDictionary *typeDic = kServerTransformTypes;
    NSString *serverType = typeDic[self];
    return serverType;
}

- (NSString *)serverClass{
	NSDictionary *typeDic = kServerTransformClasses;
	NSString *serverClass = typeDic[self]?:self;
	return serverClass;
}

- (BOOL)skipUpload{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF IN %@", attributeUploadSkipped];
    BOOL result = [predicate evaluateWithObject:self];
    return result;
}

@end
