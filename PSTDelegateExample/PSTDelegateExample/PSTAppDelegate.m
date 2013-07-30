//
//  PSTAppDelegate.m
//  PSTDelegateExample
//
//  Created by Peter Steinberger on 30/07/13.
//  Copyright (c) 2013 Peter Steinberger. All rights reserved.
//

#import "PSTAppDelegate.h"

#import "PSTDelegateProxy.h"
#import "PSTExampleDelegate.h"

@interface TestDelegate : NSObject<PSTExampleDelegate>
@end

@implementation TestDelegate
@end

@implementation PSTAppDelegate 

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    PSTDelegateProxy *delegateProxy;
    @autoreleasepool {
        TestDelegate *delegate = [TestDelegate new];
        delegateProxy = [[PSTDelegateProxy alloc] initWithDelegate:delegate];
    }
    [(id<PSTExampleDelegate>)delegateProxy exampleDelegateCalledWithString:@"Test"];
    
    return YES;
}

@end
