//
//  TTImageEffect.h
//  SatelliteEyes
//
//  Created by Johnnie Walker on 24/11/2014.
//
//

#import <Foundation/Foundation.h>

@class QCComposition;
@interface TTImageEffect : NSObject
@property (nonatomic, strong, readonly) QCComposition *composition;
@property (nonatomic, copy) NSDictionary *inputValues;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *identifier;
+ (NSDictionary *)decodeInputValues:(NSDictionary *)encodedValues;
- (NSDictionary *)encodedInputValues;   // suitable for archiving with NSArchiver

+ (instancetype)imageEffectWithComposition:(QCComposition *)composition inputValues:(NSDictionary *)inputValues;
- (instancetype)initWithComposition:(QCComposition *)composition;
@end
