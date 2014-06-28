//
//  EWUIUtil.h
//  EarlyWorm
//
//  Created by shenslu on 13-8-3.
//  Copyright (c) 2013年 Shens. All rights reserved.
//

#import <Foundation/Foundation.h>

// 基本界面常量宏
#define kTabBarHeight           49

// 基本界面变量宏
#define EWScreenWidth           [EWUIUtil screenWidth]
#define EWScreenHeight          [EWUIUtil screenHeight]

#define EWMainWidth             EWScreenWidth
#define EWMainHeight            (EWScreenHeight - [EWUIUtil statusBarHeight])

#define EWContentWidth          EWScreenWidth
#define EWContentHeight         (EWMainHeight - [EWUIUtil navigationBarHeight])

// 基本标准界面常量宏
#define kStandardUITableViewCellHeight     44
#define kAlarmCellHeight     80

@interface EWUIUtil : NSObject

+ (CGFloat)screenWidth;
+ (CGFloat)screenHeight;

+ (CGFloat)navigationBarHeight;

+ (CGFloat)statusBarHeight;

+ (void)OnSystemStatusBarFrameChange;

+ (BOOL)isMultitaskingSupported;

+ (void)showHUDWithCheckMark:(NSString *)str;

+ (NSString *)toString:(NSDictionary *)dic;

+ (CGFloat)distanceOfRectMid:(CGRect)rect1 toRectMid:(CGRect)rect2;

+ (CGFloat)distanceOfPoint:(CGPoint)point1 toPoint:(CGPoint)point2;

+ (void)addImage:(UIImage *)image toAlertView:(UIAlertView *)alert;

+ (void)applyHexagonMaskForView:(UIView *)view;
+ (void)applyHexagonSoftMaskForView:(UIView *)view;

+ (UIBezierPath *)getHexagonPath;

+ (void)applyShadow:(UIView *)view;

+ (CGPoint)getCartesianFromPolarCoordinateOfR:(float)r degree:(float)d;

+ (void)applyAlphaGradientForView:(UIView *)view withEndPoints:(NSArray *)locations;

+ (void)addTransparantNavigationBarToViewController:(UIViewController *)vc withLeftItem:(UIBarButtonItem *)leftItem rightItem:(UIBarButtonItem *)rightItem;
@end
