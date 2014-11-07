# SnapIt

[![CI Status](http://img.shields.io/travis/Zak Niazi/SnapIt.svg?style=flat)](https://travis-ci.org/Zak Niazi/SnapIt)
[![Version](https://img.shields.io/cocoapods/v/SnapIt.svg?style=flat)](http://cocoadocs.org/docsets/SnapIt)
[![License](https://img.shields.io/cocoapods/l/SnapIt.svg?style=flat)](http://cocoadocs.org/docsets/SnapIt)
[![Platform](https://img.shields.io/cocoapods/p/SnapIt.svg?style=flat)](http://cocoadocs.org/docsets/SnapIt)

## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first. You must add "libsqlite3.dylib" to your "Linked Frameworks and Libraries" section of your application.

`SnapIt` encapsulates the common patterns of persisting data to permanent storage via a SQLite Connection. 

#### Persisting a SnapIt Resource.

```objective-c
#import "SnapIt.h"
@interface Cat : SnapIt
```

To persist data, inherit from the SnapIt class.

#### `SAVE` method

```objective-c
Cat *mits = [[Cat alloc] init];
mits.name = @"Mits";
mits.color = @"orange";
[mits save];
```

To add an object to the database, modify it's attributes and run the save method.

#### `ALL` method

```objective-c
NSArray *cats = [Cat all];
```

To retrieve all objects from the database, run the all method on the class you wish to query.

#### `WHERE` method

```objective-c
NSArray *people = [Person where:@"name='Beth'"];
Person *beth = people[0];
```

To retrieve an object from the database meeting a specific criteria, enter a where clause on the class in question with the where clause formatted as "object_property=value"

#### `DELETE` method

```objective-c
[lucy deleteSelf];
```

To delete an object from the database, run deleteSelf on the instance.

#### `FETCH` method

```objective-c
[beth fetch];
```

To update an object with it's values in the database, run the fetch method on the instance. An example of when this is needed is after deleting an object with an association to the class. Run fetch to refresh it's data.

#### `BELONGS TO` association

```objective-c
@property (strong, nonatomic) Person *person;
```

To set up a belongs to association, simply list a property in the header file with the class name. The name of the property must be the same as the class name, non pluralized. (i.e Cat => "cat")

#### Example Usage

```objective-c
Person *beth = [[Person alloc] init];
beth.name = @"Beth";
[beth save];

Cat *bubbles = [[Cat alloc] init];
bubbles.name = @"Bubbles";
bubbles.color = @"grey";
bubbles.person = beth;
[bubbles save];

bubbles.person => <Person: 0x7ff323f33a20>
```

#### `HAS MANY` association

```objective-c
@property (strong, nonatomic) NSArray *cats;
```

To set up a has many association, list an array property in the header file. The name of the property must be the same as the pluralized class name. (i.e Cat => "cats")

#### Example Usage

```objective-c
Person *beth = [[Person alloc] init];
NSArray *allCats = [Cat all];
beth.cats = allCats;
[beth save];

beth.cats => [
"<Cat: 0x7ff589f5ccc0>",
"<Cat: 0x7ff589f5d360>",
"<Cat: 0x7ff589f5dc70>",
"<Cat: 0x7ff589f5ead0>",
"<Cat: 0x7ff589f618a0>",
"<Cat: 0x7ff589f5f0f0>"
]
```

## Requirements

## Installation

SnapIt is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

    pod "SnapIt"

## Authors

Zak Niazi, zniazi1029@gmail.com

Daniel Wu, dan.wu.87@gmail.com

## License

SnapIt is available under the MIT license. See the LICENSE file for more info.

