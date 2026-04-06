#import "SharedTypes.h"

typedef enum {
    RayMarchingTextureIndexOutput,
    RayMarchingTextureIndexSkybox,
    RayMarchingTextureIndexDensity,
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
