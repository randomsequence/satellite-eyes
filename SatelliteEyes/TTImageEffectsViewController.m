//
//  TTImageEffectsViewController.m
//  SatelliteEyes
//
//  Created by Johnnie Walker on 18/11/2014.
//
//

#import <CoreLocation/CoreLocation.h>

#import "TTImageEffectsViewController.h"
#import "TTMapImage.h"
#import "TTMapManager.h"
#import "TTAppDelegate.h"

@interface TTImageEffectsViewController ()
@property (nonatomic, strong) QCRenderer *renderer;
@property (nonatomic, strong) QCComposition *composition;
@property (nonatomic, weak) TTMapManager *mapManager;
@end

@implementation TTImageEffectsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSArray *compositionPaths = [[NSBundle mainBundle] pathsForResourcesOfType:@"qtz" inDirectory:@"Compositions"];
    NSMutableArray *compositions = [NSMutableArray new];
    [compositionPaths enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
        QCComposition *composition = [QCComposition compositionWithFile:path];
        if (nil != composition) [compositions addObject:composition];
    }];
    
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"attributes.name" ascending:YES];
    self.compositionsArrayController.sortDescriptors = @[sort];
    [self.compositionsArrayController setContent:compositions];
    
	[self.qcView loadCompositionFromFile:[[NSBundle mainBundle] pathForResource:@"ImageEffectsPreview" ofType:@"qtz"]];
    self.composition = [compositions firstObject];
}

- (void)setComposition:(QCComposition *)composition {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    self.renderer = [[QCRenderer alloc] initWithComposition:composition colorSpace:colorSpace];
    [self.renderer setValue:nil forInputKey:QCCompositionInputImageKey];
    
    TTAppDelegate *appDelegate = (TTAppDelegate *)[NSApp delegate];
    self.mapManager = appDelegate.mapManager;

    if (nil != self.mapManager.lastSeenLocation) {
        [self updateComposition];
    }
    
    self.parameterView.compositionRenderer = self.renderer;
    CGColorSpaceRelease(colorSpace);
}

- (void)updateComposition {
    if (nil != self.mapManager.lastSeenLocation) {
        CLLocationCoordinate2D coordinate = self.mapManager.lastSeenLocation.coordinate;
        TTMapImage *mapImage = [self.mapManager mapImageForCoordinate:coordinate
                                                          screen:[NSScreen mainScreen]
                                                          imageEffect:nil];
        [mapImage fetchTilesWithSuccess:^(NSURL *filePath) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                NSImage *image = [[NSImage alloc] initWithContentsOfURL:filePath];
                [self.renderer setValue:image forInputKey:QCCompositionInputImageKey];
                [self.renderer setValue:@(image.size.width/2.0) forInputKey:QCCompositionInputXKey];
                [self.renderer setValue:@(image.size.height/2.0) forInputKey:QCCompositionInputYKey];
                [self compositionParameterView:nil didChangeParameterWithKey:nil];
            }];
        } failure:^(NSError *error) {
            DDLogError(@"Error fetching image: %@", error);
        } skipCache:NO];
    }
}

- (QCComposition *)composition {
    return self.renderer.composition;
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    [self compositionParameterView:nil didChangeParameterWithKey:nil];
}

#pragma mark - QCCompositionParameterView Delegate

- (BOOL) compositionParameterView:(QCCompositionParameterView*)parameterView shouldDisplayParameterWithKey:(NSString*)portKey attributes:(NSDictionary*)portAttributes
{
    BOOL display = YES;
    if ([portKey isEqualToString:QCCompositionInputImageKey]
        || [portKey isEqualToString:QCCompositionInputPreviewModeKey]
        || [portKey isEqualToString:QCCompositionInputXKey]
        || [portKey isEqualToString:QCCompositionInputYKey]) {
        display = NO;
    }
    return display;
}

- (void) compositionParameterView:(QCCompositionParameterView*)parameterView didChangeParameterWithKey:(NSString*)portKey
{
    /* Since one of the parameter has changed, we need to re-renderer the QCRenderer */
    if(![self.renderer renderAtTime:0.0 arguments:nil])
        NSLog(@"QCRenderer failed rendering");
    
    /* Forward the image produced by the QCRenderer to the preview composition on the QCView */
    [self.qcView setValue:[_renderer valueForOutputKey:QCCompositionOutputImageKey ofType:@"QCImage"] forInputKey:@"inImage"];
}

@end