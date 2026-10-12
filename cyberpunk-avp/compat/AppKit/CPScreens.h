#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
// A registered app scene viewport, with a port-local identifier. This is not
// a physical macOS CGDirectDisplayID or an inventory of headset display panels.
@interface NSScreen : NSObject
+ (void)cp_setMainNativeWindow:(nullable UIWindow *)window;
+ (nullable NSScreen *)mainScreen;
+ (void)cp_notifyNativeViewportChanged;
+ (NSArray<NSScreen *> *)screens;
@property (readonly) CGRect frame;
@property (readonly) CGRect visibleFrame;
@property (readonly) CGFloat backingScaleFactor;
@property (readonly) CGFloat maximumPotentialExtendedDynamicRangeColorComponentValue;
@property (readonly) CGFloat maximumExtendedDynamicRangeColorComponentValue;
// Single observed scene cadence: no physical panel VRR negotiation exposed.
@property (readonly) NSTimeInterval minimumRefreshInterval;
@property (readonly) NSTimeInterval maximumRefreshInterval;
@property (readonly) BOOL cp_refreshTimingReady;
@property (readonly,copy) NSDictionary *cp_refreshTimingEvidence;
@property (readonly,copy) NSDictionary *deviceDescription;
@property (readonly) uint32_t cp_sceneDisplayIdentifier;
@property (nullable,readonly) UIWindow *cp_nativeWindow;
@end
NS_ASSUME_NONNULL_END
