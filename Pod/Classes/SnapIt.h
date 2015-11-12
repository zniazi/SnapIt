//
//  SnapIt.h
//  SnapClass
//
//  Created by Zak Niazi on 10/28/14.
//  Copyright (c) 2014 Zak Niazi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>
#import <objc/runtime.h>

@interface SnapIt : NSObject
@property (strong, nonatomic) NSNumber *backendId;
@property (nonatomic, readonly) NSNumber *rowID;

- (BOOL)save;
- (void)deleteSelf;
- (void)fetch;

+ (NSArray *)where:(NSString *)whereClause;
+ (NSArray *)all;
+ (NSArray *)performFetchWithSQL:(NSString *)sql;
+ (id)find:(NSInteger *)objectID;
+ (void)deleteAll;
+ (NSString *)baseURL; // Possible to be deleted.
+ (id)lastObject;
+ (NSString *)executeSQL:(NSString *)sql;

// Networking
- (void)pushBackendWithCompletionBlock:(void (^)(BOOL success))completionBlock;
- (void)pullBackendWithCompletionBlock:(void (^)(NSDictionary *response))completionBlock;
@end
