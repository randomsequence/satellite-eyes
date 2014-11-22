//
//  TTMapManager.m
//  SatelliteEyes
//
//  Created by Tom Taylor on 19/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TTMapManager.h"
#import "TTMapImage.h"
#import "TTMapTile.h"
#import "NSFileManager+StandardPaths.h"
#import "Reachability.h"

@interface TTMapManager ()
- (CGRect)tileRectForScreen:(NSScreen *)screen 
                 coordinate:(CLLocationCoordinate2D)coordinate 
                  zoomLevel:(unsigned short)zoomLevel;
@property (nonatomic, strong) CLLocation *lastSeenLocation;
@end

#define BASE_TILE_SIZE 256

@implementation TTMapManager

- (id)init
{
    self = [super init];
    if (self) {
        locationManager = [[CLLocationManager alloc] init];
        locationManager.distanceFilter = 300;
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
        locationManager.delegate = self;
        //locationManager.purpose = @"Satellite Eyes needs permission to access your location so it can update your desktop wallpaper with the view overhead.";
        
        // serial dispatch queue to synchronize map updates
        updateQueue = dispatch_queue_create("uk.co.tomtaylor.satelliteeyes.mapupdate", DISPATCH_QUEUE_SERIAL);
        
        reachability = [Reachability reachabilityForInternetConnection];
        [reachability startNotifier];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reachabilityChanged:) 
                                                     name:kReachabilityChangedNotification 
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(screensChanged:) 
                                                     name:NSApplicationDidChangeScreenParametersNotification 
                                                   object:nil];
        
        [[NSUserDefaults standardUserDefaults] addObserver:self 
                                                forKeyPath:@"selectedMapTypeId" 
                                                   options:NSKeyValueObservingOptionNew
                                                   context:nil];
        
        [[NSUserDefaults standardUserDefaults] addObserver:self 
                                                forKeyPath:@"zoomLevel" 
                                                   options:NSKeyValueObservingOptionNew
                                                   context:nil];
        
        [[NSUserDefaults standardUserDefaults] addObserver:self 
                                                forKeyPath:@"selectedImageEffectId"
                                                   options:NSKeyValueObservingOptionNew
                                                   context:nil];

        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self 
                                                               selector:@selector(spaceChanged:) 
                                                                   name:NSWorkspaceActiveSpaceDidChangeNotification 
                                                                 object:nil];
        
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self 
                                                               selector:@selector(receiveWakeNote:) 
                                                                   name:NSWorkspaceDidWakeNotification 
                                                                 object:nil];
    }
    return self;
}

- (void)start {
    if ([CLLocationManager locationServicesEnabled]) {
        [locationManager startUpdatingLocation];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:TTMapManagerLocationPermissionDenied object:nil];
    }    
}

// If the screens have changed, force an update.
- (void)screensChanged:(NSNotification *)notification {
    [self updateMap];
}

- (void)spaceChanged:(NSNotification *)notification {
    [self updateMap];
}

- (void)receiveWakeNote:(NSNotification *)notification {
    [self restartMap];
}

- (void)reachabilityChanged:(NSNotification *)notification {
    Reachability *thisReachability = notification.object;
    
    if (thisReachability.isReachable) {
        [self updateMap];
    } else {
        [self restartMap];
    }
}

- (void)updateMap {
    if (self.lastSeenLocation) {
        [self updateMapToCoordinate:self.lastSeenLocation.coordinate force:NO];
    }
}

- (void)forceUpdateMap {
    if (self.lastSeenLocation) {
        [self updateMapToCoordinate:self.lastSeenLocation.coordinate force:YES];
    }
}

// Lose the location and force fetching a new one
- (void)restartMap {
    [locationManager stopUpdatingLocation];
    self.lastSeenLocation = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:TTMapManagerLocationLost object:nil];
    [locationManager startUpdatingLocation];    
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [self updateMap];
}

- (TTMapImage *)mapImageForCoordinate:(CLLocationCoordinate2D)coordinate
                               screen:(NSScreen *)screen
                          imageEffect:(NSDictionary *)imageEffect
{
    CGRect tileRect = [self tileRectForScreen:screen
                                   coordinate:coordinate
                                    zoomLevel:self.zoomLevel];
    
    NSString *source = [self sourceForScreen:screen];
    float tileScale = [self tileScaleForScren:screen];
    
    return [[TTMapImage alloc] initWithTileRect:tileRect
                               tileScale:tileScale
                               zoomLevel:self.zoomLevel
                                  source:source
                                  effect:imageEffect
                                    logo:self.logoImage];
}

- (void)updateMapToCoordinate:(CLLocationCoordinate2D)coordinate force:(BOOL)force
{
    [[NSScreen screens] enumerateObjectsUsingBlock:^(NSScreen *screen, NSUInteger idx, BOOL *stop) {
        // put everything through the serial dispatch queue to ensure we're 
        // not requesting the same tile multiple times concurrently
        dispatch_async(updateQueue, ^{
            
            [[NSNotificationCenter defaultCenter] postNotificationName:TTMapManagerStartedLoad object:nil];
            
            TTMapImage *mapImage = [self mapImageForCoordinate:coordinate screen:screen imageEffect:[self selectedImageEffect]];
            
            [mapImage fetchTilesWithSuccess:^(NSURL *filePath) {
                [[NSNotificationCenter defaultCenter] postNotificationName:TTMapManagerFinishedLoad object:nil];
                
                NSURL *currentImageUrl = [[NSWorkspace sharedWorkspace] desktopImageURLForScreen:screen];
                
                // If the desktop image is already set to the same path, it won't update the image, even if the content has changed
                if (force && [currentImageUrl isEqual:filePath]) {
                    NSURL *tempImage = [[NSBundle mainBundle] URLForImageResource:@"loading"];
                    
                    // We set a temp image
                    [[NSWorkspace sharedWorkspace] setDesktopImageURL:tempImage
                                                            forScreen:screen
                                                              options:nil
                                                                error:nil];
                    
                    // 1 second later, update with the main image - if we do immediately after, it never seems to set it
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                        [[NSWorkspace sharedWorkspace] setDesktopImageURL:filePath
                                                                forScreen:screen
                                                                  options:nil
                                                                    error:nil];
                    });
                    
                } else {
                    [[NSWorkspace sharedWorkspace] setDesktopImageURL:filePath
                                                            forScreen:screen
                                                              options:nil
                                                                error:nil];
                }
                
                
            } failure:^(NSError *error) {
                [[NSNotificationCenter defaultCenter] postNotificationName:TTMapManagerFailedLoad object:nil];
                DDLogError(@"Error fetching image: %@", error);
            } skipCache:force];
        });
    }];
}

#pragma mark CLLocationManagerDelegate methods

- (void)locationManager:(CLLocationManager *)manager 
    didUpdateToLocation:(CLLocation *)newLocation 
           fromLocation:(CLLocation *)oldLocation
{
    // throw away location updates older than two minutes
	if (newLocation && abs([newLocation.timestamp timeIntervalSinceNow]) < 120) {
        [[NSNotificationCenter defaultCenter] postNotificationName:TTMapManagerLocationUpdated object:newLocation];
        self.lastSeenLocation = newLocation;
        [self updateMapToCoordinate:newLocation.coordinate force:NO];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    if ([error code] == kCLErrorDenied) {
        [locationManager stopUpdatingLocation];
        [[NSNotificationCenter defaultCenter] postNotificationName:TTMapManagerLocationPermissionDenied object:nil];
    }
}

// Returns a CGRect for the screen's tiles, given a centre coordinate and a zoom level
- (CGRect)tileRectForScreen:(NSScreen *)screen 
                 coordinate:(CLLocationCoordinate2D)coordinate 
                  zoomLevel:(unsigned short)z 
{
    // Find the centre tile
    CGPoint centerTile = [TTMapTile coordinateToPoint:coordinate zoomLevel:z];

    CGRect mainScreenFrame = [[NSScreen mainScreen] frame];
    CGRect targetScreenFrame = screen.frame;

    // Get the size and origin of the main screen in tiles
    float mainScreenTileHeight = NSHeight(mainScreenFrame)/BASE_TILE_SIZE;
    float mainScreenTileWidth = NSWidth(mainScreenFrame)/BASE_TILE_SIZE;
    float mainScreenTileOriginX = centerTile.x - mainScreenTileWidth/2;
    float mainScreenTileOriginY = centerTile.y + mainScreenTileHeight/2;
    
    // Calculate the size and origin of the target screen in tiles, offset from the main screen centre point
    float targetScreenTileHeight = NSHeight(targetScreenFrame)/BASE_TILE_SIZE;
    float targetScreenTileWidth = NSWidth(targetScreenFrame)/BASE_TILE_SIZE;
    float targetScreenTileOriginX = mainScreenTileOriginX + targetScreenFrame.origin.x/BASE_TILE_SIZE;
    float targetScreenTileOriginY = mainScreenTileOriginY - targetScreenFrame.origin.y/BASE_TILE_SIZE;
    
    return CGRectMake(targetScreenTileOriginX, targetScreenTileOriginY, targetScreenTileWidth, targetScreenTileHeight);
}

- (NSDictionary *)selectedImageEffect {
    NSArray *imageEffects = [[NSUserDefaults standardUserDefaults] objectForKey:@"imageEffectTypes"];
    NSString *selectedImageEffectId = [[NSUserDefaults standardUserDefaults] objectForKey:@"selectedImageEffectId"];

    // Default to the first image effect
    __block NSDictionary *selectedImageEffect = imageEffects[0];
    
    // Now try and find a matching image effect type id, and set that to be the selected one
    [imageEffects enumerateObjectsUsingBlock:^(NSDictionary *imageEffect, NSUInteger idx, BOOL *stop) {
        NSString *imageEffectId = imageEffect[@"id"];
        
        if ([imageEffectId isEqualToString:selectedImageEffectId]) {
            selectedImageEffect = imageEffect;
            *stop = YES;
        }
    }];
    
    return selectedImageEffect;
}

- (BOOL)screenIsRetina:(NSScreen *)screen {
    return screen.backingScaleFactor > 1;
}

- (NSString *)sourceForScreen:(NSScreen *)screen {
    NSString *source2x = self.selectedMapType[@"source2x"];
    if (source2x && [self screenIsRetina:screen]) {
        return source2x;
    } else {
        return self.selectedMapType[@"source"];
    }
}

- (float)tileScaleForScren:(NSScreen *)screen {
    if (self.selectedMapTypeSupportsRetina && [self screenIsRetina:screen]) {
        return 2;
    } else {
        return 1;
    }
}

- (BOOL)selectedMapTypeSupportsRetina {
    return !!self.selectedMapType[@"source2x"];
}

- (NSImage *)logoImage {
    NSString *imageName = (self.selectedMapType)[@"logoImage"];
    if (imageName) {
        return [NSImage imageNamed:imageName];
    } else {
        return nil;
    }
}

- (short unsigned int)zoomLevel {
    NSNumber *maxZoom = (self.selectedMapType)[@"maxZoom"];
    NSNumber *minZoom = (self.selectedMapType)[@"minZoom"];
    NSNumber *desiredZoom = [[NSUserDefaults standardUserDefaults] objectForKey:@"zoomLevel"];
    int desiredZoomInt = [desiredZoom intValue];
    
    if (maxZoom && desiredZoomInt > [maxZoom intValue]) {
        desiredZoomInt = [maxZoom intValue];
    } else if (minZoom && desiredZoomInt < [minZoom intValue]) {
        desiredZoomInt = [minZoom intValue];
    }
    
    return desiredZoomInt;
}

- (NSDictionary *)selectedMapType {
    NSArray *mapTypes = [[NSUserDefaults standardUserDefaults] objectForKey:@"mapTypes"];
    NSString *selectedMapTypeId = [[NSUserDefaults standardUserDefaults] objectForKey:@"selectedMapTypeId"];
    
    // Default to the first map type
    __block NSDictionary *selectedMapType = mapTypes[0];
    
    // Now try and find a matching map type id, and set that to be the selected one
    [mapTypes enumerateObjectsUsingBlock:^(NSDictionary *mapType, NSUInteger idx, BOOL *stop) {
        NSString *mapTypeId = mapType[@"id"];
        
        if ([mapTypeId isEqualToString:selectedMapTypeId]) {
            selectedMapType = mapType;
            *stop = YES;
        }
    }];
    
    return selectedMapType;
}

// Flushes out old map images, leaving the currently displayed ones, and the last 20 modified.
- (void)cleanCache {
    NSString *cacheDirectoryPath = [[NSFileManager defaultManager] privateDataPath];
    
    NSError *error;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:cacheDirectoryPath error:&error];
    if (error) {
        return;
    }

    // For each of the currently active screens, find the current wallpaper filename
    NSMutableArray *safeFiles = [NSMutableArray array];
    [[NSScreen screens] enumerateObjectsUsingBlock:^(NSScreen *screen, NSUInteger idx, BOOL *stop) {
        NSURL *desktopImageURL = [[NSWorkspace sharedWorkspace] desktopImageURLForScreen:screen];
        [safeFiles addObject:[desktopImageURL lastPathComponent]];
    }];
    
    // Find all the files which begin with map and aren't currently on the desktop
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(SELF BEGINSWITH[cd] %@) && NOT (SELF IN %@)", @"map", safeFiles];
    NSArray *filesToRemove = [files filteredArrayUsingPredicate:predicate];
    
    // Make an array of dictionaries with the modification date for each file
    NSMutableArray *filesAndProperties = [NSMutableArray arrayWithCapacity:[filesToRemove count]];
    [filesToRemove enumerateObjectsUsingBlock:^(NSString *file, NSUInteger idx, BOOL *stop) {
        NSString *filePath = [NSString pathWithComponents:@[cacheDirectoryPath, file]];
        NSError *error;
        NSDictionary* properties = [[NSFileManager defaultManager]
                                    attributesOfItemAtPath:filePath
                                    error:&error];
        if (error)
            return;
        
        NSDate* modificationDate = properties[NSFileModificationDate];
        
        [filesAndProperties addObject:@{@"filePath": filePath, 
                                       @"modificationDate": modificationDate}];
    }];
    
    // Sort by most recent first
    NSArray *sortedFiles = [filesAndProperties sortedArrayUsingComparator:
                             ^(id path1, id path2) {
                                 NSComparisonResult comp = [path1[@"modificationDate"] compare:
                                                            path2[@"modificationDate"]];
                                 if (comp == NSOrderedDescending) {
                                     comp = NSOrderedAscending;
                                 }
                                 else if (comp == NSOrderedAscending) {
                                     comp = NSOrderedDescending;
                                 }
                                 return comp;                                
                             }];
    
    // Leave the 20 most recent, and delete the rest
    [sortedFiles enumerateObjectsUsingBlock:^(NSDictionary *fileDict, NSUInteger idx, BOOL *stop) {
        if (idx >= 20) {
            NSString *path = fileDict[@"filePath"];
            NSError *error;
            [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
            if (error) {
                return;
            }
        }
    }];
}

- (NSURL *)browserURL {
    if (!self.lastSeenLocation) {
        return nil;
    }
    
    NSString *browserURL = (self.selectedMapType)[@"browserURL"];
    if (!browserURL) {
        return nil;
    }
    
    NSNumberFormatter *coordinateFormatter = [[NSNumberFormatter alloc] init];
    [coordinateFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [coordinateFormatter setMaximumFractionDigits:8];
    
    NSNumber *latitudeNumber = @(self.lastSeenLocation.coordinate.latitude);
    NSNumber *longitudeNumber = @(self.lastSeenLocation.coordinate.longitude);
    
    NSString *latitudeString = [coordinateFormatter stringFromNumber:latitudeNumber];
    NSString *longitudeString = [coordinateFormatter stringFromNumber:longitudeNumber];
    NSString *zoomString = [NSString stringWithFormat:@"%u", self.zoomLevel];
    
    browserURL = [browserURL stringByReplacingOccurrencesOfString:@"{latitude}" withString:latitudeString];
    browserURL = [browserURL stringByReplacingOccurrencesOfString:@"{longitude}" withString:longitudeString];
    browserURL = [browserURL stringByReplacingOccurrencesOfString:@"{zoom}" withString:zoomString];
    
    return [NSURL URLWithString:browserURL];
}

- (void)dealloc
{
    [reachability stopNotifier];
  
#if NEEDS_DISPATCH_RETAIN_RELEASE
    dispatch_release(updateQueue);
#endif
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"selectedMapTypeIndex"];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"zoomLevel"];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"selectedImageEffectId"];
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

@end
