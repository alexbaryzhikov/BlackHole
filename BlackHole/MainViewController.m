#import "MainViewController.h"
#import "Config.h"
#import "RenderView.h"
#import "Renderer/Renderer.h"
#import <MetalKit/MetalKit.h>

@implementation MainViewController {
    RenderView* renderView;
    Renderer* renderer;
}

- (void)loadView {
    self.view = [[RenderView alloc] initWithFrame:NSMakeRect(0, 0, VIEWPORT_WIDTH, VIEWPORT_HEIGHT)];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        NSLog(@"Metal is not supported on this device");
        self.view = [[NSView alloc] initWithFrame:self.view.frame];
        return;
    }

    renderView = (RenderView*)self.view;
    renderView.device = device;
    renderer = [[Renderer alloc] initWithMetalKitView:renderView];
    renderView.delegate = renderer;
}

@end
