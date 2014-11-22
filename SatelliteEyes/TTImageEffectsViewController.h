//
//  TTImageEffectsViewController.h
//  SatelliteEyes
//
//  Created by Johnnie Walker on 18/11/2014.
//
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@interface TTImageEffectsViewController : NSViewController
@property (nonatomic, weak) IBOutlet NSArrayController *compositionsArrayController;
@property (nonatomic, weak) IBOutlet QCView *qcView;
@property (nonatomic, weak) IBOutlet QCCompositionParameterView *parameterView;
@end
