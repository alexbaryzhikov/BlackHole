#import "Renderer.h"
#import "BloomTypes.h"
#import "CompositeTonemapTypes.h"
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
    id<MTLComputePipelineState> bloomDownsampleState;
    id<MTLComputePipelineState> bloomUpsampleState;
    id<MTLComputePipelineState> compositeTonemapState;
    id<MTLTexture> skyboxTexture;
    id<MTLTexture> densityTexture;
    id<MTLTexture> mainHDRTexture;
    NSMutableArray<id<MTLTexture>>* bloomTextures;
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
        [self createTextures];
        [self createBuffers];
        [self initializeParticles];

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
    id<MTLFunction> splatVertexFunction = [defaultLibrary newFunctionWithName:@"splatParticlesVertex"];
    id<MTLFunction> splatFragmentFunction = [defaultLibrary newFunctionWithName:@"splatParticlesFragment"];
    id<MTLFunction> marchRaysFunction = [defaultLibrary newFunctionWithName:@"marchRays"];
    id<MTLFunction> bloomDownsampleFunction = [defaultLibrary newFunctionWithName:@"bloomDownsample"];
    id<MTLFunction> bloomUpsampleFunction = [defaultLibrary newFunctionWithName:@"bloomUpsample"];
    id<MTLFunction> compositeTonemapFunction = [defaultLibrary newFunctionWithName:@"compositeTonemap"];

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

    error = nil;
    bloomDownsampleState = [device newComputePipelineStateWithFunction:bloomDownsampleFunction error:&error];
    if (!bloomDownsampleState) {
        NSLog(@"Failed to create bloomDownsampleState: %@", error);
    }

    error = nil;
    bloomUpsampleState = [device newComputePipelineStateWithFunction:bloomUpsampleFunction error:&error];
    if (!bloomUpsampleState) {
        NSLog(@"Failed to create bloomUpsampleState: %@", error);
    }

    error = nil;
    compositeTonemapState = [device newComputePipelineStateWithFunction:compositeTonemapFunction error:&error];
    if (!compositeTonemapState) {
        NSLog(@"Failed to create compositeTonemapState: %@", error);
    }
}

- (void)createTextures {
    [self loadSkybox];
    [self createParticleDensityTexture];
    [self createMainHDRTexture];
    [self createBloomTextures];
}

- (void)loadSkybox {
    TextureLoader* loader = [[TextureLoader alloc] initWithDevice:device];
    NSURL* url = [NSBundle.mainBundle URLForResource:@"nebula" withExtension:@"exr"];
    skyboxTexture = [loader loadEXR:url];
}

- (void)createParticleDensityTexture {
    MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR16Float
                                                                                    width:DENSITY_MAP_RESOLUTION
                                                                                   height:DENSITY_MAP_RESOLUTION
                                                                                mipmapped:NO];
    desc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    desc.storageMode = MTLStorageModePrivate;
    densityTexture = [device newTextureWithDescriptor:desc];
}

- (void)createMainHDRTexture {
    MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                                                                    width:MAIN_TEXTURE_WIDTH
                                                                                   height:MAIN_TEXTURE_HEIGHT
                                                                                mipmapped:NO];
    desc.usage = MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead;
    desc.storageMode = MTLStorageModePrivate;
    mainHDRTexture = [device newTextureWithDescriptor:desc];
}

- (void)createBloomTextures {
    bloomTextures = [NSMutableArray array];
    int width = MAIN_TEXTURE_WIDTH;
    int height = MAIN_TEXTURE_HEIGHT;
    for (NSInteger i = 0; i < 8; ++i) {
        MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                                                                        width:width
                                                                                       height:height
                                                                                    mipmapped:NO];
        desc.usage = MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead;
        desc.storageMode = MTLStorageModePrivate;
        [bloomTextures addObject:[device newTextureWithDescriptor:desc]];
        width = MAX(1, width / 2);
        height = MAX(1, height / 2);
    }
}

- (void)createBuffers {
    cameraBuffer = [device newBufferWithLength:sizeof(Camera) options:MTLResourceStorageModeShared];
    particleBuffer = [device newBufferWithLength:sizeof(GasParticle) * PARTICLE_COUNT options:MTLResourceStorageModeShared];
}

- (void)initializeParticles {
    const float densityFalloff = 1.5;

    GasParticle* particles = (GasParticle*)particleBuffer.contents;
    for (NSInteger i = 0; i < PARTICLE_COUNT; ++i) {
        float t = MAX((float)arc4random() / UINT32_MAX, 0.000001f);
        float radius = DISK_INNER_RADIUS - logf(t) * densityFalloff;
        if (radius > DISK_OUTER_RADIUS) radius = DISK_INNER_RADIUS;
        float angle = ((float)arc4random() / UINT32_MAX) * M_PI * 2.0;
        particles[i].radius = radius;
        particles[i].angle = angle;
        particles[i].position = simd_make_float2(cosf(angle) * radius, sinf(angle) * radius);
        particles[i].mass = ((float)arc4random() / UINT32_MAX) * 0.5f + 0.5f;
    }
}

- (void)drawInMTKView:(nonnull MTKView*)view {
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];

    [self updateUniforms:view];
    [self updateParticles:commandBuffer];
    [self splatParticles:commandBuffer];
    [self marchRays:commandBuffer];
    [self bloomDownsample:commandBuffer];
    [self bloomUpsample:commandBuffer];
    [self compositeTonemap:view commandBuffer:commandBuffer];

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

    MTLSize threadsPerGrid = MTLSizeMake(PARTICLE_COUNT, 1, 1);
    NSUInteger threadGroupSize = MIN(updateParticlesState.maxTotalThreadsPerThreadgroup, PARTICLE_COUNT);
    MTLSize threadsPerGroup = MTLSizeMake(threadGroupSize, 1, 1);

    [commandEncoder dispatchThreads:threadsPerGrid threadsPerThreadgroup:threadsPerGroup];
    [commandEncoder endEncoding];
}

- (void)splatParticles:(id<MTLCommandBuffer>)commandBuffer {
    MTLRenderPassDescriptor* descriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    descriptor.colorAttachments[0].texture = densityTexture;
    descriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    descriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

    id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [commandEncoder setRenderPipelineState:splatParticlesState];
    [commandEncoder setVertexBuffer:particleBuffer offset:0 atIndex:ParticleSplattingBufferIndexParticles];

    [commandEncoder drawPrimitives:MTLPrimitiveTypePoint vertexStart:0 vertexCount:PARTICLE_COUNT];
    [commandEncoder endEncoding];
}

- (void)marchRays:(id<MTLCommandBuffer>)commandBuffer {
    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    [commandEncoder setComputePipelineState:rayMarchingState];
    [commandEncoder setTexture:mainHDRTexture atIndex:RayMarchingTextureIndexOutput];
    [commandEncoder setTexture:skyboxTexture atIndex:RayMarchingTextureIndexSkybox];
    [commandEncoder setTexture:densityTexture atIndex:RayMarchingTextureIndexDensity];
    [commandEncoder setBuffer:cameraBuffer offset:0 atIndex:RayMarchingBufferIndexCamera];

    MTLSize threadsPerGrid = MTLSizeMake(mainHDRTexture.width, mainHDRTexture.height, 1);
    MTLSize threadsPerGroup = [self getThreadsPerGroup:rayMarchingState];

    [commandEncoder dispatchThreads:threadsPerGrid threadsPerThreadgroup:threadsPerGroup];
    [commandEncoder endEncoding];
}

- (void)bloomDownsample:(id<MTLCommandBuffer>)commandBuffer {
    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    [commandEncoder setComputePipelineState:bloomDownsampleState];

    id<MTLTexture> inputTexture = mainHDRTexture;
    for (NSInteger i = 0; i < bloomTextures.count; ++i) {
        id<MTLTexture> outputTexture = bloomTextures[i];

        [commandEncoder setTexture:outputTexture atIndex:BloomTextureIndexOutput];
        [commandEncoder setTexture:inputTexture atIndex:BloomTextureIndexInput];

        MTLSize threadsPerGrid = MTLSizeMake(outputTexture.width, outputTexture.height, 1);
        MTLSize threadsPerGroup = [self getThreadsPerGroup:bloomDownsampleState];

        [commandEncoder dispatchThreads:threadsPerGrid threadsPerThreadgroup:threadsPerGroup];

        inputTexture = outputTexture;
    }

    [commandEncoder endEncoding];
}

- (void)bloomUpsample:(id<MTLCommandBuffer>)commandBuffer {
    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    [commandEncoder setComputePipelineState:bloomUpsampleState];

    for (NSInteger i = bloomTextures.count - 1; i > 0; --i) {
        id<MTLTexture> inputTexture = bloomTextures[i];
        id<MTLTexture> mipTexture = bloomTextures[i - 1];

        [commandEncoder setTexture:mipTexture atIndex:BloomTextureIndexOutput];
        [commandEncoder setTexture:inputTexture atIndex:BloomTextureIndexInput];
        [commandEncoder setTexture:mipTexture atIndex:BloomTextureIndexMip];

        MTLSize threadsPerGrid = MTLSizeMake(mipTexture.width, mipTexture.height, 1);
        MTLSize threadsPerGroup = [self getThreadsPerGroup:bloomUpsampleState];

        [commandEncoder dispatchThreads:threadsPerGrid threadsPerThreadgroup:threadsPerGroup];
    }

    [commandEncoder endEncoding];
}

- (void)compositeTonemap:(MTKView*)view commandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    id<CAMetalDrawable> drawable = view.currentDrawable;

    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    [commandEncoder setComputePipelineState:compositeTonemapState];
    [commandEncoder setTexture:drawable.texture atIndex:CompositeTonemapTextureIndexOutput];
    [commandEncoder setTexture:mainHDRTexture atIndex:CompositeTonemapTextureIndexHDR];
    [commandEncoder setTexture:bloomTextures[0] atIndex:CompositeTonemapTextureIndexBloom];
    [commandEncoder setBytes:&edrHeadroom length:sizeof(float) atIndex:CompositeTonemapBufferIndexEDRHeadroom];

    MTLSize compositeGrid = MTLSizeMake(drawable.texture.width, drawable.texture.height, 1);
    MTLSize compositeGroup = [self getThreadsPerGroup:compositeTonemapState];
    [commandEncoder dispatchThreads:compositeGrid threadsPerThreadgroup:compositeGroup];

    [commandEncoder endEncoding];
    [commandBuffer presentDrawable:drawable];
}

- (MTLSize)getThreadsPerGroup:(id<MTLComputePipelineState>)state {
    NSUInteger width = state.threadExecutionWidth;
    NSUInteger height = state.maxTotalThreadsPerThreadgroup / width;
    return MTLSizeMake(width, height, 1);
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {
}

@end
