#import <Metal/Metal.h>

@interface TextureLoader : NSObject

- (instancetype)initWithDevice:(id<MTLDevice>)device;
- (id<MTLTexture>)loadEXR:(NSURL*)url;

@end
