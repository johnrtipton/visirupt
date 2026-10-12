#import "CPCursors.h"
#import <objc/runtime.h>
#import <math.h>
@interface CPCursorState : NSObject
@property (nullable, strong) NSImage *image;
@property CGPoint hotSpot;
@end
@implementation CPCursorState @end
static char cursorKey;
static __weak id activeRegion;
static NSCursor *activeCursor;
static void cursorThread(void){if(!NSThread.isMainThread)[NSException raise:NSInternalInconsistencyException format:@"Scene cursor operations require the main thread"];}
@implementation NSCursor
- (instancetype)init {cursorThread();if((self=[super init]))objc_setAssociatedObject(self,&cursorKey,[CPCursorState new],OBJC_ASSOCIATION_RETAIN_NONATOMIC);return self;}
- (instancetype)initWithImage:(NSImage *)image hotSpot:(CGPoint)hotSpot {
 if(![image isKindOfClass:NSImage.class]||!isfinite(hotSpot.x)||!isfinite(hotSpot.y))[NSException raise:NSInvalidArgumentException format:@"A bitmap image and finite hotspot are required"];
 if((self=[self init])){CPCursorState *state=objc_getAssociatedObject(self,&cursorKey);state.image=image;state.hotSpot=hotSpot;}return self;
}
- (NSImage *)image {cursorThread();return ((CPCursorState *)objc_getAssociatedObject(self,&cursorKey)).image;}
- (CGPoint)hotSpot {cursorThread();return ((CPCursorState *)objc_getAssociatedObject(self,&cursorKey)).hotSpot;}
+ (NSCursor *)currentCursor {
 cursorThread();static NSCursor *system;static dispatch_once_t once;dispatch_once(&once,^{system=[NSCursor new];});if(!activeRegion)activeCursor=nil;return activeRegion&&activeCursor?activeCursor:system;
}
+ (void)cp_nativeRegionEntered:(id)owner cursor:(NSCursor *)cursor {cursorThread();if(!owner||!cursor)[NSException raise:NSInvalidArgumentException format:@"A genuine pointer region owner is required"];activeRegion=owner;activeCursor=cursor;}
+ (void)cp_nativeRegionExited:(id)owner {cursorThread();if(activeRegion==owner){activeRegion=nil;activeCursor=nil;}}
- (UIPointerStyle *)cp_nativePointerStyle {
 NSImage *image=self.image;if(!image)return UIPointerStyle.systemPointerStyle;
 CGImageRef cg=[image cp_copyCGImage];if(!cg)[NSException raise:NSInvalidArgumentException format:@"Cursor image has no drawable bitmap"];
 size_t width=CGImageGetWidth(cg),height=CGImageGetHeight(cg);
 if(!width||!height||width>SIZE_MAX/4||height>SIZE_MAX/(width*4)){CGImageRelease(cg);[NSException raise:NSInvalidArgumentException format:@"Invalid cursor bitmap storage"];}
 CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();CGContextRef context=CGBitmapContextCreate(NULL,width,height,8,width*4,space,(CGBitmapInfo)kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);CGColorSpaceRelease(space);
 if(!context){CGImageRelease(cg);[NSException raise:NSMallocException format:@"Could not inspect native cursor pixels"];}CGContextDrawImage(context,CGRectMake(0,0,width,height),cg);CGImageRelease(cg);
 const unsigned char *pixels=CGBitmapContextGetData(context);BOOL transparent=YES;for(size_t i=0;i<width*height;i++)if(pixels[i*4+3]){transparent=NO;break;}CGContextRelease(context);
 if(!transparent)[NSException raise:NSInvalidArgumentException format:@"Opaque custom cursor image presentation is not implemented"];
 return UIPointerStyle.hiddenPointerStyle;
}
@end
