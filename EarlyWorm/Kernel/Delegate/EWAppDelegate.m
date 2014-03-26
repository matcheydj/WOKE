//
//  EWAppDelegate.m
//  EarlyWorm
//
//  Created by shenslu on 13-7-11.
//  Copyright (c) 2013年 Shens. All rights reserved.
//

#import "EWAppDelegate.h"

//view controller
#import "EWAlarmsViewController.h"
#import "EWSocialViewController.h"
#import "EWSettingsViewController.h"
#import "EWWakeUpViewController.h"
#import "EWAlarmManager.h"
#import "EWTaskStore.h"
#import "EWPersonStore.h"
#import "EWWakeUpManager.h"

//tools
#import "TestFlight.h"
#import "FSAudioStream.h"
#import "AVManager.h"
#import "UIViewController+Blur.h"

//model
#import "EWTaskItem.h"
#import "EWMediaItem.h"
#import "EWDownloadManager.h"
#import "EWServer.h"
#import "EWUserManagement.h"
#import "EWDataStore.h"

//global view for HUD
UIViewController *rootViewController;

//Private
@interface EWAppDelegate(){
    EWTaskItem *taskInAction;
    NSTimer *myTimer;
    long count;
    FSAudioStream *_audioStream;
}

@property (nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic, strong) NSMutableArray *musicList;

@end


@implementation EWAppDelegate
@synthesize backgroundTaskIdentifier;
//@synthesize myTimer;
//@synthesize count;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    //test flight
    [TestFlight takeOff:TESTFLIGHT_ACCESS_KEY];
    
    //background fetch
    [application setMinimumBackgroundFetchInterval:7200]; //fetch interval: 2hr
    
    //window
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    EWAlarmsViewController *controler = [[EWAlarmsViewController alloc] init];
    self.window.rootViewController = controler;
    rootViewController = self.window.rootViewController;
    
    //local notification entry
    if (launchOptions) {
        UILocalNotification *localNotif = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
        NSDictionary *remoteNotif = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
        //Let server class to handle notif info
        if (localNotif) {
            NSLog(@"Launched with local notification: %@", localNotif);
            [EWWakeUpManager handleAppLaunchNotification:localNotif];
        }else if (remoteNotif){
            NSLog(@"Launched with push notification: %@", remoteNotif);
            [EWWakeUpManager handleAppLaunchNotification:remoteNotif];
        }
    }
    
    
    //window
    [self.window makeKeyAndVisible];
    
    //init coredata and backend server
    [EWDataStore sharedInstance];
    
    //User login
    [[EWUserManagement sharedInstance] login];
    
    

    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    
    [MBProgressHUD hideAllHUDsForView:rootViewController.view animated:YES];
    NSLog(@"Canceled HUD");
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    NSLog(@"Entered background with active time left: %f", application.backgroundTimeRemaining);
    
    //detect multithreading
    BOOL result = NO;
    if ([[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)]){
        result = [[UIDevice currentDevice] isMultitaskingSupported];
    }if (!result) {
        return;
    }
    
    //responder to remote control
    [[AVManager sharedManager] prepareRemoteControlEventsListener];

#ifdef BACKGROUND_TEST
    
    //开启一个后台任务
    backgroundTaskIdentifier = [application beginBackgroundTaskWithExpirationHandler:^{
        
        NSLog(@"The first BG task will end (%ld)", count);
    }];
    
    // keep active
    if ([myTimer isValid]) [myTimer invalidate];
    myTimer = [NSTimer scheduledTimerWithTimeInterval:100 target:self selector:@selector(keepAlive:) userInfo:nil repeats:YES];
    NSLog(@"Scheduled background task when app enters background with time left: %f", application.backgroundTimeRemaining);
#endif
    
    application.applicationIconBadgeNumber = 0;
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    
    //[[UIApplication sharedApplication] clearKeepAliveTimeout];
    
    
    if (backgroundTaskIdentifier != UIBackgroundTaskInvalid){
        //end background task
        [application endBackgroundTask:backgroundTaskIdentifier];
        //stop timer
        if ([myTimer isValid]) [myTimer invalidate];
    }
    
    NSLog(@"Entered foreground and cleaned bgID and timer");
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [FBSession.activeSession handleDidBecomeActive];
    
    //audio session
    [[AVManager sharedManager] registerAudioSession];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    //[FBSession.activeSession close];
    NSLog(@"App is about to terminate");
//    backgroundTaskIdentifier = [application beginBackgroundTaskWithExpirationHandler:^{
//        NSLog(@"%ld", count++);
//    }];
}


#pragma mark - Weibo
/*
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    return [WeiboSDK handleOpenURL:url delegate:self];
}*/

#pragma mark - Facebook
- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    
    return [FBSession.activeSession handleOpenURL:url];
}



#pragma mark - Background fetch method (this is called periodocially
-(void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    NSLog(@"======== Launched in background due to background fetch event ==========");
    //enable audio session and keep audio port
    //[[AVManager sharedManager] registerAudioSession];
    [[AVManager sharedManager] playSystemSound:nil];
    
    for (EWTaskItem *task in currentUser.tasks) {
        
        //refresh
        [context refreshObject:task mergeChanges:YES];
        
        //check
        if ([lastChecked isEarlierThan:task.lastmoddate]) {
            NSLog(@"Find task on %@ has possible updates", task.time.weekday);
            [[AVManager sharedManager] playSoundFromFile:@"tock.caf"];
            
            //download
            [[EWDownloadManager sharedInstance] downloadTask:task withCompletionHandler:NULL];
        }
    }
    
    //update checked time
    lastChecked = [NSDate date];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"Returned background fetch handler");
        completionHandler(UIBackgroundFetchResultNewData);
    });
    
}

//Keep alive
- (void) keepAlive:(NSTimer *)paramSender{
    
    UIApplication *application = [UIApplication sharedApplication];
    
    //结束旧的后台任务
    [application endBackgroundTask:backgroundTaskIdentifier];
    
    //开启一个新的后台
    NSInteger ct = count;
    backgroundTaskIdentifier = [application beginBackgroundTaskWithExpirationHandler:^{
        NSLog(@"BG task will end (%ld)", (long)ct);
    }];
    
    //check time
    EWTaskItem *task = [[EWTaskStore sharedInstance] nextTaskForPerson:currentUser];
    
    //alarm time up
    NSTimeInterval timeLeft = [task.time timeIntervalSinceNow];
    if (timeLeft < 100 && timeLeft > 0) {
        NSLog(@"About to imit alart timer in %fs, schedule a timer",timeLeft);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((timeLeft - 1) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [EWWakeUpManager handleAlarmTimerEvent];
        });
    }
    
    
    NSLog(@"Background task is still working with time left %f (%ld)",[UIApplication sharedApplication].backgroundTimeRemaining , count++);

}

- (BOOL) isMultitaskingSupported {
    
    BOOL result = NO;
    
    if ([[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)]){
        result = [[UIDevice currentDevice] isMultitaskingSupported];
    }
    return result;
}

#pragma mark - Push Notification registration
//Presist the device token
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken{
    NSString *token = [[deviceToken description] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
    token = [[token componentsSeparatedByString:@" "] componentsJoinedByString:@""];//become a string
    
    // Persist token
    /*
     userDefaults{
        kPushTokenDicKey: {
            username: token,
            ...
        }
        kAWSEndPointDicKey: {
            username: ARN,
            ...
        }
        ...
     }
     */
    NSString *username = currentUser.username;
    if(!username) [NSException raise:@"User didn't log in" format:@"Check your login sequense"];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *tokenByUserDic = [NSMutableDictionary dictionaryWithDictionary:[defaults objectForKey:kPushTokenDicKey]];
    //determin if user exsits
    NSString *token_old = [tokenByUserDic objectForKey:username];
    if (!token_old || ![token_old isEqualToString:token]) {
        //new token
        [tokenByUserDic setObject:token forKey:username];
        //save
        [defaults setObject:tokenByUserDic forKey:kPushTokenDicKey];
        [defaults synchronize];
    }
    
    //Register Push on StackMob
    [[EWUserManagement sharedInstance] registerPushNotification];
    NSLog(@"Registered device token: %@", token);
    
    
    //AWS
    NSMutableDictionary *arnByUserDic = [[defaults objectForKey:kAWSEndPointDicKey] mutableCopy];
    //NSMutableDictionary *topicByUserDic = [[defaults objectForKey:kAWSTopicDicKey] mutableCopy];
    NSString *endPoint = arnByUserDic[username];
    //NSString *topicArn = topicByUserDic[username];
    if (!endPoint/* || !topicArn*/) {
        //create endPint (user)
        SNSCreatePlatformEndpointRequest *request = [[SNSCreatePlatformEndpointRequest alloc] init];
        request.token = token;
        request.customUserData = currentUser.username;
        request.platformApplicationArn = AWS_SNS_APP_ARN;
        SNSCreatePlatformEndpointResponse *response;
        NSString *endPointARN;
        @try {
            response = [snsClient createPlatformEndpoint:request];
        }
        @catch (NSException *exception) {
            
            if ([exception isKindOfClass:[SNSInvalidParameterException class]]) {
                //SNSInvalidParameterException *aws_e = (SNSInvalidParameterException *)exception;
                NSString *des = exception.description;
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"arn:aws.*?\\s"
                                                                                       options:NSRegularExpressionCaseInsensitive
                                                                                         error:NULL];
                NSRange result = [regex rangeOfFirstMatchInString:des options:0 range:NSMakeRange(0, [des length])];
                NSString *endPointNew = [des substringWithRange:result];
                //register the endpoint arn to user
                if (result.length > 0) {
                    endPointNew = [endPointNew stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    NSLog(@"Intercepted endpointArn: %@", endPointNew);
                    currentUser.aws_id = endPointNew;
                    
                    //update endPoint user info
                    SNSSetEndpointAttributesRequest *request = [[SNSSetEndpointAttributesRequest alloc] init];
                    request.endpointArn = endPointNew;
                    [request setAttributesValue:username forKey:@"CustomUserData"];
                    [snsClient setEndpointAttributes:request];
                    NSLog(@"EndPoint updated");
                    
                    //save to local
                    arnByUserDic[username] = endPointARN;
                    [defaults setObject:arnByUserDic forKey:kAWSEndPointDicKey];
                    
                }else{
                    @throw exception;
                }
            }else{
                NSLog(@"%@", exception);
                return;
            }
        }

        if (response) {
            endPointARN = response.endpointArn;
            currentUser.aws_id = endPointARN;
            NSLog(@"Created endpoint on AWS: %@", endPointARN);
        }
        
        //save defaults
        [arnByUserDic setObject:endPointARN forKey:username];
        [defaults setObject:arnByUserDic forKey:kAWSEndPointDicKey];
        [defaults synchronize];
        
        //sync
        [context refreshObject:currentUser mergeChanges:YES];
    }else{
        //found endPoint saved at local
        NSLog(@"found endPoint: %@ for user: %@", endPoint, username);
    }
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    //[NSException raise:@"Failed to regiester push token with apple" format:@"Reason: %@", err.description];
    NSLog(@"Failed to regiester push token with apple. Error: %@", err.description);
    NSString *str = [NSString stringWithFormat:@"Unable to regiester Push Notifications. Reason: %@", err.localizedDescription];
    EWAlert(str);
}

//entrance of Local Notification
- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification{
    NSLog(@"Received local notification: %@", notification);
    if ([application applicationState] == UIApplicationStateActive) {
        UIAlertView *alert = [[UIAlertView alloc]
                              initWithTitle:@"Woke Alarm"
                              message:@"It's time to get up!"
                              delegate:self
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil];
        [alert show];
    } else {
        NSLog(@"Entered by local notification");
        /*
        if (self.musicList.count > 0) {
            [self playDownloadedMusic:[self.musicList objectAtIndex:self.musicList.count-1]];
        }*/
        NSString *taskID = [notification.userInfo objectForKey:kPushTaskKey];
        NSLog(@"The task is %@", taskID);
        EWWakeUpViewController *controller = [[EWWakeUpViewController alloc] init];
        controller.task = [[EWTaskStore sharedInstance] getTaskByID:taskID];
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:controller];
        [self.window.rootViewController presentViewController:navigationController animated:YES completion:^(void){}];
    }
}
/*
//normal handler for remote notification
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo{
    if ([application applicationState] == UIApplicationStateActive) {
        NSLog(@"%s: Push received when app is running: %@", __func__, userInfo);
    }else{
        NSLog(@"%s: Push received when app is in %d : %@", __func__, application.applicationState, userInfo);
    }
}*/

//Receive remote notification in background or in foreground
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler{
    
    if ([application applicationState] == UIApplicationStateActive) {
        NSLog(@"Push Notification received when app is running: %@", userInfo);
    }else{
        NSLog(@"Push Notification received when app is in background(%ld): %@", (long)application.applicationState, userInfo);
    }
    
    //handle push
    [EWWakeUpManager handlePushNotification:userInfo];
    
    //return handler
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"@@@@@@@ Push conpletion handle returned. @@@@@@@@@");
        completionHandler(UIBackgroundFetchResultNewData);
    });
}

#pragma mark - Background transfer event

//Store the completion handler. The completion handler is invoked by the view controller's checkForAllDownloadsHavingCompleted method (if all the download tasks have been completed).
- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
{
    NSLog(@"%s: APP received message and need to handle the background transfer events", __func__);
    //store the completionHandler
    EWDownloadManager *manager = [EWDownloadManager sharedInstance];
	manager.backgroundSessionCompletionHandler = completionHandler;
}

@end

/*
@implementation EWAppDelegate (DownloadMgr)

- (void)EWDownloadMgr:(EWDownloadMgr *)mgr didFailedDownload:(NSError *)error {
    
}

- (void)EWDownloadMgr:(EWDownloadMgr *)mgr didFinishedDownload:(NSData *)result {
    NSLog(@"Dowload Success %@, %@ ",mgr.description, mgr.urlString);
    
    [self handleDownlownedData:result fromManager:mgr];
}

- (void)EWDownloadMgr:(EWDownloadMgr *)mgr didFinishedDownloadString:(NSString *)resultString{
    //
}

- (void)EWDownloadMgr:(EWDownloadMgr *)mgr didFinishedDownloadData:(NSData *)resultData{
    //
}
@end
*/
