#import "GPUImageChromaKeyBlendFilter.h"

// Shader code based on Apple's CIChromaKeyFilter example: https://developer.apple.com/library/mac/#samplecode/CIChromaKeyFilter/Introduction/Intro.html

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kGPUImageChromaKeyBlendFragmentShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 uniform mat4 transformMatrix;
 uniform mat4 orthographicMatrix;
 
 precision highp float;
 
 varying highp vec2 textureCoordinate;
 varying highp vec2 textureCoordinate2;

 uniform float thresholdSensitivity;
 uniform float smoothing;
 uniform vec3 colorToReplace;
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 
 void main()
 {
     vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
     vec4 textureColor2 = texture2D(inputImageTexture2, textureCoordinate2);
     
     float maskY = 0.2989 * colorToReplace.r + 0.5866 * colorToReplace.g + 0.1145 * colorToReplace.b;
     float maskCr = 0.7132 * (colorToReplace.r - maskY);
     float maskCb = 0.5647 * (colorToReplace.b - maskY);
     
     float Y = 0.2989 * textureColor.r + 0.5866 * textureColor.g + 0.1145 * textureColor.b;
     float Cr = 0.7132 * (textureColor.r - Y);
     float Cb = 0.5647 * (textureColor.b - Y);
     
//     float blendValue = 1.0 - smoothstep(thresholdSensitivity - smoothing, thresholdSensitivity , abs(Cr - maskCr) + abs(Cb - maskCb));
     float blendValue = 1.0 - smoothstep(thresholdSensitivity, thresholdSensitivity + smoothing, distance(vec2(Cr, Cb), vec2(maskCr, maskCb)));
     gl_FragColor = mix(textureColor, textureColor2, blendValue);

     gl_Position = transformMatrix * vec4(position.xyz, 1.0) * orthographicMatrix;
     textureCoordinate = inputTextureCoordinate.xy;
 }
);
#else
NSString *const kGPUImageChromaKeyBlendFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 varying vec2 textureCoordinate2;
 
 uniform float thresholdSensitivity;
 uniform float smoothing;
 uniform vec3 colorToReplace;
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 
 void main()
 {
     vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
     vec4 textureColor2 = texture2D(inputImageTexture2, textureCoordinate2);
     
     float maskY = 0.2989 * colorToReplace.r + 0.5866 * colorToReplace.g + 0.1145 * colorToReplace.b;
     float maskCr = 0.7132 * (colorToReplace.r - maskY);
     float maskCb = 0.5647 * (colorToReplace.b - maskY);
     
     float Y = 0.2989 * textureColor.r + 0.5866 * textureColor.g + 0.1145 * textureColor.b;
     float Cr = 0.7132 * (textureColor.r - Y);
     float Cb = 0.5647 * (textureColor.b - Y);
     
     //     float blendValue = 1.0 - smoothstep(thresholdSensitivity - smoothing, thresholdSensitivity , abs(Cr - maskCr) + abs(Cb - maskCb));
     float blendValue = 1.0 - smoothstep(thresholdSensitivity, thresholdSensitivity + smoothing, distance(vec2(Cr, Cb), vec2(maskCr, maskCb)));
     gl_FragColor = mix(textureColor, textureColor2, blendValue);
 }
);
#endif

@implementation GPUImageChromaKeyBlendFilter

@synthesize thresholdSensitivity = _thresholdSensitivity;
@synthesize smoothing = _smoothing;

@synthesize affineTransform;
@synthesize transform3D = _transform3D;
@synthesize ignoreAspectRatio = _ignoreAspectRatio;
@synthesize anchorTopLeft = _anchorTopLeft;

- (id)init;
{
    if (!(self = [super initWithFragmentShaderFromString:kGPUImageChromaKeyBlendFragmentShaderString]))
    {
		return nil;
    }
    
    thresholdSensitivityUniform = [filterProgram uniformIndex:@"thresholdSensitivity"];
    smoothingUniform = [filterProgram uniformIndex:@"smoothing"];
    colorToReplaceUniform = [filterProgram uniformIndex:@"colorToReplace"];
    
    self.thresholdSensitivity = 0.4;
    self.smoothing = 0.1;
    [self setColorToReplaceRed:0.0 green:1.0 blue:0.0];
    
    transformMatrixUniform = [filterProgram uniformIndex:@"transformMatrix"];
    orthographicMatrixUniform = [filterProgram uniformIndex:@"orthographicMatrix"];
    
    self.transform3D = CATransform3DIdentity;
    
    return self;
}

#pragma mark -
#pragma mark Conversion from matrix formats

- (void)loadOrthoMatrix:(GLfloat *)matrix left:(GLfloat)left right:(GLfloat)right bottom:(GLfloat)bottom top:(GLfloat)top near:(GLfloat)near far:(GLfloat)far;
{
    GLfloat r_l = right - left;
    GLfloat t_b = top - bottom;
    GLfloat f_n = far - near;
    GLfloat tx = - (right + left) / (right - left);
    GLfloat ty = - (top + bottom) / (top - bottom);
    GLfloat tz = - (far + near) / (far - near);
    
    float scale = 2.0f;
    if (_anchorTopLeft)
    {
        scale = 4.0f;
        tx=-1.0f;
        ty=-1.0f;
    }
    
    matrix[0] = scale / r_l;
    matrix[1] = 0.0f;
    matrix[2] = 0.0f;
    matrix[3] = tx;
    
    matrix[4] = 0.0f;
    matrix[5] = scale / t_b;
    matrix[6] = 0.0f;
    matrix[7] = ty;
    
    matrix[8] = 0.0f;
    matrix[9] = 0.0f;
    matrix[10] = scale / f_n;
    matrix[11] = tz;
    
    matrix[12] = 0.0f;
    matrix[13] = 0.0f;
    matrix[14] = 0.0f;
    matrix[15] = 1.0f;
}

//- (void)convert3DTransform:(CATransform3D *)transform3D toMatrix:(GLfloat *)matrix;
//{
//	//	struct CATransform3D
//	//	{
//	//		CGFloat m11, m12, m13, m14;
//	//		CGFloat m21, m22, m23, m24;
//	//		CGFloat m31, m32, m33, m34;
//	//		CGFloat m41, m42, m43, m44;
//	//	};
//
//	matrix[0] = (GLfloat)transform3D->m11;
//	matrix[1] = (GLfloat)transform3D->m12;
//	matrix[2] = (GLfloat)transform3D->m13;
//	matrix[3] = (GLfloat)transform3D->m14;
//	matrix[4] = (GLfloat)transform3D->m21;
//	matrix[5] = (GLfloat)transform3D->m22;
//	matrix[6] = (GLfloat)transform3D->m23;
//	matrix[7] = (GLfloat)transform3D->m24;
//	matrix[8] = (GLfloat)transform3D->m31;
//	matrix[9] = (GLfloat)transform3D->m32;
//	matrix[10] = (GLfloat)transform3D->m33;
//	matrix[11] = (GLfloat)transform3D->m34;
//	matrix[12] = (GLfloat)transform3D->m41;
//	matrix[13] = (GLfloat)transform3D->m42;
//	matrix[14] = (GLfloat)transform3D->m43;
//	matrix[15] = (GLfloat)transform3D->m44;
//}

- (void)convert3DTransform:(CATransform3D *)transform3D toMatrix:(GPUMatrix4x4 *)matrix;
{
    //	struct CATransform3D
    //	{
    //		CGFloat m11, m12, m13, m14;
    //		CGFloat m21, m22, m23, m24;
    //		CGFloat m31, m32, m33, m34;
    //		CGFloat m41, m42, m43, m44;
    //	};
    
    GLfloat *mappedMatrix = (GLfloat *)matrix;
    
    mappedMatrix[0] = (GLfloat)transform3D->m11;
    mappedMatrix[1] = (GLfloat)transform3D->m12;
    mappedMatrix[2] = (GLfloat)transform3D->m13;
    mappedMatrix[3] = (GLfloat)transform3D->m14;
    mappedMatrix[4] = (GLfloat)transform3D->m21;
    mappedMatrix[5] = (GLfloat)transform3D->m22;
    mappedMatrix[6] = (GLfloat)transform3D->m23;
    mappedMatrix[7] = (GLfloat)transform3D->m24;
    mappedMatrix[8] = (GLfloat)transform3D->m31;
    mappedMatrix[9] = (GLfloat)transform3D->m32;
    mappedMatrix[10] = (GLfloat)transform3D->m33;
    mappedMatrix[11] = (GLfloat)transform3D->m34;
    mappedMatrix[12] = (GLfloat)transform3D->m41;
    mappedMatrix[13] = (GLfloat)transform3D->m42;
    mappedMatrix[14] = (GLfloat)transform3D->m43;
    mappedMatrix[15] = (GLfloat)transform3D->m44;
}

#pragma mark -
#pragma mark GPUImageInput

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
{
    CGSize currentFBOSize = [self sizeOfFBO];
    CGFloat normalizedHeight = currentFBOSize.height / currentFBOSize.width;
    
    GLfloat adjustedVertices[] = {
        -1.0f, -normalizedHeight,
        1.0f, -normalizedHeight,
        -1.0f,  normalizedHeight,
        1.0f,  normalizedHeight,
    };
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    GLfloat adjustedVerticesAnchorTL[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f,  normalizedHeight,
        1.0f,  normalizedHeight,
    };
    
    static const GLfloat squareVerticesAnchorTL[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    if (_ignoreAspectRatio)
    {
        if (_anchorTopLeft)
        {
            [self renderToTextureWithVertices:squareVerticesAnchorTL textureCoordinates:[[self class] textureCoordinatesForRotation:inputRotation]];
        }
        else
        {
            [self renderToTextureWithVertices:squareVertices textureCoordinates:[[self class] textureCoordinatesForRotation:inputRotation]];
        }
    }
    else
    {
        if (_anchorTopLeft)
        {
            [self renderToTextureWithVertices:adjustedVerticesAnchorTL textureCoordinates:[[self class] textureCoordinatesForRotation:inputRotation]];
        }
        else
        {
            [self renderToTextureWithVertices:adjustedVertices textureCoordinates:[[self class] textureCoordinatesForRotation:inputRotation]];
        }
    }
    
    [self informTargetsAboutNewFrameAtTime:frameTime];
}

- (void)setupFilterForSize:(CGSize)filterFrameSize;
{
    if (!_ignoreAspectRatio)
    {
        [self loadOrthoMatrix:(GLfloat *)&orthographicMatrix left:-1.0 right:1.0 bottom:(-1.0 * filterFrameSize.height / filterFrameSize.width) top:(1.0 * filterFrameSize.height / filterFrameSize.width) near:-1.0 far:1.0];
        //     [self loadOrthoMatrix:orthographicMatrix left:-1.0 right:1.0 bottom:(-1.0 * (GLfloat)backingHeight / (GLfloat)backingWidth) top:(1.0 * (GLfloat)backingHeight / (GLfloat)backingWidth) near:-2.0 far:2.0];
        
        [self setMatrix4f:orthographicMatrix forUniform:orthographicMatrixUniform program:filterProgram];
    }
}

#pragma mark -
#pragma mark Accessors

- (void)setColorToReplaceRed:(GLfloat)redComponent green:(GLfloat)greenComponent blue:(GLfloat)blueComponent;
{
    GPUVector3 colorToReplace = {redComponent, greenComponent, blueComponent};
    
    [self setVec3:colorToReplace forUniform:colorToReplaceUniform program:filterProgram];
}

- (void)setThresholdSensitivity:(CGFloat)newValue;
{
    _thresholdSensitivity = newValue;

    [self setFloat:(GLfloat)_thresholdSensitivity forUniform:thresholdSensitivityUniform program:filterProgram];
}

- (void)setSmoothing:(CGFloat)newValue;
{
    _smoothing = newValue;
    
    [self setFloat:(GLfloat)_smoothing forUniform:smoothingUniform program:filterProgram];
}

@end

