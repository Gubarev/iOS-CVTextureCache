//
//  CVLCanvasView.m
//  CVTextureCacheMinification
//
//  Created by Vladislav Gubarev on 07/11/13.
//  Copyright (c) 2013 CVisionLab. All rights reserved.
//

#import "CVLCanvasView.h"
#import <Accelerate/Accelerate.h>



const static GLchar vShSrc[] = {
    #include "vertex.vsh_i"
    , 0x0
};

const static GLchar fShSrc[] = {
    #include "fragment.fsh_i"
    , 0x0
};


#define PXE_CHECK_GL_ERROR() do {\
    GLenum err = glGetError();\
    NSAssert(err == GL_NO_ERROR, @"OpenGL error: %0x", err); \
} while(0)



@implementation CVLCanvasView

{
    EAGLContext  *_context;
    vImage_Buffer _image;
    CGFloat       _scale;
    CGSize        _frameBufferSize;
    GLuint        _frameBuffer;
    GLuint        _renderBuffer;
    GLuint        _fSh; // fragment shader
    GLuint        _vSh; // vertex shader
    GLuint        _pipeline;
    GLint         _uniformTexture0Location;
}



+ (Class)layerClass {
    return [CAEAGLLayer class];
}



- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initializeOpenGL];
    }
    return self;
}



- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self loadImage];
        [self initializeOpenGL];
    }
    return self;
}



- (void)loadImage {
    // Open UI image.
    UIImage *image = [UIImage imageNamed:@"image.png"];
    
    // Preapre image buffer.
    _image.height   = image.size.height * image.scale;
    _image.width    = image.size.width  * image.scale;
    _image.rowBytes = image.size.width  * 4;
    _image.data = malloc(_image.rowBytes * _image.height);
    
    // Draw into image buffer.
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(_image.data,
                                                 _image.width,
                                                 _image.height,
                                                 8,
                                                 image.size.width * 4,
                                                 colorSpace,
                                                 kCGBitmapAlphaInfoMask &
                                                 kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    UIGraphicsPushContext(context);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    UIGraphicsPopContext();
    CGContextRelease(context);
}



- (void)initializeOpenGL {
    // Scale factor.
    {
        _scale = [[UIScreen mainScreen] scale];
        self.contentScaleFactor = _scale;
    }
    
    // Frame buffer size.
    {
        _frameBufferSize = CGSizeMake(_scale * self.bounds.size.width,
                                      _scale * self.bounds.size.height);
    }

    // EAGL.
    {
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        NSAssert(_context != nil, @"EAGL context is nil.");
        [EAGLContext setCurrentContext:_context];
        CAEAGLLayer* caeagllayer = (CAEAGLLayer *)self.layer;
        caeagllayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithBool:YES], kEAGLDrawablePropertyRetainedBacking,
                                          kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
    }
    
    // Frame buffer and render buffer.
    {
        glGenFramebuffers (1, &_frameBuffer);
        glGenRenderbuffers(1, &_renderBuffer);

        glBindFramebuffer (GL_FRAMEBUFFER,  _frameBuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    
        [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(id<EAGLDrawable>)self.layer];
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
        NSAssert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE,
                 @"Framebuffer is incomplete.");
        glClearColor(0, 0, 0, 0);
        glClear(GL_COLOR_BUFFER_BIT);
        PXE_CHECK_GL_ERROR();
    }
    
    // Misc.
    {
        glDisable(GL_CULL_FACE);
        glDisable(GL_DEPTH_TEST);
        glDisable(GL_STENCIL_TEST);
        glDisable(GL_SCISSOR_TEST);
        glDisable(GL_DITHER);
        glDisable(GL_BLEND);
        PXE_CHECK_GL_ERROR();
    }
    
    // Shaders, pipiline, coordinates and position.
    {
        [self initializeShadersAndPipeline];
        [[self class] prepareCoordinatesAndPosition];
    }
    
    // Load image.
    {
        [self loadImage];
    }
    
    [self switchToMode:1];
}



- (void)initializeShadersAndPipeline {
    // Vertex shader.
    {
        const GLchar *pSrc[] = {vShSrc};
        _vSh = glCreateShaderProgramvEXT(GL_VERTEX_SHADER, 1, pSrc);
        glProgramParameteriEXT(_vSh, GL_PROGRAM_SEPARABLE_EXT, GL_TRUE);
        PXE_CHECK_GL_ERROR();
    }
    
    // Fragment shader.
    {
        const GLchar *pSrc[] = {fShSrc};
        _fSh = glCreateShaderProgramvEXT(GL_FRAGMENT_SHADER, 1, pSrc);
        glProgramParameteriEXT(_fSh, GL_PROGRAM_SEPARABLE_EXT, GL_TRUE);
        _uniformTexture0Location = glGetUniformLocation(_fSh, "uniformTexture0");
        glProgramUniform1iEXT(_fSh, _uniformTexture0Location, 0);
        PXE_CHECK_GL_ERROR();
    }
    
    // Make pipeline, set shaders, enable attributes.
    {
        // Make pipeline.
        glGenProgramPipelinesEXT(1, &_pipeline);
        
        // Use shaders in pipeline.
        glUseProgramStagesEXT(_pipeline, GL_VERTEX_SHADER_BIT_EXT,   _vSh);
        glUseProgramStagesEXT(_pipeline, GL_FRAGMENT_SHADER_BIT_EXT, _fSh);
        
        // Bind pipeline.
        glBindProgramPipelineEXT(_pipeline);
        
        // Enable attributes.
        glEnableVertexAttribArray(0);
        glEnableVertexAttribArray(1);
        
        PXE_CHECK_GL_ERROR();
    }
}



- (void)display {
    glFinish();
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}



- (void)draw {
    CGFloat scaleCoef = 0.85;
    // Draw with parameters min:GL_NEAREST, mag:GL_NEAREST.
    {
        glViewport(0,
                   0,
                   _image.width  * scaleCoef,
                   _image.height * scaleCoef);
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        
        PXE_CHECK_GL_ERROR();
    }
    
    // Draw with parameters min:GL_LINEAR, mag:GL_NEAREST.
    {
        glViewport(_image.width * 1.1 * scaleCoef,
                   0,
                   _image.width  * scaleCoef,
                   _image.height * scaleCoef);
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        
        PXE_CHECK_GL_ERROR();
    }
}



- (void)renderInRegularMode {
    // Prepare texture.
    GLuint texture;
    {
        glActiveTexture(GL_TEXTURE0);
        glGenTextures(1, &texture);
        glBindTexture(GL_TEXTURE_2D, texture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     GL_RGBA,
                     _image.width,
                     _image.height,
                     0,
                     GL_RGBA,
                     GL_UNSIGNED_BYTE,
                     _image.data);
        PXE_CHECK_GL_ERROR();
    }
    
    // Draw.
    [self draw];
    
    // Clean.
    {
        glFinish();
        glBindTexture(GL_TEXTURE_2D, 0);
        glDeleteTextures(1, &texture);
    }
}



- (void)renderInCVTextureCacheMode:(NSUInteger)mode {
    // Prepare texture.
    CVOpenGLESTextureRef      _texture;
    CVOpenGLESTextureCacheRef _textureCache;
    CVPixelBufferRef          _pixelBuffer;
    {
        // Prepare attributes.
        CFDictionaryRef empty = CFDictionaryCreate(kCFAllocatorDefault,
                                                   NULL,
                                                   NULL,
                                                   0,
                                                   &kCFTypeDictionaryKeyCallBacks,
                                                   &kCFTypeDictionaryValueCallBacks);
        CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                                 1,
                                                                 &kCFTypeDictionaryKeyCallBacks,
                                                                 &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(attrs,
                             kCVPixelBufferIOSurfacePropertiesKey,
                             empty);
        CFRelease(empty);
        CVReturn err;
        
        // Create pixel buffer.
        if (mode == 2) {
            err = CVPixelBufferCreateWithBytes(
                                               kCFAllocatorDefault,
                                               _image.width,
                                               _image.height,
                                               kCVPixelFormatType_32BGRA,
                                               _image.data,
                                               _image.rowBytes,
                                               NULL,
                                               NULL,
                                               attrs,
                                               &_pixelBuffer);
        }
        else {
            NSAssert(mode == 1, @"Wrong mode.");
            err = CVPixelBufferCreate(kCFAllocatorDefault,
                                               _image.width,
                                               _image.height,
                                               kCVPixelFormatType_32BGRA,
                                               attrs,
                                      &_pixelBuffer);
        }
        
        // Create texture cache.
        err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault,
                                           NULL,
                                           [EAGLContext currentContext],
                                           NULL,
                                           &_textureCache);
        
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           _textureCache,
                                                           _pixelBuffer,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           GL_RGBA,
                                                           _image.width,
                                                           _image.height,
                                                           GL_RGBA,
                                                           GL_UNSIGNED_BYTE,
                                                           0,
                                                           &_texture);
        
        // Fill texture.
        if (mode == 1) {
            // Flush and lock.
            CVOpenGLESTextureCacheFlush(_textureCache, 0);
            CVPixelBufferLockBaseAddress(_pixelBuffer, 0);
            
            // Copy memory.
            void* buf = CVPixelBufferGetBaseAddress(_pixelBuffer);
            size_t rowBytes = CVPixelBufferGetBytesPerRow(_pixelBuffer);
            for (size_t y = 0; y < _image.height; y++) {
                memcpy((unsigned char*)buf         + y * rowBytes,
                       (unsigned char*)_image.data + y * _image.rowBytes,
                       _image.width * 4);
            }
            
            // Unlock and flush.
            CVPixelBufferUnlockBaseAddress(_pixelBuffer, 0);
            CVOpenGLESTextureCacheFlush(_textureCache, 0);
        }
        
        // Set the texture up.
        glBindTexture(CVOpenGLESTextureGetTarget(_texture),
                      CVOpenGLESTextureGetName(_texture));
    }
    
    // Draw.
    [self draw];
    
    // Clean.
    {
        glFinish();
        glBindTexture(GL_TEXTURE_2D, 0);
        
        CVOpenGLESTextureCacheFlush(_textureCache, 0);
        CFRelease(_texture);
        CFRelease(_textureCache);
        CVPixelBufferRelease(_pixelBuffer);
    }
}



+ (void)prepareCoordinatesAndPosition {
    static GLfloat coords[] = {
        0, 1,
        1, 1,
        0, 0,
        1, 0
    };
    glVertexAttribPointer(1, 2, GL_FLOAT, 0, 2 * sizeof(GLfloat), coords);
    
    static GLfloat position[] = {
       -1,  1,
        1,  1,
       -1, -1,
        1, -1
    };
    glVertexAttribPointer(0, 2, GL_FLOAT, 0, 2 * sizeof(GLfloat), position);
}



- (void)switchToMode:(NSUInteger)mode {
    // Prepare frame buffer.
    glBindFramebuffer(GL_FRAMEBUFFER,  _frameBuffer);
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // Render in specified mode.
    if (mode == 0)
        [self renderInRegularMode];
    else
        [self renderInCVTextureCacheMode:mode];
    
    // Present results.
    [self display];
}



- (void)dealloc {
    // Image data.
    free(_image.data);
    
    // Pipeline.
    glBindProgramPipelineEXT(0);
    glDeleteProgramPipelinesEXT(1, &_pipeline);
    
    // Shaders.
    glDeleteProgram(_vSh);
    glDeleteProgram(_fSh);
}

@end
