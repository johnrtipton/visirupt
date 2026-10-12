#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdint.h>
NS_ASSUME_NONNULL_BEGIN
// Native host controller. A preference is a request; success requires actual
// scene state to match, and never means a global desktop cursor was moved.
@interface CPScenePointerController : UIViewController
@property (readonly) BOOL cp_requestedPointerLock;
- (void)cp_requestPointerLock:(BOOL)locked;
- (void)cp_observeHover:(UIHoverGestureRecognizer *)gesture;
@end
FOUNDATION_EXPORT void CPRegisterScenePointerController(CPScenePointerController * _Nullable controller);
FOUNDATION_EXPORT CGError CPSceneAssociateMouseAndMouseCursorPosition(int32_t associate);
// No global desktop query exists: only live, observed native viewport samples.
FOUNDATION_EXPORT BOOL CPSceneReadMouseLocation(CGPoint *point);
FOUNDATION_EXPORT void CPSceneObserveMouseLocation(UIView *view, CGPoint point, BOOL present);
NS_ASSUME_NONNULL_END
