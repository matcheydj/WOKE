//
//  EWStore.m
//  EarlyWorm
//
//  Created by Lei on 8/29/13.
//  Copyright (c) 2013 Shens. All rights reserved.
//

#import "EWDataStore.h"
#import <Parse/Parse.h>
#import "EWUserManagement.h"
#import "EWPersonStore.h"
#import "EWDownloadManager.h"
#import "EWAlarmManager.h"
#import "EWTaskStore.h"
#import "EWMediaStore.h"
#import "EWMediaItem.h"
#import "NSString+MD5.h"
#import "EWWakeUpManager.h"

//Util
#import "FTWCache.h"

//Global variable
//NSDate *lastChecked;

@interface EWDataStore()
@property NSManagedObjectContext *context; //the main context(private), only expose 'currentContext' as a class method
@property (nonatomic) NSMutableDictionary *parseSaveCallbacks;
@end

@implementation EWDataStore
@synthesize context;
@synthesize model;
@synthesize dispatch_queue, coredata_queue;
@synthesize lastChecked;
@synthesize snsClient;
@synthesize parseSaveCallbacks;
@synthesize updateQueue, insertQueue, deleteQueue;

+ (EWDataStore *)sharedInstance{
    
    static EWDataStore *sharedStore_ = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedStore_ = [[EWDataStore alloc] init];
    });
    return sharedStore_;
}

- (id)init{
    self = [super init];
    if (self) {
        //dispatch queue
        dispatch_queue = dispatch_queue_create("com.wokealarm.datastore.dispatchQueue", DISPATCH_QUEUE_SERIAL);
        coredata_queue = dispatch_queue_create("com.wokealarm.datastore.coreDataQueue", DISPATCH_QUEUE_SERIAL);
        
        //AWS
        //snsClient = [[AmazonSNSClient alloc] initWithAccessKey:AWS_ACCESS_KEY_ID withSecretKey:AWS_SECRET_KEY];
        //snsClient.endpoint = [AmazonEndpoints snsEndpoint:US_WEST_2];
        
        //Parse
        [Parse setApplicationId:@"p1OPo3q9bY2ANh8KpE4TOxCHeB6rZ8oR7SrbZn6Z"
                      clientKey:@"9yfUenOzHJYOTVLIFfiPCt8QOo5Ca8fhU8Yqw9yb"];
        //[PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];
        
        //core data
        [MagicalRecord setupCoreDataStackWithAutoMigratingSqliteStoreNamed:@"Woke"];
        context = [NSManagedObjectContext defaultContext];
        
        //facebook
        [PFFacebookUtils initializeFacebook];
        
        //cache policy
        //network chenge policy
        //refesh failure behavior

        //watch for login event
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loginDataCheck) name:kPersonLoggedIn object:Nil];
    }
    return self;
}

- (NSManagedObjectModel *)model
{
    if (model != nil) {
        return model;
    }
    //Returns a model created by merging all the models found in given bundles. If you specify nil, then the main bundle is searched.
    //managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"EarlyWorm" withExtension:@"momd"];
    model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    return model;
}

#pragma mark - Property accessors

- (NSDate *)lastChecked{
    NSUserDefaults *defalts = [NSUserDefaults standardUserDefaults];
    NSDate *timeStamp = [defalts objectForKey:kLastChecked];
    return timeStamp;
}

- (void)setLastChecked:(NSDate *)time{
    if (time) {
        NSUserDefaults *defalts = [NSUserDefaults standardUserDefaults];
        [defalts setObject:time forKey:kLastChecked];
        [defalts synchronize];
    }
}

#pragma mark - Login Check
+ (void)loginDataCheck{
    NSLog(@"========> %s <=========", __func__);
    
    //change fetch policy
    //NSLog(@"0. Start sync with server");
    //[self.coreDataStore syncWithServer];
    
    //refresh current user
    dispatch_async([EWDataStore sharedInstance].dispatch_queue, ^{
        NSLog(@"1. Register AWS push key");
        [EWUserManagement registerAPNS];
    });
    
    //check alarm, task, and local notif
    NSLog(@"2. Check alarm");
    [[EWAlarmManager sharedInstance] scheduleAlarm];
    
    NSLog(@"3. Check task");
    [[EWTaskStore sharedInstance] scheduleTasks];
    
    
    //updating facebook friends
    dispatch_async([EWDataStore sharedInstance].dispatch_queue, ^{
        NSLog(@"5. Updating facebook friends");
        [EWUserManagement getFacebookFriends];
    });
    
    //update data with timely updates
    [EWDataStore registerServerUpdateService];
    
}


+ (void)checkAlarmData{
    NSInteger nAlarm = [[EWAlarmManager sharedInstance] alarmsForUser:currentUser].count;
    NSInteger nTask = [EWTaskStore myTasks].count;
    if (nTask == 0 && nAlarm == 0) {
        return;
    }
    
    
    //check alarm
    //dispatch_async(dispatch_queue, ^{
        NSLog(@"2. Check alarm");
        [[EWAlarmManager sharedInstance] scheduleAlarm];
    //});
    
    //check task
    //dispatch_async(dispatch_queue, ^{
        NSLog(@"3. Check task");
        [EWTaskStore.sharedInstance scheduleTasks];
    //});
    
    //check local notif
    //dispatch_async(dispatch_queue, ^{
        NSLog(@"4. Start check local notification");
        [EWTaskStore.sharedInstance checkScheduledNotifications];
    //});
    
}

#pragma mark - DATA from Amazon S3
+ (NSData *)getRemoteDataWithKey:(NSString *)key{
    if (!key) {
        return nil;
    }
    
    NSData *data = nil;
    
    //s3 file
    if ([key hasPrefix:@"http"]) {
        //read from url
        NSURL *audioURL = [NSURL URLWithString:key];
        NSString *keyHash = [audioURL.absoluteString MD5Hash];
        data = [FTWCache objectForKey:keyHash];
        if (!data) {
            //get from remote
            NSError *err;
            data = [NSData dataWithContentsOfURL:audioURL options:NSDataReadingUncached error:&err];
            if (err) {
                NSLog(@"@@@@@@ Error occured in reading remote content: %@", err);
            }
            [FTWCache setObject:data forKey:keyHash];
        }
        
    }else if ([[NSURL URLWithString:key] isFileURL]){
        //local file
        NSLog(@"string is a local file: %@", key);
        @try {
            data = [NSData dataWithContentsOfFile:key];
        }
        @catch (NSException *exception) {
            //pass by file name only, for main bundle resources
            NSArray *array = [key componentsSeparatedByString:@"."];
            NSAssert(array.count != 2, @"Please provide a file name with extension");
            NSString *filePath = [[NSBundle mainBundle] pathForResource:array[0] ofType:array[1]];
            data = [NSData dataWithContentsOfFile:filePath];
        }
        
    }else if(key.length > 500){
        //string contains data
        data = [key dataUsingEncoding:NSUTF8StringEncoding];
        //TODO: save again.
        NSLog(@"Return the audio key as the data itself, please check!");
        
    }
    
    return data;
}

#pragma mark - local cache

+ (NSString *)localPathForKey:(NSString *)key{
    if (key.length > 500) {
        NSLog(@"*** Something wrong with url, the url contains data");
        return nil;
    }else if ([[NSURL URLWithString:key] isFileURL] || [key hasPrefix:@"/"] || [key hasPrefix:@"\\"]) {
        //NSLog(@"Is local file path, return key directly");
        return key;
    }
    
    NSString *path = [FTWCache localPathForKey:[key MD5Hash]];
    if (!path) {
        //not in local, need to download
        //[[EWDownloadManager sharedInstance] downloadUrl:[NSURL URLWithString:key]];
        return nil;
    }
    return path;
}

+ (void)updateCacheForKey:(NSString *)key withData:(NSData *)data{
    if (!key) {
        key = [[NSDate date] date2numberLongString];
        NSLog(@"Assigned new key %@", key);
    }
    
    if (key.length == 15) {
        [NSException raise:@"Passed in MD5 value" format:@"Please provide original url string"];
    }
    
    NSString *hashKey = [key MD5Hash];
    [FTWCache setObject:data forKey:hashKey];
    
}

+ (NSDate *)lastModifiedDateForObjectAtKey:(NSString *)key{
    if (!key) {
        return nil;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *path = [self localPathForKey:key];
	
	if ([fileManager fileExistsAtPath:path])
	{
		NSDate *modificationDate = [[fileManager attributesOfItemAtPath:path error:nil] objectForKey:NSFileModificationDate];
        return modificationDate;
    }
    return nil;
}

+ (void)deleteCacheForKey:(NSString *)key{
    if (!key) return;
    NSString *path = [self localPathForKey:key];
    if (path){
        NSError *err;
        [[NSFileManager defaultManager] removeItemAtPath:path error:&err];
        if (err) {
            NSLog(@"Delete cache with error: %@", err);
        }
    }
}

#pragma mark - Timely sync
- (void)registerServerUpdateService{
    self.serverUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:kServerUpdateInterval target:self selector:@selector(serverUpdate:) userInfo:nil repeats:0];
    [self serverUpdate:nil];
}
     
- (void)serverUpdate:(NSTimer *)timer{
    //services that need to run periodically
    NSLog(@"%s: Start sync service", __func__);
    
    dispatch_async(dispatch_queue, ^{
        
        //lsat seen
        NSLog(@"Start last seen recurring task");
        [EWUserManagement updateLastSeen];
        
        //location
        NSLog(@"Start location recurring task");
        [EWUserManagement registerLocation];
        
        //check task
        NSLog(@"Start recurring task schedule");
        [[EWTaskStore sharedInstance] scheduleTasks];
        
        //check alarm timer
        NSLog(@"Start recurring alarm timer check");
        [EWWakeUpManager alarmTimerCheck];
    });
    
}


#pragma mark - Core Data Threading
//+ (void)saveDataInContext:(void(^)(NSManagedObjectContext *currentContext))block
//{
//	NSManagedObjectContext *currentContext = [EWDataStore currentContext];
//	[currentContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
//	[context setMergePolicy:NSMergeByPropertyStoreTrumpMergePolicy];
//	[context observeContext:currentContext];
//    
//    //execute change block
//    if (block) {
//        block(currentContext);
//    }
//	
//    //save
//	if ([currentContext hasChanges]){
//        //commit save to background context
//		[currentContext saveOnSuccess:^{
//            NSLog(@"Background change saved to context");
//        }onFailure:^(NSError *error) {
//            NSLog(@"Save in background thread context failed");
//        }];
//        //revert the default merge policy for main context
//        [context setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
//	}
//}

//+ (void)saveDataInBackgroundInBlock:(void(^)(NSManagedObjectContext *context))saveBlock completion:(void(^)(void))completion
//{
//	dispatch_async([EWDataStore sharedInstance].coredata_queue, ^{
//		[self saveDataInContext:saveBlock];
//        
//        if (completion) {
//            dispatch_sync(dispatch_get_main_queue(), ^{
//                completion();
//            });
//        }
//	});
//}

//+ (NSManagedObject *)refreshObjectWithServer:(NSManagedObject *)obj{
//    dispatch_sync([EWDataStore sharedInstance].coredata_queue, ^{
//        [self saveDataInContext:^(NSManagedObjectContext *currentContext) {
//            NSManagedObject *newObj = [currentContext objectWithID:obj.objectID];
//            NSLog(@"Fetched obj at background: %@", newObj.class);
//        }];
//    });
//    
//    NSAssert([obj.managedObjectContext isEqual:[EWDataStore currentContext]], @"Current context is not equal to obj's context");
//    
//    obj = [obj.managedObjectContext objectWithID:obj.objectID];
//    return obj;
//}

+ (NSManagedObject *)objectForCurrentContext:(NSManagedObject *)obj{
    //not thread save
    if ([obj.managedObjectContext isEqual:[EWDataStore currentContext]]) {
        return obj;
    }
    if (obj == nil) {
        NSLog(@"Passed in nil");
        return nil;
    }
    NSManagedObject * objForCurrentContext = [[EWDataStore currentContext] objectWithID:obj.objectID];
    return objForCurrentContext;
}


+ (void)save{
    
    //save on current thread
    [EWDataStore updateToServerAndSave];
    
    //save on designated thread
    
}

+ (NSManagedObjectContext *)currentContext{
    if ([NSThread isMainThread]) {
        return [NSManagedObjectContext defaultContext];
    }
    else{
        NSLog(@"!!! Accessing context off the main thread");
        return [NSManagedObjectContext contextForCurrentThread];
    }
    return nil;
}


#pragma mark - Server Related Accessor methods
- (NSMutableDictionary *)parseSaveCallbacks{
    if (!parseSaveCallbacks) {
        parseSaveCallbacks = [NSMutableDictionary dictionary];
    }
    return parseSaveCallbacks;
}

- (NSSet *)updateQueue{
    return [[NSUserDefaults standardUserDefaults] valueForKey:kParseQueueUpdate];
}

- (void)setUpdateQueue:(NSSet *)queue{
    [[NSUserDefaults standardUserDefaults] setValue:queue forKey:kParseQueueUpdate];
}

- (NSSet *)insertQueue{
    return [[NSUserDefaults standardUserDefaults] valueForKey:kParseQueueInsert];
}

- (void)setInsertQueue:(NSSet *)queue{
    [[NSUserDefaults standardUserDefaults] setObject:queue forKey:kParseQueueInsert];
}

- (NSSet *)deleteQueue{
    return [[NSUserDefaults standardUserDefaults] valueForKey:kParseQueueDelete];
}

- (void)setDeleteQueue:(NSSet *)queue{
    [[NSUserDefaults standardUserDefaults] setObject:queue forKey:kParseQueueDelete];
}

#pragma mark - Parse Server methods
+(void)updateToServerAndSave{
    
    //get a list of ManagedObject to insert/Update/Delete
    NSMutableArray *insertedManagedObjects = [[NSManagedObjectContext defaultContext].insertedObjects mutableCopy];
    NSMutableArray *updatedManagedObjects = [[NSManagedObjectContext defaultContext].updatedObjects mutableCopy];
    NSMutableArray *deletedManagedObjects = [[NSManagedObjectContext defaultContext].deletedObjects mutableCopy];
    
    //add queue
    [insertedManagedObjects addObjectsFromArray: EWDataStore.sharedInstance.insertQueue.allObjects];
    [updatedManagedObjects addObjectsFromArray: EWDataStore.sharedInstance.updateQueue.allObjects];
    [deletedManagedObjects addObjectsFromArray: EWDataStore.sharedInstance.deleteQueue.allObjects];
    

    //perform network calls
    for (NSManagedObject *managedObject in insertedManagedObjects) {
        [EWDataStore updateParseObjectFromManagedObject:managedObject];
    }
    
    for (NSManagedObject *managedObject in updatedManagedObjects) {
        [EWDataStore updateParseObjectFromManagedObject:managedObject];
    }
    
    for (NSManagedObject *managedObject in deletedManagedObjects) {
        [EWDataStore deleteParseObjectWithManagedObject:managedObject];
    }
    
    //save core data
    [[NSManagedObjectContext defaultContext] saveToPersistentStoreAndWait];
}


+ (void)refreshManagedObject:(NSManagedObject *)managedObject withCompletion:(void (^)(void))block{
    NSString *parseObjectId = [managedObject valueForKey:kParseObjectID];
    if (!parseObjectId) {
        NSLog(@"@@@ Updating a managedObject without a parseID, insert first");
        [EWDataStore updateParseObjectFromManagedObject:managedObject];
        if (block) {
            block();
        }
    }else{
        [[PFQuery queryWithClassName:managedObject.entity.name] getObjectInBackgroundWithId:parseObjectId block:^(PFObject *object, NSError *error) {
            [managedObject updateValueAndRelationFromParseObject:object];
            [[NSManagedObjectContext defaultContext] saveToPersistentStoreAndWait];
            if (block) {
                block();
            }
        }];
    }
}

+ (void)refreshManagedObjectAndWait:(NSManagedObject *)managedObject{
    NSString *parseObjectId = [managedObject valueForKey:kParseObjectID];
    if (!parseObjectId) {
        NSLog(@"@@@ Updating a managedObject without a parseID, insert first");
        [EWDataStore updateParseObjectFromManagedObject:managedObject];
    }else{
        PFObject *object = [[PFQuery queryWithClassName:managedObject.entity.name] getObjectWithId:parseObjectId];
        [managedObject updateValueAndRelationFromParseObject:object];
    }
    
    [[NSManagedObjectContext defaultContext] saveToPersistentStoreAndWait];
}


+ (void)updateParseObjectFromManagedObject:(NSManagedObject *)managedObject{
    NSString *parseObjectId = [managedObject valueForKey:kParseObjectID];
    PFObject *object;
    if (parseObjectId) {
        //update
        NSError *err;
        object = [[PFQuery queryWithClassName:managedObject.entity.name] getObjectWithId:parseObjectId error:&err];
        if (!object) {
            //TODO: handle error
            if ([err code] == kPFErrorObjectNotFound) {
                NSLog(@"Uh oh, we couldn't find the object!");
                // Now also check for connection errors:
                //delete ParseID from MO
                [managedObject setValue:nil forKey:kParseObjectID];
            } else if ([err code] == kPFErrorConnectionFailed) {
                NSLog(@"Uh oh, we couldn't even connect to the Parse Cloud!");
                [managedObject updateEventually];
            } else if (err) {
                NSLog(@"Error: %@", [err userInfo][@"error"]);
                [managedObject updateEventually];
            }
            
            return;
        }
    } else {
        //insert
        object = [PFObject objectWithClassName:managedObject.entity.name];
    }
    
    //set Parse value and store callback block
    [object updateValueFromManagedObject:managedObject];
    //save
    [object saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            NSLog(@"Saved to server: %@", managedObject.entity.name);
            //assign connection between MO and PO
            [managedObject setValue:object.objectId forKey:kParseObjectID];
            [EWDataStore performSaveCallbacksWithParseObject:object andManagedObjectID:managedObject.objectID];
            [[EWDataStore currentContext] save:nil];
        } else {
            NSLog(@"Failed to save server object");
            [managedObject updateEventually];
        }
    }];
    
    //save
    [[NSManagedObjectContext defaultContext] saveToPersistentStoreAndWait];
    
    //remove from queue
    NSMutableArray *updateQueue = EWDataStore.sharedInstance.updateQueue.allObjects.mutableCopy;
    if ([updateQueue containsObject:managedObject.objectID]) {
        [updateQueue removeObject:managedObject.objectID];
    }
    NSMutableArray *insertQueue = [EWDataStore sharedInstance].insertQueue.allObjects.mutableCopy;
    if ([insertQueue containsObject:managedObject.objectID]) {
        [insertQueue removeObject:managedObject.objectID];
    }
    [EWDataStore sharedInstance].updateQueue = [NSSet setWithArray:updateQueue];
    [EWDataStore sharedInstance].insertQueue = [NSSet setWithArray:insertQueue];
}

+ (void)deleteParseObjectWithManagedObject:(NSManagedObject *)managedObject{
    PFQuery *query = [PFQuery queryWithClassName:managedObject.entity.name];
    NSString *parseID = [managedObject valueForKey:kParseObjectID];
    if (parseID) {
        [query getObjectInBackgroundWithId:parseID block:^(PFObject *object, NSError *error) {
            if (error) {
                NSLog(@"Failed to delete Parse Object %@ (%@)", managedObject, parseID);
            }else{
                //delete async
                [object deleteEventually];
                
                //delete MO
                [[NSManagedObjectContext defaultContext] deleteObject:managedObject];
            }
        }];
    }else{
        //delete MO directly
        [[NSManagedObjectContext defaultContext] deleteObject:managedObject];
    }
    
    //remove from queue
    NSMutableArray *deleteQueue = [EWDataStore sharedInstance].deleteQueue.allObjects.mutableCopy;
    if ([deleteQueue containsObject:managedObject.objectID]) {
        [deleteQueue removeObject:managedObject.objectID];
    }
    [EWDataStore sharedInstance].deleteQueue = [NSSet setWithArray:deleteQueue];
}


+ (void)addSaveCallback:(PFObjectResultBlock)callback forManagedObjectID:(NSManagedObjectID *)objectID{
    //get global save callback
    NSMutableDictionary *saveCallbacks = [EWDataStore sharedInstance].parseSaveCallbacks;
    NSMutableArray *callbacks = [saveCallbacks objectForKey:objectID]?:[NSMutableArray array];
    [callbacks addObject:callbacks];
    //save
    [saveCallbacks setObject:callbacks forKey:objectID];
}



+ (void)performSaveCallbacksWithParseObject:(PFObject *)parseObject andManagedObjectID:(NSManagedObjectID *)managedObjectID{
    NSArray *saveCallbacks = [[[EWDataStore sharedInstance] parseSaveCallbacks] objectForKey:managedObjectID];
    if (saveCallbacks) {
        for (PFObjectResultBlock callback in saveCallbacks) {
            callback(parseObject, nil);
        }
        [[EWDataStore sharedInstance].parseSaveCallbacks removeObjectForKey:managedObjectID];
    }
}

+ (NSManagedObject *)getManagedObjectFromParseObject:(PFObject *)object{
    abort();
}

+ (NSManagedObject *)findOrCreateManagedObjectWithEntityName:(NSString *)name withParseObject:(PFObject *)object{
    NSManagedObject *managedObject = [[NSClassFromString(name) findAllWithPredicate:[NSPredicate predicateWithFormat:@"objectId == ", object.objectId]] lastObject];
    if (!managedObject) {
        //if managedObject not exist, create it locally
        managedObject = [NSEntityDescription insertNewObjectForEntityForName:name inManagedObjectContext:[EWDataStore currentContext]];
        [managedObject assignValueFromParseObject:object];
    }
    return managedObject;
}

@end



#pragma mark - Core Data ManagedObject extension
@implementation NSManagedObject (PFObject)
- (void)updateValueAndRelationFromParseObject:(PFObject *)parseObject{
    
    //value
    NSMutableDictionary *mutableAttributeValues = [self.entity.attributesByName mutableCopy];
    //add or delete some attributes here
    [mutableAttributeValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSAttributeDescription *obj, BOOL *stop) {
        @try {
            id parseValue = [parseObject objectForKey:key];
            if ([parseValue isKindOfClass:[PFFile class]]) {
                [self setPFFile:parseValue forPropertyDescription:obj];
            } else {
                [self setValue:parseValue forKey:key];
            }
            
        }
        @catch (NSException *exception) {
            NSLog(@"Exception when assign property [%@] from ParseObject: %@", key, parseObject);
        }
    }];
    
    //realtion
    NSMutableDictionary *relations = [self.entity.relationshipsByName mutableCopy];
    [relations enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSRelationshipDescription *obj, BOOL *stop) {
        
        if ([obj isToMany]) {
            //Fetch PFRelation
            PFRelation *toManyRelation;
            @try{
                toManyRelation = [parseObject valueForKey:key];
            }
            @catch (NSException *exception) {
                NSLog(@"Failed to assign value of key: %@ from Parse Object %@ to ManagedObject %@ \n Error: %@", key, parseObject, self, exception.description);
                return;
            }
            if (!toManyRelation){
                [self setValue:nil forKey:key];
                return;
            }
            
            NSError *err;
            NSArray *relatedParseObjects = [[toManyRelation query] findObjects:&err];
            //TODO: handle error
            if ([err code] == kPFErrorObjectNotFound) {
                NSLog(@"Uh oh, we couldn't find the object!");
                // Now also check for connection errors:
            } else if ([err code] == kPFErrorConnectionFailed) {
                NSLog(@"Uh oh, we couldn't even connect to the Parse Cloud!");
            } else if (err) {
                NSLog(@"Error: %@", [err userInfo][@"error"]);
            }
            
            //delete related MO if not on server relation async
            NSMutableArray *relatedManagedObjects = [[[self valueForKey:key] allObjects] mutableCopy];
            NSArray *managedObjectToDelete = [relatedManagedObjects filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"%@ NOT IN %@", [relatedParseObjects valueForKey:kParseObjectID]]];
            for (NSManagedObject *mo in managedObjectToDelete) {
                [[NSManagedObjectContext defaultContext] deleteObject:mo];
            }
            
            NSMutableSet *relatedMOs = [NSMutableSet set];
            //TODO:background context
            for (PFObject *object in relatedParseObjects) {
                //find corresponding MO
                NSManagedObject *relatedManagedObject = [EWDataStore findOrCreateManagedObjectWithEntityName:obj.entity.name withParseObject:object];
                [relatedMOs addObject:relatedManagedObject];
            }
            [self setValue:relatedMOs forKey:key];
            
            //save
            [self.managedObjectContext save:nil];
            
            
        }else{
            PFObject *relatedParseObject;
            @try {
                relatedParseObject = [parseObject valueForKey:key];
            }
            @catch (NSException *exception) {
                NSLog(@"Failed to assign value of key: %@ from Parse Object %@ to ManagedObject %@ \n Error: %@", key, parseObject, self, exception.description);
                return;
            }
            if (relatedParseObject) {
                //find corresponding MO
                NSManagedObject *relatedManagedObject = [EWDataStore findOrCreateManagedObjectWithEntityName:obj.entity.name withParseObject:relatedParseObject];
                [self setValue:relatedManagedObject forKey:key];
            }else{
                [self setValue:nil forKey:key];
            }
        }
    }];
    
    [self.managedObjectContext save:nil];
}
     
- (void)assignValueFromParseObject:(PFObject *)object{
    //value
    NSMutableDictionary *mutableAttributeValues = [self.entity.attributesByName mutableCopy];
    //add or delete some attributes here
    [mutableAttributeValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSAttributeDescription *obj, BOOL *stop) {
        @try {
            id parseValue = [object objectForKey:key];
            if ([parseValue isKindOfClass:[PFFile class]]) {
                [self setPFFile:parseValue forPropertyDescription:obj];
            } else {
                [self setValue:parseValue forKey:key];
            }
            
        }
        @catch (NSException *exception) {
            NSLog(@"Exception when assign property [%@] from ParseObject: %@", key, object);
        }
    }];
}


- (void)setPFFile:(PFFile *)file forPropertyDescription:(NSAttributeDescription *)attributeDescription{
    [file getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
        if ([attributeDescription.attributeValueClassName isEqualToString:@"UIImage"]) {
            UIImage *img = [UIImage imageWithData:data];
            [self setValue:img forKey:attributeDescription.name];
        }
        else{
            [self setValue:data forKey:attributeDescription.name];
        }
        //TODO: audio and audioKey
        
        NSLog(@"Assign data for key: %@ on %@", attributeDescription.name, self.class);
    }];
    
}


- (void)updateEventually{
    BOOL hasParseObjectLinked = !![self valueForKey:kParseObjectID];
    if (hasParseObjectLinked) {
        NSMutableSet *updateQueue = [[EWDataStore sharedInstance].updateQueue mutableCopy];
        if (!updateQueue) {
            updateQueue = [NSMutableSet set];
        }
        [updateQueue addObject:self.objectID];
        [EWDataStore sharedInstance].updateQueue = updateQueue;
    }else{
        NSMutableSet *insertQueue = [[EWDataStore sharedInstance].insertQueue mutableCopy];
        if (!insertQueue) {
            insertQueue = [NSMutableSet set];
        }
        [insertQueue addObject:self.objectID];
        [EWDataStore sharedInstance].insertQueue = insertQueue;
    }
    
}

- (void)deleteEventually{
    BOOL hasParseObjectLinked = !![self valueForKey:kParseObjectID];
    if (hasParseObjectLinked) {
        NSMutableSet *deleteQueue = [[EWDataStore sharedInstance].deleteQueue mutableCopy];
        if (!deleteQueue) {
            deleteQueue = [NSMutableSet set];
        }
        [deleteQueue addObject:self.objectID];
        [EWDataStore sharedInstance].deleteQueue = deleteQueue;
    }else{
        NSLog(@"@@@ You are trying to delete an ManagedObject that doesn't have a corresponding Server Object.");
    }
}

@end

#pragma mark - Parse Object extension
@implementation PFObject (NSManagedObject)
- (void)updateValueFromManagedObject:(NSManagedObject *)managedObject{
    //value
    NSMutableDictionary *mutableAttributeValues = [managedObject.entity.attributesByName mutableCopy];
    [mutableAttributeValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSAttributeDescription *obj, BOOL *stop) {
        id value = [managedObject valueForKey:key];
        if (value) {
            [self setObject:value forKey:key];
        } else {
            [self removeObjectForKey:key];
        }
    }];
    
    //relation
    NSMutableDictionary *mutableRelationships = [managedObject.entity.relationshipsByName mutableCopy];
    [mutableRelationships enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSRelationshipDescription *obj, BOOL *stop) {
        NSSet *relatedManagedObject = [managedObject valueForKey:key];
        if (relatedManagedObject){
            if ([obj isToMany]) {
                //To-Many relation
                //Parse relation
                PFRelation *parseRelation = [self relationForKey:key];
                //Find related PO to delete async
                [[parseRelation query] findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
                    NSMutableArray *relatedParseObjects = [objects mutableCopy];
                    if (relatedParseObjects.count) {
                        NSArray *relatedParseObjectsToDelete = [relatedParseObjects filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"objectId NOT IN %@", [relatedManagedObject valueForKey:@"objectId"]]];
                        for (PFObject *PO in relatedParseObjectsToDelete) {
                            [parseRelation removeObject:PO];
                        }
                    }
                }];
                
                //related managedObject that needs to add
                NSSet *relatedMOs = [managedObject valueForKey:key];
                for (NSManagedObject *relatedManagedObject in relatedMOs) {
                    NSString *parseID = [relatedManagedObject valueForKey:kParseObjectID];
                    if (parseID) {
                        //the pfobject already exists, need to inspect PFRelation to determin add or remove
                        PFObject *relatedParseObject = [PFObject objectWithoutDataWithClassName:obj.entity.name objectId:parseID];
                        //[relatedParseObject fetchIfNeeded];
                        [parseRelation addObject:relatedParseObject];
                        
                    } else {
                        __block PFObject *blockObject = self;
                        __block PFRelation *blockParseRelation = parseRelation;
                        //set up a saving block
                        PFObjectResultBlock connectRelationship = ^(PFObject *object, NSError *error) {
                            //the relation can only be additive, which is not a problem for new relation
                            [blockParseRelation addObject:object];
                            [blockObject saveInBackground];
                        };
                        
                        //add to global save callback distionary
                        [EWDataStore addSaveCallback:connectRelationship forManagedObjectID:managedObject.objectID];

                        
                    }
                }
            } else {
                //TO-One relation
                NSManagedObject *relatedManagedObject = [managedObject valueForKey:key];
                NSString *parseID = [relatedManagedObject valueForKey:kParseObjectID];
                if (!parseID) {
                    PFObject *relatedParseObject = [PFObject objectWithoutDataWithClassName:managedObject.entity.name objectId:parseID];
                    [self setObject:relatedParseObject forKey:key];
                }else{
                    //MO doesn't have parse id, save to parse
                    __block PFObject *blockObject = self;
                    //set up a saving block
                    PFObjectResultBlock connectRelationship = ^(PFObject *object, NSError *error) {
                        [blockObject setObject:object forKey:obj.entity.name];
                        [blockObject saveEventually];//relationship can be saved regardless of network condition.
                    };
                    //add to global save callback distionary
                    [EWDataStore addSaveCallback:connectRelationship forManagedObjectID:managedObject.objectID];
                }
            }
        }
        
    }];
    //Only save when network is available so that MO can link with PO
    //[self saveEventually];
}
@end


