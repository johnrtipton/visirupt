#import <UIKit/UIKit.h>
#import "CPApplicationEvents.h"

NS_ASSUME_NONNULL_BEGIN
@protocol CPSceneKeyWindowTarget <NSObject>
- (BOOL)cp_acceptsNativeKeyWindow;
@end
// A host owns one bridge for its actual game window. This is a single-scene
// adapter; it is not a complete AppKit window or native event implementation.
@interface CPSceneLifecycleBridge : NSObject
- (instancetype)initWithWindow:(UIWindow *)window application:(NSApplication *)application;
- (instancetype)initWithWindow:(UIWindow *)window application:(NSApplication *)application
               keyWindowTarget:(id)target;
@property (nullable, weak, readonly) UIWindow *window;
// Call on the main thread before replacing or discarding the game window.
- (void)invalidate;
@end
NS_ASSUME_NONNULL_END
