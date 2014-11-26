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
#import "TTImageEffect.h"

@interface TTImageEffectsViewController ()
@property (nonatomic, strong) QCRenderer *renderer;
@property (nonatomic, strong) TTImageEffect *imageEffect;
@property (nonatomic, weak) TTMapManager *mapManager;
@end

@implementation TTImageEffectsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    TTAppDelegate *appDelegate = (TTAppDelegate *)[NSApp delegate];
    self.mapManager = appDelegate.mapManager;
    NSArray *compositions = self.mapManager.imageEffects;
    
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
    self.compositionsArrayController.sortDescriptors = @[sort];
    [self.compositionsArrayController setContent:compositions];
    
	[self.qcView loadCompositionFromFile:[[NSBundle mainBundle] pathForResource:@"ImageEffectsPreview" ofType:@"qtz"]];
    self.imageEffect = self.mapManager.imageEffect;
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    [self compositionParameterView:nil didChangeParameterWithKey:nil];
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

- (void)setSelectedEffectIndex:(NSUInteger)selectedEffectIndex {
    _selectedEffectIndex = selectedEffectIndex;
    
    TTImageEffect *imageEffect = self.compositionsArrayController.arrangedObjects[selectedEffectIndex];
    if (self.imageEffect != imageEffect) {
        self.imageEffect = imageEffect;
    }
}

- (void)setImageEffect:(TTImageEffect *)imageEffect {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    self.renderer = [[QCRenderer alloc] initWithComposition:imageEffect.composition colorSpace:colorSpace];
    [self.renderer setValue:nil forInputKey:QCCompositionInputImageKey];
    
    [imageEffect.inputValues enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [self.renderer setValue:obj forInputKey:key];
    }];
    
    if (nil != self.mapManager.lastSeenLocation) {
        [self updateComposition];
    }
    
    self.parameterView.compositionRenderer = self.renderer;
    CGColorSpaceRelease(colorSpace);
}

- (TTImageEffect *)imageEffect {
    NSMutableDictionary *inputValues = [NSMutableDictionary new];
    NSArray *excludedInputKeys = self.excludedInputKeys;
    [self.renderer.composition.inputKeys enumerateObjectsUsingBlock:^(NSString *inputKey, NSUInteger idx, BOOL *stop) {
        if (! [excludedInputKeys containsObject:inputKey]) {
            id value = [self.renderer valueForInputKey:inputKey];
            if (nil != value) {
                inputValues[inputKey] = value;
            }
        }
    }];
    
    return [TTImageEffect imageEffectWithComposition:self.renderer.composition inputValues:inputValues];
}

- (NSArray *)excludedInputKeys {
    return @[QCCompositionInputImageKey, QCCompositionInputPreviewModeKey, QCCompositionInputXKey, QCCompositionInputYKey];
}

#pragma mark - QCCompositionParameterView Delegate

- (BOOL) compositionParameterView:(QCCompositionParameterView*)parameterView shouldDisplayParameterWithKey:(NSString*)portKey attributes:(NSDictionary*)portAttributes
{
    return ! [self.excludedInputKeys containsObject:portKey];
}

- (void) compositionParameterView:(QCCompositionParameterView*)parameterView didChangeParameterWithKey:(NSString*)portKey
{
    /* Since one of the parameter has changed, we need to re-renderer the QCRenderer */
    if(![self.renderer renderAtTime:0.0 arguments:nil])
        NSLog(@"QCRenderer failed rendering");
    
    /* Forward the image produced by the QCRenderer to the preview composition on the QCView */
    [self.qcView setValue:[_renderer valueForOutputKey:QCCompositionOutputImageKey ofType:@"QCImage"] forInputKey:@"inImage"];
}

- (IBAction)doneAction:(id)sender {
    self.mapManager.imageEffect = self.imageEffect;
}
@end