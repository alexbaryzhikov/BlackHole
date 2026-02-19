#import "RenderView.h"
#import "ModelBridge.h"

@implementation RenderView {
    BOOL isMouseCaptured;
    NSTrackingArea* trackingArea;
}

#pragma mark - Initialization

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    return self;
}

- (instancetype)initWithCoder:(NSCoder*)coder {
    self = [super initWithCoder:coder];
    return self;
}

#pragma mark - Responder Chain

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSWindowDidResignKeyNotification
                                                  object:self.window];
    if (self.window) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(windowDidResignKey:)
                                                     name:NSWindowDidResignKeyNotification
                                                   object:self.window];
    }
    [self.window makeFirstResponder:self];
}

- (void)windowDidResignKey:(NSNotification*)notification {
    [self stopMouseCapture];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopMouseCapture];
}

#pragma mark - Mouse Capture

- (void)startMouseCapture {
    if (!isMouseCaptured) {
        isMouseCaptured = YES;
        [NSCursor hide];
        CGAssociateMouseAndMouseCursorPosition(false);
    }
}

- (void)stopMouseCapture {
    if (isMouseCaptured) {
        isMouseCaptured = NO;
        [NSCursor unhide];
        CGAssociateMouseAndMouseCursorPosition(true);
    }
}

#pragma mark - Tracking Area

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (trackingArea) {
        [self removeTrackingArea:trackingArea];
    }
    // We want to track mouse movement and enter/exit events.
    // ActiveInKeyWindow means events are only sent when the window is active.
    NSTrackingAreaOptions options = (NSTrackingMouseMoved | NSTrackingActiveInKeyWindow | NSTrackingMouseEnteredAndExited);
    trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                options:options
                                                  owner:self
                                               userInfo:nil];
    [self addTrackingArea:trackingArea];
}

#pragma mark - Event Handling

- (void)keyDown:(NSEvent*)event {
    if (event.keyCode == 53) { // Escape key
        [self stopMouseCapture];
    } else {
        [ModelBridge keyDown:event.keyCode];
    }
}

- (void)keyUp:(NSEvent*)event {
    [ModelBridge keyUp:event.keyCode];
}

- (void)flagsChanged:(NSEvent*)event {
    [ModelBridge flagsChanged:event.modifierFlags];
}

- (void)mouseDown:(NSEvent*)event {
    if (isMouseCaptured) {
        [ModelBridge leftMouseDown];
    } else {
        [self startMouseCapture];
    }
}

- (void)mouseUp:(NSEvent*)event {
    [ModelBridge leftMouseUp];
}

- (void)rightMouseDown:(NSEvent*)event {
    if (isMouseCaptured) {
        [ModelBridge rightMouseDown];
    } else {
        [self startMouseCapture];
    }
}

- (void)rightMouseUp:(NSEvent*)event {
    [ModelBridge rightMouseUp];
}

- (void)mouseMoved:(NSEvent*)event {
    if (!isMouseCaptured) return;
    [ModelBridge mouseMoved:CGVectorMake(event.deltaX, event.deltaY)];
}

- (void)mouseDragged:(NSEvent*)event {
    if (!isMouseCaptured) return;
    [ModelBridge mouseMoved:CGVectorMake(event.deltaX, event.deltaY)];
}

- (void)scrollWheel:(NSEvent*)event {
    if (!isMouseCaptured) return;
    [ModelBridge mouseWheel:CGVectorMake(event.scrollingDeltaX, event.scrollingDeltaY)];
}

@end
