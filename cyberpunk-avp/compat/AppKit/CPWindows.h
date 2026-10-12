#import "CPViews.h"
#import "CPSceneLifecycleBridge.h"
NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSNotificationName const NSWindowDidResizeNotification;
FOUNDATION_EXPORT NSNotificationName const NSWindowWillCloseNotification;
FOUNDATION_EXPORT NSNotificationName const NSWindowDidMoveNotification;
@class NSScreen;
@interface NSWindow : NSResponder <CPSceneKeyWindowTarget>
- (instancetype)initWithContentRect:(CGRect)rect styleMask:(NSUInteger)style
                             backing:(NSUInteger)backing defer:(BOOL)defer;
- (instancetype)initWithContentRect:(CGRect)rect styleMask:(NSUInteger)style
                             backing:(NSUInteger)backing defer:(BOOL)defer screen:(nullable NSScreen *)screen;
@property (nullable,strong) NSView *contentView;
@property (nullable,weak) id delegate;
@property (nullable,readonly) NSResponder *firstResponder;
- (BOOL)makeFirstResponder:(nullable NSResponder *)responder;
@property (readonly) CGRect contentLayoutRect;
- (CGPoint)convertPointToScreen:(CGPoint)point;
- (CGPoint)convertPointFromScreen:(CGPoint)point;
@property CGRect frame;
@property NSUInteger styleMask;
@property (readonly) NSUInteger cp_requestedStyleMask;
@property CGSize contentAspectRatio;
@property CGSize minSize;
@property CGSize contentSize;
@property NSUInteger collectionBehavior;
@property (readonly) NSUInteger cp_requestedCollectionBehavior;
@property (readonly,copy) NSString *cp_collectionBehaviorStatus;
@property (nullable,readonly) NSScreen *screen;
@property BOOL acceptsMouseMovedEvents;
@property (copy) NSString *title;
@property (readonly,getter=isVisible) BOOL visible;
@property (readonly,getter=isKeyWindow) BOOL keyWindow;
@property (readonly) UIView *cp_nativeContent;
- (void)cp_attachToNativeWindow:(UIWindow *)window container:(UIView *)container;
- (void)cp_detachFromNativeWindow;
- (void)makeKeyAndOrderFront:(nullable id)sender;
- (void)setIsVisible:(BOOL)visible;
- (void)makeMainWindow;
- (void)orderOut:(nullable id)sender;
- (void)sendEvent:(NSEvent *)event;
- (void)invalidateCursorRectsForView:(NSView *)view;
- (void)close;
- (void)setFrame:(CGRect)frame display:(BOOL)display;
- (void)setFrameOrigin:(CGPoint)point;
@end
@interface NSWindowController : NSResponder
- (instancetype)initWithWindow:(nullable NSWindow *)window;
@property (nullable,strong) NSWindow *window;
- (void)windowDidLoad;
- (void)showWindow:(nullable id)sender;
- (void)close;
@end
NS_ASSUME_NONNULL_END
