#import <Foundation/Foundation.h>

@protocol CraneManagerObserver
@optional
- (void)didChangeRootSettings;
- (void)didChangeSettingsForApplicationWithIdentifier:(NSString*)applicationID;
- (void)didChangeContainersOfApplicationWithIdentifier:(NSString*)applicationID;
- (void)didChangeContainerSettingsForContainerWithIdentifier:(NSString*)containerID onApplicationWithIdentifier:(NSString*)applicationID;
@end

typedef NS_ENUM(NSInteger, ContainerPathType) {
    ContainerPathTypeApp,
    ContainerPathTypeGroup,
    ContainerPathTypePlugin
};

@interface CraneManager : NSObject

+ (instancetype)sharedManager;

// observers
- (void)addObserver:(NSObject<CraneManagerObserver>*)observer;
- (void)removeObserver:(NSObject<CraneManagerObserver>*)observer;

// app settings
- (BOOL)isApplicationSupportedByCrane:(NSString*)applicationID;
- (NSArray*)identfiersOfApplicationsThatHaveNonDefaultContainers;
- (NSArray*)identifiersOfAllSupportedApplications;
- (NSString*)displayNameForApplicationWithIdentifier:(NSString*)applicationID;
- (NSString*)activeContainerIdentifierForApplicationWithIdentifier:(NSString*)applicationID;
- (void)setActiveContainerIdentifier:(NSString*)containerID forApplicationWithIdentifier:(NSString*)applicationID;
- (NSArray*)containerIdentifiersOfApplicationWithIdentifier:(NSString*)applicationID;

// container management
- (void)createNewContainerWithName:(NSString*)containerName andIdentifier:(NSString*)containerID forApplicationWithIdentifier:(NSString*)applicationID;
- (NSString*)createNewContainerWithName:(NSString*)containerName forApplicationWithIdentifier:(NSString*)applicationID;
- (void)deleteContainerWithIdentifier:(NSString*)containerID forApplicationWithIdentifier:(NSString*)applicationID;
- (void)wipeContainerWithIdentifier:(NSString*)containerID forApplicationWithIdentifier:(NSString*)applicationID shouldRepopulate:(BOOL)repopulate;
- (NSString*)displayNameForContainerWithIdentifier:(NSString*)containerID ofApplicationWithIdentifier:(NSString*)applicationID shouldUseShortVersion:(BOOL)shortVersion;
- (void)reloadApplicationWithIdentifier:(NSString*)applicationID;

@end
