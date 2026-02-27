#import "ModelBridge.h"
#import "Camera.hpp"
#import "Mouse.hpp"
#import "Keyboard.hpp"

@implementation ModelBridge

#pragma mark - Input Events

+ (void)keyDown:(UInt16)code {
    BH::Keyboard::keyPressed(code);
}

+ (void)keyUp:(UInt16)code {
    BH::Keyboard::keyReleased(code);
}

+ (void)flagsChanged:(NSEventModifierFlags)flags {
    BH::Keyboard::flagsChanged(flags);
}

+ (void)leftMouseDown {
    BH::Mouse::leftButtonPressed();
}

+ (void)leftMouseUp {
    BH::Mouse::leftButtonReleased();
}

+ (void)rightMouseDown {
    BH::Mouse::rightButtonPressed();
}

+ (void)rightMouseUp {
    BH::Mouse::rightButtonReleased();
}

+ (void)mouseMoved:(CGVector)offset {
    BH::Mouse::moved(offset.dx, offset.dy);
}

+ (void)mouseWheel:(CGVector)offset {
    BH::Mouse::scrolled(offset.dx, offset.dy);
}

#pragma mark - Uniforms

+ (void)updateModel {
    BH::Camera::update();
}

+ (void)copyCamera:(Camera*)dst {
    dst->position = BH::Camera::position;
    dst->yaw = BH::Camera::yaw;
    dst->pitch = BH::Camera::pitch;
    dst->exposure = BH::Camera::exposure;
}

@end
