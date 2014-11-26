//
//  TTImageEffect.m
//  SatelliteEyes
//
//  Created by Johnnie Walker on 24/11/2014.
//
//

#import "TTImageEffect.h"
#import <Quartz/Quartz.h>

#import "NSColor+NSDictionary.h"

@implementation TTImageEffect
+ (instancetype)imageEffectWithComposition:(QCComposition *)composition inputValues:(NSDictionary *)inputValues {
    TTImageEffect *effect = [[TTImageEffect alloc] initWithComposition:composition];
    effect.inputValues = inputValues;
    return effect;
}

- (instancetype)initWithComposition:(QCComposition *)composition;
{
    self = [super init];
    if (self) {
        _composition = composition;
    }
    return self;
}

- (NSString *)name {
    return self.composition.attributes[@"name"];
}

- (NSString *)identifier {
    NSString *identifier = self.composition.attributes[@"uk.co.tomtaylor.SatelliteEyes.identifier"];
    if (nil == identifier) {
        identifier = self.composition.identifier;
    }
    return identifier;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ %@ %@ %@", [super description], self.name, self.identifier, self.inputValues];
}

+ (NSDictionary *)decodeInputValues:(NSDictionary *)encodedValues {
    NSMutableDictionary *decodedInputValues = [NSMutableDictionary new];
    NSArray *colorKeys = @[kCIInputColorKey, @"inputColor0", @"inputColor1"];
    [encodedValues enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([colorKeys containsObject:key]) {
            NSColor *color = [NSColor tt_colorWithRGBDictionary:obj];
            if (nil != color) {
                [decodedInputValues setObject:color forKey:key];
            }
        } else {
            [decodedInputValues setObject:obj forKey:key];
        }
    }];
    return decodedInputValues;
}

- (NSDictionary *)encodedInputValues {
    NSMutableDictionary *encodedInputValues = [NSMutableDictionary new];
    
    [self.inputValues enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([obj isKindOfClass:[NSColor class]]) {
            NSColor *color = obj;
            NSDictionary *value = [color tt_RGBDictionaryRepresentation];
            if (nil != value) {
                [encodedInputValues setObject:value forKey:key];
            }
        } else {
            [encodedInputValues setObject:obj forKey:key];
        }
    }];
    
    return encodedInputValues;
}
@end
