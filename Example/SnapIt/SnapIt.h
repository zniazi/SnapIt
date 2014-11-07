//
//  SnapIt.h
//  SnapClass
//
//  Created by Zak Niazi on 10/28/14.
//  Copyright (c) 2014 DanZak. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SnapIt : NSObject
@property (strong, nonatomic) NSString *databasePath;
@property (nonatomic, readonly) NSNumber *rowID;

- (void)save;
- (void)deleteSelf;
- (void)fetch;

+ (NSArray *)where:(NSString *)whereClause;
+ (NSArray *)all;
+ (NSArray *)performFetchWithSQL:(NSString *)sql;
+ (id)find:(NSInteger *)objectID;

@end

