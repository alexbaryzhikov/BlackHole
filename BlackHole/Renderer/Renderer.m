#import "Renderer.h"
#import "Config.h"
#import "ModelBridge.h"
#import "ParticleTypes.h"
#import "RayMarchingTypes.h"
#import "TextureLoader.h"
#import <QuartzCore/QuartzCore.h>

@implementation Renderer {
    id<MTLDevice> device;
    id<MTLCommandQueue> commandQueue;
    id<MTLComputePipelineState> updateParticlesState;
    id<MTLRenderPipelineState> splatParticlesState;
    id<MTLComputePipelineState> rayMarchingState;
    id<MTLTexture> textures[TEXTURE_HEAP_SIZE];
    id<MTLBuffer> cameraBuffer;
    id<MTLBuffer> particleBuffer;

    float edrHeadroom;
    double timeStart;
    float time;
    float deltaTime;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)view {
    self = [super init];
    if (self) {
        device = view.device;
        [self setupView:view];
        [self setupMetalPipeline:view];
        [self createBuffers];
        [self initializeParticles];
        [self loadSkybox];
        [self setupParticleDensityTexture];

        edrHeadroom = 1.0;
        timeStart = CACurrentMediaTime();
        time = 0.0;
        deltaTime = 0.0;
    }
    return self;
}

- (void)setupView:(nonnull MTKView*)view {
    view.framebufferOnly = NO;
    view.colorPixelFormat = MTLPixelFormatRGBA16Float;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceExtendedLinearDisplayP3);
    view.colorspace = colorSpace;
    CGColorSpaceRelease(colorSpace);
    view.layer.preferredDynamicRange = CADynamicRangeHigh;
}

- (void)setupMetalPipeline:(nonnull MTKView*)view {
    commandQueue = [device newCommandQueue];

    id<MTLLibrary> defaultLibrary = [device newDefaultLibrary];
    id<MTLFunction> updateParticlesFunction = [defaultLibrary newFunctionWithName:@"updateParticles"];
    id<MTLFunction> splatVertexFunction = [defaultLibrary newFunctionWithName:@"splatVertex"];
    id<MTLFunction> splatFragmentFunction = [defaultLibrary newFunctionWithName:@"splatFragment"];
    id<MTLFunction> marchRaysFunction = [defaultLibrary newFunctionWithName:@"marchRays"];

    NSError* error = nil;
    updateParticlesState = [device newComputePipelineStateWithFunction:updateParticlesFunction error:&error];
    if (!updateParticlesState) {
        NSLog(@"Failed to create updateParticlesState: %@", error);
    }

    MTLRenderPipelineDescriptor* splatDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    splatDescriptor.vertexFunction = splatVertexFunction;
    splatDescriptor.fragmentFunction = splatFragmentFunction;
    splatDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatR16Float;
    splatDescriptor.colorAttachments[0].blendingEnabled = YES;
    splatDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
    splatDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
    error = nil;
    splatParticlesState = [device newRenderPipelineStateWithDescriptor:splatDescriptor error:&error];
    if (!splatParticlesState) {
        NSLog(@"Failed to create splatParticlesState: %@", error);
    }

    error = nil;
    rayMarchingState = [device newComputePipelineStateWithFunction:marchRaysFunction error:&error];
    if (!rayMarchingState) {
        NSLog(@"Failed to create rayMarchingState: %@", error);
    }
}

- (void)createBuffers {
    cameraBuffer = [device newBufferWithLength:sizeof(Camera) options:MTLResourceStorageModeShared];
    particleBuffer = [device newBufferWithLength:sizeof(GasParticle) * PARTICLE_COUNT options:MTLResourceStorageModeShared];
}

- (void)initializeParticles {
    GasParticle* particles = (GasParticle*)particleBuffer.contents;
    for (NSUInteger i = 0; i < PARTICLE_COUNT; i++) {
        float t = (float)arc4random() / UINT32_MAX;
        float radius = DISK_INNER_RADIUS + t * t * (DISK_OUTER_RADIUS - DISK_INNER_RADIUS);
        float angle = ((float)arc4random() / UINT32_MAX) * M_PI * 2.0;
        particles[i].radius = radius;
        particles[i].angle = angle;
        particles[i].position = simd_make_float2(cosf(angle) * radius, sinf(angle) * radius);
        particles[i].mass = ((float)arc4random() / UINT32_MAX) * 0.5f + 0.2f;
    }
}

- (void)loadSkybox {
    TextureLoader* loader = [[TextureLoader alloc] initWithDevice:device];
    NSURL* url = [NSBundle.mainBundle URLForResource:@"nebula" withExtension:@"exr"];
    textures[TextureHeapIndexSkybox] = [loader loadEXR:url];
}

- (void)setupParticleDensityTexture {
    MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR16Float
                                                                                    width:SPLAT_TEXTURE_RESOLUTION
                                                                                   height:SPLAT_TEXTURE_RESOLUTION
                                                                                mipmapped:NO];
    desc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    desc.storageMode = MTLStorageModePrivate;
    textures[TextureHeapIndexParticleDensity] = [device newTextureWithDescriptor:desc];
}

- (void)drawInMTKView:(nonnull MTKView*)view {
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];

    [self updateUniforms:view];
    [self updateParticles:commandBuffer];
    [self splatParticles:view commandBuffer:commandBuffer];
    [self marchRays:view commandBuffer:commandBuffer];

    [commandBuffer commit];
}

- (void)updateUniforms:(nonnull MTKView*)view {
    [ModelBridge updateModel];
    [ModelBridge copyCamera:cameraBuffer.contents];
    [self updateEDRHeadroom:view];
    [self updateTime];
}

- (void)updateEDRHeadroom:(nonnull MTKView*)view {
    NSScreen* screen = view.window.screen;
    if (screen) {
        edrHeadroom = MAX(screen.maximumPotentialExtendedDynamicRangeColorComponentValue, 1.0);
    }
}

- (void)updateTime {
    float lastTime = time;
    time = CACurrentMediaTime() - timeStart;
    deltaTime = time - lastTime;
}

- (void)updateParticles:(id<MTLCommandBuffer>)commandBuffer {
    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    [commandEncoder setComputePipelineState:updateParticlesState];
    [commandEncoder setBuffer:particleBuffer offset:0 atIndex:ParticleSimulationBufferIndexParticles];
    [commandEncoder setBytes:&deltaTime length:sizeof(float) atIndex:ParticleSimulationBufferIndexDeltaTime];

    NSUInteger threadGroupSize = MIN(updateParticlesState.maxTotalThreadsPerThreadgroup, PARTICLE_COUNT);
    MTLSize threadsPerGroup = MTLSizeMake(threadGroupSize, 1, 1);
    MTLSize threadsPerGrid = MTLSizeMake(PARTICLE_COUNT, 1, 1);

    [commandEncoder dispatchThreads:threadsPerGrid threadsPerThreadgroup:threadsPerGroup];
    [commandEncoder endEncoding];
}

- (void)splatParticles:(nonnull MTKView*)view commandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    MTLRenderPassDescriptor* descriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    descriptor.colorAttachments[0].texture = textures[TextureHeapIndexParticleDensity];
    descriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    descriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [commandEncoder setRenderPipelineState:splatParticlesState];
    [commandEncoder setVertexBuffer:particleBuffer offset:0 atIndex:ParticleSplattingBufferIndexParticles];
    [commandEncoder drawPrimitives:MTLPrimitiveTypePoint vertexStart:0 vertexCount:PARTICLE_COUNT];
    [commandEncoder endEncoding];
}

- (void)marchRays:(nonnull MTKView*)view commandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    id<CAMetalDrawable> drawable = view.currentDrawable;
    if (!drawable) return;

    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    [commandEncoder setComputePipelineState:rayMarchingState];
    [commandEncoder setTexture:drawable.texture atIndex:RayMarchingTextureIndexOutput];
    if (TEXTURE_HEAP_SIZE > 0) {
        [commandEncoder setTextures:textures withRange:NSMakeRange(RayMarchingTextureIndexHeap, TEXTURE_HEAP_SIZE)];
    }
    [commandEncoder setBuffer:cameraBuffer offset:0 atIndex:RayMarchingBufferIndexCamera];
    [commandEncoder setBytes:&edrHeadroom length:sizeof(float) atIndex:RayMarchingBufferIndexEDRHeadroom];

    NSUInteger width = rayMarchingState.threadExecutionWidth;
    NSUInteger height = rayMarchingState.maxTotalThreadsPerThreadgroup / width;
    MTLSize threadsPerGroup = MTLSizeMake(width, height, 1);
    MTLSize threadsPerGrid = MTLSizeMake(drawable.texture.width, drawable.texture.height, 1);
    [commandEncoder dispatchThreads:threadsPerGrid threadsPerThreadgroup:threadsPerGroup];

    [commandEncoder endEncoding];
    [commandBuffer presentDrawable:drawable];
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {
}

@end
