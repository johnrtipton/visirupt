#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdint.h>
NS_ASSUME_NONNULL_BEGIN
typedef const void *CPDesktopEventSourceRef;
// No global Quartz HID event source exists in this host. NULL is a creation
// failure, not a manufactured event source or a successful input capability.
FOUNDATION_EXPORT CPDesktopEventSourceRef _Nullable CPSceneEventSourceCreate(int32_t stateID);
FOUNDATION_EXPORT void CPSceneEventSourceSetLocalEventsSuppressionInterval(CPDesktopEventSourceRef _Nullable source, double seconds);
FOUNDATION_EXPORT uint32_t CPSceneMainDisplayID(void);
FOUNDATION_EXPORT CGError CPSceneWarpMouseCursorPosition(CGPoint point);
NS_ASSUME_NONNULL_END
