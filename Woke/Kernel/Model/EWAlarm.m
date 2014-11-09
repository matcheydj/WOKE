//
//  EWAlarmItem.m
//  EarlyWorm
//
//  Created by Lei on 8/27/13.
//  Copyright (c) 2013 Shens. All rights reserved.
//

#import "EWAlarm.h"
#import "EWPersonManager.h"
#import "EWAlarmManager.h"
#import "AFNetworking.h"


@implementation EWAlarm


#pragma mark - NEW
//add new alarm, save, add to current user, save user
+ (EWAlarm *)newAlarm{
    NSParameterAssert([NSThread isMainThread]);
    DDLogVerbose(@"Create new Alarm");
    
    //add relation
    EWAlarm *a = [EWAlarm createEntity];
    a.updatedAt = [NSDate date];
    a.owner = [EWSession sharedSession].currentUser;
    a.state = @YES;
    a.tone = [EWSession sharedSession].currentUser.preference[@"DefaultTone"];
    
    return a;
}

#pragma mark - DELETE
- (void)remove{
    [[NSNotificationCenter defaultCenter] postNotificationName:kAlarmDelete object:self userInfo:nil];
    [self deleteEntity];
    [EWSync save];
}

+ (void)deleteAll{
    //delete
    [mainContext saveWithBlock:^(NSManagedObjectContext *localContext) {
        for (EWAlarm *alarm in [EWSession sharedSession].currentUser.alarms) {
            EWAlarm *localAlarm = [alarm inContext:localContext];
            [localAlarm remove];
        }
    }];
}

#pragma mark - Validate alarm
- (BOOL)validate{
    BOOL good = YES;
    if (!self.owner) {
        DDLogError(@"Alarm（%@）missing owner", self.serverID);
        self.owner = [[EWSession sharedSession].currentUser inContext:self.managedObjectContext];
    }
    if (!self.time) {
        DDLogError(@"Alarm（%@）missing time", self.serverID);
        good = NO;
    }
    //check tone
    if (!self.tone) {
        DDLogError(@"Tone not set, fixed!");
        self.tone = [EWSession sharedSession].currentUser.preference[@"DefaultTone"];
    }
    
    if (!good) {
        DDLogError(@"Alarm failed validation: %@", self);
    }
    return good;
}

#pragma mark - response to changes
- (void)setState:(NSNumber *)state {
    [self willChangeValueForKey:EWAlarmAttributes.state];
    [self setPrimitiveState:state];
	//update cached time in person
    [self updateCachedAlarmTime];
	//update saved time in user defaults
	[self setSavedAlarmTime];
	//schedule local notification
	if (state.boolValue == YES) {
		//schedule local notif
		[self scheduleLocalNotification];
	} else {
		//cancel local notif
		[self cancelLocalNotification];
	}
    [self didChangeValueForKey:EWAlarmAttributes.state];
    [[NSNotificationCenter defaultCenter] postNotificationName:kAlarmStateChanged object:self];
}

- (void)setTime:(NSDate *)time {
    [self willChangeValueForKey:EWAlarmAttributes.time];
    [self setPrimitiveTime:time];
    
    //update saved time in user defaults
    [self setSavedAlarmTime];
    
    //update cached alarm time in currentUser
    [self updateCachedAlarmTime];
    
    //schedule local notification
    [self cancelLocalNotification];
    [self scheduleLocalNotification];
    [self didChangeValueForKey:EWAlarmAttributes.time];
    
    // schedule on server
    [self scheduleNotificationOnServer];
    [[NSNotificationCenter defaultCenter] postNotificationName:kAlarmTimeChanged object:self];
}

- (void)setTone:(NSString *)tone {
    [self willChangeValueForKey:EWAlarmAttributes.tone];
    [self setPrimitiveTone:tone];
    [self cancelLocalNotification];
    [self scheduleLocalNotification];
    [self didChangeValueForKey:EWAlarmAttributes.tone];
    [[NSNotificationCenter defaultCenter] postNotificationName:kAlarmToneChanged object:self];
}

- (void)setStatement:(NSString *)statement {
    [self willChangeValueForKey:EWAlarmAttributes.statement];
    [self setPrimitiveStatement:statement];
    [self updateCachedStatement];
    [self didChangeValueForKey:EWAlarmAttributes.statement];
    [[NSNotificationCenter defaultCenter] postNotificationName:kAlarmToneChanged object:self];
}


#pragma mark - Tools
//update saved time in user defaults
- (void)setSavedAlarmTime{
	NSInteger wkd = [self.time weekdayNumber];
	NSCalendar *cal = [NSCalendar currentCalendar];
	NSDateComponents *comp = [cal components: (NSHourCalendarUnit | NSMinuteCalendarUnit) fromDate:self.time];
	double hour = comp.hour;
	double minute = comp.minute;
	double number = round(hour*100 + minute)/100.0;
    NSMutableArray *alarmTimes = [[[NSUserDefaults standardUserDefaults] objectForKey:kSavedAlarms] mutableCopy];
	[alarmTimes setObject:[NSNumber numberWithDouble:number] atIndexedSubscript:wkd];
	[[NSUserDefaults standardUserDefaults] setObject:alarmTimes.copy forKey:kSavedAlarms];

}


#pragma mark - Cached alarm time to user defaults

- (void)updateCachedAlarmTime{
    NSMutableDictionary *cache = [EWSession sharedSession].currentUser.cachedInfo.mutableCopy?:[NSMutableDictionary new];
    NSMutableDictionary *timeTable = [cache[kCachedAlarmTimes] mutableCopy]?:[NSMutableDictionary new];
    for (EWAlarm *alarm in [EWSession sharedSession].currentUser.alarms) {
        if (alarm.state) {
            NSString *wkday = alarm.time.weekday;
            timeTable[wkday] = alarm.time;
        }
    }
    cache[kCachedAlarmTimes] = timeTable;
    [EWSession sharedSession].currentUser.cachedInfo = cache;
    [EWSync save];
    DDLogVerbose(@"Updated cached alarm times: %@", timeTable);
}

- (void)updateCachedStatement{
    NSMutableDictionary *cache = [EWSession sharedSession].currentUser.cachedInfo.mutableCopy?:[NSMutableDictionary new];
    NSMutableDictionary *statements = [cache[kCachedStatements] mutableCopy]?:[NSMutableDictionary new];
    for (EWAlarm *alarm in [EWSession sharedSession].currentUser.alarms) {
        if (alarm.state) {
            NSString *wkday = alarm.time.weekday;
            statements[wkday] = alarm.statement;
        }
    }
    cache[kCachedStatements] = statements;
    [EWSession sharedSession].currentUser.cachedInfo = cache;
    [EWSync save];
    DDLogVerbose(@"Updated cached statements: %@", statements);
}

#pragma mark - Local Notification
- (void)scheduleTimerAndSleepLocalNotification{
	//check state
	if (self.state == NO) {
		[self cancelLocalNotification];
		return;
	}
	
	//check existing
	NSMutableArray *notifications = [[self localNotifications] mutableCopy];
	
	//check missing
	for (unsigned i=0; i<nWeeksToSchedule; i++) {
		//get time
		NSDate *time_i = [self.time dateByAddingTimeInterval: i * 60];
		BOOL foundMatchingLocalNotif = NO;
		for (UILocalNotification *notification in notifications) {
			if ([time_i isEqualToDate:notification.fireDate]) {
				//found matching notification
				foundMatchingLocalNotif = YES;
				[notifications removeObject:notification];
				break;
			}
		}
		if (!foundMatchingLocalNotif) {
			
			//make self objectID perminent
			if (self.objectID.isTemporaryID) {
				[self.managedObjectContext obtainPermanentIDsForObjects:@[self] error:NULL];
			}
			//schedule
			UILocalNotification *localNotif = [[UILocalNotification alloc] init];
			//set fire time
			localNotif.fireDate = time_i;
			localNotif.timeZone = [NSTimeZone systemTimeZone];
			if (self.statement) {
				localNotif.alertBody = [NSString stringWithFormat:LOCALSTR(self.statement)];
			}else{
				localNotif.alertBody = @"It's time to get up!";
			}
			
			localNotif.alertAction = LOCALSTR(@"Get up!");//TODO
			localNotif.soundName = self.tone;
			localNotif.applicationIconBadgeNumber = i+1;
			
			//======= user information passed to app delegate =======
            //Use Alarm's objectID as the identifier instead of serverID to avoid cases where alarm doesn't have one
			localNotif.userInfo = @{kLocalAlarmKey: self.objectID.URIRepresentation.absoluteString,
									kLocalNotificationTypeKey: kLocalNotificationTypeAlarmTimer};
			//=======================================================
			
			if (i == nWeeksToSchedule - 1) {
				//if this is the last one, schedule to be repeat
				localNotif.repeatInterval = NSWeekCalendarUnit;
			}
			
			[[UIApplication sharedApplication] scheduleLocalNotification:localNotif];
			NSLog(@"Local Notif scheduled at %@", localNotif.fireDate.date2detailDateString);
		}
	}
	
	//delete remaining alarm timer
	for (UILocalNotification *ln in notifications) {
		if ([ln.userInfo[kLocalNotificationTypeKey] isEqualToString:kLocalNotificationTypeAlarmTimer]) {
			
			NSLog(@"Unmatched alarm notification deleted (%@) ", ln.fireDate.date2detailDateString);
			[[UIApplication sharedApplication] cancelLocalNotification:ln];
		}
		
	}
	
	//schedule sleep timer
	[self scheduleSleepNotification];
	
}


- (void)cancelTimerLocalNotification{
    NSArray *notifications = [self localNotifications];
    for(UILocalNotification *aNotif in notifications) {
        NSLog(@"Local Notification cancelled for:%@", aNotif.fireDate.date2detailDateString);
        [[UIApplication sharedApplication] cancelLocalNotification:aNotif];
    }
}

- (NSArray *)localNotifications{
    NSMutableArray *notifArray = [[NSMutableArray alloc] init];
    for(UILocalNotification *aNotif in [[UIApplication sharedApplication] scheduledLocalNotifications]) {
        if([aNotif.userInfo[kLocalAlarmKey] isEqualToString:self.objectID.URIRepresentation.absoluteString]) {
            [notifArray addObject:aNotif];
        }
    }
    
    return notifArray;
}

#pragma mark - Sleep notification

- (void)scheduleSleepNotification{
    NSNumber *duration = [EWSession sharedSession].currentUser.preference[kSleepDuration];
    float d = duration.floatValue;
    NSDate *sleepTime = [self.time dateByAddingTimeInterval:-d*3600];
    
    //cancel if no change
    NSArray *notifs = [self localNotifications];
    for (UILocalNotification *notif in notifs) {
        if ([notif.userInfo[kLocalNotificationTypeKey] isEqualToString:kLocalNotificationTypeSleepTimer]) {
            if ([notif.fireDate isEqualToDate:sleepTime]) {
                //nothing to do
                return;
            }else{
                [[UIApplication sharedApplication] cancelLocalNotification:notif];
            }
        }
    }
    
    //local notification
    UILocalNotification *sleepNotif = [[UILocalNotification alloc] init];
    sleepNotif.timeZone = [NSTimeZone systemTimeZone];
    sleepNotif.alertBody = [NSString stringWithFormat:@"It's time to sleep, press here to enter sleep mode (%@)", sleepTime.date2String];
    sleepNotif.alertAction = @"Sleep";
    sleepNotif.repeatInterval = NSWeekCalendarUnit;
    sleepNotif.soundName = @"sleep mode.caf";
    sleepNotif.userInfo = @{kLocalAlarmKey: self.objectID.URIRepresentation.absoluteString,
                            kLocalNotificationTypeKey: kLocalNotificationTypeSleepTimer};
    if ([sleepTime timeIntervalSinceNow]>0) {
        //future
        sleepNotif.fireDate = sleepTime;
    }
    
    [[UIApplication sharedApplication] scheduleLocalNotification:sleepNotif];
    NSLog(@"Sleep notification schedule at %@", sleepNotif.fireDate.date2detailDateString);
}

- (void)cancelSleepNotification{
    NSArray *sleeps = [UIApplication sharedApplication].scheduledLocalNotifications;
    NSInteger n = 0;
    for (UILocalNotification *sleep in sleeps) {
        if ([sleep.userInfo[kLocalNotificationTypeKey] isEqualToString:kLocalNotificationTypeSleepTimer]) {
            [[UIApplication sharedApplication] cancelLocalNotification:sleep];
            n++;
        }
    }
    NSLog(@"Cancelled %ld sleep notification", (long)n);
}


#pragma mark - Schedule Alarm Timer

- (void)scheduleNotificationOnServer{
    if (!self.time) {
        DDLogError(@"*** The Task for schedule push doesn't have time: %@", self);
        return;
    }else if (!self.objectId){
        __block EWAlarm *blockSelf = self;
        [EWSync saveWithCompletion:^{
            [blockSelf scheduleNotificationOnServer];
        }];
        return;
    }
    
    if ([self.time timeIntervalSinceNow] < 0) {
        DDLogWarn(@"The alarm you are trying to schedule on server is in the past: %@", self);
        return;
    }
    NSString *alarmID = self.serverID;
    NSDate *time = self.time;
    //check local schedule records before make the REST call
    __block NSMutableDictionary *timeTable = [[[NSUserDefaults standardUserDefaults] objectForKey:kScheduledAlarmTimers] mutableCopy] ?:[NSMutableDictionary new];
    for (NSString *objectId in timeTable.allKeys) {
        EWAlarm *alarm = [EWAlarm findFirstByAttribute:kParseObjectID withValue:objectId];
        if (alarm.time.timeElapsed > 0) {
            //delete from time table
            [timeTable removeObjectForKey:objectId];
            DDLogInfo(@"Past task on %@ has been removed from schedule table", alarm.time.date2detailDateString);
        }
    }
    //add scheduled time to task
    __block NSMutableArray *times = [[timeTable objectForKey:alarmID] mutableCopy]?:[NSMutableArray new];
    if ([times containsObject:time]) {
        DDLogInfo(@"===Task (%@) timer push (%@) has already been scheduled on server, skip.", alarmID, time);
        return;
    }else{
        [times addObject:time];
        [timeTable setObject:times.copy forKey:alarmID];
        [[NSUserDefaults standardUserDefaults] setObject:timeTable.copy forKey:kScheduledAlarmTimers];
        DDLogInfo(@"Scheduled task timer on server: %@", times);
    }
    
    
    //============ Start scheduling task timer on server ============
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    
    [manager.requestSerializer setValue:kParseApplicationId forHTTPHeaderField:@"X-Parse-Application-Id"];
    [manager.requestSerializer setValue:kParseRestAPIId forHTTPHeaderField:@"X-Parse-REST-API-Key"];
    [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    
    NSDictionary *dic = @{@"where":@{kUsername:[EWSession sharedSession].currentUser.username},
                          @"push_time":[NSNumber numberWithDouble:[time timeIntervalSince1970]+30],
                          @"data":@{@"alert":@"Time to get up",
                                    @"content-available":@1,
                                    kPushType: kPushTypeAlarmTimer,
                                    kPushTaskID: alarmID},
                          };
    
    [manager POST:kParsePushUrl parameters:dic
          success:^(AFHTTPRequestOperation *operation,id responseObject) {
              
              DDLogVerbose(@"SCHEDULED alarm timer PUSH success for time %@", time.date2detailDateString);
              [times addObject:time];
              [timeTable setObject:times forKey:alarmID];
              [[NSUserDefaults standardUserDefaults] setObject:timeTable.copy forKey:kScheduledAlarmTimers];
              
          }failure:^(AFHTTPRequestOperation *operation,NSError *error) {
              
              DDLogError(@"Schedule Push Error: %@", error);
              
          }];
    
}

@end
