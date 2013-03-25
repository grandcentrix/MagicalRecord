//
//  NSManagedObjectContext+MagicalObserving.m
//  Magical Record
//
//  Created by Saul Mora on 3/9/12.
//  Copyright (c) 2012 Magical Panda Software LLC. All rights reserved.
//

#import "NSManagedObjectContext+MagicalObserving.h"
#import "NSManagedObjectContext+MagicalRecord.h"
#import "MagicalRecord.h"
#import "MagicalRecord+iCloud.h"

NSString * const kMagicalRecordDidMergeChangesFromiCloudNotification = @"kMagicalRecordDidMergeChangesFromiCloudNotification";


@implementation NSManagedObjectContext (MagicalObserving)

#pragma mark - Context Observation Helpers

- (void) MR_observeContext:(NSManagedObjectContext *)otherContext
{
    if (self == otherContext) return;

    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter addObserver:self
                           selector:@selector(MR_mergeChangesFromNotification:)
                               name:NSManagedObjectContextDidSaveNotification
                             object:otherContext];
}

- (void) MR_observeContextOnMainThread:(NSManagedObjectContext *)otherContext
{
    if (self == otherContext) return;

    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter addObserver:self
                           selector:@selector(MR_mergeChangesOnMainThread:)
                               name:NSManagedObjectContextDidSaveNotification
                             object:otherContext];
}

- (void) MR_stopObservingContext:(NSManagedObjectContext *)otherContext
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

	[notificationCenter removeObserver:self
                                  name:NSManagedObjectContextDidSaveNotification
                                object:otherContext];
}

#pragma mark - Context iCloud Merge Helpers

- (void) MR_mergeChangesFromiCloud:(NSNotification *)notification;
{
    [self performBlock:^{
        
        MRLog(@"Merging changes From iCloud to %@ %@",
              [self MR_workingName],
              ([NSThread isMainThread] ? @" *** on Main Thread ***" : @""));
        
        [self mergeChangesFromContextDidSaveNotification:notification];
        
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

        [notificationCenter postNotificationName:kMagicalRecordDidMergeChangesFromiCloudNotification
                                          object:self
                                        userInfo:[notification userInfo]];
    }];
}

- (void) MR_mergeChangesFromNotification:(NSNotification *)notification;
{
    NSManagedObjectContext *fromContext = [notification object];
    if (fromContext == self) return;
    
	MRLog(@"Merging changes from %@ to %@ %@",
          [fromContext MR_workingName], [self MR_workingName],
          ([NSThread isMainThread] ? @" *** on Main Thread ***" : @""));

    void (^mergeBlock)(void) = ^{
        [self mergeChangesFromContextDidSaveNotification:notification];
    };
    
    if (self.concurrencyType == NSConfinementConcurrencyType)
    {
        mergeBlock();
    }
    else
    {
        [self performBlock:mergeBlock];
    }
}

- (void) MR_mergeChangesOnMainThread:(NSNotification *)notification;
{
	if ([NSThread isMainThread])
	{
		[self MR_mergeChangesFromNotification:notification];
	}
	else
	{
		[self performSelectorOnMainThread:@selector(MR_mergeChangesFromNotification:) withObject:notification waitUntilDone:YES];
	}
}

- (void) MR_observeiCloudChangesInCoordinator:(NSPersistentStoreCoordinator *)coordinator;
{
    if (![MagicalRecord isICloudEnabled]) return;
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(MR_mergeChangesFromiCloud:)
                               name:NSPersistentStoreDidImportUbiquitousContentChangesNotification
                             object:coordinator];
    
}

- (void) MR_stopObservingiCloudChangesInCoordinator:(NSPersistentStoreCoordinator *)coordinator;
{
    if (![MagicalRecord isICloudEnabled]) return;
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self
                                  name:NSPersistentStoreDidImportUbiquitousContentChangesNotification
                                object:coordinator];
}

@end
