#import "ShaderTypesShared.h"

namespace BH::Camera {

extern simd::float4 position;
extern float yaw;
extern float pitch;
extern float exposure;

void mouseDidMove(float dx, float dy);

void update();

} // namespace BH::Camera
