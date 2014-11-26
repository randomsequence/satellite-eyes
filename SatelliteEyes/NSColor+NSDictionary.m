//
//  NSColor+NSDictionary.m
//  SatelliteEyes
//
//  Created by Johnnie Walker on 24/11/2014.
//
//

#import "NSColor+NSDictionary.h"

NSString * const redKey = @"red";
NSString * const greenKey = @"green";
NSString * const blueKey = @"blue";
NSString * const alphaKey = @"alpha";

@implementation NSColor (NSDictionary)
- (NSDictionary *)tt_RGBDictionaryRepresentation;
{
    NSColor *rgbColor = [self colorUsingColorSpaceName:NSDeviceRGBColorSpace];
    
    if (!rgbColor) {
        return nil; // happens if the colorspace couldn’t be converted
    }
    
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithFloat:[rgbColor redComponent]], redKey,
            [NSNumber numberWithFloat:[rgbColor greenComponent]], greenKey,
            [NSNumber numberWithFloat:[rgbColor blueComponent]], blueKey,
            [NSNumber numberWithFloat:[rgbColor alphaComponent]], alphaKey,
            nil];
}

+ (id)tt_colorWithRGBDictionary:(NSDictionary *)rgbDictionary;
{
    CGFloat red = [[rgbDictionary objectForKey:redKey] floatValue];
    CGFloat green = [[rgbDictionary objectForKey:greenKey] floatValue];
    CGFloat blue = [[rgbDictionary objectForKey:blueKey] floatValue];
    CGFloat alpha = [[rgbDictionary objectForKey:alphaKey] floatValue];
    
    return [NSColor colorWithDeviceRed:red green:green blue:blue alpha:alpha];
}
@end
