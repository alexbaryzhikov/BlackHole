#import "MainViewController.h"
#import "Config.h"
#import "RenderingView.h"
#import <MetalKit/MetalKit.h>

@implementation MainViewController {
    RenderingView* renderingView;
}

- (void)loadView {
    self.view = [[RenderingView alloc] initWithFrame:NSMakeRect(0, 0, VIEWPORT_WIDTH, VIEWPORT_HEIGHT)];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        NSLog(@"Metal is not supported on this device");
        self.view = [[NSView alloc] initWithFrame:self.view.frame];
        return;
    }

    renderingView = (RenderingView*)self.view;
    renderingView.device = device;
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
}

@end
