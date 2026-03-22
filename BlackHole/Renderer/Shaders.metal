#include <metal_stdlib>
using namespace metal;

#import "../Config.h"
#import "ShaderTypesInternal.hpp"

constant constexpr float eventHorizon = 1.0;
constant constexpr float escapeRadius = 500.0;
constant constexpr int maxSteps = 1000;

constant constexpr bool accretionDiskVisible = true;
constant constexpr float accretionDiskInner = 3.2;
constant constexpr float accretionDiskOuter = 15.0;

constant constexpr float2 anglesToUV = float2(1.0 / (M_PI_F * 2.0), M_1_PI_F);
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
    return float4x4(float4(cy * cp, sy * cp, sp, 0.0),
                    float4(-sy, cy, 0.0, 0.0),
                    float4(-cy * sp, -sy * sp, cp, 0.0),
                    float4(0.0, 0.0, 0.0, 1.0));
}

float4 getRayNormal(constant Camera& camera, uint2 viewportSize, uint2 pixel) {
    const float4x4 cameraRotation = makeRotation(camera.yaw, camera.pitch);
    const float projectionDistance = (viewportSize.x / 2.0) / tan(CAMERA_HORIZONTAL_FOV / 2.0);
    float u = (pixel.x + 0.5) - viewportSize.x / 2.0;
    float v = (pixel.y + 0.5) - viewportSize.y / 2.0;
    float4 direction = {projectionDistance, -u, -v, 0.0};
    return normalize(cameraRotation * direction);
}

float3 getAcceleration(float3 p, float h2) {
    float r2 = length_squared(p);
    float r5 = r2 * r2 * sqrt(r2);
    return -1.5 * eventHorizon * h2 / r5 * p;
}

inline float hash21(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453123);
}

inline float noise2D(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);

    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));

    float2 u = f * f * (3.0 - 2.0 * f);

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Fractal Brownian Motion for turbulent plasma layers.
inline float fbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise2D(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

inline float4 getAccretionDiskColor(float2 pos) {
    float r = length(pos);

    float t = saturate((r - accretionDiskInner) / (accretionDiskOuter - accretionDiskInner));

    float2 noiseCoords = 2.0 * pos / r + float2(r * 5.0, 0.0);
    float fluidNoise = fbm(noiseCoords);

    float spaceWarp = fbm(float2(r * 2.0, 12.4)) * 1.5;
    float warpedRadius = r + spaceWarp + fluidNoise * 0.25;

    float lowFreq  = sin(warpedRadius * 6.0);
    float midFreq  = sin(warpedRadius * 14.0);
    float highFreq = sin(warpedRadius * 32.0);

    float bands = (lowFreq * 0.55 + midFreq * 0.3 + highFreq * 0.15);
    bands = saturate(bands * 0.5 + 0.5);

    float bandPinch = mix(0.05, 1.0, t);
    bands = pow(bands, bandPinch);

    float coreGlow = smoothstep(0.4, 0.0, t);
    bands = saturate(bands + coreGlow);

    float innerFade = smoothstep(0.0, 0.05, t);
    float outerFade = smoothstep(1.0, 0.3, t);
    float radialFade = innerFade * outerFade;

    float glowIntensity = (fluidNoise * 0.6 + 0.4) * bands * radialFade;

    float3 darkPlasma = float3(2.0, 0.2, 0.3);
    float3 midPlasma  = float3(7.8, 0.6, 0.5);
    float3 hotPlasma  = float3(12.0, 4.5, 2.0);

    float3 color = mix(darkPlasma, midPlasma, smoothstep(0.0, 0.4, glowIntensity));
    color = mix(color, hotPlasma, smoothstep(0.4, 0.8, glowIntensity));

    float alpha = glowIntensity * 0.9;

    return float4(color * alpha, alpha);
}

float3 getDopplerShift(float3 hitPosition, float hitRadius, float3 rayNormal) {
    float3 gasDirection = normalize(cross(float3(0.0, 0.0, 1.0), hitPosition));
    float gasSpeed = sqrt(0.5 * eventHorizon / hitRadius);
    float3 gasVelocity = gasDirection * gasSpeed;
    float3 photonDirection = -rayNormal;
    float gamma = 1.0 / sqrt(1.0 - gasSpeed * gasSpeed);
    float dopplerFactor = 1.0 / (gamma * (1.0 - dot(gasVelocity, photonDirection)));
    float beaming = pow(dopplerFactor, 3.0);
    float3 colorShift = float3(
        pow(dopplerFactor, -0.6), // Red channel thrives when receding
        pow(dopplerFactor, 0.2),  // Green gets a slight bump
        pow(dopplerFactor, 1.5)   // Blue channel explodes when approaching
    );
    return colorShift * beaming;
}

void traceRay(float4 rayOrigin, float4 rayNormal, thread float4& outRayNormal, thread float4& accumulatedColor, thread bool& captured) {
    float3 p = rayOrigin.xyz;
    float3 v = rayNormal.xyz;
    float3 angularMomentum = cross(p, v);
    float h2 = length_squared(angularMomentum);
    for (int i = 0; i < maxSteps; ++i) {
        float r = length(p);
        if (r < eventHorizon) {
            captured = true;
            break;
        }
        if (r > escapeRadius && dot(p, v) > 0.0) {
            break;
        }
        float dt = 0.05 * r;

        // Runge-Kutta integration.
        float3 p0 = p;
        float3 v0 = v;

        float3 p1 = v0 * dt;
        float3 v1 = getAcceleration(p0, h2) * dt;

        float3 p2 = (v0 + 0.5 * v1) * dt;
        float3 v2 = getAcceleration(p0 + 0.5 * p1, h2) * dt;

        float3 p3 = (v0 + 0.5f * v2) * dt;
        float3 v3 = getAcceleration(p0 + 0.5 * p2, h2) * dt;

        float3 p4 = (v0 + v3) * dt;
        float3 v4 = getAcceleration(p0 + p3, h2) * dt;

        p += (p1 + 2.0 * p2 + 2.0 * p3 + p4) / 6.0;
        v += (v1 + 2.0 * v2 + 2.0 * v3 + v4) / 6.0;

        v = normalize(v);

        // Accretion disk intersection.
        if (accretionDiskVisible && p0.z * p.z < 0.0) {
            float t = p0.z / (p0.z - p.z);
            float3 hitPosition = mix(p0, p, t);
            float hitRadius = length(hitPosition);
            if (hitRadius > accretionDiskInner && hitRadius < accretionDiskOuter) {
                float4 diskColor = getAccretionDiskColor(hitPosition.xy);
                float3 dopplerShift = getDopplerShift(hitPosition, hitRadius, v);
                diskColor.rgb *= dopplerShift;
                accumulatedColor.rgb += diskColor.rgb * (1.0 - accumulatedColor.a);
                accumulatedColor.a += diskColor.a * (1.0 - accumulatedColor.a);
                if (accumulatedColor.a >= 0.99) {
                    break;
                }
            }
        }
    }
    outRayNormal = float4(v, 0.0);
}

float2 getSkyboxCoord(float4 normal) {
    float2 uv = float2(atan2(normal.y, normal.x), asin(clamp(normal.z, -1.0, 1.0))) * anglesToUV;
    uv.x = 0.5 - uv.x;
    uv.y = 0.5 - uv.y;
    return uv;
}

float3 applyEDRRollOff(float3 color, float edrHeadroom) {
    float luma = dot(color, colorToLuma);
    if (luma <= 1.0) {
        return color;
    }
    float headroom = edrHeadroom - 1.0;
    float excessLuma = luma - 1.0;
    float compressedLuma = 1.0 + headroom * (1.0 - exp(-excessLuma/headroom));
    return color * (compressedLuma / luma);
}

float4 sampleSkybox(texture2d<float, access::sample> skyboxTexture, float4 rayNormal, float edrHeadroom) {
    constexpr sampler textureSampler(coord::normalized, address::repeat, filter::linear);
    float2 readCoord = getSkyboxCoord(rayNormal);
    float4 outColor = skyboxTexture.sample(textureSampler, readCoord);
    outColor.rgb = sRGBToP3 * outColor.rgb;
    return outColor;
}

float4 getColor(constant Camera& camera, float4 rayNormal, texture2d<float, access::sample> skybox, float edrHeadroom) {
    float4 outRayNormal = float(0.0);
    float4 accumulatedColor = float(0.0);
    bool captured = false;
    traceRay(camera.position, rayNormal, outRayNormal, accumulatedColor, captured);
    float4 outColor;
    if (!captured && accumulatedColor.a < 0.99) {
        outColor = sampleSkybox(skybox, outRayNormal, edrHeadroom);
        outColor = float4(accumulatedColor.rgb + outColor.rgb * (1.0 - accumulatedColor.a), 1.0);
    } else {
        outColor = float4(accumulatedColor.rgb, 1.0);
    }
    outColor.rgb *= camera.exposure;
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
    float4 color = getColor(camera, rayNormal, textures[TextureHeapIndexSkybox], edrHeadroom);
    outputTexture.write(color, gid);
}
