//
//  EWActivityManager.h
//  Woke
//
//  Created by Lei Zhang on 10/29/14.
//  Copyright (c) 2014 WokeAlarm.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EWPerson.h"

@interface EWActivityManager : NSObject

+ (EWActivityManager *)sharedManager;
+ (NSArray *)myActivities;

- (EWActivity *)createMediaActivityWithMedia:(EWMedia *)media;
- (EWActivity *)createFriendshipActivityWithPerson:(EWPerson *)person friended:(BOOL)friended;

@end
