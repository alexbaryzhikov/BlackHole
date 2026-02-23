#import "TextureLoader.h"
#import <ImageIO/ImageIO.h>

@implementation TextureLoader {
    id<MTLDevice> device;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        self->device = device;
    }
    return self;
}

- (id<MTLTexture>)loadEXR:(NSURL*)url {
    CGImageSourceRef imageSource = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    if (!imageSource) {
        NSLog(@"Failed to load EXR image source from URL.");
        return nil;
    }

    NSDictionary* options = @{
        (__bridge NSString*)kCGImageSourceShouldCache : @YES,
        (__bridge NSString*)kCGImageSourceShouldAllowFloat : @YES
    };
    CGImageRef cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, (__bridge CFDictionaryRef)options);
    CFRelease(imageSource);
    if (!cgImage) {
        NSLog(@"Failed to create CGImage from EXR.");
        return nil;
    }

    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    size_t bitsPerComponent = CGImageGetBitsPerComponent(cgImage);
    size_t bytesPerRow = CGImageGetBytesPerRow(cgImage);

    MTLPixelFormat pixelFormat;
    if (bitsPerComponent == 16) {
        pixelFormat = MTLPixelFormatRGBA16Float;
        NSLog(@"EXR loaded as 16-bit half-floats.");
    } else if (bitsPerComponent == 32) {
        pixelFormat = MTLPixelFormatRGBA32Float;
        NSLog(@"EXR loaded as 32-bit floats.");
    } else {
        NSLog(@"Unsupported EXR bit depth: %zu", bitsPerComponent);
        CGImageRelease(cgImage);
        return nil;
    }

    CGDataProviderRef dataProvider = CGImageGetDataProvider(cgImage);
    CFDataRef rawData = CGDataProviderCopyData(dataProvider);
    if (!rawData) {
        NSLog(@"Failed to extract raw data from CGImage.");
        CGImageRelease(cgImage);
        return nil;
    }

    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:pixelFormat
                                                                                          width:width
                                                                                         height:height
                                                                                      mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead;
    descriptor.storageMode = MTLStorageModeShared;
    id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
    if (!texture) {
        NSLog(@"Failed to create MTLTexture.");
        CFRelease(rawData);
        CGImageRelease(cgImage);
        return nil;
    }

    MTLRegion region = MTLRegionMake2D(0, 0, width, height);
    [texture replaceRegion:region mipmapLevel:0 withBytes:CFDataGetBytePtr(rawData) bytesPerRow:bytesPerRow];

    CFRelease(rawData);
    CGImageRelease(cgImage);

    return texture;
}

@end
