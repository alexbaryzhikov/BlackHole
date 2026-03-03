#import "Camera.hpp"
#import "Config.h"
#import "Keyboard.hpp"
#include <numbers>

namespace BH::Camera {

constexpr float pi = std::numbers::pi_v<float>;

simd::float4 position = {-100.0f, 0.0f, 0.0f, 1.0f};
float yaw = 0.0f;
float pitch = 0.0f;
float exposureValue = 0.0f;
float exposure = 1.0f;
float orbitRadius = 100.0f;

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

void mouseDidMove(float dx, float dy) {
    yaw = normalizeAngle(yaw - dx * MOUSE_SENSITIVITY / 1024.0f);
    pitch = simd::clamp(pitch + dy * MOUSE_SENSITIVITY / 1024.0f, -pi / 2.0f, pi / 2.0f);
}

void mouseDidScroll(float dx, float dy) {
    orbitRadius = simd::clamp(orbitRadius * (1.0f + dy * MOUSE_ZOOM_SENSITIVITY / 1024.0f), CAMERA_ORBIT_MIN, CAMERA_ORBIT_MAX);
}

void updatePosition() {
    position.x = -orbitRadius * cosf(yaw) * cosf(pitch);
    position.y = -orbitRadius * sinf(yaw) * cosf(pitch);
    position.z = -orbitRadius * sinf(pitch);
}

void updateExposure() {
    if (BH::Keyboard::keys[BH::Keyboard::keyPeriod]) {
        exposureValue += CAMERA_EXPOSURE_DELTA;
        exposure = powf(2.0f, exposureValue);
    }
    if (BH::Keyboard::keys[BH::Keyboard::keyComma]) {
        exposureValue -= CAMERA_EXPOSURE_DELTA;
        exposure = powf(2.0f, exposureValue);
    }
    if (BH::Keyboard::keys[BH::Keyboard::keyBackslash]) {
        exposureValue = 0.0f;
        exposure = powf(2.0f, exposureValue);
    }
}

void update() {
    updatePosition();
    updateExposure();
}

} // namespace BH::Camera
