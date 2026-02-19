#import "Renderer.h"
#import "Config.h"
#import "ModelBridge.h"
#import "ShaderTypesShared.h"

@implementation Renderer {
    id<MTLDevice> device;
    id<MTLCommandQueue> commandQueue;
    id<MTLComputePipelineState> computePipelineState;

    id<MTLTexture> textures[TEXTURE_HEAP_SIZE];

    id<MTLBuffer> cameraBuffer;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)view {
    self = [super init];
    if (self) {
        device = view.device;
        [self setupView:view];
        [self setupMetalPipeline];
        [self createBuffers];
        [self loadTextures];
    }
    return self;
}

- (void)setupView:(nonnull MTKView*)view {
    view.framebufferOnly = NO;
    view.autoResizeDrawable = NO;
    view.drawableSize = CGSizeMake(VIEWPORT_WIDTH, VIEWPORT_HEIGHT);
    view.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    view.layer.magnificationFilter = kCAFilterNearest;
    view.layer.contentsGravity = kCAGravityResizeAspect;
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

- (void)loadTextures {
    MTKTextureLoader* loader = [[MTKTextureLoader alloc] initWithDevice:device];
    NSDictionary<MTKTextureLoaderOption, id>* options = @{
        MTKTextureLoaderOptionTextureUsage : @(MTLTextureUsageShaderRead),
        MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModePrivate),
    };
    textures[TextureHeapIndexSkybox] = [self loadTexture:@"milky_way" loader:loader options:options];
}

- (nullable id<MTLTexture>)loadTexture:(nonnull NSString*)name
                                loader:(MTKTextureLoader*)loader
                               options:(NSDictionary<MTKTextureLoaderOption, id>*)options {
    NSURL* url = [NSBundle.mainBundle URLForResource:name withExtension:@"png"];
    if (!url) {
        NSLog(@"Could not find file '%@.png' in main bundle", name);
        return nil;
    }
    NSError* error = nil;
    id<MTLTexture> texture = [loader newTextureWithContentsOfURL:url
                                                         options:options
                                                           error:&error];
    if (!texture || error) {
        NSLog(@"Error loading texture '%@.png': %@", name, error);
        return nil;
    }
    return texture;
}

- (void)drawInMTKView:(MTKView*)view {
    [self updateUniforms];

    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];

    id<CAMetalDrawable> drawable = view.currentDrawable;
    if (!drawable) {
        return;
    }

    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    [commandEncoder setComputePipelineState:computePipelineState];
    [commandEncoder setTexture:drawable.texture atIndex:TextureIndexOutput];
    if (TEXTURE_HEAP_SIZE > 0) {
        [commandEncoder setTextures:textures withRange:NSMakeRange(TextureIndexHeap, TEXTURE_HEAP_SIZE)];
    }
    [commandEncoder setBuffer:cameraBuffer offset:0 atIndex:BufferIndexCamera];

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

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {
}

@end
