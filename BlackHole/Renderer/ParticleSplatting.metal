#import "../Config.h"
#include "ParticleTypes.h"

struct SplatVertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float intensity;
};

constexpr constant float densityMapRadius = DISK_OUTER_RADIUS * 1.02;

vertex SplatVertexOut splatVertex(device const GasParticle* particles [[buffer(0)]],
                                  uint vid [[vertex_id]]) {
    GasParticle p = particles[vid];
    SplatVertexOut out;
    
    out.position = float4(p.position.xy / densityMapRadius, 0.0, 1.0);
    out.pointSize = p.mass * ((1.0 - p.radius / DISK_OUTER_RADIUS) * 0.6 + 0.4) * PARTICLE_SCALE;
    out.intensity = p.mass;
    
    return out;
}

fragment float4 splatFragment(SplatVertexOut in [[stage_in]],
                              float2 pointCoord [[point_coord]]){
    float2 worldCoord = (in.position.xy / SPLAT_TEXTURE_RESOLUTION * 2.0 - 1.0) * densityMapRadius;
    if (length(worldCoord) < DISK_INNER_RADIUS) discard_fragment();
    
    float2 uv = pointCoord * 2.0 - 1.0;
    float distSq = length_squared(uv);
    if (distSq > 1.0) discard_fragment();
    
    float intensity = in.intensity * exp(-distSq * PARTICLE_SOFTNESS) * PARTICLE_TRANSPARENCY;
    return float4(intensity, 0.0, 0.0, 1.0);
}
