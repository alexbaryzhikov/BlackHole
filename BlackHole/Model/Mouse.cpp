#import "Mouse.hpp"
#import "Camera.hpp"
#import "Config.h"

namespace BH::Mouse {

bool buttonLeft = false;
bool buttonRight = false;

void leftButtonDown() {
    buttonLeft = true;
}

void leftButtonUp() {
    buttonLeft = false;
}

void rightButtonDown() {
    buttonRight = true;
}

void rightButtonUp() {
    buttonRight = false;
}

void moved(float dx, float dy) {
    Camera::mouseDidMove(dx, dy);
}

void scrolled(float dx, float dy) {
}

} // namespace BH::Mouse
