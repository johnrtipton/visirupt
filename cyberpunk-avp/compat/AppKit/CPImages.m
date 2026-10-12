#import "CPImages.h"
#import "CPApplicationEvents.h"
#import "CPScreens.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <math.h>
@interface CPImageState : NSObject
@property CGSize size;
@property CGContextRef bitmap;
@property CGImageRef source;
@end
@implementation CPImageState
- (void)dealloc {if(_bitmap)CGContextRelease(_bitmap);if(_source)CGImageRelease(_source);}
@end
static char imageStateKey;
static void imageThread(void) {if(!NSThread.isMainThread)[NSException raise:NSInternalInconsistencyException format:@"Bitmap image focus requires the main thread"];}
static CPImageState *imageState(NSImage *image) {imageThread();return objc_getAssociatedObject(image,&imageStateKey);}
static NSMutableArray<NSImage *> *focusStack(void) {
 imageThread();NSMutableDictionary *thread=NSThread.currentThread.threadDictionary;
 NSMutableArray *stack=thread[@"local.games.cyberpunk.imageFocus"];
 if(!stack){stack=[NSMutableArray new];thread[@"local.games.cyberpunk.imageFocus"]=stack;}return stack;
}
@implementation NSImage
- (instancetype)init {return [self initWithSize:CGSizeZero];}
- (instancetype)initWithSize:(CGSize)size {
 imageThread();if(!isfinite(size.width)||!isfinite(size.height)||size.width<0||size.height<0)[NSException raise:NSInvalidArgumentException format:@"Invalid bitmap image dimensions"];
 if((self=[super init])){CPImageState *state=[CPImageState new];state.size=size;objc_setAssociatedObject(self,&imageStateKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}return self;
}
- (instancetype)initWithCGImage:(CGImageRef)image size:(CGSize)size {
 if(!image)[NSException raise:NSInvalidArgumentException format:@"A genuine CGImage is required"];
 if((self=[self initWithSize:size]))imageState(self).source=CGImageRetain(image);return self;
}
- (CGSize)size {return imageState(self).size;}
- (void)lockFocus {
 CPImageState *state=imageState(self);
 if(state.size.width<=0||state.size.height<=0)[NSException raise:NSInvalidArgumentException format:@"A positive image size is required for drawing focus"];
 if(!state.bitmap){
  CGFloat scale=NSScreen.mainScreen.backingScaleFactor;if(!isfinite(scale)||scale<=0)scale=1;
  double width=ceil(state.size.width*scale),height=ceil(state.size.height*scale);
  if(width>SIZE_MAX/4 || height>SIZE_MAX/(width*4))[NSException raise:NSInvalidArgumentException format:@"Bitmap dimensions exceed addressable storage"];
  CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
  state.bitmap=CGBitmapContextCreate(NULL,(size_t)width,(size_t)height,8,(size_t)width*4,space,(CGBitmapInfo)kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);CGColorSpaceRelease(space);
  if(!state.bitmap)[NSException raise:NSMallocException format:@"Could not allocate native bitmap context"];
  CGContextScaleCTM(state.bitmap,width/state.size.width,height/state.size.height);
  if(state.source)CGContextDrawImage(state.bitmap,CGRectMake(0,0,state.size.width,state.size.height),state.source);
 }
 CGContextSaveGState(state.bitmap);UIGraphicsPushContext(state.bitmap);[focusStack() addObject:self];
}
- (void)unlockFocus {
 if(focusStack().lastObject!=self)[NSException raise:NSInternalInconsistencyException format:@"Image focus must unwind in last-in-first-out order"];
 UIGraphicsPopContext();CGContextRestoreGState(imageState(self).bitmap);[focusStack() removeLastObject];
}
- (CGImageRef)cp_copyCGImage {
 CPImageState *state=imageState(self);return state.bitmap?CGBitmapContextCreateImage(state.bitmap):(state.source?CGImageRetain(state.source):NULL);
}
- (void)drawInRect:(CGRect)destination fromRect:(CGRect)source operation:(NSUInteger)operation fraction:(CGFloat)fraction respectFlipped:(BOOL)respectFlipped hints:(NSDictionary *)hints {
 imageThread();NSImage *target=focusStack().lastObject;
 if(!target)[NSException raise:NSInternalInconsistencyException format:@"Image drawing requires owned image focus"];
 if(!isfinite(fraction)||fraction<0||fraction>1 || CGRectIsInfinite(destination)||CGRectIsNull(destination))[NSException raise:NSInvalidArgumentException format:@"Invalid image draw arguments"];
 if(!isfinite(destination.origin.x)||!isfinite(destination.origin.y)||!isfinite(destination.size.width)||!isfinite(destination.size.height)||destination.size.width<0||destination.size.height<0)[NSException raise:NSInvalidArgumentException format:@"Invalid destination rectangle"];
 CGBlendMode blend;
 switch(operation){case 0:blend=kCGBlendModeClear;break;case 1:blend=kCGBlendModeCopy;break;case 2:blend=kCGBlendModeNormal;break;default:[NSException raise:NSInvalidArgumentException format:@"Unaudited image compositing operation"];return;}
 CGInterpolationQuality interpolation=kCGInterpolationDefault;
 for(id key in hints){
  if(![key isEqual:NSImageHintInterpolation]||![hints[key] isKindOfClass:NSNumber.class])[NSException raise:NSInvalidArgumentException format:@"Unsupported image drawing hint"];
  switch([hints[key] integerValue]){case 0:interpolation=kCGInterpolationDefault;break;case 1:interpolation=kCGInterpolationNone;break;case 2:interpolation=kCGInterpolationLow;break;case 3:interpolation=kCGInterpolationHigh;break;case 4:interpolation=kCGInterpolationMedium;break;default:[NSException raise:NSInvalidArgumentException format:@"Unknown image interpolation quality"];}
 }
 CGImageRef image=[self cp_copyCGImage];if(!image)return; // Native empty source draws no pixels.
 if(!CGRectEqualToRect(source,CGRectZero)){
  CGSize size=self.size;
  if(size.width<=0||size.height<=0||!CGRectContainsRect(CGRectMake(0,0,size.width,size.height),source)){CGImageRelease(image);[NSException raise:NSInvalidArgumentException format:@"Image crop lies outside its logical bounds"];}
  CGFloat sx=CGImageGetWidth(image)/size.width,sy=CGImageGetHeight(image)/size.height;
  CGImageRef crop=CGImageCreateWithImageInRect(image,CGRectMake(source.origin.x*sx,(size.height-CGRectGetMaxY(source))*sy,source.size.width*sx,source.size.height*sy));CGImageRelease(image);image=crop;
 }
 if(!image)return;
 CGContextRef context=imageState(target).bitmap;CGContextSaveGState(context);CGContextSetBlendMode(context,blend);CGContextSetAlpha(context,fraction);CGContextSetInterpolationQuality(context,interpolation);CGContextDrawImage(context,destination,image);CGContextRestoreGState(context);CGImageRelease(image);
 // Both source and owned bitmap target use unflipped AppKit coordinates.
 // respectFlipped does not invert an unflipped destination context.
 (void)respectFlipped;
}
@end
