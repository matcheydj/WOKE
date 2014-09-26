//
//  WOKE_Tests.m
//  WOKE Tests
//
//  Created by Zitao Xiong on 17/09/2014.
//  Copyright (c) 2014 WokeAlarm.com. All rights reserved.
//

#import <XCTest/XCTest.h>
#define EXP_SHORTHAND YES
#import "Expecta.h"
#import "OCMock.h"
#import "EWPerson.h"
#import "CoreData+MagicalRecord.h"
#import "EWDataStore.h"
#import "EWPersonStore.h"
#import "EWSync.h"

@interface WOKE_Tests : XCTestCase

@end

@implementation WOKE_Tests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [Expecta setAsynchronousTestTimeout:3];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample
{
    expect(2).equal(2);
    
//    [[MakeSpaceSessionManager shared] loginWithEmail:@"false@xxx.com" password:@"faslse" completion:^(NSDictionary *dictioanry, NSError *aError) {
//        response = dictioanry;
//        error = aError;
//    }];
//    
//    expect(response).will.beNil();
//    expect(error).willNot.beNil();
//    expect(error).will.beKindOf([NSError class]);
}

- (void)testUploadMO {
    NSArray *allPerson = [EWPerson MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"NOT %K IN %@", kParseObjectID, [me.friends valueForKey:kParseObjectID]]];
    
    EWPerson *friend = allPerson.firstObject;
    
    [me addFriendsObject:friend];
    
    __block PFUser *aUser;
    [EWSync saveWithCompletion:^{
        NSLog(@"save");
        aUser = (PFUser *)me.parseObject;
    }];
    expect([[aUser[@"friends"] valueForKey:kParseObjectID] containsObject:friend.serverID]).after(13).to.beNil();
}

@end