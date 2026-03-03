#include <metal_stdlib>
using namespace metal;

#import "../Config.h"
#import "ShaderTypesInternal.hpp"

constant constexpr float2 anglesToUV = float2(1.0f / (M_PI_F * 2.0f), M_1_PI_F);
constant constexpr float3 colorToLuma = {0.2126, 0.7152, 0.0722};

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

float getRaySphereHit(float4 rayOrigin, float4 rayNormal, float4 sphereCenter, float sphereRadius) {
    float3 l = rayOrigin.xyz - sphereCenter.xyz;
    float half_b = dot(rayNormal.xyz, l);
    float c = dot(l, l) - (sphereRadius * sphereRadius);
    float discriminant = half_b * half_b - c;

    // If discriminant is negative, the ray misses the sphere entirely
    if (discriminant < 0.0) {
        return -1.0;
    }

    float sqrt_d = sqrt(discriminant);

    // Find the closest point of intersection
    float t = -half_b - sqrt_d;

    // If the closest point is behind the camera/ray origin, try the other side
    if (t < 0.0) {
        t = -half_b + sqrt_d;
    }

    // If both points are behind the origin, the intersection is not valid
    if (t < 0.0) {
        return -1.0;
    }

    return t;
}

float2 getSkyboxCoord(float4 normal) {
    float2 uv = float2(atan2(normal.y, normal.x), asin(clamp(normal.z, -1.0f, 1.0f))) * anglesToUV;
    uv.x = 0.5f - uv.x;
    uv.y = 0.5f - uv.y;
    return uv;
}

float3 applyEDRRollOff(float3 color, float edrHeadroom) {
    float luma = dot(color, colorToLuma);
    if (luma <= 1.0f) {
        return color;
    }
    float headroom = edrHeadroom - 1.0f;
    float excessLuma = luma - 1.0f;
    float compressedLuma = 1.0f + headroom * (1.0f - exp(-excessLuma/headroom));
    return color * (compressedLuma / luma);
}

float4 sampleSkybox(texture2d<float, access::sample> skyboxTexture, float4 rayNormal, float exposure, float edrHeadroom) {
    constexpr sampler textureSampler(coord::normalized, address::repeat, filter::linear);
    float2 readCoord = getSkyboxCoord(rayNormal);
    float4 outColor = skyboxTexture.sample(textureSampler, readCoord);
    outColor.rgb *= exposure;
    outColor.rgb = sRGBToP3 * outColor.rgb;
    outColor.rgb = applyEDRRollOff(outColor.rgb, edrHeadroom);
    return outColor;
}

kernel void render(texture2d<float, access::write> outputTexture [[texture(TextureIndexOutput)]],
                   array<texture2d<float, access::sample>, TEXTURE_HEAP_SIZE> textures [[texture(TextureIndexHeap)]],
                   constant Camera& camera [[buffer(BufferIndexCamera)]],
                   constant float& edrHeadroom [[buffer(BufferIndexEDRHeadroom)]],
                   uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    float4 rayNormal = getRayNormal(camera, {outputTexture.get_width(), outputTexture.get_height()}, gid);
    float4 outColor = float4(0);
    if (getRaySphereHit(camera.position, rayNormal, float4(0), 10.0f) < 0) {
        outColor = sampleSkybox(textures[TextureHeapIndexSkybox], rayNormal, camera.exposure, edrHeadroom);
    }
    outputTexture.write(outColor, gid);
}
