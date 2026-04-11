#import "../Config.h"
#include "ParticleTypes.h"

struct SplatVertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float intensity;
};

constexpr constant float densityMapRadius = DISK_OUTER_RADIUS * 1.02;

vertex SplatVertexOut splatParticlesVertex(device const GasParticle* particles [[buffer(0)]],
                                           uint vid [[vertex_id]]) {
    constexpr float particleScale = 30.0;
    constexpr float particleIntensity = 0.5;

    GasParticle p = particles[vid];
    SplatVertexOut out;
    out.position = float4(p.position.xy / densityMapRadius, 0.0, 1.0);
    out.pointSize = p.mass * particleScale * ((1.0 - p.radius / DISK_OUTER_RADIUS) * 0.8 + 0.2);
    out.intensity = p.mass * particleIntensity;
    return out;
}

fragment float4 splatParticlesFragment(SplatVertexOut in [[stage_in]],
                                       float2 pointCoord [[point_coord]]){
    constexpr float particleSoftness = 3.0;

    float2 worldCoord = (in.position.xy / DENSITY_MAP_RESOLUTION * 2.0 - 1.0) * densityMapRadius;
    if (length(worldCoord) < DISK_INNER_RADIUS) discard_fragment();
    
    float2 uv = pointCoord * 2.0 - 1.0;
    float distSq = length_squared(uv);
    if (distSq > 1.0) discard_fragment();
    
    float intensity = in.intensity * exp(-distSq * particleSoftness);
    return float4(intensity, 0.0, 0.0, 1.0);
}
