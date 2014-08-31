//
//  EWServer.m
//  EarlyWorm
//
//  Translate client requests to server custom code, providing a set of tailored APIs to client coding environment.
//
//  Created by Lee on 2/21/14.
//  Copyright (c) 2014 Shens. All rights reserved.
//

#import "EWServer.h"
#import "UIAlertView+.h"

//model
#import "EWDataStore.h"
#import "EWPersonStore.h"
#import "EWTaskItem.h"
#import "EWTaskStore.h"
#import "EWMediaItem.h"
#import "EWMediaStore.h"
#import "EWDownloadManager.h"
#import "EWNotification.h"
#import "EWNotificationManager.h"
#import "EWWakeUpManager.h"

//view
#import "EWWakeUpViewController.h"
#import "EWAppDelegate.h"
#import "AVManager.h"
#import "UIAlertView+.h"
#import "EWSleepViewController.h"

//Tool
#import "EWUIUtil.h"

@implementation EWServer

+ (EWServer *)sharedInstance{
    static EWServer *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[EWServer alloc] init];
    });
    return manager;
}



#pragma mark - Handle Push Notification
+ (void)handlePushNotification:(NSDictionary *)pushInfo{
    NSString *type = pushInfo[kPushTypeKey];
    BOOL isBuzz = [type isEqualToString:kPushTypeBuzzKey];
    BOOL isVoice = [type isEqualToString:kPushTypeMediaKey];
    BOOL isNotification = [type isEqualToString:kPushTypeNotificationKey];
    BOOL isAlarmTimer = [type isEqualToString:kPushTypeTimerKey];
    if (isNotification) {
        [EWNotificationManager handleNotification: pushInfo[kPushNofiticationIDKey]];
    }else if(isBuzz || isVoice){
        [EWWakeUpManager handlePushNotification:pushInfo];
    }else if (isAlarmTimer){
        [EWWakeUpManager handlePushNotification:pushInfo];
    }else{
        NSString *str = [NSString stringWithFormat:@"Unknown push: %@", pushInfo];
        EWAlert(str);
    }
}

#pragma mark - Handle Local Notification
+ (void)handleLocalNotification:(UILocalNotification *)notification{
    NSString *type = notification.userInfo[kLocalNotificationTypeKey];
    NSLog(@"Received local notification: %@", type);
    
    if ([type isEqualToString:kLocalNotificationTypeAlarmTimer]) {
        [EWWakeUpManager handleAlarmTimerEvent:notification.userInfo];
    }else if([type isEqualToString:kLocalNotificationTypeReactivate]){
        NSLog(@"==================> Reactivated Woke <======================");
        EWAlert(@"You brought me back to life!");
    }else if ([type isEqualToString:kLocalNotificationTypeSleepTimer]){
        NSLog(@"Entering sleep mode...");
        if (me) {
            //logged in enter sleep mode
            EWSleepViewController *controller = [[EWSleepViewController alloc] initWithNibName:nil bundle:nil];
            [rootViewController presentViewControllerWithBlurBackground:controller];
        }else{
            [[NSNotificationCenter defaultCenter] addObserverForName:kPersonLoggedIn object:nil queue:nil usingBlock:^(NSNotification *note) {
                EWSleepViewController *controller = [[EWSleepViewController alloc] initWithNibName:nil bundle:nil];
                [rootViewController presentViewControllerWithBlurBackground:controller];
                [[NSNotificationCenter defaultCenter] removeObserver:self name:kPersonLoggedIn object:nil];
            }];
        }
    }
    else{
        NSLog(@"Unexpected Local Notification Type. Detail: %@", notification);
    }

}

#pragma mark - Push buzz

+ (void)buzz:(NSArray *)users{
    //delayed hide
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [MBProgressHUD hideAllHUDsForView:rootViewController.view animated:YES];
    });
    [MBProgressHUD showHUDAddedTo:rootViewController.view animated:YES];
    
    for (EWPerson *person in users) {
        //get next wake up time
        NSDate *time = [[EWTaskStore sharedInstance] nextWakeUpTimeForPerson:person];
        //create buzz
        EWMediaItem *buzz = [[EWMediaStore sharedInstance] createBuzzMedia];
        //add receiver: single direction
        [buzz addReceiversObject:person];
        //add sound
        NSString *sound = me.preference[@"buzzSound"]?:@"default";
        buzz.buzzKey = sound;
        
        [EWDataStore saveWithCompletion:^{
            NSParameterAssert(buzz.objectId);
            
            //push payload
            NSMutableDictionary *pushMessage = [@{@"content-available": @1,
                                          @"badge": @"Increment",
                                          kPushMediaKey: buzz.objectId,
                                          kPushTypeKey: kPushTypeBuzzKey} mutableCopy];
            
            
            if ([[NSDate date] isEarlierThan:time]) {
                //before wake up
                //silent push
                
                
            }else if (time.timeElapsed < kMaxWakeTime){
                //struggle state
                //send push notification, The payload can consist of the alert, badge, and sound keys.
                
                NSString *buzzType = buzz.buzzKey;
                NSDictionary *sounds = buzzSounds;
                NSString *buzzSound = sounds[buzzType];
                
                pushMessage[@"alert"] = @"Someone has sent you an buzz";
                pushMessage[@"sound"] = buzzSound;
                
            }else{
                
                //tomorrow's task
                //silent push
            }
            
            //send
            [EWServer parsePush:pushMessage toUsers:@[person] completion:^(BOOL succeeded, NSError *error) {
                if (succeeded) {
                    [rootViewController.view showSuccessNotification:@"Sent"];
                }else{
                    NSLog(@"Send push message about media %@ failed. Reason:%@", buzz.objectId, error.description);
                    [rootViewController.view showFailureNotification:@"Failed"];
                }
            }];
        }];
        
    }
    
}

#pragma mark - Send Voice tone
+ (void)pushMedia:(EWMediaItem *)media ForUser:(EWPerson *)person{
    
    NSString *mediaId = media.objectId;
    NSDate *time = [[EWTaskStore sharedInstance] nextWakeUpTimeForPerson:person];
    
    NSMutableDictionary *pushMessage = [@{@"badge": @"Increment",
                                 @"alert": @"Someone has sent you an voice greeting",
                                 @"content-available": @1,
                                 kPushTypeKey: kPushTypeMediaKey,
                                 kPushPersonKey: me.objectId,
                                 kPushMediaKey: mediaId} mutableCopy];
    
    //form push payload
    if ([[NSDate date] isEarlierThan:time]) {
        //early, silent message

    }else if(time.timeElapsed < kMaxWakeTime){
        //struggle state
        pushMessage[@"sound"] = @"media.caf";
        pushMessage[@"alert"] = @"Someone has sent you an voice greeting";
        
    }else{
        //send silent push for next task
        
    }
    
    //push
    [EWServer parsePush:pushMessage toUsers:@[person] completion:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            [rootViewController.view showSuccessNotification:@"Sent"];
        }else{
            NSLog(@"Send push message about media %@ failed. Reason:%@", mediaId, error.description);
            [rootViewController.view showFailureNotification:@"Failed"];
        }
    }];
    
    //save
    [EWDataStore save];
    
}



+ (void)broadcastMessage:msg onSuccess:(void (^)(void))block onFailure:(void (^)(void))failureBlock{
    
    NSDictionary *payload = @{@"alert": msg};
    
    PFQuery *pushQuery = [PFInstallation query];
    [pushQuery whereKeyExists:@"username"];
    PFPush *push = [PFPush new];
    [push setQuery:pushQuery];
    [push setData:payload];
    block = block?:NULL;
    [push sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded && block) {
            block();
        }else if (failureBlock){
            NSLog(@"Failed to broadcast push message: %@", error.description);
            failureBlock();
        }
    }];
}


#pragma mark - Parse Push
+ (void)parsePush:(NSDictionary *)pushPayload toUsers:(NSArray *)users completion:(PFBooleanResultBlock)block{
    
    NSArray *userIDs = [users valueForKey:kUsername];
    PFQuery *pushQuery = [PFInstallation query];
    [pushQuery whereKey:kUsername containedIn:userIDs];
    PFPush *push = [PFPush new];
    [push setQuery:pushQuery];
    [push setData:pushPayload];
    block = block?:NULL;
    //[push sendPushInBackgroundWithBlock:block];
    [push sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        block(succeeded, error);
    }];
}


#pragma mark - PUSH

+ (void)registerAPNS{
    //push
#if TARGET_IPHONE_SIMULATOR
    //Code specific to simulator
#else
    //pushClient = [[SMPushClient alloc] initWithAPIVersion:@"0" publicKey:kStackMobKeyDevelopment privateKey:kStackMobKeyDevelopmentPrivate];
    //register everytime in case for events like phone replacement
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeNewsstandContentAvailability | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound];
#endif
}

+ (void)registerPushNotificationWithToken:(NSData *)deviceToken{
    
    //Parse: Store the deviceToken in the current Installation and save it to Parse.
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation setDeviceTokenFromData:deviceToken];
    [currentInstallation saveInBackground];
}


+(void)searchForFriendsOnServer
{
    PFQuery *q = [PFQuery queryWithClassName:@"User"];
    
    [q whereKey:@"email" containedIn:[EWUtil readContactsEmailsFromAddressBooks]];
    
    [q findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            
            // push  notification;
            
            
        } else {
            // Log details of the failure
            NSLog(@"Error: %@ %@", error, [error userInfo]);
        }
    }];
    
}

+(void)publishOpenGraphUsingAPICallsWithObjectId:(NSString *)objectId{
    
    // We will post a story on behalf of the user
    // These are the permissions we need:
    NSArray *permissionsNeeded = @[@"publish_actions"];
    
    // Request the permissions the user currently has
    [FBRequestConnection startWithGraphPath:@"/me/permissions"
                          completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                              if (!error){
                                  NSDictionary *currentPermissions= [(NSArray *)[result data] objectAtIndex:0];
                                  NSLog(@"current permissions %@", currentPermissions);
                                  NSMutableArray *requestPermissions = [[NSMutableArray alloc] initWithArray:@[]];
                                  
                                  // Check if all the permissions we need are present in the user's current permissions
                                  // If they are not present add them to the permissions to be requested
                                  for (NSString *permission in permissionsNeeded){
                                      if (![currentPermissions objectForKey:permission]){
                                          [requestPermissions addObject:permission];
                                      }
                                  }
                                  
                                  // If we have permissions to request
                                  if ([requestPermissions count] > 0){
                                      // Ask for the missing permissions
                                      [FBSession.activeSession requestNewPublishPermissions:requestPermissions
                                                                            defaultAudience:FBSessionDefaultAudienceFriends
                                                                          completionHandler:^(FBSession *session, NSError *error) {
                                                                              if (!error) {
                                                                                  // Permission granted
                                                                                  NSLog(@"new permissions %@", [FBSession.activeSession permissions]);
                                                                                  // We can request the user information
                                                          [EWServer makeRequestToPostStoryWithId:objectId];
                                                        //upload a graph and form a OG story
                                                                                  
                                                                              } else {
                                                                                  // An error occurred, we need to handle the error
                                                                                  // Check out our error handling guide: https://developers.facebook.com/docs/ios/errors/
                                                                                  NSLog(@"error %@", error.description);
                                                                              }
                                                                          }];
                                  } else {
                                      // Permissions are present
                                      // We can request the user information
                                      
                                      [EWServer makeRequestToPostStoryWithId:objectId];
                                       //upload a graph and form a OG story
                                  }
                                  
                              } else {
                                  // An error occurred, we need to handle the error
                                  // Check out our error handling guide: https://developers.facebook.com/docs/ios/errors/
                                  NSLog(@"error %@", error.description);
                              }
                          }];

    
    
}







+(void)updatingStatusInFacebook:(NSString *)status
{
    // NOTE: pre-filling fields associated with Facebook posts,
    // unless the user manually generated the content earlier in the workflow of your app,
    // can be against the Platform policies: https://developers.facebook.com/policy
    
    [FBRequestConnection startForPostStatusUpdate:status
                                completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                                    if (!error) {
                                        // Status update posted successfully to Facebook
                                        NSLog(@"result: %@", result);
                                        
                                    } else {
                                        // An error occurred, we need to handle the error
                                        // See: https://developers.facebook.com/docs/ios/errors
                                        NSLog(@"%@", error.description);
                                    }
                                }];
}

+(void)uploadOGStoryWithPhoto:(UIImage *)image

{
    
    [FBRequestConnection startForUploadStagingResourceWithImage:image completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        __block NSString *alertText;
        __block NSString *alertTitle;
        if(!error) {
            
            NSLog(@"Successfuly staged image with staged URI: %@", [result objectForKey:@"uri"]);
            
            // Package image inside a dictionary, inside an array like we'll need it for the object
            NSArray *image = @[@{@"url": [result objectForKey:@"uri"], @"user_generated" : @"true" }];
            
            // Create an object
            NSMutableDictionary<FBOpenGraphObject> *place = [FBGraphObject openGraphObjectForPost];
            
            // specify that this Open Graph object will be posted to Facebook
            place.provisionedForPost = YES;
            
            // Add the standard object properties
            place[@"og"] = @{ @"title":@"mytitle", @"type":@"restaurant.restaurant", @"description":@"my description", @"image":image };
            
            // Add the properties restaurant inherits from place
            place[@"place"] = @{ @"location" : @{ @"longitude": @"-58.381667", @"latitude":@"-34.603333"} };
            
            // Add the properties particular to the type restaurant.restaurant
            place[@"restaurant"] = @{@"category": @[@"Mexican"],
                                          @"contact_info": @{@"street_address": @"123 Some st",
                                                             @"locality": @"Menlo Park",
                                                             @"region": @"CA",
                                                             @"phone_number": @"555-555-555",
                                                             @"website": @"http://www.example.com"}};
            
            // Make the Graph API request to post the object
            FBRequest *request = [FBRequest requestForPostWithGraphPath:@"me/objects/restaurant.restaurant"
                                                            graphObject:@{@"object":place}];
            [request startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                if (!error) {
                    // Success! Include your code to handle the results here
                    NSLog(@"result: %@", result);
                   NSString *  _objectID = [result objectForKey:@"id"];
                    alertTitle = @"Object successfully created";
                    alertText = [NSString stringWithFormat:@"An object with id %@ has been created", _objectID];
                    [[[UIAlertView alloc] initWithTitle:alertTitle
                                                message:alertText
                                               delegate:self
                                      cancelButtonTitle:@"OK!"
                                      otherButtonTitles:nil] show];
                    
                } else {
                    // An error occurred, we need to handle the error
                    // Check out our error handling guide: https://developers.facebook.com/docs/ios/errors/
                    NSLog(@"error %@", error.description);
                }
            }];
        } else {
            // An error occurred, we need to handle the error
            // Check out our error handling guide: https://developers.facebook.com/docs/ios/errors/
            NSLog(@"error %@", error.description);
        }
    }];

}

+(void)makeRequestToPostStoryWithId:(NSString *)objectId
{
    if(!objectId){
        [[[UIAlertView alloc] initWithTitle:@"Error"
                                    message:@"Please tap the \"Post an object\" button first to create an object, then you can click on this button to like it."
                                   delegate:self
                          cancelButtonTitle:@"OK!"
                          otherButtonTitles:nil] show];
    } else {
        // Create a like action
        id<FBOpenGraphAction> action = (id<FBOpenGraphAction>)[FBGraphObject graphObject];
        
        // Link that like action to the restaurant object that we have created
        [action setObject:objectId forKey:@"object"];
        
        // Post the action to Facebook
        [FBRequestConnection startForPostWithGraphPath:@"me/og.likes"
                                           graphObject:action
                                     completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                                         __block NSString *alertText;
                                         __block NSString *alertTitle;
                                         if (!error) {
                                             // Success, the restaurant has been liked
                                             NSLog(@"Posted OG action, id: %@", [result objectForKey:@"id"]);
                                             alertText = [NSString stringWithFormat:@"Posted OG action, id: %@", [result objectForKey:@"id"]];
                                             alertTitle = @"Success";
                                             [[[UIAlertView alloc] initWithTitle:alertTitle
                                                                         message:alertText
                                                                        delegate:self
                                                               cancelButtonTitle:@"OK!"
                                                               otherButtonTitles:nil] show];
                                         } else {
                                             // An error occurred, we need to handle the error
                                             // Check out our error handling guide: https://developers.facebook.com/docs/ios/errors/
                                             NSLog(@"error %@", error.description);
                                         }
                                     }];
        
    }
}


@end
