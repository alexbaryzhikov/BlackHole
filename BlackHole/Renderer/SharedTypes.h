#ifdef __METAL_VERSION__

#include <metal_stdlib>
using namespace metal;

#else

#include <simd/simd.h>
typedef simd_float2 float2;
typedef simd_float3 float3;
typedef simd_float4 float4;

#endif /* __METAL_VERSION__ */
