#include <metal_stdlib>
using namespace metal;

#import "../Config.h"
#import "ShaderTypesInternal.hpp"

constant constexpr float2 anglesToUV = float2(1.0f / (M_PI_F * 2.0f), M_1_PI_F);

constant float3x3 sRGBToP3 = {
    {0.82246, 0.03319, 0.01708}, // Column 0 (Red mapping)
    {0.17754, 0.96681, 0.07240}, // Column 1 (Green mapping)
    {0.00000, 0.00000, 0.91052}  // Column 2 (Blue mapping)
};

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

float4 getRayNormal(constant Camera& camera, uint2 viewportSize, uint2 pixel) {
    const float4x4 cameraRotation = makeRotation(camera.yaw, camera.pitch);
    const float projectionDistance = (viewportSize.x / 2.0f) / tan(CAMERA_HORIZONTAL_FOV / 2.0f);
    float u = (pixel.x + 0.5f) - viewportSize.x / 2.0f;
    float v = (pixel.y + 0.5f) - viewportSize.y / 2.0f;
    float4 direction = {projectionDistance, -u, -v, 0.0f};
    return normalize(cameraRotation * direction);
}

float2 getSkyboxCoord(float4 normal) {
    float2 uv = float2(atan2(normal.y, normal.x), asin(clamp(normal.z, -1.0f, 1.0f))) * anglesToUV;
    uv.x = 0.5f - uv.x;
    uv.y = 0.5f - uv.y;
    return uv;
}

kernel void render(texture2d<float, access::write> outputTexture [[texture(TextureIndexOutput)]],
                   array<texture2d<float, access::sample>, TEXTURE_HEAP_SIZE> textures [[texture(TextureIndexHeap)]],
                   constant Camera& camera [[buffer(BufferIndexCamera)]],
                   constant float& edrHeadroom [[buffer(BufferIndexEDRHeadroom)]],
                   uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    constexpr sampler textureSampler(coord::normalized, address::repeat, filter::linear);
    texture2d<float, access::sample> skyboxTexture = textures[TextureHeapIndexSkybox];
    float4 rayNormal = getRayNormal(camera, {outputTexture.get_width(), outputTexture.get_height()}, gid);
    float2 readCoord = getSkyboxCoord(rayNormal);
    float4 outColor = skyboxTexture.sample(textureSampler, readCoord);
    outColor.rgb = sRGBToP3 * outColor.rgb * camera.exposure;
    outputTexture.write(outColor, gid);
}
