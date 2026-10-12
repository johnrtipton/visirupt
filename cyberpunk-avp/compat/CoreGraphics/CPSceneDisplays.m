#import "CPSceneDisplays.h"
#import "CPScreens.h"
#include <pthread.h>
#include <math.h>
const CFStringRef CPSceneShowDuplicateLowResolutionModes=CFSTR("kCGDisplayResolution");
typedef struct {uint32_t identifier;CGRect bounds;size_t pixelsWide,pixelsHigh;double refreshRate,observedRefreshRate;} CPSnapshot;
static pthread_mutex_t snapshotMutex=PTHREAD_MUTEX_INITIALIZER;
static CPSnapshot currentSnapshot;
static CPSnapshot CopySnapshot(void) {pthread_mutex_lock(&snapshotMutex);CPSnapshot s=currentSnapshot;pthread_mutex_unlock(&snapshotMutex);return s;}
BOOL CPRefreshSceneDisplaySnapshot(void) {
 if(!NSThread.isMainThread)[NSException raise:NSInternalInconsistencyException format:@"Viewport snapshot updates require the main thread"];
 CPSnapshot s={0};NSScreen *screen=NSScreen.mainScreen;
 if(screen){
  CGRect bounds=screen.frame;double scale=screen.backingScaleFactor;
  double width=round(bounds.size.width*scale),height=round(bounds.size.height*scale);
  // Bound to UINT32_MAX, below the double/size_t precision boundary on ARM64.
  if(isfinite(width)&&isfinite(height)&&width>0&&height>0&&width<=UINT32_MAX&&height<=UINT32_MAX){
   s.identifier=screen.cp_sceneDisplayIdentifier;s.bounds=bounds;s.pixelsWide=(size_t)width;s.pixelsHigh=(size_t)height;
  }
 }
 pthread_mutex_lock(&snapshotMutex);
 if(s.identifier&&s.identifier==currentSnapshot.identifier){s.refreshRate=currentSnapshot.refreshRate;s.observedRefreshRate=currentSnapshot.observedRefreshRate;}
 currentSnapshot=s;pthread_mutex_unlock(&snapshotMutex);
 return s.identifier!=0;
}
CGError CPGetActiveSceneDisplayList(uint32_t capacity,uint32_t *displays,uint32_t *count) {
 if(!count)return kCGErrorIllegalArgument;
 CPSnapshot s=CopySnapshot();*count=0;
 if(!s.identifier)return kCGErrorSuccess;
 if(!displays){*count=1;return kCGErrorSuccess;}
 if(capacity){displays[0]=s.identifier;*count=1;}
 return kCGErrorSuccess;
}
CGRect CPSceneDisplayBounds(uint32_t display) {CPSnapshot s=CopySnapshot();return s.identifier&&display==s.identifier?s.bounds:CGRectZero;}
size_t CPSceneDisplayPixelsWide(uint32_t display) {CPSnapshot s=CopySnapshot();return s.identifier&&display==s.identifier?s.pixelsWide:0;}
size_t CPSceneDisplayPixelsHigh(uint32_t display) {CPSnapshot s=CopySnapshot();return s.identifier&&display==s.identifier?s.pixelsHigh:0;}
BOOL CPRecordSceneDisplayRefreshPeriod(uint32_t display,double seconds) {
 if(!NSThread.isMainThread)[NSException raise:NSInternalInconsistencyException format:@"Native refresh observations require the main thread"];
 if(!display||!isfinite(seconds)||seconds<=0||!isfinite(1.0/seconds))return NO;
 pthread_mutex_lock(&snapshotMutex);BOOL matches=display==currentSnapshot.identifier;
 if(matches){currentSnapshot.observedRefreshRate=1.0/seconds;currentSnapshot.refreshRate=CPSceneNominalRefreshRate(currentSnapshot.observedRefreshRate);}
 pthread_mutex_unlock(&snapshotMutex);return matches;
}
CPSceneDisplayModeRef CPSceneDisplayCopyMode(uint32_t display) {
 CPSnapshot s=CopySnapshot();if(!s.identifier||display!=s.identifier)return NULL;
 // This immutable CF object is the port's current native scene backing mode,
 // not a macOS CGDisplayModeRef. All original getters need explicit adaptation.
 NSDictionary *mode=@{@"CPSceneModeKind":@"RegisteredViewportV1",@"width":@(llround(s.bounds.size.width)),@"height":@(llround(s.bounds.size.height)),@"pixelWidth":@(s.pixelsWide),@"pixelHeight":@(s.pixelsHigh),@"refresh":@(s.refreshRate),@"observedRefresh":@(s.observedRefreshRate),@"scene":@(s.identifier)};
 return (CFDictionaryRef)CFBridgingRetain(mode);
}
CFArrayRef CPSceneDisplayCopyAllModes(uint32_t display,CFDictionaryRef options) {
 if(options) {
  if(CFGetTypeID(options)!=CFDictionaryGetTypeID())return NULL;
  CFIndex count=CFDictionaryGetCount(options);
  if(count>1)return NULL;
  if(count==1){
   if(!CFDictionaryContainsKey(options,CPSceneShowDuplicateLowResolutionModes))return NULL;
   CFTypeRef show=CFDictionaryGetValue(options,CPSceneShowDuplicateLowResolutionModes);
   if(!show||CFGetTypeID(show)!=CFBooleanGetTypeID())return NULL;
  }
 }
 // The registered scene exposes one observed backing mode. Neither true nor
 // false fabricates alternate resolutions or duplicate physical monitor modes.
 CPSceneDisplayModeRef mode=CPSceneDisplayCopyMode(display);if(!mode)return NULL;
 const void *value=mode;CFArrayRef modes=CFArrayCreate(NULL,&value,1,&kCFTypeArrayCallBacks);
 CFRelease(mode);return modes;
}
static NSDictionary *Mode(CPSceneDisplayModeRef mode) {
 if(!mode||CFGetTypeID(mode)!=CFDictionaryGetTypeID())return nil;
 NSDictionary *d=(__bridge NSDictionary *)mode;
 if(![d[@"CPSceneModeKind"] isEqual:@"RegisteredViewportV1"])return nil;
 for(NSString *key in @[@"width",@"height",@"pixelWidth",@"pixelHeight",@"refresh",@"observedRefresh",@"scene"])
  if(![d[key] isKindOfClass:NSNumber.class])return nil;
 return d;
}
size_t CPSceneModeGetWidth(CPSceneDisplayModeRef mode) {return [Mode(mode)[@"width"] unsignedLongLongValue];}
size_t CPSceneModeGetHeight(CPSceneDisplayModeRef mode) {return [Mode(mode)[@"height"] unsignedLongLongValue];}
size_t CPSceneModeGetPixelWidth(CPSceneDisplayModeRef mode) {return [Mode(mode)[@"pixelWidth"] unsignedLongLongValue];}
size_t CPSceneModeGetPixelHeight(CPSceneDisplayModeRef mode) {return [Mode(mode)[@"pixelHeight"] unsignedLongLongValue];}
double CPSceneModeGetRefreshRate(CPSceneDisplayModeRef mode) {return [Mode(mode)[@"refresh"] doubleValue];}
double CPSceneModeGetObservedRefreshRate(CPSceneDisplayModeRef mode) {return [Mode(mode)[@"observedRefresh"] doubleValue];}
double CPSceneNominalRefreshRate(double observedRate) {
 if(!isfinite(observedRate)||observedRate<=0)return 0;
 double integral=round(observedRate);
 return integral>0&&fabs(observedRate-integral)<=0.001?integral:observedRate;
}
uint32_t CPSceneModeGetIOFlags(CPSceneDisplayModeRef mode) {
 // Native means the current registered viewport's native backing, not panel
 // EDID or IOKit safety flags. Do not assert unsupported hardware safety bits.
 return Mode(mode)?0x02000000:0;
}
bool CPSceneModeIsUsableForGUI(CPSceneDisplayModeRef mode) {
 return Mode(mode)&&CPSceneModeGetWidth(mode)>0&&CPSceneModeGetHeight(mode)>0;
}
void CPSceneModeRelease(CPSceneDisplayModeRef mode) {if(mode)CFRelease(mode);}
static BOOL IsRegisteredViewport(uint32_t display) {CPSnapshot s=CopySnapshot();return s.identifier&&display==s.identifier;}
int32_t CPSceneDisplayIsBuiltin(uint32_t display) {return IsRegisteredViewport(display)?0:-1;}
int32_t CPSceneDisplayIsInMirrorSet(uint32_t display) {return IsRegisteredViewport(display)?0:-1;}
uint32_t CPSceneDisplayVendorNumber(uint32_t display) {
 // This backend exposes no physical monitor identity. A port scene ID cannot
 // be looked up in a desktop EDID registry, even when the viewport is valid.
 (void)display;return UINT32_MAX;
}
uint32_t CPSceneDisplayModelNumber(uint32_t display) {(void)display;return UINT32_MAX;}
uint32_t CPSceneDisplaySerialNumber(uint32_t display) {(void)display;return UINT32_MAX;}
uint32_t CPSceneDisplayIOServicePort(uint32_t display) {(void)display;return 0;}
