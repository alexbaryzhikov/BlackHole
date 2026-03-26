#import "SharedTypes.h"

#define TEXTURE_HEAP_SIZE 2

typedef enum {
    TextureHeapIndexSkybox,
    TextureHeapIndexParticleDensity
} TextureHeapIndex;

typedef enum {
    RayMarchingTextureIndexOutput,
    RayMarchingTextureIndexHeap,
} RayMarchingTextureIndex;

typedef enum {
    RayMarchingBufferIndexCamera,
    RayMarchingBufferIndexEDRHeadroom,
} RayMarchingBufferIndex;

typedef struct {
    float4 position;
    float yaw;
    float pitch;
    float exposure;
} Camera;
