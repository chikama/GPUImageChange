#import "GPUImageTwoInputFilter.h"

/** Selectively replaces a color in the first image with the second image
 */
@interface GPUImageChromaKeyBlendFilter : GPUImageTwoInputFilter
{
    GLint colorToReplaceUniform, thresholdSensitivityUniform, smoothingUniform;
}

// You can either set the transform to apply to be a 2-D affine transform or a 3-D transform. The default is the identity transform (the output image is identical to the input).
@property(readwrite, nonatomic) CGAffineTransform affineTransform;
@property(readwrite, nonatomic) CATransform3D transform3D;

// This applies the transform to the raw frame data if set to YES, the default of NO takes the aspect ratio of the image input into account when rotating
@property(readwrite, nonatomic) BOOL ignoreAspectRatio;

// sets the anchor point to top left corner
@property(readwrite, nonatomic) BOOL anchorTopLeft;

/** The threshold sensitivity controls how similar pixels need to be colored to be replaced
 
 The default value is 0.3
 */
@property(readwrite, nonatomic) CGFloat thresholdSensitivity;

/** The degree of smoothing controls how gradually similar colors are replaced in the image
 
 The default value is 0.1
 */
@property(readwrite, nonatomic) CGFloat smoothing;

/** The color to be replaced is specified using individual red, green, and blue components (normalized to 1.0).
 
 The default is green: (0.0, 1.0, 0.0).
 
 @param redComponent Red component of color to be replaced
 @param greenComponent Green component of color to be replaced
 @param blueComponent Blue component of color to be replaced
 */
- (void)setColorToReplaceRed:(GLfloat)redComponent green:(GLfloat)greenComponent blue:(GLfloat)blueComponent;

@end
