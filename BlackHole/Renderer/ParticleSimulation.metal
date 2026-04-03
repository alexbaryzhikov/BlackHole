#import "../Config.h"
#include "ParticleTypes.h"

kernel void updateParticles(device GasParticle* particles [[buffer(ParticleSimulationBufferIndexParticles)]],
                            constant float& deltaTime [[buffer(ParticleSimulationBufferIndexDeltaTime)]],
                            uint id [[thread_position_in_grid]]) {
    constexpr float rotationSpeed = 5.0;

    GasParticle p = particles[id];
    float angularVelocity = -rotationSpeed / sqrt(p.radius * p.radius * p.radius);
    p.angle += angularVelocity * deltaTime;
    p.position.x = cos(p.angle) * p.radius;
    p.position.y = sin(p.angle) * p.radius;
    particles[id] = p;
}
