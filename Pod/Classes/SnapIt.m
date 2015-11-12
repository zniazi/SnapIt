//
//  SnapIt.m
//  SnapClass
//
//  Created by Zak Niazi on 10/28/14.
//  Copyright (c) 2014 Zak. All rights reserved.
//

// @synchronized blocks getter for has many association

#import "SnapIt.h"
#import <sqlite3.h>
#import <objc/runtime.h>
#import "NSString+Inflections.h"
#import <AFNetworking/AFNetworking.h>

// Don't fetch objects in has many association until they are called.
// On reload of has many objects, only create new instances for objects that don't exist yet.

// Create queue for this class. Put operation on queue. Take off queue when sqlite DB closes (FIFO)

// Could have _dbConnection for each class. Calling save on a hasMany class would be fine because
// the save method would be called inside another class which has another _dbConnection.

// Delete method pass in argument (removeHasMany:true)

static sqlite3 *_dbConnection;
static NSString *_databasePath;
static NSMutableDictionary *_propertiesListAndTypes;
static NSMutableDictionary *_columnNames;
static NSMutableDictionary *_snapItCache; // Store cache of SnapIt objects -
static BOOL _isOpened;

@interface SnapIt()
@property (nonatomic, readwrite) NSNumber *rowID;
@end

// Keywords "id" and "index" are reserved.

// Changes I would like
// 1. Add support for BOOL
// 2. When property changes, change column type
// 3. Modify pushBackend to accept data like images, audio, video


// Implement queue for SnapIt
// Put job to be done on queue - method name and value.
// Job can be placed on queue when method like performFetch is called
// When job completes or fails, an NSNotification is sent that pops the next item off of the queue and executes it.

@implementation SnapIt

// TODO: Incomplete (Method intended to convert JSON structure to object)
- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [SnapIt init];
    // for key in dictionary
    // assign value of key to self
    
    return self;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
//        [self createHasManyAssociations];
    }
    return self;
}

+ (void)initialize {
    if (!_propertiesListAndTypes) {
        _propertiesListAndTypes = [[NSMutableDictionary alloc] init];
    }
    if (!_columnNames) {
        _columnNames = [[NSMutableDictionary alloc] init];
    }
    if (!_snapItCache) {
        _snapItCache = [[NSMutableDictionary alloc] init];
    }
    
    [self setupDB];
    [self createHasManyAssociations];
    if (sqlite3_config(SQLITE_CONFIG_SERIALIZED) == SQLITE_ERROR) {
        NSLog(@"Couldn't set serialized mode.");
    }
}

+ (NSString*)baseURL {
    // Overwrite in subclass
    return @"";
}

+ (NSString *)databasePath {
    return _databasePath;
}

+ (sqlite3 **)catsDB {
    return &_dbConnection;
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
    
    // New Code
    objc_property_t *snapItProperties = class_copyPropertyList([SnapIt class], &count);
    unsigned j;
    for (j = 0; j < count; j++) {
        objc_property_t property = snapItProperties[j];
        NSString *name = [NSString stringWithUTF8String:property_getName(property)];
        if (![name isEqualToString:@"rowID"]) {
            [propertyList addObject:name];
        }
    }
    
    free(snapItProperties);
    // End New Code
    
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
//        if ([self isObject:cPropertyType]) {
        [temporaryDictionary setObject:propertyTypeAfterParse forKey:propertyName];
//        }
    }
    
    // Duplicate Code
    // New Code
    free(properties);
    objc_property_t *snapItProperties = class_copyPropertyList([SnapIt class], &propertyCount);
    for (int i = 0; i < propertyCount; i++) {
        objc_property_t currentProperty = snapItProperties[i];
        NSString *propertyName = [NSString stringWithUTF8String:property_getName(currentProperty)];
        
        const char *cPropertyType = property_getAttributes(currentProperty);
        NSString *propertyTypeAfterParse = [self parseString:cPropertyType];
        
        if ([self isObject:cPropertyType] && ![propertyName isEqualToString:@"rowID"]) {
            [temporaryDictionary setObject:propertyTypeAfterParse forKey:propertyName];
        }
    }
    
    NSMutableDictionary *correctDictionary = [[NSMutableDictionary alloc] init];
    
    for (NSString *key in temporaryDictionary) {
        if ([temporaryDictionary[key] isEqualToString:@"NSString"]) {
            correctDictionary[key] = @"TEXT";
        } else if ([temporaryDictionary[key] isEqualToString:@"NSNumber"]) {
            correctDictionary[key] = @"REAL";
        } else if ([temporaryDictionary[key] isEqualToString:@"BOOL"]) {
            correctDictionary[key] = @"INTEGER";
        } else {
            correctDictionary[key] = temporaryDictionary[key];
        }
    }
    
    _propertiesListAndTypes[NSStringFromClass(self)] = [NSDictionary dictionaryWithDictionary:correctDictionary];
}

+ (NSDictionary *)propertyDictionary {
    [self getAllPropertiesAndTypes];
    return _propertiesListAndTypes[NSStringFromClass(self)];
}

+ (NSString *)parseString:(const char *)stringToParse
{
    // @"TB" is BOOL
    NSMutableString *result = [[NSMutableString alloc] init];
    if (stringToParse[1] == 'B') {
        return @"BOOL";
    }
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

+ (NSArray *)columnNames {
    if (_columnNames[NSStringFromClass(self)] != nil) {
        return _columnNames[NSStringFromClass(self)];
    }
    
//    [self.class sleepIfDatabaseIsOpen];
    @synchronized(self) {
        NSMutableArray *columnNames = [NSMutableArray new];
        const char *dbpath = [_databasePath UTF8String];
        sqlite3_stmt *statement;
        if (sqlite3_open(dbpath, &_dbConnection) == SQLITE_OK) {
//            [self lockDatabase];
            NSLog(@"ColumnNames open connection");
            NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@", [self getTableName]];
            const char *query_statement = [sql UTF8String];
            if (sqlite3_prepare_v2(_dbConnection, query_statement, -1, &statement, NULL) == SQLITE_OK) {
                for (NSInteger i=0; i < sqlite3_column_count(statement); i++) {
                    NSString *columnName = [[NSString alloc] initWithUTF8String:sqlite3_column_name(statement, (int)i)];
                    [columnNames addObject:columnName];
                }
            }
            sqlite3_close(_dbConnection);
            NSLog(@"ColumnNames close connection");
//            [self openDatabase];
        }
        _columnNames[NSStringFromClass(self)] = columnNames;
        return _columnNames[NSStringFromClass(self)];
    }
}

+ (void)updateTable {
    NSArray *columnNames = [self columnNames];
    NSArray *properties = [self allPropertyNames];
    
    for (NSString *property in properties) {
        NSString *newColumn = [property underscore];
        NSPredicate *containsColumn = [NSPredicate predicateWithFormat:@"%@ IN SELF", newColumn];
        NSArray *filteredArray = [columnNames filteredArrayUsingPredicate:containsColumn];
        // New Code
        if (property == nil) {
            continue;
        }
        //
        
        if (filteredArray.count == 0) {
            // TODO: Do not add column if it is an unsupported data type (NSData, NSInteger, etc)
            NSString *propertyType = _propertiesListAndTypes[NSStringFromClass(self)][property];
            if (propertyType == nil) {
                NSLog(@"Null property type for %@", property);
                continue; // New
            }
            if (!([propertyType isEqualToString:@"NSArray"] || [propertyType isEqualToString:@"NSMutableArray"])) {
                if (!([propertyType isEqualToString:@"TEXT"] || [propertyType isEqualToString:@"INTEGER"] || [propertyType isEqualToString:@"REAL"])) {
                    NSString *foreignKey = [NSString stringWithFormat:@"%@_id", [propertyType underscore]];
                    NSString *insertColumnSQL = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ %@", [self getTableName], foreignKey, @"INTEGER"];
                    [self performSQL:insertColumnSQL];
                    NSLog(@"%@", insertColumnSQL);
                } else {
                    NSString *insertColumnSQL = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ %@", [self getTableName],newColumn, propertyType];
                    [self performSQL:insertColumnSQL];
                    NSLog(@"%@", insertColumnSQL);
                }
            }
        }
    }
    // SQLite does not support deleting columns
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
        
//        [self sleepIfDatabaseIsOpen];
        @synchronized(self) {
            if (sqlite3_open(dbpath, &_dbConnection) == SQLITE_OK) {
//                [self lockDatabase];
                NSLog(@"setupDB open connection");
                NSMutableString *sql_create_string =
                [NSMutableString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(id INTEGER PRIMARY KEY AUTOINCREMENT", [self getTableName]];
                NSArray *properties = [self allPropertyNames];
                
                for (NSInteger i=0; i < [properties count]; i++) {
                    NSString *propertyType = _propertiesListAndTypes[NSStringFromClass(self)][properties[i]];
                    // If property type is not NSArray, but is 'Cat' or 'Human', create a foreign key for belongs to.
                    // TODO: Create 4th nested if statement, checking if propertyType is a forbidden type like NSData, NSInteger, etc.
                    // TODO: If it is, create error message saying the data type is unsupported.
                    if (!([propertyType isEqualToString:@"NSArray"] || [propertyType isEqualToString:@"NSMutableArray"])) {
                        if (!([propertyType isEqualToString:@"TEXT"] || [propertyType isEqualToString:@"INTEGER"] || [propertyType isEqualToString:@"REAL"])) {
                            NSString *foreignKey = [NSString stringWithFormat:@"%@_id", [propertyType underscore]];
                            [sql_create_string appendString:[NSString stringWithFormat:@", %@ %@", foreignKey, @"INTEGER"]];
                        } else {
                            [sql_create_string appendString:[NSString stringWithFormat:@", %@ %@", [properties[i] underscore], propertyType]];
                        }
                    }
                }
                
                [sql_create_string appendString:@")"];
                
                const char *sql_create_statement = [sql_create_string UTF8String];
                if (sqlite3_exec(_dbConnection, sql_create_statement, NULL, NULL, &errMessage) != SQLITE_OK)
                {
                    NSLog(@"Failed to create table.");
                }
                sqlite3_close(_dbConnection);
                NSLog(@"setupDB close connection");
//                [self openDatabase];
                
            } else {
                NSLog(@"Failed to open / create Database.");
            }
        }
    }
}

+ (void)performSQL:(NSString *)sql {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    const char *dbpath = [_databasePath UTF8String];
    char *errMessage;
    
    @synchronized(self) {
        if (sqlite3_open(dbpath, &_dbConnection) == SQLITE_OK) {
            NSLog(@"performSQL open connection");
            const char *sql_statement = [sql UTF8String];
            if (sqlite3_exec(_dbConnection, sql_statement, NULL, NULL, &errMessage) != SQLITE_OK)
            {
                NSLog(@"Error executing SQL.");
            }
            sqlite3_close(_dbConnection);
            NSLog(@"performSQL close connection");
        } else {
            NSLog(@"Failed to open database connection.");
        }
    }
}

// Try and cache value. Set hasMany object. If doesn't exist, then fetch. Or store locally to class in cache.
+ (NSArray *)createObjectsFromDictionaries:(NSArray *)objectDictionaries {
    NSMutableArray *snapItObjects = [[NSMutableArray alloc] init];
    for (NSDictionary *objectDictionary in objectDictionaries) {
        SnapIt *object = [[self alloc] init];
        NSDictionary *propertyDictionary = [object.class propertyDictionary];
        NSArray *columnNames = [objectDictionary allKeys];
        for (NSString __strong *columnName in columnNames) {
            NSString *dataString = objectDictionary[columnName];
            if ([columnName isEqualToString:@"id"]) {
                columnName = [@"rowID" classify];
            } else {
                columnName = [columnName classify];
            }
            // if class name superclass is SnapIt
            NSString *className = [[columnName substringToIndex:columnName.length - 2] classify];
            id snapItObject = [[NSClassFromString(className) alloc] init];
            // Have to make sure object is not nil before invoking method on it.
            if ([[columnName substringFromIndex:columnName.length - 2] isEqualToString:@"Id"] && snapItObject != nil && [snapItObject isKindOfClass:[SnapIt class]]) {
                // Use cache here
                NSInteger rowID = [dataString integerValue];
                NSString *objectToFind = [[columnName underscore] substringToIndex:columnName.length - 2];
                Class class = NSClassFromString([objectToFind classify]);
                id data;
                NSString *className = NSStringFromClass(class);
                if (_snapItCache[className] && _snapItCache[className][@(rowID)]) {
                    data = _snapItCache[className][@(rowID)];
                } else {
                    data = [self findObject:objectToFind withID:rowID];
                    if (!_snapItCache[className]) {
                        _snapItCache[className] = [[NSMutableDictionary alloc] init];
                    }
                    _snapItCache[className][@(rowID)] = data;
                } 
                
                columnName = [columnName substringToIndex:columnName.length - 2];
                NSString *setter = [NSString stringWithFormat:@"set%@:", columnName];
                SEL s = NSSelectorFromString(setter);
                [object performSelector:s withObject:data];
                
            } else {
                NSString *setter = [NSString stringWithFormat:@"set%@:", columnName];
                SEL s = NSSelectorFromString(setter);
                
                NSString *propertyName = [columnName lowCamelCase];
                
                if (dataString != nil) {
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
        }
        [snapItObjects addObject:object];
    }
    return snapItObjects;
}

+ (void)sleepIfDatabaseIsOpen {
//    @synchronized(self) {
        [NSThread sleepForTimeInterval:0.03f];
        for (NSInteger i = 0; i < 2; i++) {
            if (_isOpened == YES) {
                NSLog(@"Is opened: %li", i);
                [NSThread sleepForTimeInterval:1.0f];
            } else {
                break;
            }
        }
//    }
}

+ (void)lockDatabase {
    @synchronized(self) {
        _isOpened = YES;
    }
}

+ (void)openDatabase {
    @synchronized(self) {
        _isOpened = NO;
    }
}

+ (NSString *)executeSQL:(NSString *)sql {
    const char *dbpath = [_databasePath UTF8String];
    sqlite3_stmt *statement;
    NSMutableString *result = [[NSMutableString alloc] init];
    
    //    Remove for time being - blocking main thread. Put back when needed.
    @synchronized(self) {
        if (sqlite3_open(dbpath, &_dbConnection) == SQLITE_OK) {
            NSLog(@"executeSQL open connection");
            NSString *querySQL = sql;
            const char *query_statement = [querySQL UTF8String];
            if (sqlite3_prepare_v2(_dbConnection, query_statement, -1, &statement, NULL) == SQLITE_OK) {
                while (sqlite3_step(statement) == SQLITE_ROW) {
                    for (NSInteger i=0; i < sqlite3_column_count(statement); i++) {
                        NSString *columnName = [[NSString alloc] initWithUTF8String:sqlite3_column_name(statement, (int)i)];
                        NSString *dataString = nil;
                        if (sqlite3_column_text(statement, (int)i) != nil) {
                            dataString = [[NSString alloc] initWithUTF8String:(const char *)sqlite3_column_text(statement, (int)i)];
                            [result appendString:[NSString stringWithFormat:@"%@", dataString]];
                        }
                    }
                }
                sqlite3_finalize(statement);
            }
            
            sqlite3_close(_dbConnection);
            NSLog(@"executeSQL close connection");
        }
        
        return result;
    }
}

+ (NSArray *)performFetchWithSQL:(NSString *)sql {
    NSMutableArray *objects = [[NSMutableArray alloc] init];
    NSArray *snapItObjects = [[NSArray alloc] init];
    const char *dbpath = [_databasePath UTF8String];
    sqlite3_stmt *statement;
    
//    Remove for time being - blocking main thread. Put back when needed.
    @synchronized(self) {
        if (sqlite3_open(dbpath, &_dbConnection) == SQLITE_OK) {
            NSLog(@"performFetchWithSQL open connection");
            NSString *querySQL = sql;
            const char *query_statement = [querySQL UTF8String];
            if (sqlite3_prepare_v2(_dbConnection, query_statement, -1, &statement, NULL) == SQLITE_OK) {
                //            NSLog(@"Query Statement: %@", querySQL);
                while (sqlite3_step(statement) == SQLITE_ROW) {
                    NSMutableDictionary *objectDictionary = [[NSMutableDictionary alloc] init];
                    for (NSInteger i=0; i < sqlite3_column_count(statement); i++) {
                        NSString *columnName = [[NSString alloc] initWithUTF8String:sqlite3_column_name(statement, (int)i)];
                        NSString *dataString = nil;
                        if (sqlite3_column_text(statement, (int)i) != nil) {
                            dataString = [[NSString alloc] initWithUTF8String:(const char *)sqlite3_column_text(statement, (int)i)];
                            objectDictionary[columnName] = dataString;
                        }
                    }
                    [objects addObject:objectDictionary];
                }
                sqlite3_finalize(statement);
            }
            
            sqlite3_close(_dbConnection);
            NSLog(@"performFetchWithSQL close connection");
            snapItObjects = [self createObjectsFromDictionaries:objects];
        }
    
        return snapItObjects;
    }
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

// Should be able to remove objectID and use self.rowID
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

+ (void)deleteAll {
    NSArray *allObjects = [self all];
    for (SnapIt *obj in allObjects) {
        [obj deleteSelf];
    }
}

// Possible add @synchronized. May double read objects on another thread - performance optimization.

// NOTE: Does not have many relation on has many object unless object has been saved. Should explicitly set that objects array if not saving.
- (NSArray *)replaceGetter:(NSString *)propertyName {
    @synchronized(self.class) {
        NSString *ivarString = [NSString stringWithFormat:@"_%@", propertyName];
        
        Ivar objectIvar = class_getInstanceVariable(self.class, [ivarString UTF8String]);
        NSArray *objects = object_getIvar(self, objectIvar); // See if object has any of has many objects already
        
        NSString *foreignKey = [NSString stringWithFormat:@"%@_id", [NSStringFromClass(self.class) underscore]];
        NSString *numberOfHasManyObjects = [self.class executeSQL:[NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=%@", [propertyName underscore], foreignKey, self.rowID]];
        if ([objects count] > 0 && [numberOfHasManyObjects integerValue] == objects.count) {
            return objects;
        } else {
            if (_rowID) {
                objects = [self.class findObjectsWithType:propertyName andID:[_rowID integerValue]];
                object_setIvar(self, objectIvar, objects);
                // Cache objects to local object
            }
            return objects;
        } 
    }
}

+ (void)createHasManyAssociations
{
    NSArray *propertyNames = [self allPropertyNames];
    NSInteger propertyCount = [propertyNames count];
    
    unsigned int methodCount;
    
    Method *myMethods = class_copyMethodList(self, &methodCount);
    
    NSMutableArray *methodNames = [[NSMutableArray alloc] init];
    
    //gets all method names into an array
    for (NSInteger i = 0 ; i < methodCount; i++) {
        SEL methodNameSel = method_getName(myMethods[i]);
        const char *cMethodName = sel_getName(methodNameSel);
        NSString *objc_MethodName = [NSString stringWithUTF8String:cMethodName];
        [methodNames addObject:objc_MethodName];
    }
    
    NSDictionary *propertiesListAndTypes = _propertiesListAndTypes[NSStringFromClass(self)];
    for (NSInteger i = 0; i < propertyCount; i++) {
        for (NSInteger j = 0; j < methodCount; j++) {
            if ([propertyNames[i] isEqualToString:methodNames[j]] && ([propertiesListAndTypes[propertyNames[i]] isEqualToString:@"NSArray"] || [propertiesListAndTypes[propertyNames[i]] isEqualToString:@"NSMutableArray"])) {
                
                //getter is an array or mutable array
                NSLog(@"Found a match of property: %@ and methodName: %@", propertyNames[i], methodNames[j]);
                
                SEL getterSEL = NSSelectorFromString(propertyNames[i]);
                Method getterMethod = class_getInstanceMethod(self, getterSEL);
                method_setImplementation(getterMethod, imp_implementationWithBlock(^NSArray *(id _self) {
                    NSArray *snapItObjects = [_self replaceGetter:propertyNames[i]];
                    return snapItObjects;
                }));
            }
        }
    }
    free(myMethods);
}

+ (id)lastObject {
    NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE id=(SELECT MAX(id) FROM %@)", [self getTableName], [self getTableName]];
    NSArray *snapItObject = [self performFetchWithSQL:sql];
    return [snapItObject firstObject];
}

// Save seems to be called while opening DetailVC

- (BOOL)save {
    // If I need to put back in dispatch_async, pass title to next VC.
    [self.class updateTable];
    if (self.rowID) {
        return [self update];
    } else {
        return [self insert];
    }
    
//    if (![[self.class baseURL] isEqualToString:@""]) {
//        [self pushBackend];
//    }
}

- (BOOL)update {
    sqlite3_stmt *statement;
    const char *dbpath = [self.class.databasePath UTF8String];
    BOOL updated = YES;
    BOOL synchronizedBlockCalled = NO;
    
    @synchronized(self.class) {
        synchronizedBlockCalled = YES;
        if (sqlite3_open(dbpath, &_dbConnection) == SQLITE_OK) {
            NSLog(@"update open connection");
            NSMutableString *updateSQL = [NSMutableString stringWithFormat:@"UPDATE %@ ", [self.class getTableName]];
            NSDictionary *propertyDictionary = [self.class propertyDictionary];
            NSArray *properties = [self.class allPropertyNames];
            for (NSInteger i=0; i < [properties count]; i++) {
                NSString *propertyType = propertyDictionary[properties[i]];
                NSString *getter = [NSString stringWithFormat:@"%@", properties[i]];
                
                if (![propertyType isEqualToString:@"NSArray"] || [propertyType isEqualToString:@"NSMutableArray"]) {
                    id value = [self valueForKey:getter];
                    if ([propertyType isEqualToString:@"TEXT"]) {
                        value = (value == nil) ? @"NULL" : [NSString stringWithFormat:@"\"%@\"", value];
                    }
                    value = (value == nil) ? @"NULL" : value;
                    if (!([propertyType isEqualToString:@"TEXT"] || [propertyType isEqualToString:@"INTEGER"] || [propertyType isEqualToString:@"REAL"])) {
                        NSString *foreignKey = [NSString stringWithFormat:@"%@_id", [propertyType underscore]];
                        // Value is belongs to association
                        if ([value isKindOfClass:[SnapIt class]]) {
                            value = ((SnapIt *)value).rowID;
                        }
                        if (i == 0) {
                            [updateSQL appendString:[NSString stringWithFormat:@"SET %@=%@", foreignKey, value]];
                        } else {
                            [updateSQL appendString:[NSString stringWithFormat:@", %@=%@", foreignKey, value]];
                        }
                    } else {
                        NSString *property = properties[i];

                        if (i == 0) {
                            [updateSQL appendString:[NSString stringWithFormat:@"SET %@=%@", [property underscore], value]];
                        } else {
                            // If value is 0 and is NSNumber, set to @"0"
                            [updateSQL appendString:[NSString stringWithFormat:@", %@=%@", [property underscore], value]];
                        }                        
                    }
                }
            }
            
            [updateSQL appendString:[NSString stringWithFormat:@" WHERE id=%i;", [self.rowID integerValue]]];
            
            const char *update_statement = [updateSQL UTF8String];
            
            sqlite3_prepare_v2(_dbConnection, update_statement, -1, &statement, NULL);
            if (sqlite3_step(statement) == SQLITE_DONE) {
                NSLog(@"Object updated");
            } else {
                NSLog(@"Failed to update object.");
                NSLog(@"%s", sqlite3_errmsg(_dbConnection));
                updated = NO;
            }
            sqlite3_finalize(statement);
            
            sqlite3_close(_dbConnection);
            NSLog(@"update close connection");
            [self saveHasManyObjects];
        }
    }
    
    return updated;
}

- (BOOL)insert {
    sqlite3_stmt *statement;
    const char *dbpath = [self.class.databasePath UTF8String];
    BOOL inserted = YES;
    
    @synchronized(self.class) {
        if (sqlite3_open(dbpath, self.class.catsDB) == SQLITE_OK) {
            NSLog(@"insert open connection");
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
                        NSString *property = properties[i];
                        if (i == 0) {
                            [insertSQL appendString:[NSString stringWithFormat:@" (%@", [property underscore]]];
                        } else {
                            [insertSQL appendString:[NSString stringWithFormat:@", %@", [property underscore]]];
                        }
                    }
                }
            }
            
            [insertSQL appendString:@") "];
            
            for (NSInteger i=0; i < [properties count]; i++) {
                NSString *propertyType = propertyDictionary[properties[i]];
                
                if ([propertyType isEqualToString:@"NSArray"] || [propertyType isEqualToString:@"NSMutableArray"]) {
                    continue;
                }
                
                SEL s = NSSelectorFromString(properties[i]);
                id value = [self performSelector:s];
                
                if (!([propertyType isEqualToString:@"TEXT"] || [propertyType isEqualToString:@"INTEGER"] || [propertyType isEqualToString:@"REAL"])) {
                    if (value != nil) {
                        value = ((SnapIt *)value).rowID;
                    }
                }
                value = (value == nil) ? @"NULL" : value;
                if ([propertyType isEqualToString:@"TEXT"] && ![value isEqualToString:@"NULL"]) {
                    value = [NSString stringWithFormat:@"\"%@\"", value];
                }
                
                if (i == 0) {
                    [insertSQL appendString:[NSString stringWithFormat:@"VALUES (%@", value]];
                } else {
                    [insertSQL appendString:[NSString stringWithFormat:@", %@", value]];
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
                inserted = NO;
            }
            sqlite3_finalize(statement);
            
            sqlite3_close(catsDB);
            NSLog(@"insert close connection");
            catsDB = nil;
            
            [self saveHasManyObjects];
        }
        
        return inserted;
    }
}

- (void)saveHasManyObjects {
    NSDictionary *propertyDictionary = [self.class propertyDictionary];
    for (NSString *key in propertyDictionary) {
        if ([propertyDictionary[key] isEqualToString:@"NSArray"] || [propertyDictionary[key] isEqualToString:@"NSMutableArray"]) {
            NSString *name = [key lowCamelCase];
            NSString *getter = [NSString stringWithFormat:@"%@", name];
            SEL g = NSSelectorFromString(getter);
            NSArray *objects = [self performSelector:g];
            
            // Some objects point to this object, but they should no longer do so if this object does not reference them.
            NSArray *hasManyObjects = [self.class findObjectsWithType:key andID:[self.rowID integerValue]];
            NSString *className = NSStringFromClass(self.class);
            NSString *classSetter = [NSString stringWithFormat:@"set%@:", [className classify]];
            SEL s = NSSelectorFromString(classSetter);
            NSLog(@"About to save");
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
            NSLog(@"Done saving");
        }
    }
}

- (void)deleteSelf {
    sqlite3_stmt *statement;
    const char *dbpath = [self.class.databasePath UTF8String];
    
//    [self.class sleepIfDatabaseIsOpen];
    @synchronized(self.class) {
        if (sqlite3_open(dbpath, self.class.catsDB) == SQLITE_OK) {
//            [self.class lockDatabase];
            NSLog(@"deleteSelf open connection");
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
            NSLog(@"deleteSelf open connection");
//            [self.class openDatabase];
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
}

- (void)fetch {
    NSArray *objects = [self.class where:[NSString stringWithFormat:@"id=%@", self.rowID]];
    if ([objects count] > 0) {
        id object = objects[0];
        NSArray *propertyNames = [self.class allPropertyNames];
        NSInteger propertyCount = [propertyNames count];
        for (NSInteger i = 0; i < propertyCount; i++) {
            // If BOOL, update differently
//            if (_propertiesListAndTypes == nil) {
//                [self.class getAllPropertiesAndTypes];
//            }
//            if ([_propertiesListAndTypes[propertyNames[i]] isEqualToString:@"BOOL"]) {
//                
//            } else {
                NSString *ivarString = [NSString stringWithFormat:@"_%@", propertyNames[i]];
                Ivar objectIvar = class_getInstanceVariable(self.class, [ivarString UTF8String]);
                id updatedPropertyValue = object_getIvar(object, objectIvar);
                id ourPropertyValue = object_getIvar(self, objectIvar);
                ourPropertyValue = updatedPropertyValue;
//            }
        }
    }
}

// Networking
- (void)pushBackendWithCompletionBlock:(void (^)(BOOL success))completionBlock {
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    NSMutableSet *acceptableContentTypes = [NSMutableSet setWithSet:manager.responseSerializer.acceptableContentTypes];
    [acceptableContentTypes addObject:@"text/plain"];
    manager.responseSerializer.acceptableContentTypes = acceptableContentTypes;
    NSDictionary *propertyDictionary = [self.class propertyDictionary];

    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    // TODO: If NSNumber and null, send as @"0"
    for (NSString *property in [self.class allPropertyNames]) {
        NSString *ivarString = [NSString stringWithFormat:@"_%@", property];
        Ivar objectIvar = class_getInstanceVariable(self.class, [ivarString UTF8String]);
        id propertyValue = object_getIvar(self, objectIvar);
        if ([propertyDictionary[property] isEqualToString:@"REAL"]) {
            propertyValue = (propertyValue == nil) ? @(0) : propertyValue;
            [params setObject:propertyValue forKey:[NSString stringWithFormat:@"%@[%@]",[self.class getClassName], [property underscore]]];
        } else {
            propertyValue = (propertyValue == nil) ? @"" : propertyValue;
            [params setObject:propertyValue forKey:[NSString stringWithFormat:@"%@[%@]",[self.class getClassName], [property underscore]]];
        }
    }
    NSLog(@"Backend Params: %@", params); // To be deleted
    if (self.backendId == nil) {
        NSLog(@"Push to backend");
        [manager POST:[self.class baseURL] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
            if (responseObject[@"id"] != nil) {
                NSLog(@"Updated object on server.");
                self.backendId = @([responseObject[@"id"] integerValue]);
                [self save];
                completionBlock(YES);
            }
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSLog(@"Failed to update object on server: %@", error.description);
            completionBlock(NO);
        }];
    } else {
        [manager PATCH:[NSString stringWithFormat:@"%@/%@", [self.class baseURL], self.backendId] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
            if (responseObject[@"id"] != nil) {
                NSLog(@"Updated object on server.");
                completionBlock(YES);
            }
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSLog(@"Failed to update object on server.");
            completionBlock(NO);
        }];
    }
}

//- (void)pushBackend{
//    AFHTTPRequestOperationManager *manager = [[AFHTTPRequestOperationManager alloc] init];
//    NSMutableSet *acceptableContentTypes = [NSMutableSet setWithSet:manager.responseSerializer.acceptableContentTypes];
//    [acceptableContentTypes addObject:@"text/plain"];
//    manager.responseSerializer.acceptableContentTypes = acceptableContentTypes;
//    NSDictionary *propertyDictionary = [self.class propertyDictionary];
//    
//    [manager POST:[self.class baseURL] parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
//        // TODO: If NSNumber and null, send as @"0"
//        for (NSString *property in [self.class allPropertyNames]) {
//            NSString *ivarString = [NSString stringWithFormat:@"_%@", property];
//            Ivar objectIvar = class_getInstanceVariable(self.class, [ivarString UTF8String]);
//            id propertyValue = object_getIvar(self, objectIvar);
//            if ([propertyDictionary[property] isEqualToString:@"REAL"]) {
//                propertyValue = (propertyValue == nil) ? @(0) : propertyValue;
//                [formData appendPartWithFormData:[audioChunk.audioFileName dataUsingEncoding:NSUTF8StringEncoding] name:[NSString stringWithFormat:@"%@[%@]",[self.class getClassName]];
//                [params setObject:propertyValue forKey:, [property underscore]]];
//            } else {
//                propertyValue = (propertyValue == nil) ? @"" : propertyValue;
//                [params setObject:propertyValue forKey:[NSString stringWithFormat:@"%@[%@]",[self.class getClassName], [property underscore]]];
//            }
//        }
//        [formData appendPartWithFileData:subData
//                                    name:@"audio_chunk[audio]"
//                                fileName:audioChunk.audioFileName mimeType:@"audio/wav"];
//        
//        [formData appendPartWithFormData:[audioChunk.audioFileName dataUsingEncoding:NSUTF8StringEncoding] name:@"audio_chunk[audioFileName]"];
//        [formData appendPartWithFormData:[audioChunk.iosCreatedAt dataUsingEncoding:NSUTF8StringEncoding] name:@"audio_chunk[ios_created_at"];
//        [formData appendPartWithFormData:[[NSString stringWithFormat:@"%@", audioChunk.recording.backendId] dataUsingEncoding:NSUTF8StringEncoding] name:@"audio_chunk[recording_id]"];
//    } success:^(AFHTTPRequestOperation *operation, id responseObject) {
//        NSLog(@"Success: %@", responseObject);
//    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
//        NSLog(@"Error: %@", error);
//    }];
//    
//    if (self.backendId == nil) {
//        [manager POST:[self.class baseURL] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
//            if (responseObject[@"id"] != nil) {
//                NSLog(@"Updated object on server.");
//                self.backendId = @([responseObject[@"id"] integerValue]);
//                [self save];
//            }
//        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
//            NSLog(@"Failed to update object on server: %@", error.description);
//        }];
//    } else {
//        [manager PATCH:[NSString stringWithFormat:@"%@/%@", [self.class baseURL], self.backendId] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
//            if (responseObject[@"id"] != nil) {
//                NSLog(@"Updated object on server.");
//            }
//        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
//            NSLog(@"Failed to update object on server.");
//        }];
//    }
//}

- (void)pullBackendWithCompletionBlock:(void (^)(NSDictionary *response))completionBlock {
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    NSMutableSet *acceptableContentTypes = [NSMutableSet setWithSet:manager.responseSerializer.acceptableContentTypes];
    [acceptableContentTypes addObject:@"text/plain"];
    manager.responseSerializer.acceptableContentTypes = acceptableContentTypes;
    
    [manager GET:[self.class baseURL] parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"%@", responseObject);
        NSDictionary *response = responseObject;
        completionBlock(response);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Failed to get object: %@", error);
    }];
}

@end

// TODO: Check that property type is not one of forbidden data types like NSData, NSInteger, CGFloat, etc
// TODO: Regex in where expression, capture %@=%@ to underscore first expression to match column name.
// TODO: Fetch SQL crashes if columnValue is nil.
// TODO: Add support for NSMutableString.