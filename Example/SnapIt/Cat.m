//
//  Cat.m
//  SnapClass
//
//  Created by Zak Niazi on 11/1/14.
//  Copyright (c) 2014 DanZak. All rights reserved.
//

#import "Cat.h"

@implementation Cat
- (instancetype)init {
    self = [self initWithName:@"" andColor:@""];
    return self;
}

- (instancetype)initWithName:(NSString *)name
                    andColor:(NSString *)color {
    self = [super init];
    if (self) {
        _name = name;
        _color = color;
    }
    
    return self;
}

@end