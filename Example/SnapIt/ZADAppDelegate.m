//
//  ZADAppDelegate.m
//  SnapIt
//
//  Created by CocoaPods on 11/06/2014.
//  Copyright (c) 2014 Zak Niazi. All rights reserved.
//

#import "ZADAppDelegate.h"

@implementation ZADAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
# pragma mark - Code Snippet 1
    //    Cat *mits = [[Cat alloc] init];
    //    mits.name = @"Mits";
    //    mits.color = @"orange";
    //    [mits save];
    
# pragma mark - Code Snippet 2
    //    Person *beth = [[Person alloc] init];
    //    beth.name = @"Beth";
    //    [beth save];
    //
    //    Cat *bubbles = [[Cat alloc] init];
    //    bubbles.name = @"Bubbles";
    //    bubbles.color = @"grey";
    //    bubbles.person = beth;
    //    [bubbles save];
    
# pragma mark - Code Snippet 3
    //    Cat *lucy = [[Cat alloc] init];
    //    lucy.name = @"Lucy";
    //    lucy.color = @"indigo";
    //    [lucy save];
    //
    //    NSArray *people = [Person where:@"name='Bet'"];
    //    Person *beth = people[0];
    //    NSArray *allCats = [Cat all];
    //    beth.cats = allCats;
    //    [beth save];
    
# pragma mark - Code Snippet 4
    //    Person *beth = [Person where:@"name='Beth'"][0];
    //    NSLog(@"%@", beth.cats);
    
    //    Cat *lucy = [Cat where:@"name='Lucy'"][0];
    //    [lucy deleteSelf];
    
    //    [beth fetch];
    //    NSLog(@"%@", beth.cats);
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
