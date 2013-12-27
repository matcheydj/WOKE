//
//  EWRecordingViewController.m
//  EarlyWorm
//
//  Created by Lei on 12/24/13.
//  Copyright (c) 2013 Shens. All rights reserved.
//

#import "EWRecordingViewController.h"
#import "EWAppDelegate.h"

//object
#import "EWTaskItem.h"
#import "EWMediaItem.h"
#import "EWMediaStore.h"
#import "EWPerson.h"
#import "EWPersonStore.h"

//Util
#import "MBProgressHUD.h"

//backend
#import "StackMob.h"

@interface EWRecordingViewController ()

@end

@implementation EWRecordingViewController
@synthesize progressBar, playBtn, recordBtn;
@synthesize task;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        manager = [AVManager sharedManager];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.view.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.5];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    self.view.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.5];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)play:(id)sender {
    manager.progressBar = progressBar;
    
    if (!manager.player.isPlaying) {
        [playBtn setTitle:@"Stop" forState:UIControlStateNormal];
        [manager playSoundFromURL:recordingFileUrl];
    }else{
        [playBtn setTitle:@"Play" forState:UIControlStateNormal];
        [manager stopAllPlaying];
    }
}

- (IBAction)record:(id)sender {
    manager.progressBar = progressBar;
    progressBar.maximumValue = kMaxRecordTime;
    manager.playStopBtn = recordBtn;
    recordingFileUrl = [manager record];
    if (manager.recorder.isRecording) {
        [recordBtn setTitle:@"Stop" forState:UIControlStateNormal];
    }else{
        [recordBtn setTitle:@"Record" forState:UIControlStateNormal];
    }
}

- (IBAction)send:(id)sender {
    if (recordingFileUrl) {
        //finished recording, prepare for data
        NSError *err;
        NSData *recordData = [NSData dataWithContentsOfFile:[recordingFileUrl path] options:0 error:&err];
        if (!recordData) {
            return;
        }
        //save data to task
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        NSString *recordDataString = [SMBinaryDataConversion stringForBinaryData:recordData name:@"voicetone.m4a" contentType:@"media/m4a"];
        EWMediaItem *media = [[EWMediaStore sharedInstance] createMedia];
        media.author = [EWPersonStore sharedInstance].currentUser;
        media.title = @"Voice Tone";
        media.message = self.message.text;
        [media addTasksObject:task];
        media.audioKey = recordDataString;
        
        //save
        NSManagedObjectContext *context = [[[SMClient defaultClient] coreDataStore] contextForCurrentThread];
        [context saveOnSuccess:^{
            [context refreshObject:media mergeChanges:YES];
            hud.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark"]];
            hud.mode = MBProgressHUDModeCustomView;
            hud.labelText = @"Sent";
            [hud hide:YES afterDelay:1.5];
            //clean
            recordingFileUrl = nil;
            if ([media.audioKey length]<100) {
                //NSLog(@"media's audioKey after merge is %@", media.audioKey);
            }else{
                NSLog(@"audioKey failed to upload to S3 server and remained as string data");
            }
            
            //send push notification
            EWAppDelegate *delegate = (EWAppDelegate *)[UIApplication sharedApplication].delegate;
            NSDictionary *pushMessage = @{@"alert": [NSString stringWithFormat:@"New voice tone sent from %@", [EWPersonStore sharedInstance].currentUser.username],
                                          @"badge": @1,
                                          @"taskID": task.ewtaskitem_id};
            
            [delegate.pushClient sendMessage:pushMessage toUsers:@[task.owner.username] onSuccess:^{
                NSLog(@"Push notification successfully sent to %@", task.owner.username);
            } onFailure:^(NSError *error) {
                [NSException raise:@"Failed to send push notification" format:@"Reason: %@", error.description];
            }];
            
            //dismiss
            [self dismissViewControllerAnimated:YES completion:NULL];
            
        } onFailure:^(NSError *error) {
            [NSException raise:@"Error in saving new Meida object" format:@"Reason: %@", err.description];
        }];
    }
}

- (IBAction)seek:(id)sender {
}

- (IBAction)back:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
}
@end
