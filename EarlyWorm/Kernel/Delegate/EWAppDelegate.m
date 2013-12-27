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
#import "EWLogInViewController.h"
#import "EWWakeUpViewController.h"

//tools
#import "AVManager.h"
#import "EWDefines.h"
#import "EWUIUtil.h"
#import "MBProgressHUD.h"

//#import "AVManager.h"
#import "EWAlarmManager.h"
#import "EWDownloadMgr.h"
#import "EWTaskStore.h"
#import "EWWeiboManager.h"
#import "EWFacebookManager.h"
#import "EWPersonStore.h"

#import "EWDatabaseDefault.h"
#import "EWDefines.h"

//Private
@interface EWAppDelegate(){
    EWTaskItem *taskInAction;
}

@property (nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic) UIBackgroundTaskIdentifier oldBackgroundTaskIdentifier;

@property (nonatomic, strong) NSTimer *myTimer;
@property (nonatomic) long count;

@property (nonatomic, strong) NSMutableArray *musicList;

@end

@interface EWAppDelegate (DownloadMgr)<EWDownloadMgrDelegate>
@end

@implementation EWAppDelegate
@synthesize backgroundTaskIdentifier;
@synthesize oldBackgroundTaskIdentifier;
@synthesize myTimer;
@synthesize count;
@synthesize client, pushClient, managedObjectModel, coreDataStore;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    //stackMob
    SM_CACHE_ENABLED = YES;//enable cache
    self.client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:kStackMobKeyDevelopment];
    self.client.userSchema = @"EWPerson";
    self.coreDataStore = [self.client coreDataStoreWithManagedObjectModel:[self managedObjectModel]];
    
    //cache related
    self.coreDataStore.fetchPolicy = SMFetchPolicyTryNetworkElseCache;
    [client.session.networkMonitor setNetworkStatusChangeBlockWithFetchPolicyReturn:^SMFetchPolicy(SMNetworkStatus status) {
        // Customize this block to fit your application's needs
        if (status == SMNetworkStatusReachable) {
            return SMFetchPolicyTryNetworkElseCache;
        } else {
            return SMFetchPolicyCacheOnly;
        }
    }];
    
    //background fetch
    [application setMinimumBackgroundFetchInterval:kBackgroundFetchInterval]; //fetch
    
    //push
    pushClient = [[SMPushClient alloc] initWithAPIVersion:@"0" publicKey:kStackMobKeyDevelopment privateKey:kStackMobKeyDevelopmentPrivate];
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert];
    //user login
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userLoggedIn) name:kPersonLoggedIn object:nil];
    
    
    
    // Weibo SDK
    EWWeiboManager *weiboMgr = [EWWeiboManager sharedInstance];
    [weiboMgr registerApp];
    
    //background download
    count = 0;
    self.musicList = [NSMutableArray array];
    
    //window
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    //controller
    EWAlarmsViewController *alarmController = [[EWAlarmsViewController alloc] init];
    UINavigationController *alarmsNavigationController = [[UINavigationController alloc] initWithRootViewController:alarmController];
    
    EWSocialViewController *taskController = [[EWSocialViewController alloc] init];
    UINavigationController *tasksNavigationController = [[UINavigationController alloc] initWithRootViewController:taskController];

    
    EWSettingsViewController *settingsController = [[EWSettingsViewController alloc] init];
    UINavigationController *settingsNavigationController = [[UINavigationController alloc] initWithRootViewController:settingsController];
    
    self.tabBarController = [[UITabBarController alloc] init];
    self.tabBarController.delegate = self;
    self.tabBarController.viewControllers = @[alarmsNavigationController, tasksNavigationController, settingsNavigationController];
    self.window.rootViewController = self.tabBarController;
    
    
    //local notification entry
    UILocalNotification *localNotif =
    [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
    //TODO ??? why it doesn't work? 
    if (localNotif) {
        NSString *alarmID = [localNotif.userInfo objectForKey:@"alarmID"];
        //[viewController displayItem:itemName];  // custom method
        //app.applicationIconBadgeNumber = localNotif.applicationIconBadgeNumber-1;

        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Local notification"
            message:alarmID
            delegate:nil
            cancelButtonTitle:@"OK"
            otherButtonTitles:nil];
        [alert show];
    }
    
    
    //last step
    [self.window makeKeyAndVisible];
    
    //user check
    
    if (![self.client isLoggedIn]) {
        //user has not logged in, start logging in

        //first time view controller
        EWLogInViewController *controller = [[EWLogInViewController alloc] init];
        [alarmController presentViewController:controller animated:YES completion:NULL];
        
    }else{
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.window.rootViewController.view animated:YES];
        [[SMClient defaultClient] getLoggedInUserOnSuccess:^(NSDictionary *result) {
            //get the full user object
            EWPerson *me = [[EWPersonStore sharedInstance] getPersonByID:result[@"username"]];
            //merge changes
            [[self.client.coreDataStore contextForCurrentThread] refreshObject:me mergeChanges:YES];
            NSLog(@"Current logged in user: %@",me.name);
            [EWPersonStore sharedInstance].currentUser = me;
            
            //check default
            [[EWDatabaseDefault sharedInstance] setDefault];
            //broadcasting
            [[NSNotificationCenter defaultCenter] postNotificationName:kPersonLoggedIn object:self userInfo:@{@"User": [EWPersonStore sharedInstance].currentUser}];
            
            
            //log in with facebook
            [[EWLogInViewController sharedInstance] viewDidLoad];
            
            //refresh view
            [alarmController.view setNeedsDisplay];
            
            [MBProgressHUD hideAllHUDsForView:self.window.rootViewController.view animated:YES];
        } onFailure:^(NSError *error) {
            NSLog(@"Failed to get logged in user: %@", error.description);
            // Reset local session info
            [self.client.session clearSessionInfo];
            //Login vc
            EWLogInViewController *controller = [[EWLogInViewController alloc] init];
            [alarmController presentViewController:controller animated:YES completion:NULL];
        }];
        
        
        
        //continue check remote data at background
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            //
        });
    }
    
    //log in view controller
    //EWLogInViewController *controller = [[EWLogInViewController alloc] init];
    //[alarmController presentViewController:controller animated:YES completion:NULL];
    
    
    return YES;
}

- (void)application:(UIApplication *)application willChangeStatusBarFrame:(CGRect)newStatusBarFrame{
    [EWUIUtil OnSystemStatusBarFrameChange];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
    if (![self isMultitaskingSupported]){
        return;
    }
    
#ifdef BACKGROUND_TEST
    [self performSelectorInBackground:@selector(backgroundDownload) withObject:nil];
#endif
    //开启一个后台任务
    backgroundTaskIdentifier = [application beginBackgroundTaskWithExpirationHandler:^{
//        [self backgroundDownload];
        
    }];
    oldBackgroundTaskIdentifier = backgroundTaskIdentifier;
    if ([self.myTimer isValid]) {
        [self.myTimer invalidate];
    }
    self.myTimer = [NSTimer scheduledTimerWithTimeInterval:1800 target:self selector:@selector(timerMethod:) userInfo:nil repeats:YES];
    NSLog(@"Scheduled background task");
//    self.myTimer = nil;

    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    
//    [[UIApplication sharedApplication] clearKeepAliveTimeout];
    
    if (backgroundTaskIdentifier != UIBackgroundTaskInvalid){
        [application endBackgroundTask:backgroundTaskIdentifier];
        if ([self.myTimer isValid]) {
            [self.myTimer invalidate];
        }
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [FBSession.activeSession handleDidBecomeActive];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [FBSession.activeSession close];
}



- (void)OnCancel {
    [self.window.rootViewController dismissViewControllerAnimated:YES completion:^(void){}];
}

#pragma mark - CORE DATA
- (NSManagedObjectModel *)managedObjectModel
{
    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
    //Returns a model created by merging all the models found in given bundles. If you specify nil, then the main bundle is searched.
    managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    return managedObjectModel;
}

#pragma mark - Weibo
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    return [WeiboSDK handleOpenURL:url delegate:self];
}

#pragma mark - Facebook
- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    
    return [FBSession.activeSession handleOpenURL:url];
}



- (BOOL) isMultitaskingSupported {
    
    BOOL result = NO;
    
    if ([[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)]){
            result = [[UIDevice currentDevice] isMultitaskingSupported];
    }
    return result;
}

#pragma mark - Background download
- (void) timerMethod:(NSTimer *)paramSender{
    count++;
    UIApplication *application = [UIApplication sharedApplication];
    
    //开启一个新的后台
    backgroundTaskIdentifier = [application beginBackgroundTaskWithExpirationHandler:^{
        
        // Download
//            [self backgroundDownload];
    }];
    
    //结束旧的后台任务
    [application endBackgroundTask:backgroundTaskIdentifier];
    oldBackgroundTaskIdentifier = backgroundTaskIdentifier;
    
#ifdef BACKGROUND_TEST

    NSLog(@"%ld",count);
#endif
}

- (void)backgroundDownload {
    
    EWDownloadMgr *mgr = [[EWDownloadMgr alloc] init];
    mgr.urlString = @"http://med.a5mp3.com/ttpod/11612.mp3";
    mgr.delegate = self;
    
    NSString *fileName = nil;
    if (mgr.description && mgr.description.length > 0) {
        fileName = [NSString stringWithFormat:@"%@.mp3",mgr.description];
    }
    else {
        //get file name
        NSArray *array = [mgr.urlString componentsSeparatedByString:@"/"];
        if (array && array.count > 0) {
            fileName = [array objectAtIndex:array.count-1];
        }
    }

    if (fileName) {
        NSString *filePath = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%@", fileName]];
        
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
        if (fileExists) {
            
            // test
            [self.musicList addObject:filePath];
            
            // 播放 test
            [self playDownloadedMusic:filePath];
            return;
        }
    }
    
//    [mgr startDownload];
    
    NSData *data = [mgr syncDownloadByGet];
    
    [self handleDownlownedData:data fromManager:mgr];
}

- (void)handleDownlownedData:(NSData *)data fromManager:(EWDownloadMgr *)mgr {
    if (!data) {
        return;
    }
    
    NSString *fileName = nil;
    if (mgr.description && mgr.description.length > 0) {
        fileName = [NSString stringWithFormat:@"%@.mp3",mgr.description];
    }
    else {
        NSArray *array = [mgr.urlString componentsSeparatedByString:@"/"];
        if (array && array.count > 0) {
            fileName = [array objectAtIndex:array.count-1];
        }
        else {
            NSTimeInterval timeInterval = [[NSDate date] timeIntervalSince1970];
            fileName = [NSString stringWithFormat:@"%f.mp3",timeInterval];
        }
    }
    
    NSString *filePath = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%@", fileName]];
    [data writeToFile:filePath atomically:YES];
    
    NSLog(@"write to local file: %@", filePath);
    [self.musicList addObject:filePath];
    
    // 播放 test
    [self playDownloadedMusic:filePath];
}

- (void)playDownloadedMusic:(NSString *)path {
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL: [NSURL fileURLWithPath:path] error: nil];
    [player prepareToPlay];
    
    //    [player play];
    
    [player performSelectorOnMainThread:@selector(play) withObject:nil waitUntilDone:NO];
}

#pragma mark - Push Notification
//Presist the device token
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken{
    NSString *token = [[deviceToken description] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
    token = [[token componentsSeparatedByString:@" "] componentsJoinedByString:@""];
    
    // Persist token if needed
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:token forKey:@"DeviceToken"];
    [defaults synchronize];
    
    // Register the token with StackMob.  User is an arbitrary string to associate with the token.
    if ([EWPersonStore sharedInstance].currentUser) {
        NSString *username = [EWPersonStore sharedInstance].currentUser.username;
        [self.pushClient registerDeviceToken:token withUser:username onSuccess:^{
            NSLog(@"APP registered push token and assigned to StackMob server");
        } onFailure:^(NSError *error) {
            [NSException raise:@"Failed to regiester push token with StackMob" format:@"Reason: %@", error.description];
        }];
    }
    
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    [NSException raise:@"Failed to regiester push token with apple" format:@"Reason: %@", err.description];
}

//entrance of Local Notification
- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification{
    NSLog(@"Received local notification: %@", notification);
    if ([application applicationState] == UIApplicationStateActive) {
        UIAlertView *alert = [[UIAlertView alloc]
                              initWithTitle:@"Alarm"
                              message:@"It's time to get up!"
                              delegate:self
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil];
        [alert show];
    } else {
        NSLog(@"Entered by local notification");
        
        
        if (self.musicList.count > 0) {
            [self playDownloadedMusic:[self.musicList objectAtIndex:self.musicList.count-1]];
        }
        
        EWWakeUpViewController *controller = [[EWWakeUpViewController alloc] init];
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:controller];
        [self.window.rootViewController presentViewController:navigationController animated:YES completion:^(void){}];
        controller.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(OnCancel)];
    }
}

//Receive remote notification
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo{
    NSLog(@"Notification received: %@", userInfo);
    //if ([application applicationState] == UIApplicationStateActive) {
        NSString *message = [[userInfo valueForKey:@"aps"] valueForKey:@"alert"];
        NSString *title = @"New Voice Tone";
        NSString *taskID = userInfo[@"taskID"];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            taskInAction = [[EWTaskStore sharedInstance] getTaskByID:taskID];
            NSString *btnTitle;
            if (taskInAction) {
                btnTitle = @"Show";
            }else{
                btnTitle = nil;
            }
            
            //notification
            [[NSNotificationCenter defaultCenter] postNotificationName:kTaskChangedNotification object:self userInfo:@{@"task": taskInAction}];
            
            //main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                                    message:message
                                                                   delegate:self
                                                          cancelButtonTitle:@"Close"
                                                          otherButtonTitles:btnTitle, nil];
                [alertView show];
            });
        });
        
        
        
    //}else{
    //    NSLog(@"Push notification received while app in background");
    //}
}


- (void)userLoggedIn{
    //register notification
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *token;
    @try {
        token = [defaults objectForKey:@"DeviceToken"];
    }
    @catch (NSException *exception) {
        NSLog(@"Exception caught: %@", exception.description);
        return;
    }
    NSString *username = [EWPersonStore sharedInstance].currentUser.username;
    
    [self.pushClient registerDeviceToken:token withUser:username onSuccess:^{
        NSLog(@"APP registered push token and assigned to StackMob server");
    } onFailure:^(NSError *error) {
        [NSException raise:@"Failed to regiester push token with StackMob" format:@"Reason: %@", error.description];
    }];
    
    
}

#pragma mark - Alert Delegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if ([alertView.title isEqualToString:@"New Voice Tone"]) {
        if (buttonIndex == 1) {
            //show
            if (taskInAction) {
                //got taskInAction
                EWWakeUpViewController *controller = [[EWWakeUpViewController alloc] init];
                controller.task = taskInAction;
                UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:controller];
                [self.window.rootViewController presentViewController:navigationController animated:YES completion:NULL];
            }
            taskInAction = nil;
        }
    }
    
}


#pragma mark - Weibo SDK

- (void)didReceiveWeiboRequest:(WBBaseRequest *)request {
    EWWeiboManager *weiboManager = [EWWeiboManager sharedInstance];
    [weiboManager didReceiveWeiboRequest:request];
}

- (void)didReceiveWeiboResponse:(WBBaseResponse *)response {
    EWWeiboManager *weiboManager = [EWWeiboManager sharedInstance];
    [weiboManager didReceiveWeiboResponse:response];
}

-  (void)didReceiveWeiboSDKResponse:(id)JsonObject err:(NSError *)error {
    EWWeiboManager *weiboManager = [EWWeiboManager sharedInstance];
    [weiboManager didReceiveWeiboSDKResponse:JsonObject err:error];
}

@end

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
