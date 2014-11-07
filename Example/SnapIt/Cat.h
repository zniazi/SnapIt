//
//  Cat.h
//  SnapClass
//
//  Created by Zak Niazi on 11/1/14.
//  Copyright (c) 2014 DanZak. All rights reserved.
//

#import "Person.h"
#import "SnapIt.h"

@interface Cat : SnapIt
@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *color;
@property (strong, nonatomic) Person *person;
@end
