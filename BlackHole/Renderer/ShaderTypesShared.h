#ifndef __METAL_VERSION__

#include <simd/simd.h>
typedef simd_float4 float4;

#endif /* __METAL_VERSION__ */

#define TEXTURE_HEAP_SIZE 1

typedef enum {
    TextureHeapIndexSkybox,
} TextureHeapIndex;

typedef enum {
    TextureIndexOutput,
    TextureIndexHeap,
} TextureIndex;

typedef enum {
    BufferIndexCamera,
    BufferIndexEDRHeadroom,
    BufferIndexTime,
} BufferIndex;

typedef struct {
    float4 position;
    float yaw;
    float pitch;
    float exposure;
} Camera;
