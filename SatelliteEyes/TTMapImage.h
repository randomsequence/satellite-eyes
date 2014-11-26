//
//  TTMapImage.h
//  SatelliteEyes
//
//  Created by Tom Taylor on 19/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@class TTImageEffect;

@interface TTMapImage : NSObject {
    CGRect tileRect;
    float tileScale;
    unsigned short zoomLevel;
    NSString *source;
    TTImageEffect *imageEffect;
    NSArray *tiles;
    CGPoint pixelShift;
    NSOperationQueue *tileQueue;
    NSImage *logoImage;
    NSUInteger tileSize;
}

- (id)initWithTileRect:(CGRect)_tileRect
             tileScale:(float)_tileScale
             zoomLevel:(unsigned short)_zoomLevel
                source:(NSString *)_provider
                effect:(TTImageEffect *)_effect
                  logo:(NSImage *)_logoImage;

- (void)fetchTilesWithSuccess:(void (^)(NSURL *filePath))success
                      failure:(void (^)(NSError *error))failure
                    skipCache:(BOOL)skipCache;

- (NSURL *)fileURL;

@end