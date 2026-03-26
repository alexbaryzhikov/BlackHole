#import "SharedTypes.h"

typedef enum {
    ParticleSimulationBufferIndexParticles,
    ParticleSimulationBufferIndexDeltaTime,
} ParticleSimulationBufferIndex;

typedef enum {
    ParticleSplattingBufferIndexParticles,
} ParticleSplattingBufferIndex;

typedef struct {
    float2 position;
    float mass;
    float radius;
    float angle;
} GasParticle;
