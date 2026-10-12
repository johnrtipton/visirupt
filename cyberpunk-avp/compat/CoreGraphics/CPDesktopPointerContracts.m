#import "CPDesktopPointerContracts.h"
#import "CPSceneDisplays.h"
#include <math.h>
CPDesktopEventSourceRef CPSceneEventSourceCreate(int32_t stateID) {
 (void)stateID;
 // This factory cannot create a desktop system HID state or Quartz posting
 // source. Preserve the API's nullable failure path for every requested state.
 return NULL;
}
void CPSceneEventSourceSetLocalEventsSuppressionInterval(CPDesktopEventSourceRef source, double seconds) {
 (void)seconds;
 if(!source)return;
 // The host never manufactures a non-NULL source. Reject foreign objects
 // explicitly rather than claiming to configure global hardware suppression.
 [NSException raise:NSInvalidArgumentException format:@"Desktop Quartz event-source suppression is unavailable in this scene host"];
}
uint32_t CPSceneMainDisplayID(void) {
 uint32_t identifier=0,count=0;
 return CPGetActiveSceneDisplayList(1,&identifier,&count)==kCGErrorSuccess && count==1 ? identifier : 0;
}
CGError CPSceneWarpMouseCursorPosition(CGPoint point) {
 if(!isfinite(point.x)||!isfinite(point.y))return kCGErrorIllegalArgument;
 // There is no supported global desktop cursor warp in this host. Do not
 // alter a logical coordinate and claim that the physical cursor moved.
 return kCGErrorNotImplemented;
}
