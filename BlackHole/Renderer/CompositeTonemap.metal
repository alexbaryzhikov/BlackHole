#import "CompositeTonemapTypes.h"

constexpr sampler linearSampler(coord::normalized, filter::linear, address::clamp_to_edge);

inline float3 acesTonemap(float3 color) {
    constexpr float a = 2.51;
    constexpr float b = 0.03;
    constexpr float c = 2.43;
    constexpr float d = 0.59;
    constexpr float e = 0.14;
    return saturate((color * (a * color + b)) / (color * (c * color + d) + e));
}

inline float3 edrRollOff(float3 color, float edrHeadroom) {
    constexpr float3 colorToLuma = {0.2126, 0.7152, 0.0722};

    float luma = dot(color, colorToLuma);
    if (luma <= 1.0) {
        return color;
    }
    float headroom = edrHeadroom - 1.0;
    float excessLuma = luma - 1.0;
    float compressedLuma = 1.0 + headroom * (1.0 - exp(-excessLuma/headroom));
    return color * (compressedLuma / luma);
}

kernel void compositeTonemap(texture2d<float, access::write> outputTexture [[texture(CompositeTonemapTextureIndexOutput)]],
                             texture2d<float, access::sample> hdrTexture [[texture(CompositeTonemapTextureIndexHDR)]],
                             texture2d<float, access::sample> bloomTexture [[texture(CompositeTonemapTextureIndexBloom)]],
                             constant float& edrHeadroom [[buffer(CompositeTonemapBufferIndexEDRHeadroom)]],
                             uint2 gid [[thread_position_in_grid]]) {
    constexpr float bloomIntensity = 0.005;

    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) return;

    float2 uv = (float2(gid) + 0.5) / float2(outputTexture.get_width(), outputTexture.get_height());

    float3 hdrColor = hdrTexture.sample(linearSampler, uv).rgb;
    float3 bloomColor = bloomTexture.sample(linearSampler, uv).rgb * bloomIntensity;
    float3 outColor = hdrColor + bloomColor;
    outColor = edrRollOff(outColor, edrHeadroom);

    outputTexture.write(float4(outColor, 1.0), gid);
}
