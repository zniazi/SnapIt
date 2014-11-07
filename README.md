# SnapIt

[![CI Status](http://img.shields.io/travis/Zak Niazi/SnapIt.svg?style=flat)](https://travis-ci.org/Zak Niazi/SnapIt)
[![Version](https://img.shields.io/cocoapods/v/SnapIt.svg?style=flat)](http://cocoadocs.org/docsets/SnapIt)
[![License](https://img.shields.io/cocoapods/l/SnapIt.svg?style=flat)](http://cocoadocs.org/docsets/SnapIt)
[![Platform](https://img.shields.io/cocoapods/p/SnapIt.svg?style=flat)](http://cocoadocs.org/docsets/SnapIt)

## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first.

`SnapIt` encapsulates the common patterns of persisting data to permanent storage via a SQLite Connection. 

#### `SAVE` method

```objective-c
Cat *mits = [[Cat alloc] init];
mits.name = @"Mits";
mits.color = @"orange";
[mits save];
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

