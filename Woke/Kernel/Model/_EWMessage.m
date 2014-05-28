// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to EWMessage.m instead.

#import "_EWMessage.h"

const struct EWMessageAttributes EWMessageAttributes = {
	.createdAt = @"createdAt",
	.media = @"media",
	.objectId = @"objectId",
	.text = @"text",
	.time = @"time",
	.updatedAt = @"updatedAt",
};

const struct EWMessageRelationships EWMessageRelationships = {
	.groupTask = @"groupTask",
	.recipient = @"recipient",
	.sender = @"sender",
	.task = @"task",
};

const struct EWMessageFetchedProperties EWMessageFetchedProperties = {
};

@implementation EWMessageID
@end

@implementation _EWMessage

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"EWMessage" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"EWMessage";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"EWMessage" inManagedObjectContext:moc_];
}

- (EWMessageID*)objectID {
	return (EWMessageID*)[super objectID];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	

	return keyPaths;
}




@dynamic createdAt;






@dynamic media;






@dynamic objectId;






@dynamic text;






@dynamic time;






@dynamic updatedAt;






@dynamic groupTask;

	

@dynamic recipient;

	

@dynamic sender;

	

@dynamic task;

	






@end