//
//  SnapIt.h
//  SnapClass
//
//  Created by Zak Niazi on 10/28/14.
//  Copyright (c) 2014 DanZak. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SnapIt : NSObject
@property (strong, nonatomic) NSNumber *backendId;

- (void)save;
- (void)deleteSelf;
- (void)fetch;

+ (NSArray *)where:(NSString *)whereClause;
+ (NSArray *)all;
+ (NSArray *)performFetchWithSQL:(NSString *)sql;
+ (id)find:(NSInteger *)objectID;
+ (void)deleteAll;
+ (NSString *)baseURL; // Possible to be deleted.

// Networking
- (void)pushBackendWithCompletionBlock:(void (^)(BOOL success))completionBlock;
- (void)pullBackend;
@end

