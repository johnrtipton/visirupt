#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN
typedef NSUInteger NSEventType;
typedef NSUInteger NSEventMask;
@class NSEvent, NSApplication, NSTrackingArea;

// These facades keep state in associated objects so guest subclass ivars can
// retain the original NSObject-sized superclass layout. This must be checked
// against the complete host and guest metadata before loading game classes.
@interface NSResponder : NSObject
@property (nullable, weak) NSResponder *nextResponder;
- (BOOL)acceptsFirstResponder;
- (BOOL)becomeFirstResponder;
- (BOOL)resignFirstResponder;
- (void)mouseEntered:(NSEvent *)event;
- (void)mouseMoved:(NSEvent *)event;
- (void)mouseDown:(NSEvent *)event;
- (void)mouseUp:(NSEvent *)event;
- (void)mouseDragged:(NSEvent *)event;
- (void)scrollWheel:(NSEvent *)event;
- (void)mouseExited:(NSEvent *)event;
- (void)keyDown:(NSEvent *)event;
- (void)keyUp:(NSEvent *)event;
@end

@interface NSEvent : NSObject
+ (CGPoint)mouseLocation;
+ (void)setMouseCoalescingEnabled:(BOOL)enabled;
+ (BOOL)isMouseCoalescingEnabled;
@property (nullable, readonly) NSTrackingArea *trackingArea;
- (void)cp_setTrackingArea:(NSTrackingArea *)area;
@property (readonly) NSEventType type;
@property (readonly) NSUInteger modifierFlags;
@property (readonly) unsigned short keyCode;
@property (readonly,copy) NSString *characters;
@property (readonly,copy) NSString *charactersIgnoringModifiers;
@property (readonly) BOOL isARepeat;
@property (readonly) NSInteger buttonNumber;
@property (readonly) NSInteger clickCount;
- (void)cp_setKeyCharacters:(NSString *)characters ignoringModifiers:(NSString *)unmodified;
- (void)cp_setClickCount:(NSUInteger)count;
@property (readonly) NSTimeInterval timestamp;
@property (readonly) CGPoint locationInWindow;
@property (readonly) CGFloat deltaX;
@property (readonly) CGFloat deltaY;
@property (readonly) CGFloat scrollingDeltaX;
@property (readonly) CGFloat scrollingDeltaY;
@property (readonly) BOOL hasPreciseScrollingDeltas;
@property (readonly) NSUInteger phase;
@property (readonly) NSUInteger momentumPhase;
- (void)cp_setScrollPhase:(NSUInteger)phase;
@property (nullable, readonly) id window;
+ (nullable id)addLocalMonitorForEventsMatchingMask:(NSEventMask)mask
                                           handler:(NSEvent * _Nullable (^)(NSEvent *))handler;
+ (void)removeMonitor:(id)monitor;
// Host input translation supplies actual native event data through this
// internal factory. Native backing views supply hover, primary click and
// the explicitly mapped hardware key callbacks.
+ (instancetype)cp_eventWithType:(NSEventType)type
                        keyCode:(unsigned short)keyCode
                  modifierFlags:(NSUInteger)flags
                      timestamp:(NSTimeInterval)timestamp
                       location:(CGPoint)location
                          delta:(CGPoint)delta
                   preciseScroll:(BOOL)precise
                         window:(nullable id)window;
@end

@protocol NSApplicationDelegate <NSObject>
@optional
- (void)applicationWillFinishLaunching:(NSNotification *)notification;
- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (void)applicationDidBecomeActive:(NSNotification *)notification;
- (void)applicationWillResignActive:(NSNotification *)notification;
- (void)applicationDidResignActive:(NSNotification *)notification;
@end

FOUNDATION_EXPORT NSApplication * _Nullable NSApp;
FOUNDATION_EXPORT NSNotificationName const NSApplicationWillFinishLaunchingNotification;
FOUNDATION_EXPORT NSNotificationName const NSApplicationDidFinishLaunchingNotification;
FOUNDATION_EXPORT NSNotificationName const NSApplicationDidBecomeActiveNotification;
FOUNDATION_EXPORT NSNotificationName const NSApplicationWillResignActiveNotification;
FOUNDATION_EXPORT NSRunLoopMode const NSEventTrackingRunLoopMode;
FOUNDATION_EXPORT NSNotificationName const NSApplicationDidChangeScreenParametersNotification;
FOUNDATION_EXPORT NSNotificationName const NSApplicationDidResignActiveNotification;
FOUNDATION_EXPORT NSNotificationName const NSWindowDidBecomeKeyNotification;
FOUNDATION_EXPORT NSNotificationName const NSWindowDidResignKeyNotification;
// Values are exported for ABI compatibility; fullscreen/image behavior remains
// separately implemented and is not implied by the presence of these keys.
FOUNDATION_EXPORT NSNotificationName const NSWindowWillExitFullScreenNotification;
FOUNDATION_EXPORT NSString * const NSImageHintInterpolation;

@interface NSApplication : NSResponder
+ (instancetype)sharedApplication;
@property (nullable, weak) id<NSApplicationDelegate> delegate;
@property (nullable, readonly) NSEvent *currentEvent;
@property (nullable, readonly) id keyWindow;
@property (nullable, readonly) id mainWindow;
@property (readonly, getter=isActive) BOOL active;
@property NSUInteger presentationOptions;
@property (readonly) NSUInteger cp_requestedPresentationOptions;
- (void)finishLaunching;
- (void)postEvent:(NSEvent *)event atStart:(BOOL)atStart;
- (nullable NSEvent *)nextEventMatchingMask:(NSEventMask)mask
                                 untilDate:(nullable NSDate *)expiration
                                    inMode:(NSRunLoopMode)mode
                                   dequeue:(BOOL)dequeue;
- (void)sendEvent:(NSEvent *)event;
- (void)cp_setKeyWindow:(nullable id)window;
- (void)cp_setMainWindow:(nullable id)window;
// The native scene host supplies its observed activation state. This component
// does not synthesize activation or subscribe to a physical input source.
- (void)cp_setActiveFromNativeScene:(BOOL)active;
@end
NS_ASSUME_NONNULL_END
