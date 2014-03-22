//
//  EWMediaSlider.h
//  EarlyWorm
//
//  Created by Lei on 3/18/14.
//  Copyright (c) 2014 Shens. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface EWMediaSlider : UISlider{
    UILabel *typeLabel;
}
@property (nonatomic) UILabel *timeLabel;
@property (nonatomic) UIImageView *buzzIcon;
@property (nonatomic) UIImageView *playIndicator;
@property (nonatomic) NSString *type;


- (void)play;
- (void)stop;
@end