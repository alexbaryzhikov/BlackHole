#include <metal_stdlib>
using namespace metal;

#import "../Config.h"
#import "ShaderTypesInternal.hpp"

constant constexpr float2 anglesToUV = float2(1.0f / (M_PI_F * 2.0f), M_1_PI_F);

float4x4 makeRotation(float yaw, float pitch) {
    float cy = cos(yaw);
    float sy = sin(yaw);
    float cp = cos(pitch);
    float sp = sin(pitch);
    return float4x4(float4(cy * cp, sy * cp, sp, 0.0f),
                    float4(-sy, cy, 0.0f, 0.0f),
                    float4(-cy * sp, -sy * sp, cp, 0.0f),
                    float4(0.0f, 0.0f, 0.0f, 1.0f));
}

float4 getRayNormal(constant Camera& camera, uint2 pixel) {
    const float4x4 cameraRotation = makeRotation(camera.yaw, camera.pitch);
    const float projectionDistance = (VIEWPORT_WIDTH / 2.0f) / tan(CAMERA_FOV / 2.0f);
    float u = (pixel.x + 0.5f) - VIEWPORT_WIDTH / 2.0f;
    float v = (pixel.y + 0.5f) - VIEWPORT_HEIGHT / 2.0f;
    float4 direction = {projectionDistance, u, -v, 0.0f};
    return normalize(cameraRotation * direction);
}

float2 getEquirectangularUV(float4 normal) {
    float2 uv = float2(atan2(normal.y, normal.x), asin(normal.z)) * anglesToUV;
    uv.x += 0.5f;
    uv.y = 0.5f - uv.y;
    return uv;
}

kernel void render(texture2d<float, access::write> outputTexture [[texture(TextureIndexOutput)]],
                   array<texture2d<float, access::sample>, TEXTURE_HEAP_SIZE> textures [[texture(TextureIndexHeap)]],
                   constant Camera& camera [[buffer(BufferIndexCamera)]],
                   uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    float4 rayDirection = getRayNormal(camera, gid);
    float2 uv = getEquirectangularUV(rayDirection);
    float4 outColor = {uv.x, 0, uv.y, 1};
    outputTexture.write(outColor, gid);
}
