//
//  EWAppDelegate.m
//  EarlyWorm
//
//  Created by shenslu on 13-7-11.
//  Copyright (c) 2013年 Shens. All rights reserved.
//

#import "EWAppDelegate.h"
//#define MR_SHORTHAND
#define MR_LOGGING_ENABLED 0
//view controller
#import "EWAlarmsViewController.h"
#import "EWSettingsViewController.h"
#import "EWWakeUpViewController.h"
#import "EWAlarmManager.h"
#import "EWTaskStore.h"
#import "EWPersonStore.h"
#import "EWWakeUpManager.h"

//tools
#import "TestFlight.h"
#import "TestFlight+ManualSessions.h"
#import "AVManager.h"
#import "UIViewController+Blur.h"
#import <Parse/Parse.h>

//model
#import "EWTaskItem.h"
#import "EWMediaItem.h"
#import "EWMediaStore.h"
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
}

@property (nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic, strong) NSMutableArray *musicList;

@end


@implementation EWAppDelegate
@synthesize backgroundTaskIdentifier;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    //test flight
    [TestFlight setOptions:@{ TFOptionManualSessions : @YES }];
    [TestFlight takeOff:TESTFLIGHT_ACCESS_KEY];
    [TestFlight manuallyStartSession];
    
    //Parse
    [Parse setApplicationId:@"p1OPo3q9bY2ANh8KpE4TOxCHeB6rZ8oR7SrbZn6Z"
                  clientKey:@"9yfUenOzHJYOTVLIFfiPCt8QOo5Ca8fhU8Yqw9yb"];
    //Analytics
    if (application.applicationState != UIApplicationStateBackground) {
        // Track an app open here if we launch with a push, unless
        // "content_available" was used to trigger a background push (introduced
        // in iOS 7). In that case, we skip tracking here to avoid double
        // counting the app-open.
        BOOL preBackgroundPush = ![application respondsToSelector:@selector(backgroundRefreshStatus)];
        BOOL oldPushHandlerOnly = ![self respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)];
        BOOL noPushPayload = ![launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
        if (preBackgroundPush || oldPushHandlerOnly || noPushPayload) {
            [PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];
        }
    }
    
    
    //background fetch
    [application setMinimumBackgroundFetchInterval:7200]; //fetch interval: 2hr
    
    //window
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    EWAlarmsViewController *controler = [[EWAlarmsViewController alloc] initWithNibName:nil bundle:nil];
    self.window.rootViewController = controler;
    rootViewController = self.window.rootViewController;
    
    //init coredata and backend server
    [EWDataStore sharedInstance];
    
    //window
    [self.window makeKeyAndVisible];
    
    //User login
    [EWUserManagement login];
    
    //local notification entry
    if (launchOptions) {
        UILocalNotification *localNotif = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
        NSDictionary *remoteNotif = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
        //Let server class to handle notif info
        if (localNotif) {
            NSLog(@"Launched with local notification: %@", localNotif);
            [EWServer handleLocalNotification:localNotif];
        }else if (remoteNotif){
            NSLog(@"Launched with push notification: %@", remoteNotif);
            [EWServer handlePushNotification:remoteNotif];
        }
    }
    
    [[UINavigationBar appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]}];
    return YES;
}


#pragma mark - BACKGROUND TASK
//=================>> Point to enter background <<===================
- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    NSLog(@"Entered background with active time left: %f", application.backgroundTimeRemaining>999?999:application.backgroundTimeRemaining);

    
    //save core data
    [EWDataStore save];
    
    //detect multithreading
    BOOL result = NO;
    if ([[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)]){
        result = [[UIDevice currentDevice] isMultitaskingSupported];
    }if (!result) {
        EWAlert(@"Your device doesn't support background task. Alarm will not fire. Please change your settings.");
    }

    //keep alive
    [self backgroundTaskKeepAlive:nil];
    
    //clean badge
    application.applicationIconBadgeNumber = 0;
}


- (void)backgroundTaskKeepAlive:(NSTimer *)timer{
    UIApplication *application = [UIApplication sharedApplication];
    NSMutableDictionary *userInfo;
    if (timer) {
        NSDate *start = timer.userInfo[@"start_date"];
        count = [(NSNumber *)timer.userInfo[@"count"] integerValue];
        NSLog(@"Backgrounding started at %@ is checking the %ld times", start.date2detailDateString, count);
        count++;
        timer.userInfo[@"count"] = @(count);
        userInfo = timer.userInfo;
    }else{
        //first time
        userInfo = [NSMutableDictionary new];
        userInfo[@"start_date"] = [NSDate date];
        userInfo[@"count"] = @0;
    }
    
    //schedule timer
    if ([myTimer isValid]) [myTimer invalidate];
    NSInteger randomInterval = kAlarmTimerCheckInterval + arc4random_uniform(60);
    myTimer = [NSTimer scheduledTimerWithTimeInterval:randomInterval target:self selector:@selector(backgroundTaskKeepAlive:) userInfo:userInfo repeats:NO];
    
    //start silent sound
    [[AVManager sharedManager] playSilentSound];
    
    //end old background task
    [application endBackgroundTask:backgroundTaskIdentifier];
    
    //begin a new background task
    backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        //[self backgroundTaskKeepAlive:nil];
        //NSLog(@"The backgound task is renewed at (%ld)" , count);
    }];
    
    //check time left
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        double timeLeft = application.backgroundTimeRemaining;
        NSLog(@"Background time left: %.1f", timeLeft>999?999:timeLeft);
        if (timeLeft < 300) {
            //alert user
            UILocalNotification *alarm = [[UILocalNotification alloc] init];
            alarm.alertBody = @"Woke is being deactivated. Tap here to reactivate me.";
            alarm.alertAction = @"Reactivate";
            alarm.userInfo = @{kLocalNotificationTypeKey: kLocalNotificationTypeReactivate};
            [[UIApplication sharedApplication] scheduleLocalNotification:alarm];
            [[AVManager sharedManager] playSoundFromFile:me.preference[@"DefaultTone"]];
        }
    });
    
    //alarm timer check
    [EWWakeUpManager alarmTimerCheck];
}

#pragma mark - APP LIFE CYCLE
- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    
    [MBProgressHUD hideAllHUDsForView:rootViewController.view animated:YES];
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    
    if (backgroundTaskIdentifier != UIBackgroundTaskInvalid){
        //end background task
        [application endBackgroundTask:backgroundTaskIdentifier];
        
    }
    //stop timer
    if ([myTimer isValid]){
        [myTimer invalidate];
    }
    
    //audio session
    [[AVManager sharedManager] registerActiveAudioSession];
    
    NSLog(@"Entered foreground and cleaned bgID and timer");
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Handle the user leaving the app while the Facebook login dialog is being shown
    // For example: when the user presses the iOS "home" button while the login dialog is active
    //[FBAppCall handleDidBecomeActive];
    [FBAppCall handleDidBecomeActiveWithSession:[PFFacebookUtils session]];
    
    //audio session
    [[AVManager sharedManager] registerAudioSession];
    
    count = 0;
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [FBSession.activeSession close];
    [[AVManager sharedManager] playSoundFromFile:@"new.caf"];
    NSLog(@"App is about to terminate");

    [TestFlight manuallyEndSession];
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
    
    BOOL handled_1 = [FBSession.activeSession handleOpenURL:url];
    BOOL handled_2 =  [FBAppCall handleOpenURL:url
                  sourceApplication:sourceApplication
                        withSession:[PFFacebookUtils session]];
    
    return handled_1 && handled_2;
}



#pragma mark - Background fetch method (this is called periodocially
-(void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    NSLog(@"======== Launched in background due to background fetch event ==========");
    //enable audio session and keep audio port
    //[[AVManager sharedManager] registerAudioSession];
    [[AVManager sharedManager] playSystemSound:nil];
    
    //check media assets
    BOOL newMedia = [[EWMediaStore sharedInstance] checkMediaAssets];
    
    //update checked time
    [EWDataStore sharedInstance].lastChecked = [NSDate date];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"Returned background fetch handler with %@", newMedia?@"new data":@"no data");
        if (newMedia) {
            completionHandler(UIBackgroundFetchResultNewData);
        }else{
            completionHandler(UIBackgroundFetchResultNoData);
        }
        
    });
    
}



#pragma mark - Push Notification registration
//Presist the device token
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken{
    
    //Register Push on Server
    [EWServer registerPushNotificationWithToken:deviceToken];
    
 
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    //[NSException raise:@"Failed to regiester push token with apple" format:@"Reason: %@", err.description];
    NSLog(@"*** Failed to regiester push token with apple. Error: %@", err.description);
    NSString *str = [NSString stringWithFormat:@"Unable to regiester Push Notifications. Reason: %@", err.localizedDescription];
    EWAlert(str);
}

//entrance of Local Notification
- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification{
    [EWServer handleLocalNotification:notification];
}

//Receive remote notification in background or in foreground
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler{
    
    if (application.applicationState == UIApplicationStateInactive) {
        // The application was just brought from the background to the foreground,
        // so we consider the app as having been "opened by a push notification."
        [PFAnalytics trackAppOpenedWithRemoteNotificationPayload:userInfo];
    }
    
    if (!me) {
        return;
    }
    
    if ([application applicationState] == UIApplicationStateActive) {
        NSLog(@"Push Notification received when app is running: %@", userInfo);
    }else{
        NSLog(@"Push Notification received when app is in background(%ld): %@", (long)application.applicationState, userInfo);
    }
    
    //handle push
    [EWServer handlePushNotification:userInfo];
    
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
    //EWDownloadManager *manager = [EWDownloadManager sharedInstance];
	//manager.backgroundSessionCompletionHandler = completionHandler;
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
