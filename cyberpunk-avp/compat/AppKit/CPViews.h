#import "CPApplicationEvents.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN
@class NSWindow, NSCursor, NSTrackingArea;
@interface NSView : NSResponder
- (void)updateTrackingAreas;
- (void)addTrackingArea:(NSTrackingArea *)area;
- (void)removeTrackingArea:(NSTrackingArea *)area;
@property (readonly, copy) NSArray<NSTrackingArea *> *trackingAreas;
@property (readonly) UIHoverGestureRecognizer *cp_hoverRecognizer;
@property (readonly) UIPanGestureRecognizer *cp_scrollRecognizer;
@property (readonly) NSUInteger cp_nativeHoverSampleCount;
// Shared translation path. Direct fixture samples are labeled synthetic and
// never increment the counter reserved for UIKit recognizer action delivery.
- (void)cp_updateTrackingAtNativePoint:(CGPoint)point present:(BOOL)present timestamp:(NSTimeInterval)timestamp modifierFlags:(NSUInteger)flags;
- (void)resetCursorRects;
- (void)addCursorRect:(CGRect)rect cursor:(NSCursor *)cursor;
- (void)discardCursorRects;
- (void)cp_deactivateCursorRegions;
- (BOOL)isFlipped;
@property (readonly) UIPointerInteraction *cp_pointerInteraction;
// Same selection path used by UIKit; helper enables separately labeled geometry tests.
- (nullable UIPointerRegion *)cp_cursorRegionAtPoint:(CGPoint)point;
- (instancetype)initWithFrame:(CGRect)frame;
@property (nullable, readonly) NSWindow *window;
- (void)cp_setOwningWindow:(nullable NSWindow *)window;
@property CGRect frame;
@property CGRect bounds;
@property (readonly) CGRect safeAreaRect;
@property NSUInteger autoresizingMask;
@property (nullable, strong) CALayer *layer;
@property (getter=isHidden) BOOL hidden;
@property (readonly) UIView *cp_nativeView;
// These host-only methods attach the actual native view and retain its supplied
// Metal layer. They do not implement NSWindow, input, or game initialization.
- (void)cp_attachToNativeContainer:(UIView *)container;
- (void)cp_detachFromNativeContainer;
@end
NS_ASSUME_NONNULL_END
