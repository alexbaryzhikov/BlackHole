#import "Mouse.hpp"
#import "Camera.hpp"
#import "Config.h"

namespace BH::Mouse {

bool buttonLeft = false;
bool buttonRight = false;

void leftButtonPressed() {
    buttonLeft = true;
}

void leftButtonReleased() {
    buttonLeft = false;
}

void rightButtonPressed() {
    buttonRight = true;
}

void rightButtonReleased() {
    buttonRight = false;
}

void moved(float dx, float dy) {
    Camera::mouseDidMove(dx, dy);
}

void scrolled(float dx, float dy) {
}

} // namespace BH::Mouse
