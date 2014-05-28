// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to EWAlarmItem.m instead.

#import "_EWAlarmItem.h"

const struct EWAlarmItemAttributes EWAlarmItemAttributes = {
	.createdAt = @"createdAt",
	.important = @"important",
	.objectId = @"objectId",
	.state = @"state",
	.statement = @"statement",
	.time = @"time",
	.todo = @"todo",
	.tone = @"tone",
	.updatedAt = @"updatedAt",
};

const struct EWAlarmItemRelationships EWAlarmItemRelationships = {
	.owner = @"owner",
	.tasks = @"tasks",
};

const struct EWAlarmItemFetchedProperties EWAlarmItemFetchedProperties = {
};

@implementation EWAlarmItemID
@end

@implementation _EWAlarmItem

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"EWAlarmItem" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"EWAlarmItem";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"EWAlarmItem" inManagedObjectContext:moc_];
}

- (EWAlarmItemID*)objectID {
	return (EWAlarmItemID*)[super objectID];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"importantValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"important"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}
	if ([key isEqualToString:@"stateValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"state"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}

	return keyPaths;
}




@dynamic createdAt;






@dynamic important;



- (BOOL)importantValue {
	NSNumber *result = [self important];
	return [result boolValue];
}

- (void)setImportantValue:(BOOL)value_ {
	[self setImportant:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveImportantValue {
	NSNumber *result = [self primitiveImportant];
	return [result boolValue];
}

- (void)setPrimitiveImportantValue:(BOOL)value_ {
	[self setPrimitiveImportant:[NSNumber numberWithBool:value_]];
}





@dynamic objectId;






@dynamic state;



- (BOOL)stateValue {
	NSNumber *result = [self state];
	return [result boolValue];
}

- (void)setStateValue:(BOOL)value_ {
	[self setState:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveStateValue {
	NSNumber *result = [self primitiveState];
	return [result boolValue];
}

- (void)setPrimitiveStateValue:(BOOL)value_ {
	[self setPrimitiveState:[NSNumber numberWithBool:value_]];
}





@dynamic statement;






@dynamic time;






@dynamic todo;






@dynamic tone;






@dynamic updatedAt;






@dynamic owner;

	

@dynamic tasks;

	
- (NSMutableSet*)tasksSet {
	[self willAccessValueForKey:@"tasks"];
  
	NSMutableSet *result = (NSMutableSet*)[self mutableSetValueForKey:@"tasks"];
  
	[self didAccessValueForKey:@"tasks"];
	return result;
}
	






@end