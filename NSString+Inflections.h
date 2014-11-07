//
//  NSString+Inflections.h
//  SnapClass
//
//  Created by Zak Niazi on 10/30/14.
//  Copyright (c) 2014 DanZak. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Inflections)
- (NSString *)underscore;
- (NSString *)camelcase;
- (NSString *)classify;
- (NSString *)lowCamelCase;
@end
