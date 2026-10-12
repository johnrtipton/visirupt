#import "CPImages.h"
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@interface NSCursor : NSObject
- (instancetype)initWithImage:(NSImage *)image hotSpot:(CGPoint)hotSpot;
@property (nullable, readonly) NSImage *image;
@property (readonly) CGPoint hotSpot;
+ (NSCursor *)currentCursor;
// Own scene-region integration. It does not control a global desktop cursor.
- (UIPointerStyle *)cp_nativePointerStyle;
+ (void)cp_nativeRegionEntered:(id)owner cursor:(NSCursor *)cursor;
+ (void)cp_nativeRegionExited:(id)owner;
@end
NS_ASSUME_NONNULL_END
