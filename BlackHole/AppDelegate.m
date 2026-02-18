#import "AppDelegate.h"
#import "Config.h"
#import "MainViewController.h"

@interface AppDelegate ()

@property(nonatomic, strong) NSWindow* window;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification {
    [self setupMenus];
    [self setupWindow];
}

- (void)setupMenus {
    NSMenu* mainMenu = [[NSMenu alloc] initWithTitle:@"MainMenu"];

    // --- App Menu ---

    NSMenuItem* appMenuItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:appMenuItem];

    NSMenu* appMenu = [[NSMenu alloc] init];
    [appMenuItem setSubmenu:appMenu];

    NSString* appName = [[NSProcessInfo processInfo] processName];
    NSString* aboutTitle = [NSString stringWithFormat:@"About %@", appName];
    NSMenuItem* aboutMenuItem = [[NSMenuItem alloc] initWithTitle:aboutTitle action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [appMenu addItem:aboutMenuItem];

    [appMenu addItem:[NSMenuItem separatorItem]];

    NSString* quitTitle = [NSString stringWithFormat:@"Quit %@", appName];
    NSMenuItem* quitMenuItem = [[NSMenuItem alloc] initWithTitle:quitTitle action:@selector(terminate:) keyEquivalent:@"q"];
    [appMenu addItem:quitMenuItem];

    // --- Window Menu ---

    NSMenuItem* windowMenuItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:windowMenuItem];

    NSMenu* windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    [windowMenuItem setSubmenu:windowMenu];

    NSMenuItem* closeMenuItem = [[NSMenuItem alloc] initWithTitle:@"Close Window" action:@selector(performClose:) keyEquivalent:@"w"];
    [windowMenu addItem:closeMenuItem];

    NSMenuItem* minimizeMenuItem = [[NSMenuItem alloc] initWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [windowMenu addItem:minimizeMenuItem];

    NSMenuItem* zoomMenuItem = [[NSMenuItem alloc] initWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];
    [windowMenu addItem:zoomMenuItem];

    [NSApp setMainMenu:mainMenu];
}

- (void)setupWindow {
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
                                              styleMask:(NSWindowStyleMaskTitled |
                                                         NSWindowStyleMaskClosable |
                                                         NSWindowStyleMaskMiniaturizable |
                                                         NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.title = @"Black Omega Star";
    self.window.backgroundColor = NSColor.blackColor;
    self.window.contentAspectRatio = NSMakeSize(VIEWPORT_WIDTH, VIEWPORT_HEIGHT);
    self.window.contentViewController = [[MainViewController alloc] init];
    [self.window makeFirstResponder:self.window.contentViewController];
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender {
    return YES;
}

@end
