//
//  EWPopupMenu.m
//  Woke
//
//  Created by Lei on 4/26/14.
//  Copyright (c) 2014 Shens. All rights reserved.
//

#import "EWPopupMenu.h"
#import "EWUIUtil.h"
#import "EWPersonStore.h"

#define kCallOutBtnSize         40

@interface EWPopupMenu(){
    CGPoint cellCenter;
    EWCollectionPersonCell *cell;
    UIScrollView *collectionView;
    UILabel *name;
    UILabel *locationAndTimeLabel;
}

@end

@implementation EWPopupMenu

-(id)initWithCell:(EWCollectionPersonCell *)c
{
    cell = c;
    collectionView = (UIScrollView *)cell.superview;
    self = [super initWithFrame: collectionView.bounds];
    if (!self) {
        return nil;
    }
    
    //add self
    [collectionView addSubview:self];
    collectionView.scrollEnabled = NO;
    
    
    //move to the cell first
    CGRect frame = CGRectInset(cell.frame, -50, -80);
    CGRect intersection = CGRectIntersection(frame, collectionView.bounds);
    float delay = 0.3;
    if (CGSizeEqualToSize(intersection.size, frame.size)) {
        //no need to move
        delay = 0;
    }else{
        [collectionView scrollRectToVisible:frame animated:YES];
        //TODO: hide the self indicator
    }
    //delay if scrollview moves
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        //[collectionView.delegate scrollViewDidScroll:collectionView];
        
        //alpha view
        self.frame = collectionView.bounds;
        _alphaView = [[UIView alloc] initWithFrame: self.bounds];
        _alphaView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
        _alphaView.alpha = 0;
        //[(UIToolbar *)_alphaView setBarStyle:UIBarStyleBlack];
        [self addSubview:_alphaView];
        
        //cellCenter
        cellCenter = [self convertPoint:cell.center fromView:collectionView];
        
        //create buttons
        _profileButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, kCallOutBtnSize, kCallOutBtnSize)];
        _profileButton.center = cellCenter;
        UIImage *aimge = [UIImage imageNamed:@"Callout_Profile_Btn"];
        [_profileButton setImage:aimge forState:UIControlStateNormal];
        [_profileButton addTarget:self action:@selector(toPerson) forControlEvents:UIControlEventTouchUpInside];
        
        _buzzButton = [[UIButton alloc] initWithFrame: CGRectMake(0, 0, kCallOutBtnSize, kCallOutBtnSize)];
        _buzzButton.center = cellCenter;
        UIImage *bimge=[UIImage imageNamed:@"Callout_Buzz_Btn"];
        [_buzzButton setImage:bimge forState:UIControlStateNormal];
        [_buzzButton addTarget:self action:@selector(toBuzz) forControlEvents:UIControlEventTouchUpInside];
        
        _voiceButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, kCallOutBtnSize, kCallOutBtnSize)];
        _voiceButton.center = cellCenter;
        UIImage *cimge=[UIImage imageNamed:@"Callout_Voice_Message_Btn"];
        [_voiceButton setImage:cimge forState:UIControlStateNormal];
        [_voiceButton addTarget:self action:@selector(toVoice) forControlEvents:UIControlEventTouchUpInside];
        
        _closeButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, kCallOutBtnSize, kCallOutBtnSize)];
        _closeButton.center = cellCenter;
        [_closeButton addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
        UIImage *dimge=[UIImage imageNamed:@"Callout_Close_Btn"];
        [_closeButton setImage:dimge forState:UIControlStateNormal];
        
        
        locationAndTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 120, 22)];
        locationAndTimeLabel.center = cellCenter;
        locationAndTimeLabel.textAlignment = NSTextAlignmentCenter;
        locationAndTimeLabel.adjustsFontSizeToFitWidth = YES;
        locationAndTimeLabel.textColor = [UIColor whiteColor];
        locationAndTimeLabel.font =[UIFont fontWithName:@"Lato-Regular" size:12];
        locationAndTimeLabel.text = cell.timeAndDistance;
        locationAndTimeLabel.alpha = 0;
        [self addSubview:locationAndTimeLabel];
        
        
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeMenu)];
        [self addGestureRecognizer:tap];
        
        [self addSubview:_profileButton];
        [self addSubview:_buzzButton];
        [self addSubview:_voiceButton];
//        [self addSubview:_closeButton];
        _profileButton.alpha=0;
        _buzzButton.alpha=0;
        _voiceButton.alpha=0;
        _closeButton.alpha=0;
        //name.alpha = 0;
        
        
        //bring cell to the top
        [collectionView bringSubviewToFront:cell];
        
        
        [UIView transitionWithView:cell
                          duration:0.3
                           options:(/*UIViewAnimationOptionTransitionFlipFromLeft | */UIViewAnimationOptionAllowAnimatedContent)
                        animations:
         ^{
             CGAffineTransform scale = CGAffineTransformMakeScale(1.2, 1.2);
             cell.transform = scale;
             
             //hide everything
             cell.km.alpha = 0;
             cell.time.alpha = 0;
             cell.initial.alpha = 0;
             
             //show name and info
             locationAndTimeLabel.alpha = 1;
             cell.name.alpha = 1;
             
             //location
             _profileButton.x += kCollectionViewCellWidth / 2 + 22.5;
             _profileButton.y -= kCollectionViewCellHeight / 2 + 15;
             _buzzButton.y -= kCollectionViewCellHeight / 2 + 15;
             _buzzButton.x -= kCollectionViewCellWidth / 2 + 22.5;
             _voiceButton.y -= kCollectionViewCellHeight / 2 + 30 + kCallOutBtnSize/2;
             locationAndTimeLabel.y += kCollectionViewCellHeight / 2 + 40;
             cell.name.y += 20;
             
             _alphaView.alpha = 1;
             _profileButton.alpha=1;
             _buzzButton.alpha=1;
             _voiceButton.alpha=1;
             _closeButton.alpha=1;
             
             [EWUIUtil applyShadow:name];
             //[EWUIUtil applyShadow:locationAndTimeLabel];
             
         } completion:^(BOOL finished){
             
         }];
    });

    return self;
}



- (void)toPerson
{
    self.toProfileButtonBlock();
}
- (void)toBuzz
{
    self.toBuzzButtonBlock();
}
- (void)toVoice
{
    self.toVoiceButtonBlock();
}

//close method
- (void)closeMenu{
    [self closeMenuWithCompletion:NULL];
}

- (void)closeMenuWithCompletion:(void (^)(void))block{
    
    //[UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
    
    [UIView transitionWithView:cell
                      duration:0.25
                       options:(/*UIViewAnimationOptionTransitionFlipFromRight | */UIViewAnimationOptionAllowAnimatedContent)
                    animations:
     ^{
         //me
         BOOL isMe = cell.person.isMe;
         if (isMe) {
             cell.initial.alpha = 1;
         }
         
         //scale
         CGAffineTransform scale = CGAffineTransformMakeScale(1.0, 1.0);
         cell.transform = scale;
         
         //shadow
         cell.layer.shadowRadius = 0;
         
         //location
         _profileButton.center = cellCenter;
         _buzzButton.center = cellCenter;
         _voiceButton.center = cellCenter;
         _closeButton.center = cellCenter;
         CGPoint nameRect = cell.name.center;
         nameRect.y -= 20;
         cell.name.center = nameRect;
         locationAndTimeLabel.center = cellCenter;
         
         if (cell.showDistance){
             cell.km.alpha = 1;
         }
         if (cell.showTime) {
             cell.time.alpha = 1;
         }
         if (!cell.showName) {
             cell.name.alpha = 0;
         }
         _profileButton.alpha=0;
         _buzzButton.alpha=0;
         _voiceButton.alpha=0;
         _closeButton.alpha=0;
         _alphaView.alpha=0;
         //name.alpha = 0;
         locationAndTimeLabel.alpha = 0;
         
     } completion:^(BOOL finished) {
         collectionView.scrollEnabled = YES;
         [self removeFromSuperview];
         
         if (block) {
             block();
         }
         
     }];
}




////open method
//+ (void)flipCell:(EWCollectionPersonCell *)cell completion:(void (^)(void))block{
//    if (cell.isSelected == YES) {
//        //back to initial state
//        [UIView transitionWithView:cell
//                          duration:0.4
//                           options:(/*UIViewAnimationOptionTransitionFlipFromLeft | */UIViewAnimationOptionAllowAnimatedContent)
//                        animations:^{
//            //cell.white.alpha = 0.8;
//            //cell.distance.alpha = 1;
//            cell.time.alpha = 1;
//            cell.initial.alpha = 0;
//        } completion:^(BOOL finished) {
//            if (block) {
//                block();
//            }
//        }];
//        [UIView animateWithDuration:0.4 animations:^{
//            
//        }];
//    }else{
//        
//        [UIView transitionWithView:cell
//                          duration:0.4
//                           options:(/*UIViewAnimationOptionTransitionFlipFromRight | */UIViewAnimationOptionAllowAnimatedContent)
//                        animations:
//         ^{
//             cell.selected = YES;
//             cell.time.alpha = 0;
//             cell.initial.alpha = 1;
//        } completion:^(BOOL finished) {
//            if (block) {
//                block();
//            }
//        }];
//    }
//}

@end