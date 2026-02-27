#import "ShaderTypesShared.h"
#import <AppKit/AppKit.h>

@interface ModelBridge : NSObject

#pragma mark - Input Events

+ (void)keyDown:(UInt16)code;
+ (void)keyUp:(UInt16)code;
+ (void)flagsChanged:(NSEventModifierFlags)flags;
+ (void)leftMouseDown;
+ (void)leftMouseUp;
+ (void)rightMouseDown;
+ (void)rightMouseUp;
+ (void)mouseMoved:(CGVector)offset;
+ (void)mouseWheel:(CGVector)offset;

#pragma mark - Uniforms

+ (void)updateModel;
+ (void)copyCamera:(Camera*)dst;

@end
