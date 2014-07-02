//
//  EWAlarmEditCell.m
//  EarlyWorm
//
//  Created by Lei on 12/31/13.
//  Copyright (c) 2013 Shens. All rights reserved.
//

#import "EWAlarmEditCell.h"
#import "EWTaskItem.h"
#import "EWAlarmManager.h"
#import "EWAlarmItem.h"
#import "NSDate+Extend.h"
#import "EWCostumTextField.h"
@implementation EWAlarmEditCell
@synthesize task, alarm;
@synthesize myTime, myStatement, myMusic;


- (id)initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    if (self) {
        self.contentView.backgroundColor = [UIColor clearColor];
        self.statement.textColor = [UIColor whiteColor];
       [ self.statement setValue:[UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1] forKeyPath:@"_placeholderLabel.textColor"];
//        UIColor *color = [UIColor whiteColor];
//        self.statement.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"PlaceHolder Text" attributes:@{NSForegroundColorAttributeName: color}];
        [self bringSubviewToFront:self.statement];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setTask:(EWTaskItem *)t{
    //data
    task = t;
    alarm = task.alarm;
    //alarmOn = self.alarm.state;
    myTime = self.task.time ;
    myMusic = self.alarm.tone;
    myStatement = self.task.statement;
    
    //view
    self.time.text = [myTime date2timeShort];
    self.AM.text = [myTime date2am];
    self.weekday.text = [myTime weekdayShort];
    NSArray *name = [myMusic componentsSeparatedByString:@"."];
    [self.music setTitle:name[0] forState:UIControlStateNormal];
    self.statement.text = myStatement;
    //NSString *alarmState = alarmOn ? @"ON":@"OFF";
    //[self.alarmToggle setTitle:alarmState forState:UIControlStateNormal];
    
    self.alarmToggle.selected = task.state;
    if (self.alarmToggle.selected) {
        [self.alarmToggle setImage:[UIImage imageNamed:@"On_Btn"] forState:UIControlStateNormal];
    }else{
        [self.alarmToggle setImage:[UIImage imageNamed:@"Off_Btn"] forState:UIControlStateNormal];
    }
}

//Not used
- (void)setAlarm:(EWAlarmItem *)a{
    //data
    //task = [[EWAlarmManager sharedInstance] firstTaskForAlarm:a];
    alarm = a;
    myTime = alarm.time;
    myMusic = alarm.tone;
    myStatement = alarm.statement;
    
    //view
    self.time.text = [myTime date2timeShort];
    self.AM.text = [myTime date2am];
    self.weekday.text = [myTime weekday];
    NSArray *name = [myMusic componentsSeparatedByString:@"."];
    [self.music setTitle:name[0] forState:UIControlStateNormal];
    self.statement.text = myStatement;
    //NSString *alarmState = alarmOn ? @"ON":@"OFF";
    //[self.alarmToggle setTitle:alarmState forState:UIControlStateNormal];
    
    self.alarmToggle.selected = alarm.state;
    if (self.alarmToggle.selected) {
        [self.alarmToggle setImage:[UIImage imageNamed:@"On_Btn"] forState:UIControlStateNormal];
    }else{
        [self.alarmToggle setImage:[UIImage imageNamed:@"Off_Btn"] forState:UIControlStateNormal];
    }

}

- (IBAction)toggleAlarm:(UIControl *)sender {
    sender.selected = !sender.selected;
    if (self.alarmToggle.selected) {
        [self.alarmToggle setImage:[UIImage imageNamed:@"On_Btn"] forState:UIControlStateNormal];
    }else{
        [self.alarmToggle setImage:[UIImage imageNamed:@"Off_Btn"] forState:UIControlStateNormal];
    }
}

- (IBAction)changeMusic:(id)sender {
    EWRingtoneSelectionViewController *controller = [[EWRingtoneSelectionViewController alloc] init];
    UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:controller];
    controller.delegate = self;
    NSArray *ringtones = ringtoneNameList;
    controller.selected = [ringtones indexOfObject:myMusic];
    [self.presentingViewController presentViewController:nc animated:YES completion:NULL];
}

- (IBAction)hideKeyboard:(UITextField *)sender {
    [sender resignFirstResponder];
}

- (IBAction)changeTime:(UIStepper *)sender {
    NSInteger time2add = (NSInteger)sender.value;
    NSDateComponents *comp = [myTime dateComponents];
    if (comp.hour == 0 && comp.minute == 0 && time2add < 0) {
       myTime = [myTime timeByAddingMinutes:60 * 24];
    }else if (comp.hour == 23 && comp.minute == 50 && time2add > 0 ){
       myTime = [myTime timeByAddingMinutes:-60 * 24];
    }
    
    myTime = [myTime timeByAddingMinutes:time2add];
    
    self.time.text = [myTime date2timeShort];
    self.AM.text = [myTime date2am];
    sender.value = 0;//reset to 0
    NSLog(@"New value is: %ld, and new time is: %@", (long)time2add, myTime.date2String);
    [self setNeedsDisplay];
}

- (void)ViewController:(EWRingtoneSelectionViewController *)controller didFinishSelectRingtone:(NSString *)tone{
    myMusic = tone;
    NSArray *name = [myMusic componentsSeparatedByString:@"."];
    [self.music setTitle:name[0] forState:UIControlStateNormal];
}


@end
