//
//  UIViewController+Blur.m
//  EarlyWorm
//
//  Created by Lei on 3/23/14.
//  Copyright (c) 2014 Shens. All rights reserved.
//

#import "UIViewController+Blur.h"
#import "EWUIUtil.h"
#import "NavigationControllerDelegate.h"


static NavigationControllerDelegate *delegate = nil;

@implementation UIViewController (Blur)

- (void)presentViewControllerWithBlurBackground:(UIViewController *)viewController{
	
	[self presentViewControllerWithBlurBackground:viewController completion:NULL];
	
}

- (void)presentViewControllerWithBlurBackground:(UIViewController *)viewController completion:(void (^)(void))block{
	[self presentViewControllerWithBlurBackground:viewController option:EWBlurViewOptionBlack completion:block];
}


- (void)presentViewControllerWithBlurBackground:(UIViewController *)viewController option:(EWBlurViewOptions)blurOption completion:(void (^)(void))block{
	viewController.modalPresentationStyle = UIModalPresentationCustom;
	if (!delegate) {
		delegate = [NavigationControllerDelegate new];
	}
	
	viewController.transitioningDelegate = delegate;
	if ([viewController isKindOfClass:[UINavigationController class]]) {
		[(UINavigationController *)viewController setDelegate:delegate];
	}
	
	if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
		
		//hide status bar
		[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
		
		//if active, show the animation
		[self presentViewController:viewController animated:YES completion:block];
	} else {
		//if inactive, wait until app become active
		__block id observer = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			NSLog(@"Application did become active, start blur animation");
			[self presentViewController:viewController animated:YES completion:block];
			[[NSNotificationCenter defaultCenter] removeObserver:observer];
		}];
	}
	
	
	
	return;
}


- (void)dismissBlurViewControllerWithCompletionHandler:(void(^)(void))completion{
	[self dismissViewControllerAnimated:YES completion:^{
		if (completion) {
			completion();
		}
		
		//status bar
		[[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
	}];
	
	
}



@end
