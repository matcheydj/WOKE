//
//  EWSleepViewController.m
//  Woke
//
//  Created by Lee on 8/6/14.
//  Copyright (c) 2014 WokeAlarm.com. All rights reserved.
//

#import "EWSleepViewController.h"
#import "EWBackgroundingManager.h"
#import "AVManager.h"
#import "EWTaskStore.h"
#import "EWPersonStore.h"

@interface EWSleepViewController (){
    NSTimer *timer;
}

@end

@implementation EWSleepViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [[EWBackgroundingManager sharedInstance] startSleep];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    //sound
    [[AVManager sharedManager] playSoundFromFile:@"sleep mode.caf"];
    //timer
    timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateTimer:) userInfo:nil repeats:YES];
}

- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [timer invalidate];
}

- (IBAction)cancel:(id)sender {
    [self.presentingViewController dismissBlurViewControllerWithCompletionHandler:NULL];
    [[EWBackgroundingManager sharedInstance] endSleep];
}

- (void)updateTimer:(NSTimer *)timer{
    NSDate *t = [NSDate date];
    self.timeLabel.text = t.date2String;
    NSDate *wakeTime = [[EWTaskStore sharedInstance] nextWakeUpTimeForPerson:me];
    self.timeLeftLabel.text = [NSString stringWithFormat:@"%@ left", wakeTime.timeLeft];
}
@end