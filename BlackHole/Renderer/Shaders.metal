#include <metal_stdlib>
using namespace metal;

#import "../Config.h"
#import "ShaderTypesInternal.hpp"

constant constexpr float4 spherePosition = {0.0f, 0.0f, 0.0f, 1.0f};
constant constexpr float sphereRadius = 10.0f;

constant constexpr float eventHorizon = 1.0f;
constant constexpr float escapeRadius = 500.0f;
constant constexpr int maxSteps = 1000;

constant constexpr bool accretionDiskVisible = true;
constant constexpr float accretionDiskInner = 3.2f;
constant constexpr float accretionDiskOuter = 15.0f;

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

float getRaySphereHit(float4 rayOrigin, float4 rayNormal, float4 spherePosition, float sphereRadius) {
    float3 l = rayOrigin.xyz - spherePosition.xyz;
    float half_b = dot(rayNormal.xyz, l);
    float c = dot(l, l) - (sphereRadius * sphereRadius);
    float discriminant = half_b * half_b - c;

    // If discriminant is negative, the ray misses the sphere entirely
    if (discriminant < 0.0f) {
        return -1.0f;
    }

    float sqrt_d = sqrt(discriminant);

    // Find the closest point of intersection
    float t = -half_b - sqrt_d;

    // If the closest point is behind the camera/ray origin, try the other side
    if (t < 0.0f) {
        t = -half_b + sqrt_d;
    }

    // If both points are behind the origin, the intersection is not valid
    if (t < 0.0f) {
        return -1.0f;
    }

    return t;
}

float4 getRayReflectedNormal(float4 rayOrigin, float4 rayNormal, float4 spherePosition, float sphereRadius) {
    float t = getRaySphereHit(rayOrigin, rayNormal, spherePosition, sphereRadius);
    if (t < 0.0f) {
        return rayNormal;
    } else {
        float4 intersectionPoint = rayOrigin + rayNormal * t;
        float3 surfaceNormal = normalize(intersectionPoint.xyz - spherePosition.xyz);
        float3 reflectedNormal = normalize(reflect(rayNormal.xyz, surfaceNormal));
        return float4(reflectedNormal, 0.0f);
    }
}

float3 getAcceleration(float3 p, float h2) {
    float r2 = length_squared(p);
    float r5 = r2 * r2 * sqrt(r2);
    return -1.5f * eventHorizon * h2 / r5 * p;
}

inline float hash21(float2 p) {
    return fract(sin(dot(p, float2(12.9898f, 78.233f))) * 43758.5453123f);
}

inline float noise2D(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);

    float a = hash21(i);
    float b = hash21(i + float2(1.0f, 0.0f));
    float c = hash21(i + float2(0.0f, 1.0f));
    float d = hash21(i + float2(1.0f, 1.0f));

    float2 u = f * f * (3.0f - 2.0f * f);

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Fractal Brownian Motion for turbulent plasma layers
inline float fbm(float2 p) {
    float value = 0.0f;
    float amplitude = 0.5f;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise2D(p);
        p *= 2.0f;
        amplitude *= 0.5f;
    }
    return value;
}

inline float4 getAccretionDiskColor(float2 pos) {
    float r = length(pos);
    float2 dir = pos / r;

    float t = saturate((r - accretionDiskInner) / (accretionDiskOuter - accretionDiskInner));

    float2 noiseCoords = dir * 2.0f + float2(r * 5.0f, 0.0f);
    float fluidNoise = fbm(noiseCoords);

    float spaceWarp = fbm(float2(r * 2.0f, 12.4f)) * 1.5f;
    float warpedRadius = r + spaceWarp + fluidNoise * 0.25f;

    float lowFreq  = sin(warpedRadius * 6.0f);
    float midFreq  = sin(warpedRadius * 14.0f);
    float highFreq = sin(warpedRadius * 32.0f);

    float bands = (lowFreq * 0.55f + midFreq * 0.3f + highFreq * 0.15f);
    bands = saturate(bands * 0.5f + 0.5f);

    float bandPinch = mix(0.05f, 1.0f, t);
    bands = pow(bands, bandPinch);

    float coreGlow = smoothstep(0.4f, 0.0f, t);
    bands = saturate(bands + coreGlow);

    float innerFade = smoothstep(0.0f, 0.05f, t);
    float outerFade = smoothstep(1.0f, 0.3f, t);
    float radialFade = innerFade * outerFade;

    float glowIntensity = (fluidNoise * 0.6f + 0.4f) * bands * radialFade;

    float3 darkPlasma = float3(3.0f, 0.0f, 0.0f);
    float3 midPlasma  = float3(14.0f, 2.5f, 0.2f);
    float3 hotPlasma  = float3(25.0f, 15.0f, 8.0f);

    float3 color = mix(darkPlasma, midPlasma, smoothstep(0.0f, 0.4f, glowIntensity));
    color = mix(color, hotPlasma, smoothstep(0.4f, 0.8f, glowIntensity));

    // Exponential core brightness.
    float innerEdgeBoost = 1.0f + pow(1.0f - t, 4.0f) * 3.5f;
    color *= innerEdgeBoost;

    float alpha = glowIntensity * 0.9f;

    return float4(color * alpha, alpha);
}

float4 getRayBentNormal(float4 rayOrigin, float4 rayNormal, thread bool& captured, thread float4& accumulatedColor) {
    float3 p = rayOrigin.xyz;
    float3 v = rayNormal.xyz;
    float3 angularMomentum = cross(p, v);
    float h2 = length_squared(angularMomentum);
    captured = false;
    for (int i = 0; i < maxSteps; ++i) {
        float r = length(p);
        if (r < eventHorizon) {
            captured = true;
            break;
        }
        if (r > escapeRadius && dot(p, v) > 0.0f) {
            break;
        }
        float dt = 0.05f * r;

        // Runge-Kutta integration.
        float3 p0 = p;
        float3 v0 = v;

        float3 p1 = v0 * dt;
        float3 v1 = getAcceleration(p0, h2) * dt;

        float3 p2 = (v0 + 0.5f * v1) * dt;
        float3 v2 = getAcceleration(p0 + 0.5f * p1, h2) * dt;

        float3 p3 = (v0 + 0.5f * v2) * dt;
        float3 v3 = getAcceleration(p0 + 0.5f * p2, h2) * dt;

        float3 p4 = (v0 + v3) * dt;
        float3 v4 = getAcceleration(p0 + p3, h2) * dt;

        p += (p1 + 2.0f * p2 + 2.0f * p3 + p4) / 6.0f;
        v += (v1 + 2.0f * v2 + 2.0f * v3 + v4) / 6.0f;

        v = normalize(v);

        // Accretion disk intersection.
        if (accretionDiskVisible && p0.z * p.z < 0.0f) {
            float t = p0.z / (p0.z - p.z);
            float3 hitPosition = mix(p0, p, t);
            float hitRadius = length(hitPosition);
            if (hitRadius > accretionDiskInner && hitRadius < accretionDiskOuter) {
                float4 diskSample = getAccretionDiskColor(hitPosition.xy);
                accumulatedColor.rgb += diskSample.rgb * (1.0f - accumulatedColor.a);
                accumulatedColor.a += diskSample.a * (1.0f - accumulatedColor.a);
                if (accumulatedColor.a >= 0.99f) {
                    break;
                }
            }
        }
    }
    return float4(v, 0.0f);
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
    return outColor;
}

float4 getReflectedColor(constant Camera& camera, float4 rayNormal, texture2d<float, access::sample> skybox, float edrHeadroom) {
    float4 rayReflectedNormal = getRayReflectedNormal(camera.position, rayNormal, spherePosition, sphereRadius);
    float4 outColor = sampleSkybox(skybox, rayReflectedNormal, camera.exposure, edrHeadroom);
    outColor.rgb = applyEDRRollOff(outColor.rgb, edrHeadroom);
    return outColor;
}

float4 getBentColor(constant Camera& camera, float4 rayNormal, texture2d<float, access::sample> skybox, float edrHeadroom) {
    bool captured = false;
    float4 accumulatedColor = float(0.0f);
    float4 rayBentNormal = getRayBentNormal(camera.position, rayNormal, captured, accumulatedColor);
    if (!captured && accumulatedColor.a < 0.99f) {
        float4 outColor = sampleSkybox(skybox, rayBentNormal, camera.exposure, edrHeadroom);
        outColor = float4(accumulatedColor.rgb + outColor.rgb * (1.0f - accumulatedColor.a), 1.0f);
        outColor.rgb = applyEDRRollOff(outColor.rgb, edrHeadroom);
        return outColor;
    } else {
        return float4(accumulatedColor.rgb, 1.0f);
    }
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
    float4 outColor = getBentColor(camera, rayNormal, textures[TextureHeapIndexSkybox], edrHeadroom);
    outputTexture.write(outColor, gid);
}
