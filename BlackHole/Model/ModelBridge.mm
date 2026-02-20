#import "ModelBridge.h"
#import "Camera.hpp"
#import "Mouse.hpp"

@implementation ModelBridge

#pragma mark - Input Events

+ (void)keyDown:(UInt16)code {
}

+ (void)keyUp:(UInt16)code {
}

+ (void)flagsChanged:(NSEventModifierFlags)flags {
}

+ (void)leftMouseDown {
    BH::Mouse::leftButtonDown();
}

+ (void)leftMouseUp {
    BH::Mouse::leftButtonUp();
}

+ (void)rightMouseDown {
    BH::Mouse::rightButtonDown();
}

+ (void)rightMouseUp {
    BH::Mouse::rightButtonUp();
}

+ (void)mouseMoved:(CGVector)offset {
    BH::Mouse::moved(offset.dx, offset.dy);
}

+ (void)mouseWheel:(CGVector)offset {
    BH::Mouse::scrolled(offset.dx, offset.dy);
}

#pragma mark - Uniforms

+ (void)copyCamera:(Camera*)dst {
    dst->position = BH::Camera::position;
    dst->yaw = BH::Camera::yaw;
    dst->pitch = BH::Camera::pitch;
}

@end
