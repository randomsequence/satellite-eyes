//
//  NSColor+NSDictionary.h
//  SatelliteEyes
//
//  Created by Johnnie Walker on 24/11/2014.
//
//

#import <Cocoa/Cocoa.h>

@interface NSColor (NSDictionary)
- (NSDictionary *)tt_RGBDictionaryRepresentation;
+ (id)tt_colorWithRGBDictionary:(NSDictionary *)rgbDictionary;
@end
