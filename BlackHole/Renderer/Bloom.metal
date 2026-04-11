#import "BloomTypes.h"

constexpr sampler linearSampler(coord::normalized, filter::linear, address::clamp_to_edge);

// 13-Tap Downsample: Grabs a wide footprint to prevent bright pixels from flickering
kernel void bloomDownsample(texture2d<float, access::write> outputTexture [[texture(BloomTextureIndexOutput)]],
                            texture2d<float, access::sample> inputTexture [[texture(BloomTextureIndexInput)]],
                            uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) return;

    float2 texelSize = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());
    float2 uv = (float2(gid) + 0.5) / float2(outputTexture.get_width(), outputTexture.get_height());
    float x = texelSize.x;
    float y = texelSize.y;

    float3 a = inputTexture.sample(linearSampler, uv + float2(-2*x, 2*y)).rgb;
    float3 b = inputTexture.sample(linearSampler, uv + float2(0, 2*y)).rgb;
    float3 c = inputTexture.sample(linearSampler, uv + float2(2*x, 2*y)).rgb;
    float3 d = inputTexture.sample(linearSampler, uv + float2(-2*x, 0)).rgb;
    float3 e = inputTexture.sample(linearSampler, uv).rgb;
    float3 f = inputTexture.sample(linearSampler, uv + float2(2*x, 0)).rgb;
    float3 g = inputTexture.sample(linearSampler, uv + float2(-2*x, -2*y)).rgb;
    float3 h = inputTexture.sample(linearSampler, uv + float2(0, -2*y)).rgb;
    float3 i = inputTexture.sample(linearSampler, uv + float2(2*x, -2*y)).rgb;
    float3 j = inputTexture.sample(linearSampler, uv + float2(-x, y)).rgb;
    float3 k = inputTexture.sample(linearSampler, uv + float2(x, y)).rgb;
    float3 l = inputTexture.sample(linearSampler, uv + float2(-x, -y)).rgb;
    float3 m = inputTexture.sample(linearSampler, uv + float2(x, -y)).rgb;

    float3 color = e * 0.125 + (a + c + g + i) * 0.03125 + (b + d + f + h) * 0.0625 + (j + k + l + m) * 0.125;
    outputTexture.write(float4(color, 1.0), gid);
}

// 9-Tap Upsample: Blends the blurred data with the current mip level
kernel void bloomUpsample(texture2d<float, access::write> outputTexture [[texture(BloomTextureIndexOutput)]],
                          texture2d<float, access::sample> inputTexture [[texture(BloomTextureIndexInput)]],
                          texture2d<float, access::read> mipTexture [[texture(BloomTextureIndexMip)]],
                          uint2 gid [[thread_position_in_grid]]) {
    // Radius controls the "spread" of the bloom. 1.0 is standard, 1.5 is cinematic and wide.
    constexpr float radius = 1.5;

    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) return;

    float2 texelSize = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());
    float2 uv = (float2(gid) + 0.5) / float2(outputTexture.get_width(), outputTexture.get_height());
    float x = texelSize.x * radius;
    float y = texelSize.y * radius;

    float3 a = inputTexture.sample(linearSampler, uv + float2(-x, y)).rgb;
    float3 b = inputTexture.sample(linearSampler, uv + float2(0, y)).rgb;
    float3 c = inputTexture.sample(linearSampler, uv + float2(x, y)).rgb;
    float3 d = inputTexture.sample(linearSampler, uv + float2(-x, 0)).rgb;
    float3 e = inputTexture.sample(linearSampler, uv).rgb;
    float3 f = inputTexture.sample(linearSampler, uv + float2(x, 0)).rgb;
    float3 g = inputTexture.sample(linearSampler, uv + float2(-x, -y)).rgb;
    float3 h = inputTexture.sample(linearSampler, uv + float2(0, -y)).rgb;
    float3 i = inputTexture.sample(linearSampler, uv + float2(x, -y)).rgb;

    float3 bloom = e * 0.25 + (b + d + f + h) * 0.125 + (a + c + g + i) * 0.0625;
    
    // Additive Blend: Combine the upsampled blur with the existing detail at this level
    float3 baseColor = mipTexture.read(gid).rgb;
    outputTexture.write(float4(baseColor + bloom, 1.0), gid);
}
