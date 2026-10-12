#import <CoreGraphics/CoreGraphics.h>
#include <stdint.h>
#include <stddef.h>
// Main-thread host update; query functions consume a locked value snapshot and
// never access UIKit on an engine thread. Identifiers are port-local scene IDs.
BOOL CPRefreshSceneDisplaySnapshot(void);
CGError CPGetActiveSceneDisplayList(uint32_t capacity, uint32_t *displays, uint32_t *count);
CGRect CPSceneDisplayBounds(uint32_t display);
size_t CPSceneDisplayPixelsWide(uint32_t display);
size_t CPSceneDisplayPixelsHigh(uint32_t display);
// Record an actual native display-link period on the UI thread; rate is unknown
// (0) until a matching registered scene has supplied such an observation.
BOOL CPRecordSceneDisplayRefreshPeriod(uint32_t display, double seconds);
typedef CFDictionaryRef CPSceneDisplayModeRef;
CPSceneDisplayModeRef CPSceneDisplayCopyMode(uint32_t display) CF_RETURNS_RETAINED;
extern const CFStringRef CPSceneShowDuplicateLowResolutionModes;
CFArrayRef CPSceneDisplayCopyAllModes(uint32_t display, CFDictionaryRef options) CF_RETURNS_RETAINED;
size_t CPSceneModeGetWidth(CPSceneDisplayModeRef mode);
size_t CPSceneModeGetHeight(CPSceneDisplayModeRef mode);
size_t CPSceneModeGetPixelWidth(CPSceneDisplayModeRef mode);
size_t CPSceneModeGetPixelHeight(CPSceneDisplayModeRef mode);
double CPSceneModeGetRefreshRate(CPSceneDisplayModeRef mode);
double CPSceneModeGetObservedRefreshRate(CPSceneDisplayModeRef mode);
// Declared port precision policy: snap only sub-millihertz integer drift.
double CPSceneNominalRefreshRate(double observedRate);
uint32_t CPSceneModeGetIOFlags(CPSceneDisplayModeRef mode);
bool CPSceneModeIsUsableForGUI(CPSceneDisplayModeRef mode);
void CPSceneModeRelease(CPSceneDisplayModeRef mode);
// Known scene viewports are virtual (not desktop built-in or mirror displays).
// Physical monitor identifiers are unavailable; preserve desktop failure forms.
int32_t CPSceneDisplayIsBuiltin(uint32_t display);
int32_t CPSceneDisplayIsInMirrorSet(uint32_t display);
uint32_t CPSceneDisplayVendorNumber(uint32_t display);
uint32_t CPSceneDisplayModelNumber(uint32_t display);
uint32_t CPSceneDisplaySerialNumber(uint32_t display);
uint32_t CPSceneDisplayIOServicePort(uint32_t display);
