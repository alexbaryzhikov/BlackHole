#import "Renderer.h"
#import "Config.h"
#import "ModelBridge.h"
#import "ShaderTypesShared.h"
#import "TextureLoader.h"

@implementation Renderer {
    __weak MTKView* mtkView;
    id<MTLDevice> device;
    id<MTLCommandQueue> commandQueue;
    id<MTLComputePipelineState> computePipelineState;
    id<MTLTexture> textures[TEXTURE_HEAP_SIZE];
    id<MTLBuffer> cameraBuffer;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)view {
    self = [super init];
    if (self) {
        mtkView = view;
        device = view.device;
        [self setupView:view];
        [self setupMetalPipeline];
        [self createBuffers];
        [self loadSkybox];
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

- (void)setupMetalPipeline {
    commandQueue = [device newCommandQueue];

    id<MTLLibrary> defaultLibrary = [device newDefaultLibrary];
    id<MTLFunction> kernelFunction = [defaultLibrary newFunctionWithName:@"render"];

    NSError* error = nil;
    computePipelineState = [device newComputePipelineStateWithFunction:kernelFunction error:&error];
    if (!computePipelineState) {
        NSLog(@"Failed to create compute pipeline state: %@", error);
    }
}

- (void)createBuffers {
    cameraBuffer = [device newBufferWithLength:sizeof(Camera) options:MTLResourceStorageModeShared];
}

- (void)loadSkybox {
    TextureLoader* loader = [[TextureLoader alloc] initWithDevice:device];
    NSURL* url = [NSBundle.mainBundle URLForResource:@"nebula" withExtension:@"exr"];
    textures[TextureHeapIndexSkybox] = [loader loadEXR:url];
}

- (void)loadTextures {
    MTKTextureLoader* loader = [[MTKTextureLoader alloc] initWithDevice:device];
    NSDictionary<MTKTextureLoaderOption, id>* options = @{
        MTKTextureLoaderOptionTextureUsage : @(MTLTextureUsageShaderRead),
        MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModePrivate),
    };
    textures[TextureHeapIndexSkybox] = [self loadTexture:@"nebula" extension:@"exr" loader:loader options:options];
}

- (nullable id<MTLTexture>)loadTexture:(nonnull NSString*)name
                             extension:(nonnull NSString*)extension
                                loader:(MTKTextureLoader*)loader
                               options:(NSDictionary<MTKTextureLoaderOption, id>*)options {
    NSURL* url = [NSBundle.mainBundle URLForResource:name withExtension:extension];
    if (!url) {
        NSLog(@"Could not find file '%@.%@' in main bundle", name, extension);
        return nil;
    }
    NSError* error = nil;
    id<MTLTexture> texture = [loader newTextureWithContentsOfURL:url
                                                         options:options
                                                           error:&error];
    if (!texture || error) {
        NSLog(@"Error loading texture '%@.%@': %@", name, extension, error);
        return nil;
    }
    return texture;
}

- (void)drawInMTKView:(MTKView*)view {
    [self updateUniforms];
    float edrHeadroom = [self getEDRHeadroom];
    id<CAMetalDrawable> drawable = view.currentDrawable;
    if (!drawable) {
        return;
    }

    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    [commandEncoder setComputePipelineState:computePipelineState];
    [commandEncoder setTexture:drawable.texture atIndex:TextureIndexOutput];
    if (TEXTURE_HEAP_SIZE > 0) {
        [commandEncoder setTextures:textures withRange:NSMakeRange(TextureIndexHeap, TEXTURE_HEAP_SIZE)];
    }
    [commandEncoder setBuffer:cameraBuffer offset:0 atIndex:BufferIndexCamera];
    [commandEncoder setBytes:&edrHeadroom length:sizeof(float) atIndex:BufferIndexEDRHeadroom];

    NSUInteger width = computePipelineState.threadExecutionWidth;
    NSUInteger height = computePipelineState.maxTotalThreadsPerThreadgroup / width;
    MTLSize threadsPerThreadgroup = MTLSizeMake(width, height, 1);
    MTLSize threadsPerGrid = MTLSizeMake(drawable.texture.width, drawable.texture.height, 1);
    [commandEncoder dispatchThreads:threadsPerGrid threadsPerThreadgroup:threadsPerThreadgroup];

    [commandEncoder endEncoding];
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

- (void)updateUniforms {
    [ModelBridge copyCamera:cameraBuffer.contents];
}

- (float)getEDRHeadroom {
    float headroom = 1.0f;
    NSScreen* screen = mtkView.window.screen;
    if (screen) {
        headroom = screen.maximumPotentialExtendedDynamicRangeColorComponentValue;
    }
    return MAX(1.0f, headroom);
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {
}

@end
