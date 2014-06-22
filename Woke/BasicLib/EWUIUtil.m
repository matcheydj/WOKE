//
//  EWUIUtil.m
//  EarlyWorm
//
//  Created by shenslu on 13-8-3.
//  Copyright (c) 2013年 Shens. All rights reserved.
//

#import "EWUIUtil.h"
#import "EWAppDelegate.h"

@implementation EWUIUtil

+ (CGFloat)screenWidth {
    return [[UIScreen mainScreen] bounds].size.width;
}

+ (CGFloat)screenHeight {
    return [[UIScreen mainScreen] bounds].size.height;
}

+ (CGFloat)navigationBarHeight {
    return 44;
}

+ (CGFloat)statusBarHeight {
    return [UIApplication sharedApplication].statusBarFrame.size.height;
}

+ (void)OnSystemStatusBarFrameChange {
    
}

+ (BOOL) isMultitaskingSupported {
    
    BOOL result = NO;
    
    if ([[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)]){
        result = [[UIDevice currentDevice] isMultitaskingSupported];
    }
    return result;
}

+ (void)showHUDWithCheckMark:(NSString *)str{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:rootViewController.view animated:YES];
    hud.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark"]];
    hud.mode = MBProgressHUDModeCustomView;
    hud.labelText = str;
    [hud hide:YES afterDelay:1.5];
}

+ (NSString *)toString:(NSDictionary *)dic{
    NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:NULL];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return str;
}

+ (CGFloat)distanceOfRectMid:(CGRect)rect1 toRectMid:(CGRect)rect2{
    
    CGFloat distance = sqrt(pow((CGRectGetMidX(rect1) - CGRectGetMidX(rect2)),2) + pow((CGRectGetMidY(rect1) - CGRectGetMidY(rect2)), 2));
    return distance;
}

+ (CGFloat)distanceOfPoint:(CGPoint)point1 toPoint:(CGPoint)point2{
    CGFloat distance = sqrt(pow((point1.x - point2.x),2) + pow((point1.y - point2.y), 2));
    return distance;
}

+ (void)addImage:(UIImage *)image toAlertView:(UIAlertView *)alert{
    
    alert.message = [NSString stringWithFormat:@"\n\n\n\n\n%@", alert.message];
    UIImageView *imgView = [[UIImageView alloc] initWithImage:image];
    CGRect frame = imgView.frame;
    frame.origin.x = 40;
    frame.origin.y = (alert.frame.size.width - imgView.frame.size.width)/2;
    
}

+ (void)applyHexagonMaskForView:(UIView *)view{
    float originalSize = 80.0;
    
    //get mask
    CAShapeLayer *hexagonMask = [[CAShapeLayer alloc] initWithLayer:view.layer];
    UIBezierPath *hexagonPath = [EWUIUtil getHexagonPath];
    
    //scale
    float height = view.bounds.size.height;
    float width = view.bounds.size.width;
    float ratio = MAX(height, width)/originalSize;
    [hexagonPath applyTransform:CGAffineTransformMakeScale(ratio, ratio)];
    
    //apply mask
    hexagonMask.path = hexagonPath.CGPath;
    view.layer.mask  = hexagonMask;
    view.layer.masksToBounds = YES;
    //view.clipsToBounds = YES;
}

+ (void)applyHexagonSoftMaskForView:(UIView *)view{
    float originalSize = 80.0;
    CAShapeLayer *hexagonMask = [[CAShapeLayer alloc] initWithLayer:view.layer];
    UIBezierPath *hexagonPath = [EWUIUtil getHexagonSoftPath];
    float height = view.bounds.size.height;
    float width = view.bounds.size.width;
    float ratio = MAX(height, width)/originalSize;
    [hexagonPath applyTransform:CGAffineTransformMakeScale(ratio, ratio)];
    
    hexagonMask.path = hexagonPath.CGPath;
    view.layer.mask  = hexagonMask;
    view.layer.masksToBounds = YES;
    //view.clipsToBounds = YES;
}

+ (UIBezierPath *)getHexagonSoftPath{
    
    UIBezierPath* polygonPath = [UIBezierPath bezierPath];
    [polygonPath moveToPoint: CGPointMake(70.23, 17.06)];
    [polygonPath addCurveToPoint: CGPointMake(45.22, 2.34) controlPoint1: CGPointMake(55, 8.1) controlPoint2: CGPointMake(56.04, 8.53)];
    [polygonPath addCurveToPoint: CGPointMake(34.71, 2.34) controlPoint1: CGPointMake(41.86, 0.42) controlPoint2: CGPointMake(37.52, 0.68)];
    [polygonPath addCurveToPoint: CGPointMake(9.73, 17.06) controlPoint1: CGPointMake(32.64, 3.57) controlPoint2: CGPointMake(17.78, 12.31)];
    [polygonPath addCurveToPoint: CGPointMake(5, 25.9) controlPoint1: CGPointMake(6.86, 18.76) controlPoint2: CGPointMake(4.97, 20.93)];
    [polygonPath addCurveToPoint: CGPointMake(5, 52.86) controlPoint1: CGPointMake(5.08, 39.43) controlPoint2: CGPointMake(5.06, 48.65)];
    [polygonPath addCurveToPoint: CGPointMake(9.73, 62.37) controlPoint1: CGPointMake(4.94, 57.06) controlPoint2: CGPointMake(6.39, 60.1)];
    [polygonPath addCurveToPoint: CGPointMake(34.71, 77.51) controlPoint1: CGPointMake(13.07, 64.64) controlPoint2: CGPointMake(31.59, 75.65)];
    [polygonPath addCurveToPoint: CGPointMake(45.22, 77.51) controlPoint1: CGPointMake(37.83, 79.36) controlPoint2: CGPointMake(41.56, 79.63)];
    [polygonPath addCurveToPoint: CGPointMake(70.23, 62.37) controlPoint1: CGPointMake(55.42, 71.57) controlPoint2: CGPointMake(68.24, 63.93)];
    [polygonPath addCurveToPoint: CGPointMake(74.99, 52.86) controlPoint1: CGPointMake(72.93, 60.25) controlPoint2: CGPointMake(74.98, 58.06)];
    [polygonPath addCurveToPoint: CGPointMake(74.99, 25.9) controlPoint1: CGPointMake(75, 41.06) controlPoint2: CGPointMake(75, 40.06)];
    [polygonPath addCurveToPoint: CGPointMake(70.23, 17.06) controlPoint1: CGPointMake(74.98, 20.8) controlPoint2: CGPointMake(74.04, 19.3)];
    [polygonPath closePath];
    polygonPath.miterLimit = 11;
    
    polygonPath.lineJoinStyle = kCGLineJoinRound;
    
    
    return polygonPath;
}

+ (UIBezierPath *)getHexagonPath{
    UIBezierPath* polygonPath = [UIBezierPath bezierPath];
    [polygonPath moveToPoint: CGPointMake(40, -0)];
    [polygonPath addLineToPoint: CGPointMake(5, 20)];
    [polygonPath addLineToPoint: CGPointMake(5, 60)];
    [polygonPath addLineToPoint: CGPointMake(40, 80)];
    [polygonPath addLineToPoint: CGPointMake(75, 60)];
    [polygonPath addLineToPoint: CGPointMake(75, 20)];
    [polygonPath addLineToPoint: CGPointMake(40, -0)];
    [polygonPath closePath];
    
    return polygonPath;
}

+ (void)applyShadow:(UIView *)view{
    view.layer.shadowColor = [UIColor blackColor].CGColor;
    float op = 0.4;
    float r = 5;
    if ([view isKindOfClass:[UILabel class]]) {
        op = 1.0;
        r = 3;
    }
    view.layer.shadowOpacity = op;
    view.layer.shadowRadius = r;
    view.layer.shadowOffset = CGSizeMake(0,0);
    view.clipsToBounds = NO;
}

+ (CGPoint)getCartesianFromPolarCoordinateOfR:(float)r degree:(float)d{
    float degree_pi = d/180 * M_PI;
    float x = r * cosf(degree_pi);
    float y = r * sinf(degree_pi);
    CGPoint p = CGPointMake(x, y);
    return p;
}

+ (void)applyAlphaGradientForView:(UIView *)view withEndPoints:(NSArray *)locations{
    //alpha mask
    
    CAGradientLayer *alphaMask = [CAGradientLayer layer];
    alphaMask.anchorPoint = CGPointZero;
    alphaMask.startPoint = CGPointZero;
    alphaMask.endPoint = CGPointMake(0.0f, 1.0f);
    UIColor *startColor = [UIColor colorWithWhite:1.0 alpha:0.0];
    UIColor *endColor = [UIColor colorWithWhite:1.0 alpha:1.0];
    NSArray *endPoints;
    NSArray *colors;
    if (locations.count == 1) {
        endPoints = @[@0.0, locations[0], @1.0];
        colors = @[(id)startColor.CGColor, (id)endColor.CGColor, (id)endColor.CGColor];
    }else if (locations.count == 2){
        endPoints = @[@0.0, locations[0], locations[1], @1.0];
        colors = @[(id)startColor.CGColor, (id)endColor.CGColor, (id)endColor.CGColor, (id)startColor.CGColor];
    }
    alphaMask.colors = colors;
    alphaMask.locations =endPoints;
    alphaMask.bounds = CGRectMake(0, 0, view.frame.size.width, view.frame.size.height);
    view.backgroundColor = [UIColor clearColor];
    view.layer.mask = alphaMask;
    
}

@end
