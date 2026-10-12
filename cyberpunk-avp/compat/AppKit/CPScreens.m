#import "CPScreens.h"
#import "CPApplicationEvents.h"
#import "CPSceneDisplays.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#include <math.h>
@interface CPScreenState : NSObject
@property (nullable,weak) UIWindow *window;
@property uint32_t identifier;
@property BOOL viewportCached;
@property CGRect cachedBounds;
@property UIEdgeInsets cachedInsets;
@property CGFloat cachedScale;
@property NSTimeInterval observedPeriod;
@property NSTimeInterval observedTimestamp;
@property (nullable,strong) CADisplayLink *displayLink;
@property (atomic,strong) NSDictionary *snapshot;
@property (nullable,strong) id disconnectObserver;
@end
@implementation CPScreenState
- (void)dealloc {if(_disconnectObserver)[NSNotificationCenter.defaultCenter removeObserver:_disconnectObserver];}
@end
@interface CPScreenTimingTarget : NSObject
@property (weak) NSScreen *screen;
- (void)sample:(CADisplayLink *)link;
@end
static char screenStateKey;
static NSScreen *mainScreen;
static uint32_t lastIdentifier;
static void Main(void) {if(!NSThread.isMainThread)[NSException raise:NSInternalInconsistencyException format:@"Scene viewport queries require the main thread"];}
static CPScreenState *State(NSScreen *screen) {
 Main();CPScreenState *s=objc_getAssociatedObject(screen,&screenStateKey);
 if(!s||!s.window.windowScene||s.window.windowScene.activationState==UISceneActivationStateUnattached)[NSException raise:NSInternalInconsistencyException format:@"Viewport has no connected native scene window"];
 return s;
}
static void Publish(CPScreenState *s) {
 Main();
 s.snapshot=@{@"connected":@YES,@"frame":[NSValue valueWithCGRect:s.cachedBounds],@"visible":[NSValue valueWithCGRect:UIEdgeInsetsInsetRect(s.cachedBounds,s.cachedInsets)],@"scale":@(s.cachedScale),@"identifier":@(s.identifier),@"period":@(s.observedPeriod),@"timestamp":@(s.observedTimestamp)};
}
static NSDictionary *Snapshot(NSScreen *screen) {
 CPScreenState *s=objc_getAssociatedObject(screen,&screenStateKey);NSDictionary *snapshot=s.snapshot;
 if(![snapshot[@"connected"] boolValue])[NSException raise:NSInternalInconsistencyException format:@"Viewport has no observed connected scene snapshot"];
 return snapshot;
}
@implementation CPScreenTimingTarget
- (void)sample:(CADisplayLink *)link {
 NSScreen *screen=self.screen;
 if(!screen||screen!=NSScreen.mainScreen){[link invalidate];return;}
 CPScreenState *s=State(screen);double period=link.duration;
 if(!isfinite(period)||period<=0||!isfinite(1.0/period))return;
 s.observedPeriod=period;s.observedTimestamp=link.timestamp;
 Publish(s);
 CPRecordSceneDisplayRefreshPeriod(s.identifier,period);
 // Capture one actual scene cadence for this port's single backing mode.
 // This is not a probe of all physical panel refresh rates.
 [link invalidate];s.displayLink=nil;
}
@end
@implementation NSScreen
+ (void)cp_setMainNativeWindow:(UIWindow *)window {
 Main();
 if(!window){
  if(!mainScreen)return;
  CPScreenState *retired=objc_getAssociatedObject(mainScreen,&screenStateKey);[retired.displayLink invalidate];retired.snapshot=@{@"connected":@NO};
  if(retired.disconnectObserver)[NSNotificationCenter.defaultCenter removeObserver:retired.disconnectObserver];retired.disconnectObserver=nil;
  @synchronized(NSScreen.class){mainScreen=nil;}CPRefreshSceneDisplaySnapshot();
  [NSNotificationCenter.defaultCenter postNotificationName:NSApplicationDidChangeScreenParametersNotification object:NSApplication.sharedApplication];return;
 }
 if(!window.windowScene||window.windowScene.activationState==UISceneActivationStateUnattached)[NSException raise:NSInvalidArgumentException format:@"Register an actual connected scene window"];
 CPScreenState *existing=mainScreen?objc_getAssociatedObject(mainScreen,&screenStateKey):nil;
 if(existing.window==window){[self cp_notifyNativeViewportChanged];return;}
 [existing.displayLink invalidate];
 existing.snapshot=@{@"connected":@NO};
 if(existing.disconnectObserver)[NSNotificationCenter.defaultCenter removeObserver:existing.disconnectObserver];existing.disconnectObserver=nil;
 if(lastIdentifier==UINT32_MAX)[NSException raise:NSInternalInconsistencyException format:@"Scene display identifiers exhausted"];
 NSScreen *screen=[NSScreen new];CPScreenState *s=[CPScreenState new];s.window=window;s.identifier=++lastIdentifier;
 objc_setAssociatedObject(screen,&screenStateKey,s,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
 s.cachedBounds=window.bounds;s.cachedInsets=window.safeAreaInsets;s.cachedScale=window.traitCollection.displayScale;Publish(s);
 @synchronized(NSScreen.class){mainScreen=screen;}[self cp_notifyNativeViewportChanged];
 __weak NSScreen *weakScreen=screen;
 s.disconnectObserver=[NSNotificationCenter.defaultCenter addObserverForName:UISceneDidDisconnectNotification object:window.windowScene queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){if(weakScreen&&NSScreen.mainScreen==weakScreen)[NSScreen cp_setMainNativeWindow:nil];}];
 CPScreenTimingTarget *target=[CPScreenTimingTarget new];target.screen=screen;
 if(@available(visionOS 27.0,*))s.displayLink=[window.windowScene displayLinkWithTarget:target selector:@selector(sample:)];
 else s.displayLink=[CADisplayLink displayLinkWithTarget:target selector:@selector(sample:)];
 [s.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
+ (void)cp_notifyNativeViewportChanged {
 Main();CPScreenState *s=mainScreen?objc_getAssociatedObject(mainScreen,&screenStateKey):nil;
 if(!s)return;
 UIWindow *window=s.window;
 if(!window.windowScene||window.windowScene.activationState==UISceneActivationStateUnattached){[self cp_setMainNativeWindow:nil];return;}
 CGRect bounds=window.bounds;UIEdgeInsets insets=window.safeAreaInsets;CGFloat scale=window.traitCollection.displayScale;
 if(s.viewportCached && CGRectEqualToRect(bounds,s.cachedBounds) && UIEdgeInsetsEqualToEdgeInsets(insets,s.cachedInsets) && scale==s.cachedScale)return;
 s.viewportCached=YES;s.cachedBounds=bounds;s.cachedInsets=insets;s.cachedScale=scale;
 Publish(s);
 CPRefreshSceneDisplaySnapshot();
 [NSNotificationCenter.defaultCenter postNotificationName:NSApplicationDidChangeScreenParametersNotification object:NSApplication.sharedApplication];
}
+ (NSScreen *)mainScreen {@synchronized(NSScreen.class){CPScreenState *s=mainScreen?objc_getAssociatedObject(mainScreen,&screenStateKey):nil;return [s.snapshot[@"connected"] boolValue]?mainScreen:nil;}}
+ (NSArray<NSScreen *> *)screens {NSScreen *screen=self.mainScreen;return screen?@[screen]:@[];}
- (UIWindow *)cp_nativeWindow {return State(self).window;}
- (CGRect)frame {return [Snapshot(self)[@"frame"] CGRectValue];}
- (CGRect)visibleFrame {return [Snapshot(self)[@"visible"] CGRectValue];}
- (CGFloat)backingScaleFactor {
 CGFloat scale=[Snapshot(self)[@"scale"] doubleValue];
 if(!isfinite(scale)||scale<=0)[NSException raise:NSInternalInconsistencyException format:@"Native scene does not provide a valid display scale"];
 return scale;
}
// This facade describes the host viewport, not the headset's physical panels.
// The current host explicitly presents SDR layers; HDR viewport negotiation is
// not implemented. Returning the supported SDR range lets the engine choose SDR.
- (CGFloat)maximumPotentialExtendedDynamicRangeColorComponentValue {
 (void)Snapshot(self);return 1.0;
}
- (CGFloat)maximumExtendedDynamicRangeColorComponentValue {
 (void)Snapshot(self);return 1.0;
}
- (BOOL)cp_refreshTimingReady {return [Snapshot(self)[@"period"] doubleValue]>0;}
- (NSTimeInterval)minimumRefreshInterval {
 double period=[Snapshot(self)[@"period"] doubleValue];
 if(period<=0)[NSException raise:NSInternalInconsistencyException format:@"No native scene display-link timing has been observed"];
 return period;
}
- (NSTimeInterval)maximumRefreshInterval {return self.minimumRefreshInterval;}
- (NSDictionary *)cp_refreshTimingEvidence {
 NSDictionary *s=Snapshot(self);
 return @{@"policy":@"SINGLE_OBSERVED_SCENE_CADENCE_NO_VRR_NEGOTIATION",@"ready":@([s[@"period"] doubleValue]>0),@"observed_duration_seconds":s[@"period"],@"observed_timestamp_seconds":s[@"timestamp"],@"physical_panel_range_measured":@NO};
}
- (uint32_t)cp_sceneDisplayIdentifier {return [Snapshot(self)[@"identifier"] unsignedIntValue];}
- (NSDictionary *)deviceDescription {NSDictionary *s=Snapshot(self);return @{@"NSScreenNumber":s[@"identifier"],@"NSDeviceSize":[NSValue valueWithCGSize:[s[@"frame"] CGRectValue].size]};}
@end
