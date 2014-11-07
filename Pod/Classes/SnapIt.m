//
//  SnapIt.m
//  SnapClass
//
//  Created by Zak Niazi on 10/28/14.
//  Copyright (c) 2014 DanZak. All rights reserved.
//

#import "SnapIt.h"
#import <sqlite3.h>
#import <objc/runtime.h>
#import "NSString+Inflections.h"
#import "Swizzlean.h"

static sqlite3 *_catsDB;
static NSString *_databasePath;
static NSDictionary *_propertiesListAndTypes;
static NSString *_lastSwizzledGetter;

@interface SnapIt()
@property (nonatomic, readwrite) NSNumber *rowID;
@end

@implementation SnapIt

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self createHasManyAssociations];
    }
    return self;
}

+(void)initialize {
    [self setupDB];
}

+ (NSString *)databasePath {
    return _databasePath;
}

+ (sqlite3 **)catsDB {
    return &_catsDB;
}

+ (NSString *)getClassName
{
    return [NSStringFromClass([self class]) underscore];
}

+ (NSString *)getTableName
{
    return [NSString stringWithFormat:@"%@s", [self getClassName]];
}

+ (NSArray *)allPropertyNames
{
    unsigned count;
    objc_property_t *properties = class_copyPropertyList(self, &count);
    
    NSMutableArray *propertyList = [NSMutableArray array];
    
    unsigned i;
    for (i = 0; i < count; i++)
    {
        objc_property_t property = properties[i];
        NSString *name = [NSString stringWithUTF8String:property_getName(property)];
        [propertyList addObject:name];
    }
    
    free(properties);
    
    return propertyList;
}

+ (void)getAllPropertiesAndTypes
{
    unsigned int propertyCount;
    objc_property_t *properties = class_copyPropertyList(self, &propertyCount);
    
    NSMutableDictionary *temporaryDictionary = [[NSMutableDictionary alloc] init];
    
    for (int i  = 0; i < propertyCount; i++) {
        
        objc_property_t currentProperty = properties[i];
        
        NSString *propertyName = [NSString stringWithUTF8String:property_getName(currentProperty)];
        
        const char *cPropertyType = property_getAttributes(currentProperty);
        NSString *propertyTypeAfterParse = [self parseString:cPropertyType];
        
        //only objective C objects are stored into dictionary
        if ([self isObject:cPropertyType]) {
            [temporaryDictionary setObject:propertyTypeAfterParse forKey:propertyName];
        }
    }
    
    NSMutableDictionary *correctDictionary = [[NSMutableDictionary alloc] init];
    
    for (NSString *key in temporaryDictionary) {
        if ([temporaryDictionary[key] isEqualToString:@"NSString"]) {
            correctDictionary[key] = @"TEXT";
        } else if ([temporaryDictionary[key] isEqualToString:@"NSNumber"]) {
            correctDictionary[key] = @"REAL";
        } else if ([temporaryDictionary[key] isEqualToString:@"Bool"]) {
            correctDictionary[key] = @"INTEGER";
        } else {
            correctDictionary[key] = temporaryDictionary[key];
        }
    }
    
    _propertiesListAndTypes = [NSDictionary dictionaryWithDictionary:correctDictionary];
}

+ (NSDictionary *)propertyDictionary {
    [self getAllPropertiesAndTypes];
    return _propertiesListAndTypes;
}

+ (NSString *)parseString:(const char *)stringToParse
{
    NSMutableString *result = [[NSMutableString alloc] init];
    
    if ([self isObject:stringToParse]) {
        
        for (int i = 3; stringToParse[i] != '\"'; i++) {
            [result appendFormat:@"%c", stringToParse[i]];
        }
    }
    
    return result;
}

+ (BOOL)isObject:(const char *)stringToCheck
{
    if (stringToCheck[1] == '@') {
        return YES;
    }
    
    return NO;
}

- (void)createHasManyAssociations
{
    NSArray *propertyNames = [self.class allPropertyNames];
    NSInteger propertyCount = [propertyNames count];
    
    unsigned int methodCount;
    
    Method *myMethods = class_copyMethodList(self.class, &methodCount);
    
    NSMutableArray *methodNames = [[NSMutableArray alloc] init];
    
    //gets all method names into an array
    for (NSInteger i = 0 ; i < methodCount; i++) {
        SEL methodNameSel = method_getName(myMethods[i]);
        const char *cMethodName = sel_getName(methodNameSel);
        NSString *objc_MethodName = [NSString stringWithUTF8String:cMethodName];
        [methodNames addObject:objc_MethodName];
    }
    
    for (NSInteger i = 0; i < propertyCount; i++) {
        for (NSInteger j = 0; j < methodCount; j++) {
            if ([propertyNames[i] isEqualToString:methodNames[j]] && ([_propertiesListAndTypes[propertyNames[i]] isEqualToString:@"NSArray"] || [_propertiesListAndTypes[propertyNames[i]] isEqualToString:@"NSMutableArray"])) {
                
                //getter is an array or mutable array
                NSLog(@"Found a match of property: %@ and methodName: %@", propertyNames[i], methodNames[j]);
                
                SEL getterSEL = NSSelectorFromString(propertyNames[i]);
                Swizzlean *swizzleThis = [[Swizzlean alloc] initWithClassToSwizzle:self.class];
                swizzleThis.resetWhenDeallocated = NO;
                [swizzleThis swizzleInstanceMethod:getterSEL withReplacementImplementation:^(id _self){
                    
                    NSString *ivarString = [NSString stringWithFormat:@"_%@", propertyNames[i]];
                    
                    Ivar objectIvar = class_getInstanceVariable(self.class, [ivarString UTF8String]);
                    NSArray *objects = object_getIvar(self, objectIvar);
                    if ([objects count] > 0) {
                        return objects;
                    } else {
                        if (_rowID) {
                            objects = [self.class findObjectsWithType:propertyNames[i] andID:[_rowID integerValue]];
                        }
                        return objects;
                    }
                }];
            }
        }
    }
    free(myMethods);
}

+ (void)setupDB {
    if (self == [SnapIt class]) {
        NSArray *directoryPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSMutableString *documentDirectory = directoryPaths[0];
        NSString *fileName = [NSString stringWithFormat:@"/%@.db", [self getTableName]];
        _databasePath = [[NSString alloc] initWithString: [documentDirectory stringByAppendingString:fileName]];
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (!(self.class == [SnapIt class])) {
        [self getAllPropertiesAndTypes];
        const char *dbpath = [_databasePath UTF8String];
        char *errMessage;
        
        if (sqlite3_open(dbpath, &_catsDB) == SQLITE_OK) {
            NSMutableString *sql_create_string =
            [NSMutableString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(id INTEGER PRIMARY KEY AUTOINCREMENT", [self getTableName]];
            NSArray *properties = [self allPropertyNames];
            
            for (NSInteger i=0; i < [properties count]; i++) {
                NSString *propertyType = _propertiesListAndTypes[properties[i]];
                if (!([propertyType isEqualToString:@"NSArray"] || [propertyType isEqualToString:@"NSMutableArray"])) {
                    if (i == [properties count] - 1) {
                        if (!([propertyType isEqualToString:@"TEXT"] || [propertyType isEqualToString:@"INTEGER"] || [propertyType isEqualToString:@"REAL"])) {
                            NSString *foreignKey = [NSString stringWithFormat:@"%@_id", [propertyType underscore]];
                            [sql_create_string appendString:[NSString stringWithFormat:@", %@ %@", foreignKey, @"INTEGER"]];
                        } else {
                            [sql_create_string appendString:[NSString stringWithFormat:@", %@ %@", [properties[i] underscore], propertyType]];
                        }
                    } else {
                        if (!([propertyType isEqualToString:@"TEXT"] || [propertyType isEqualToString:@"INTEGER"] || [propertyType isEqualToString:@"REAL"])) {
                            NSString *foreignKey = [NSString stringWithFormat:@"%@_id", [propertyType underscore]];
                            [sql_create_string appendString:[NSString stringWithFormat:@", %@ %@", foreignKey, @"INTEGER"]];
                        } else {
                            [sql_create_string appendString:[NSString stringWithFormat:@", %@ %@", [properties[i] underscore], propertyType]];
                        }
                    }
                }
            }
            
            [sql_create_string appendString:@")"];
            
            const char *sql_create_statement = [sql_create_string UTF8String];
            if (sqlite3_exec(_catsDB, sql_create_statement, NULL, NULL, &errMessage) != SQLITE_OK)
            {
                NSLog(@"Failed to create table.");
            }
            sqlite3_close(_catsDB);
            
        } else {
            NSLog(@"Failed to open / create Database.");
        }
    }
}

- (void)save {
    if (self.rowID) {
        [self update];
    } else {
        [self insert];
    }
}

- (void)update {
    sqlite3_stmt *statement;
    const char *dbpath = [self.class.databasePath UTF8String];
    
    if (sqlite3_open(dbpath, self.class.catsDB) == SQLITE_OK) {
        NSMutableString *updateSQL = [NSMutableString stringWithFormat:@"UPDATE %@ ", [self.class getTableName]];
        NSDictionary *propertyDictionary = [self.class propertyDictionary];
        NSArray *properties = [self.class allPropertyNames];
        for (NSInteger i=0; i < [properties count]; i++) {
            NSString *propertyType = propertyDictionary[properties[i]];
            NSString *getter = [NSString stringWithFormat:@"%@", properties[i]];
            SEL s = NSSelectorFromString(getter);
            id value = [self performSelector:s];
            if ([propertyType isEqualToString:@"TEXT"]) {
                value = [self performSelector:s];
                value = [NSString stringWithFormat:@"\"%@\"", value];
            }
            if (!([propertyType isEqualToString:@"TEXT"] || [propertyType isEqualToString:@"INTEGER"] || [propertyType isEqualToString:@"REAL"] || [propertyType isEqualToString:@"NSArray"] || [propertyType isEqualToString:@"NSMutableArray"])) {
                NSString *foreignKey = [NSString stringWithFormat:@"%@_id", [propertyType underscore]];
                value = ((SnapIt *)value).rowID;
                if (i == 0) {
                    [updateSQL appendString:[NSString stringWithFormat:@"SET %@=%@", foreignKey, value]];
                } else {
                    [updateSQL appendString:[NSString stringWithFormat:@", %@=%@", foreignKey, value]];
                }
            } else {
                if (!([propertyType isEqualToString:@"NSArray"] || [propertyType isEqualToString:@"NSMutableArray"])) {
                    if (i == 0) {
                        [updateSQL appendString:[NSString stringWithFormat:@"SET %@=%@", properties[i], value]];
                    } else {
                        [updateSQL appendString:[NSString stringWithFormat:@", %@=%@", properties[i], value]];
                    }
                }
            }
        }
        
        [updateSQL appendString:[NSString stringWithFormat:@" WHERE id=%i", [self.rowID integerValue]]];
        
        const char *update_statement = [updateSQL UTF8String];
        
        sqlite3 *catsDB = *self.class.catsDB;
        
        sqlite3_prepare_v2(catsDB, update_statement, -1, &statement, NULL);
        if (sqlite3_step(statement) == SQLITE_DONE) {
            NSLog(@"Object updated");
        } else {
            NSLog(@"Failed to update object.");
            NSLog(@"%s", sqlite3_errmsg(catsDB));
        }
        sqlite3_finalize(statement);
        
        sqlite3_close(catsDB);
        catsDB = nil;
    }
    
    NSDictionary *propertyDictionary = [self.class propertyDictionary];
    for (NSString *key in propertyDictionary) {
        if ([propertyDictionary[key] isEqualToString:@"NSArray"] || [propertyDictionary[key] isEqualToString:@"NSMutableArray"]) {
            NSString *name = [key lowCamelCase];
            NSString *getter = [NSString stringWithFormat:@"%@", name];
            SEL g = NSSelectorFromString(getter);
            NSArray *objects = [self performSelector:g];
            
            NSArray *hasManyObjects = [self.class findObjectsWithType:key andID:[self.rowID integerValue]];
            NSString *className = NSStringFromClass(self.class);
            NSString *classSetter = [NSString stringWithFormat:@"set%@:", [className classify]];
            SEL s = NSSelectorFromString(classSetter);
            for (SnapIt *obj in hasManyObjects) {
                [obj performSelector:s withObject:nil];
                [obj save];
            }

            for (SnapIt *object in objects) {
                NSString *className = NSStringFromClass(self.class);
                NSString *classSetter = [NSString stringWithFormat:@"set%@:", [className classify]];
                SEL s = NSSelectorFromString(classSetter);
                [object performSelector:s withObject:self];
                [object save];
            }
        }
    }

}

- (void)insert {
    sqlite3_stmt *statement;
    const char *dbpath = [self.class.databasePath UTF8String];
    
    if (sqlite3_open(dbpath, self.class.catsDB) == SQLITE_OK) {
        NSMutableString *insertSQL = [NSMutableString stringWithFormat:@"INSERT INTO %@", [self.class getTableName]];
        NSDictionary *propertyDictionary = [self.class propertyDictionary];
        NSArray *properties = [self.class allPropertyNames];
        for (NSInteger i=0; i < [properties count]; i++) {
            NSString *propertyType = propertyDictionary[properties[i]];
            if (!([propertyType isEqualToString:@"TEXT"] || [propertyType isEqualToString:@"INTEGER"] || [propertyType isEqualToString:@"REAL"] || [propertyType isEqualToString:@"NSArray"] || [propertyType isEqualToString:@"NSMutableArray"])) {
                NSString *foreignKey = [NSString stringWithFormat:@"%@_id", [propertyType underscore]];
                if (i == 0) {
                    [insertSQL appendString:[NSString stringWithFormat:@" (%@", foreignKey]];
                } else {
                    [insertSQL appendString:[NSString stringWithFormat:@", %@", foreignKey]];
                }
            } else {
                if (!([propertyType isEqualToString:@"NSArray"] || [propertyType isEqualToString:@"NSMutableArray"])) {
                    if (i == 0) {
                        [insertSQL appendString:[NSString stringWithFormat:@" (%@", properties[i]]];
                    } else {
                        [insertSQL appendString:[NSString stringWithFormat:@", %@", properties[i]]];
                    }
                }
            }
        }
        
        [insertSQL appendString:@") "];
        
        for (NSInteger i=0; i < [properties count]; i++) {
            SEL s = NSSelectorFromString(properties[i]);
            id value = [self performSelector:s];
            NSDictionary *propertyDictionary = [self.class propertyDictionary];
            NSString *propertyType = propertyDictionary[properties[i]];
            if (!([propertyType isEqualToString:@"TEXT"] || [propertyType isEqualToString:@"INTEGER"] || [propertyType isEqualToString:@"REAL"] || [propertyType isEqualToString:@"NSArray"] || [propertyType isEqualToString:@"NSMutableArray"])) {
                if (value != nil) {
                    value = ((SnapIt *)value).rowID;
                }
            }
            value = (value == nil) ? @"NULL" : value;
            if ([propertyType isEqualToString:@"TEXT"] && ![value isEqualToString:@"NULL"]) {
                value = [NSString stringWithFormat:@"\"%@\"", value];
            }
            if (!([propertyType isEqualToString:@"NSArray"] || [propertyType isEqualToString:@"NSMutableArray"])) {
                if (i == 0) {
                    [insertSQL appendString:[NSString stringWithFormat:@"VALUES (%@", value]];
                } else {
                    [insertSQL appendString:[NSString stringWithFormat:@", %@", value]];
                }
            }
        }
        
        [insertSQL appendString:@")"];
        const char *insert_statement = [insertSQL UTF8String];
        
        sqlite3 *catsDB = *self.class.catsDB;
        
        sqlite3_prepare_v2(catsDB, insert_statement, -1, &statement, NULL);
        if (sqlite3_step(statement) == SQLITE_DONE) {
            NSLog(@"Object added");
            self.rowID = @(sqlite3_last_insert_rowid(catsDB));
        } else {
            NSLog(@"Failed to add object.");
            NSLog(@"%s", sqlite3_errmsg(catsDB));
        }
        sqlite3_finalize(statement);

        sqlite3_close(catsDB);
        catsDB = nil;
    }
    
    NSDictionary *propertyDictionary = [self.class propertyDictionary];
    for (NSString *key in propertyDictionary) {
        if ([propertyDictionary[key] isEqualToString:@"NSArray"] || [propertyDictionary[key] isEqualToString:@"NSMutableArray"]) {
            NSString *name = [key lowCamelCase];
            NSString *getter = [NSString stringWithFormat:@"%@", name];
            SEL g = NSSelectorFromString(getter);
            NSArray *objects = [self performSelector:g];
            
            NSArray *hasManyObjects = [self.class findObjectsWithType:key andID:[self.rowID integerValue]];
            NSString *className = NSStringFromClass(self.class);
            NSString *classSetter = [NSString stringWithFormat:@"set%@:", [className classify]];
            SEL s = NSSelectorFromString(classSetter);
            for (SnapIt *obj in hasManyObjects) {
                [obj performSelector:s withObject:nil];
                [obj save];
            }
            for (SnapIt *object in objects) {
                NSString *className = NSStringFromClass(self.class);
                NSString *classSetter = [NSString stringWithFormat:@"set%@:", [className classify]];
                SEL s = NSSelectorFromString(classSetter);
                [object performSelector:s withObject:self];
                [object save];
            }
        }
    }
}

- (void)deleteSelf {
    sqlite3_stmt *statement;
    const char *dbpath = [self.class.databasePath UTF8String];
    
    if (sqlite3_open(dbpath, self.class.catsDB) == SQLITE_OK) {
        NSMutableString *deleteSQL = [NSMutableString stringWithFormat:@"DELETE FROM %@ ", [self.class getTableName]];
        [deleteSQL appendString:[NSString stringWithFormat:@" WHERE id=%li", [self.rowID integerValue]]];
        
        const char *delete_statement = [deleteSQL UTF8String];
        
        sqlite3 *catsDB = *self.class.catsDB;
        
        sqlite3_prepare_v2(catsDB, delete_statement, -1, &statement, NULL);
        if (sqlite3_step(statement) == SQLITE_DONE) {
            NSLog(@"Object deleted");
        } else {
            NSLog(@"Failed to update object.");
            NSLog(@"%s", sqlite3_errmsg(catsDB));
        }
        sqlite3_finalize(statement);
        
        sqlite3_close(catsDB);
        catsDB = nil;
    }
    
    // Let's do cleanup
    NSDictionary *propertyDictionary = [self.class propertyDictionary];
    for (NSString *key in propertyDictionary) {
        NSString *propertyType = propertyDictionary[key];
        if ([propertyDictionary[key] isEqualToString:@"NSArray"] || [propertyDictionary[key] isEqualToString:@"NSMutableArray"]) {
            NSString *name = [key lowCamelCase];
            NSString *getter = [NSString stringWithFormat:@"%@", name];
            SEL g = NSSelectorFromString(getter);
            NSArray *objects = [self performSelector:g];
            
            NSArray *hasManyObjects = [self.class findObjectsWithType:key andID:[self.rowID integerValue]];
            NSString *className = NSStringFromClass(self.class);
            NSString *classSetter = [NSString stringWithFormat:@"set%@:", [className classify]];
            SEL s = NSSelectorFromString(classSetter);
            for (SnapIt *obj in hasManyObjects) {
                [obj performSelector:s withObject:nil];
                [obj save];
            }
        }
    }
}

- (void)fetch {
    NSArray *objects = [self.class where:[NSString stringWithFormat:@"id=%@", self.rowID]];
    if ([objects count] > 0) {
        id object = objects[0];
        NSArray *propertyNames = [self.class allPropertyNames];
        NSInteger propertyCount = [propertyNames count];
        for (NSInteger i = 0; i < propertyCount; i++) {
            NSString *ivarString = [NSString stringWithFormat:@"_%@", propertyNames[i]];
            Ivar objectIvar = class_getInstanceVariable(self.class, [ivarString UTF8String]);
            id updatedPropertyValue = object_getIvar(object, objectIvar);
            id ourPropertyValue = object_getIvar(self, objectIvar);
            ourPropertyValue = updatedPropertyValue;
        }
    }
}

+ (NSArray *)performFetchWithSQL:(NSString *)sql {
    NSMutableArray *objects = [[NSMutableArray alloc] init];
    const char *dbpath = [_databasePath UTF8String];
    sqlite3_stmt *statement;
    if (sqlite3_open(dbpath, &_catsDB) == SQLITE_OK) {
        NSString *querySQL = sql;
        const char *query_statement = [querySQL UTF8String];
        if (sqlite3_prepare_v2(_catsDB, query_statement, -1, &statement, NULL) == SQLITE_OK) {
            while (sqlite3_step(statement) == SQLITE_ROW) {
                SnapIt *object = [[self alloc] init];
                NSDictionary *propertyDictionary = [object.class propertyDictionary];
                for (NSInteger i=0; i < sqlite3_column_count(statement); i++) {
                    NSString *columnName = [[NSString alloc] initWithUTF8String:sqlite3_column_name(statement, i)];
                    if ([columnName isEqualToString:@"id"]) {
                        columnName = [@"rowID" classify];
                    } else {
                        columnName = [columnName classify];
                    }
                    if ([[columnName substringFromIndex:columnName.length - 2] isEqualToString:@"Id"]) {
                        if (sqlite3_column_text(statement, i)) {
                            NSString *dataString = [[NSString alloc] initWithUTF8String:(const char *)sqlite3_column_text(statement, i)];
                            NSString *objectToFind = [[columnName underscore] substringToIndex:columnName.length - 2];
                            id data = [self findObject:objectToFind withID:[dataString integerValue]];
                            columnName = [columnName substringToIndex:columnName.length - 2];
                            NSString *setter = [NSString stringWithFormat:@"set%@:", columnName];
                            SEL s = NSSelectorFromString(setter);
                            [object performSelector:s withObject:data];
                        }
                    } else {
                        NSString *dataString = [[NSString alloc] initWithUTF8String:(const char *)sqlite3_column_text(statement, i)];
                        
                        NSString *setter = [NSString stringWithFormat:@"set%@:", columnName];
                        SEL s = NSSelectorFromString(setter);
                        
                        NSString *propertyName = [columnName lowCamelCase];
                        if ([propertyDictionary[propertyName] isEqualToString:@"TEXT"]) {
                            NSString *data = dataString;
                            [object performSelector:s withObject:data];
                        } else if ([propertyDictionary[propertyName] isEqualToString:@"REAL"]) {
                            NSNumber *data = @([dataString floatValue]);
                            [object performSelector:s withObject:data];
                        } else if ([propertyDictionary[propertyName] isEqualToString:@"INTEGER"]) {
                            NSNumber *data = @([dataString integerValue]);
                            [object performSelector:s withObject:data];
                        } else {
                            if ([setter isEqualToString:@"setRowID:"]) {
                                NSNumber *data = @([dataString integerValue]);
                                [object performSelector:s withObject:data];
                            }
                        }
                    }
                }
                
                [objects addObject:object];
            }
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(_catsDB);
    }
    
    return objects;

}

+ (NSArray *)where:(NSString *)whereClause {
    NSString *sql = [NSString stringWithFormat:
     @"SELECT\
     *\
     FROM\
     %@\
     WHERE %@", [self getTableName], whereClause];
    return [self performFetchWithSQL:sql];
}

+ (NSArray *)all {
    NSString *sql = [NSString stringWithFormat:
     @"SELECT\
     *\
     FROM\
     %@", [self getTableName]];
    return [self performFetchWithSQL:sql];
}

+ (NSArray *)findObjectsWithType:(NSString *)type andID:(NSInteger)objectID {
    NSString *className = [[type substringToIndex:type.length - 1] classify];
    Class class = NSClassFromString(className);
    NSString *foreignKey = [NSStringFromClass([self class]) underscore];
    foreignKey = [foreignKey stringByAppendingString:@"_id"];
    NSArray *objects = [class where:[NSString stringWithFormat:@"%@=%i", foreignKey, objectID]];
    return objects;
}

+ (id)find:(NSInteger *)objectID {
    NSArray *data = [self where:[NSString stringWithFormat:@"id=%i", objectID]];
    if ([data count] > 0) {
        return data[0];
    }
    return nil;
}

+ (id)findObject:(NSString *)object withID:(NSInteger)objectID {
    Class class = NSClassFromString([object classify]);
    NSArray *data = [class where:[NSString stringWithFormat:@"id=%i", objectID]];
    if ([data count] > 0) {
        return data[0];
    }
    return nil;
}
@end

