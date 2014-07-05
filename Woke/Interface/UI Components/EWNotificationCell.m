//
//  EWNotificationCell.m
//  Woke
//
//  Created by Lee on 7/3/14.
//  Copyright (c) 2014 Shens. All rights reserved.
//

#import "EWNotificationCell.h"
#import "EWNotification.h"
#import "EWPerson.h"
#import "EWUIUtil.h"
#import "EWPersonStore.h"


@implementation EWNotificationCell

- (void)awakeFromNib
{
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setNotification:(EWNotification *)notification{
  
    //time
    double t = notification.updatedAt.timeElapsed;
    self.time.text = [[EWUIUtil getStringFromTime:t] stringByAppendingString:@" ago"];
    
    NSString *type = notification.type;
    if ([type isEqualToString:kNotificationTypeNotice]) {
        self.profilePic.image = nil;
        NSInteger deltaX = self.detail.x - self.profilePic.x;
        self.detail.left = self.profilePic.x;
        self.detail.width += deltaX;
        self.time.left = self.profilePic.x;
        self.time.width += deltaX;
        
        NSString *title = notification.userInfo[@"title"];
        NSString *body = notification.userInfo[@"content"];
        NSString *link = notification.userInfo[@"link"];
        
        self.detail.text = title;
    }else{
        self.profilePic.image = notification.owner.profilePic;
        [EWUIUtil applyHexagonSoftMaskForView:self.profilePic];
        EWPerson *sender = [[EWPersonStore sharedInstance] getPersonByObjectID:notification.sender];
        if([type isEqualToString:kNotificationTypeFriendRequest]){
            
               self.detail.text = [NSString stringWithFormat:@"%@ has sent you a friend request  fdsj fdls kfjk lsdjflj sdalkjf lksdajlfja sdk  lfjlk sdfjljs dlfj lsdajf", sender.name];
            
            
        }else if([type isEqualToString:kNotificationTypeFriendAccepted]){
            
            self.detail.text = [NSString stringWithFormat:@"%@ has sent accepted your friend request fjdlfjdslkflfdls", sender.name];
            
        }else if (kNotificationTypeNextTaskHasMedia){
            self.detail.text = @"You have received voice(s) for tomorrow morning. To find out, wake up on time!";
        }
    }
    
    
    if (notification.completed) {
        self.detail.enabled = NO;
        self.time.enabled = NO;
    }else{
        self.detail.enabled = YES;
        self.time.enabled = YES;
    }
    
    
//    self.detail.textColor = [UIColor whiteColor];
//    CGSize fixLabelSize = [self.detail.text  sizeWithFont:self.detail.font constrainedToSize:CGSizeMake(250, 1000)  lineBreakMode:UILineBreakModeWordWrap];
//    self.detail.height = fixLabelSize.height;
//    
//   
//    self.detail.backgroundColor = [UIColor whiteColor];
//   
//    CGFloat deltaHeight = self.detail.height - 35;
//    //self.detail.height += deltaHeight;
//    self.time.y += deltaHeight;
//    self.contentView.height += deltaHeight;
//    self.height = self.contentView.height;
//    
//    [self setNeedsDisplay];
}



@end
