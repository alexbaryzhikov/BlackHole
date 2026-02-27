#import "Camera.hpp"
#import "Config.h"
#import "Keyboard.hpp"
#include <numbers>

namespace BH::Camera {

constexpr float pi = std::numbers::pi_v<float>;

simd::float4 position = {0.0f, 0.0f, 0.0f, 1.0f};
float yaw = 0.0f;
float pitch = 0.0f;
float exposureValue = 0.0f;
float exposure = 1.0f;

/**
 * Force angle to (-pi, pi] range.
 */
float normalizeAngle(float angle) {
    angle = fmod(angle, pi * 2.0f);
    if (angle <= -pi) {
        angle += pi * 2.0f;
    } else if (angle > pi) {
        angle -= pi * 2.0f;
    }
    return angle;
}

float clampAngle(float angle, float low, float high) {
    return fmin(fmax(angle, low), high);
}

void mouseDidMove(float dx, float dy) {
    yaw = normalizeAngle(yaw - dx * MOUSE_SENSITIVITY / 1024.0f);
    pitch = clampAngle(pitch - dy * MOUSE_SENSITIVITY / 1024.0f, -pi / 2.0f, pi / 2.0f);
}

void updateExposure() {
    if (BH::Keyboard::keys[BH::Keyboard::keyUp]) {
        exposureValue += CAMERA_EXPOSURE_DELTA;
        exposure = powf(2.0f, exposureValue);
    }
    if (BH::Keyboard::keys[BH::Keyboard::keyDown]) {
        exposureValue -= CAMERA_EXPOSURE_DELTA;
        exposure = powf(2.0f, exposureValue);
    }
}

void update() {
    updateExposure();
}

} // namespace BH::Camera
