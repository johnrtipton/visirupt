#import "CPApplicationEvents.h"
#import "CPScenePointer.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

NSApplication *NSApp;
static _Thread_local BOOL servicingNativePoll;
NSNotificationName const NSApplicationWillFinishLaunchingNotification = @"NSApplicationWillFinishLaunchingNotification";
NSNotificationName const NSApplicationDidFinishLaunchingNotification = @"NSApplicationDidFinishLaunchingNotification";
NSNotificationName const NSApplicationDidBecomeActiveNotification = @"NSApplicationDidBecomeActiveNotification";
NSNotificationName const NSApplicationWillResignActiveNotification = @"NSApplicationWillResignActiveNotification";
NSRunLoopMode const NSEventTrackingRunLoopMode = @"NSEventTrackingRunLoopMode";
NSNotificationName const NSApplicationDidChangeScreenParametersNotification=@"NSApplicationDidChangeScreenParametersNotification";
NSNotificationName const NSApplicationDidResignActiveNotification=@"NSApplicationDidResignActiveNotification";
NSNotificationName const NSWindowDidBecomeKeyNotification=@"NSWindowDidBecomeKeyNotification";
NSNotificationName const NSWindowDidResignKeyNotification=@"NSWindowDidResignKeyNotification";
NSNotificationName const NSWindowWillExitFullScreenNotification=@"NSWindowWillExitFullScreenNotification";
NSString * const NSImageHintInterpolation=@"NSImageHintInterpolation";

@interface CPResponderState : NSObject
@property (nullable, weak) NSResponder *next;
@end
@implementation CPResponderState @end
static char responderKey;
static CPResponderState *responderState(NSResponder *object) {
    @synchronized (object) {
        CPResponderState *state = objc_getAssociatedObject(object, &responderKey);
        if (!state) { state = [CPResponderState new]; objc_setAssociatedObject(object, &responderKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        return state;
    }
}
@implementation NSResponder
- (BOOL)acceptsFirstResponder { return NO; }
- (BOOL)becomeFirstResponder { return YES; }
- (BOOL)resignFirstResponder { return YES; }

- (NSResponder *)nextResponder { return responderState(self).next; }
- (void)setNextResponder:(NSResponder *)next { responderState(self).next = next; }
- (void)mouseMoved:(NSEvent *)event {[self.nextResponder mouseMoved:event];}
- (void)mouseDown:(NSEvent *)event {[self.nextResponder mouseDown:event];}
- (void)mouseUp:(NSEvent *)event {[self.nextResponder mouseUp:event];}
- (void)mouseDragged:(NSEvent *)event {[self.nextResponder mouseDragged:event];}
- (void)scrollWheel:(NSEvent *)event {[self.nextResponder scrollWheel:event];}
- (void)mouseEntered:(NSEvent *)event {[self.nextResponder mouseEntered:event];}
- (void)mouseExited:(NSEvent *)event {[self.nextResponder mouseExited:event];}
- (void)keyDown:(NSEvent *)event { [self.nextResponder keyDown:event]; }
- (void)keyUp:(NSEvent *)event { [self.nextResponder keyUp:event]; }
@end

@interface CPEventState : NSObject
@property (nullable, strong) NSTrackingArea *trackingArea;
@property NSEventType type;
@property NSUInteger flags;
@property unsigned short key;
@property (copy) NSString *characters,*unmodified;
@property NSUInteger clickCount;
@property NSTimeInterval timestamp;
@property CGPoint location;
@property CGPoint delta;
@property BOOL precise;
@property NSUInteger phase;
@property (nullable, weak) id window;
@end
@implementation CPEventState @end
static char eventKey;
static CPEventState *eventState(NSEvent *event) {
    CPEventState *state = objc_getAssociatedObject(event, &eventKey);
    if (!state) [NSException raise:NSInternalInconsistencyException format:@"NSEvent has no translated native input data"];
    return state;
}

@interface CPMonitor : NSObject
@property NSEventMask mask;
@property (copy) NSEvent * _Nullable (^handler)(NSEvent *);
@end
@implementation CPMonitor @end

@interface CPApplicationState : NSObject
@property NSUInteger requestedPresentationOptions;
@property (strong) NSCondition *condition;
@property (strong) NSMutableArray<NSEvent *> *events;
@property (strong) NSMutableArray<CPMonitor *> *monitors;
@property (nullable, weak) id<NSApplicationDelegate> delegate;
@property (nullable, weak) id window;
@property (nullable, weak) id primaryWindow;
@property (nullable, strong) NSEvent *current;
@property BOOL launchStarted;
@property BOOL active;
@property BOOL activationTransition;
@property BOOL pendingActivation;
@property BOOL requestedActivation;
@property BOOL keyTransition;
@property BOOL pendingKey;
@property (nullable,strong) id requestedKey;
@end
@implementation CPApplicationState
- (instancetype)init {
    if ((self = [super init])) { _condition = [NSCondition new]; _events = [NSMutableArray new]; _monitors = [NSMutableArray new]; }
    return self;
}
@end
static char applicationKey;
static CPApplicationState *applicationState(NSApplication *application) {
    @synchronized (application) {
        CPApplicationState *state = objc_getAssociatedObject(application, &applicationKey);
        if (!state) { state = [CPApplicationState new]; objc_setAssociatedObject(application, &applicationKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        return state;
    }
}
static BOOL matches(NSEventMask mask, NSEvent *event) {
    return event.type < sizeof(NSEventMask) * CHAR_BIT && (mask & ((NSEventMask)1 << event.type)) != 0;
}

@implementation NSEvent
+ (void)setMouseCoalescingEnabled:(BOOL)enabled {
 // The host queues every motion callback UIKit delivers. We cannot change
 // UIKit's upstream sampling or combine callbacks in this bounded adapter.
 if(enabled)[NSException raise:NSInvalidArgumentException format:@"Native host event coalescing is not implemented"];
}
+ (BOOL)isMouseCoalescingEnabled {return NO;}
+ (CGPoint)mouseLocation {
 CGPoint point;
 if(!CPSceneReadMouseLocation(&point))[NSException raise:NSInternalInconsistencyException format:@"No observed pointer position in the live native viewport is available"];
 return point;
}
+ (instancetype)cp_eventWithType:(NSEventType)type keyCode:(unsigned short)keyCode modifierFlags:(NSUInteger)flags timestamp:(NSTimeInterval)timestamp location:(CGPoint)location delta:(CGPoint)delta preciseScroll:(BOOL)precise window:(id)window {
    if (type >= sizeof(NSEventMask) * CHAR_BIT) [NSException raise:NSInvalidArgumentException format:@"Event type cannot be represented by an NSEventMask"];
    NSEvent *event = [self new]; CPEventState *state = [CPEventState new];
    state.type = type; state.key = keyCode; state.flags = flags; state.timestamp = timestamp;
    state.location = location; state.delta = delta; state.precise = precise; state.window = window;
    objc_setAssociatedObject(event, &eventKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return event;
}
- (NSTrackingArea *)trackingArea {return eventState(self).trackingArea;}
- (void)cp_setTrackingArea:(NSTrackingArea *)area {if(self.type!=8&&self.type!=9)[NSException raise:NSInvalidArgumentException format:@"Tracking metadata requires an enter/exit event"];eventState(self).trackingArea=area;}
- (NSEventType)type { return eventState(self).type; }
- (NSUInteger)modifierFlags { return eventState(self).flags; }
- (unsigned short)keyCode { return eventState(self).key; }
- (NSString *)characters {return eventState(self).characters?:@"";}
- (NSString *)charactersIgnoringModifiers {return eventState(self).unmodified?:@"";}
- (BOOL)isARepeat {return NO; /* Only native press-began/ended callbacks are translated. */}
- (NSInteger)buttonNumber {if(self.type!=1&&self.type!=2&&self.type!=6)[NSException raise:NSInvalidArgumentException format:@"No button metadata for this event"];return 0;}
- (NSInteger)clickCount {return eventState(self).clickCount;}
- (void)cp_setKeyCharacters:(NSString *)characters ignoringModifiers:(NSString *)unmodified {if(self.type!=10&&self.type!=11)[NSException raise:NSInvalidArgumentException format:@"Key text requires keyboard event"];eventState(self).characters=characters;eventState(self).unmodified=unmodified;}
- (void)cp_setClickCount:(NSUInteger)count {if(self.type!=1&&self.type!=2)[NSException raise:NSInvalidArgumentException format:@"Click count requires primary button event"];eventState(self).clickCount=count;}

- (NSTimeInterval)timestamp { return eventState(self).timestamp; }
- (CGPoint)locationInWindow { return eventState(self).location; }
- (CGFloat)deltaX { return eventState(self).delta.x; }
- (CGFloat)deltaY { return eventState(self).delta.y; }
- (CGFloat)scrollingDeltaX { return eventState(self).delta.x; }
- (CGFloat)scrollingDeltaY { return eventState(self).delta.y; }
- (BOOL)hasPreciseScrollingDeltas { return eventState(self).precise; }
- (NSUInteger)phase {return eventState(self).phase;}
- (NSUInteger)momentumPhase {return 0; /* UIKit pan callbacks do not expose separate momentum phases. */}
- (void)cp_setScrollPhase:(NSUInteger)phase {if(self.type!=22)[NSException raise:NSInvalidArgumentException format:@"Scroll phase requires scroll event"];eventState(self).phase=phase;}

- (id)window { return eventState(self).window; }
+ (id)addLocalMonitorForEventsMatchingMask:(NSEventMask)mask handler:(NSEvent * _Nullable (^)(NSEvent *))handler {
    if (!handler) [NSException raise:NSInvalidArgumentException format:@"A local event monitor requires a handler"];
    CPMonitor *monitor = [CPMonitor new]; monitor.mask = mask; monitor.handler = handler;
    CPApplicationState *state = applicationState(NSApplication.sharedApplication);
    [state.condition lock]; [state.monitors addObject:monitor]; [state.condition unlock];
    return monitor;
}
+ (void)removeMonitor:(id)monitor {
    CPApplicationState *state = applicationState(NSApplication.sharedApplication);
    [state.condition lock]; [state.monitors removeObjectIdenticalTo:monitor]; [state.condition unlock];
}
@end

@protocol CPEventWindow <NSObject>
- (void)sendEvent:(NSEvent *)event;
@end
@implementation NSApplication
- (NSUInteger)presentationOptions {return 0; /* Native windowed presentation; no desktop cursor assistance. */}
- (NSUInteger)cp_requestedPresentationOptions {return applicationState(self).requestedPresentationOptions;}
- (void)setPresentationOptions:(NSUInteger)options {
 if(options!=0&&options!=4096)[NSException raise:NSInvalidArgumentException format:@"Unaudited desktop presentation option"];
 applicationState(self).requestedPresentationOptions=options;
 NSURL *documents=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
 NSDictionary *r=@{@"requested_options":@(options),@"actual_options":@0,@"status":@"UNSUPPORTED_DESKTOP_CURSOR_LOCATION_ASSISTANCE"};
 [[NSJSONSerialization dataWithJSONObject:r options:NSJSONWritingPrettyPrinted error:nil] writeToURL:[documents URLByAppendingPathComponent:@"host-presentation-policy.json"] options:NSDataWritingAtomic error:nil];
}
+ (instancetype)sharedApplication {
    static dispatch_once_t once; dispatch_once(&once, ^{ NSApp = [self new]; });
    return NSApp;
}
- (id<NSApplicationDelegate>)delegate { return applicationState(self).delegate; }
- (void)setDelegate:(id<NSApplicationDelegate>)delegate { applicationState(self).delegate = delegate; }
static BOOL NativeMainWindowEligible(id window) {
 SEL selector=NSSelectorFromString(@"cp_acceptsNativeKeyWindow");
 if(!window||![window respondsToSelector:selector])return NO;
 BOOL (*send)(id,SEL)=(void *)[window methodForSelector:selector];return send(window,selector);
}
- (id)mainWindow {
 if(!NSThread.isMainThread)[NSException raise:NSInternalInconsistencyException format:@"Native main-window queries require the main thread"];
 id primary=applicationState(self).primaryWindow;return NativeMainWindowEligible(primary)?primary:nil;
}
- (void)cp_setMainWindow:(id)window {
 if(!NSThread.isMainThread)[NSException raise:NSInternalInconsistencyException format:@"Native main-window changes require the main thread"];
 if(window&&!NativeMainWindowEligible(window))[NSException raise:NSInternalInconsistencyException format:@"Main window must be attached and visible"];
 applicationState(self).primaryWindow=window;
}
- (id)keyWindow { return applicationState(self).window; }
- (void)cp_setKeyWindow:(id)window {
 if(!NSThread.isMainThread)[NSException raise:NSInternalInconsistencyException format:@"Native key-window changes require the main thread"];
 CPApplicationState *state=applicationState(self);state.requestedKey=window;state.pendingKey=YES;
 if(state.keyTransition)return;state.keyTransition=YES;
 @try {
  while(state.pendingKey) {
   id requested=state.requestedKey;state.pendingKey=NO;id old=state.window;
   if(old==requested)continue;
   state.window=nil;
   if(old)[NSNotificationCenter.defaultCenter postNotificationName:NSWindowDidResignKeyNotification object:old];
   // A resignation observer may request another target. Do not publish a
   // stale become-key notification for the superseded request.
   if(state.pendingKey)continue;
   state.window=requested;
   if(NativeMainWindowEligible(requested)&&!NativeMainWindowEligible(state.primaryWindow))state.primaryWindow=requested;
   if(requested)[NSNotificationCenter.defaultCenter postNotificationName:NSWindowDidBecomeKeyNotification object:requested];
  }
 } @finally {state.keyTransition=NO;state.requestedKey=nil;}
}
- (NSEvent *)currentEvent { return applicationState(self).current; }
- (BOOL)isActive { return applicationState(self).active; }
- (void)cp_setActiveFromNativeScene:(BOOL)active {
    if (!NSThread.isMainThread) [NSException raise:NSInternalInconsistencyException format:@"Native scene activation must arrive on the main UI thread"];
    CPApplicationState *state = applicationState(self);
    state.requestedActivation = active;
    state.pendingActivation = YES;
    if (state.activationTransition) return;
    state.activationTransition = YES;
    @try {
        while (state.pendingActivation) {
            BOOL requested = state.requestedActivation;
            state.pendingActivation = NO;
            if (state.active == requested) continue;
            NSNotificationName name = requested ? NSApplicationDidBecomeActiveNotification : NSApplicationWillResignActiveNotification;
            NSNotification *note = [NSNotification notificationWithName:name object:self];
            id<NSApplicationDelegate> delegate = state.delegate;
            if (requested) {
                state.active = YES;
                if ([delegate respondsToSelector:@selector(applicationDidBecomeActive:)]) [delegate applicationDidBecomeActive:note];
                [NSNotificationCenter.defaultCenter postNotification:note];
            } else {
                if ([delegate respondsToSelector:@selector(applicationWillResignActive:)]) [delegate applicationWillResignActive:note];
                [NSNotificationCenter.defaultCenter postNotification:note];
                state.active = NO;
                NSNotification *did=[NSNotification notificationWithName:NSApplicationDidResignActiveNotification object:self];
                if([delegate respondsToSelector:@selector(applicationDidResignActive:)])[delegate applicationDidResignActive:did];
                [NSNotificationCenter.defaultCenter postNotification:did];
            }
        }
    } @finally {
        state.activationTransition = NO;
    }
}
- (void)finishLaunching {
    CPApplicationState *state = applicationState(self);
    @synchronized (self) { if (state.launchStarted) return; state.launchStarted = YES; }
    id<NSApplicationDelegate> delegate = state.delegate;
    NSNotification *will = [NSNotification notificationWithName:NSApplicationWillFinishLaunchingNotification object:self];
    if ([delegate respondsToSelector:@selector(applicationWillFinishLaunching:)]) [delegate applicationWillFinishLaunching:will];
    [NSNotificationCenter.defaultCenter postNotification:will];
    NSNotification *did = [NSNotification notificationWithName:NSApplicationDidFinishLaunchingNotification object:self];
    if ([delegate respondsToSelector:@selector(applicationDidFinishLaunching:)]) [delegate applicationDidFinishLaunching:did];
    [NSNotificationCenter.defaultCenter postNotification:did];
}
- (void)postEvent:(NSEvent *)event atStart:(BOOL)atStart {
    if (!event) [NSException raise:NSInvalidArgumentException format:@"Cannot queue a nil event"];
    CPApplicationState *state = applicationState(self);
    [state.condition lock];
    if (atStart) [state.events insertObject:event atIndex:0]; else [state.events addObject:event];
    [state.condition broadcast]; [state.condition unlock];
}
- (NSEvent *)nextEventMatchingMask:(NSEventMask)mask untilDate:(NSDate *)expiration inMode:(NSRunLoopMode)mode dequeue:(BOOL)dequeue {
    CPApplicationState *state = applicationState(self);
    // AppKit's documented nil expiration is a nonblocking poll.
    NSDate *deadline = expiration ?: NSDate.distantPast;
    // A legacy game loop can poll continuously without returning to UIKit's
    // outer run loop. Service already-ready native work and commit its layer
    // changes while retaining the nonblocking event deadline.
    if(NSThread.isMainThread&&deadline.timeIntervalSinceNow<=0&&!servicingNativePoll) {
        servicingNativePoll=YES;
        @try {
            [NSRunLoop.currentRunLoop runMode:mode beforeDate:NSDate.date];
            [CATransaction flush];
        } @finally {servicingNativePoll=NO;}
    }
    [state.condition lock];
    while (YES) {
        NSUInteger index = [state.events indexOfObjectPassingTest:^BOOL(NSEvent *event, NSUInteger i, BOOL *stop) { (void)i; (void)stop; return matches(mask, event); }];
        if (index != NSNotFound) {
            NSEvent *event = state.events[index]; if (dequeue) [state.events removeObjectAtIndex:index];
            state.current = event;
            [state.condition unlock]; return event;
        }
        if (deadline.timeIntervalSinceNow <= 0) { [state.condition unlock]; return nil; }
        if (!NSThread.isMainThread) { [state.condition waitUntilDate:deadline]; continue; }
        // Keep native main-run-loop input deliverable while a guest polls.
        // Thread ownership and full UIKit/game integration are later gates.
        NSDate *slice = [NSDate dateWithTimeIntervalSinceNow:MIN(0.01, deadline.timeIntervalSinceNow)];
        [state.condition unlock];
        BOOL ran = [NSRunLoop.currentRunLoop runMode:mode beforeDate:slice];
        [state.condition lock];
        if (!ran) [state.condition waitUntilDate:slice];
    }
}
- (void)sendEvent:(NSEvent *)event {
    if(!NSThread.isMainThread)[NSException raise:NSInternalInconsistencyException format:@"Native event delivery requires the main thread"];
    CPApplicationState *state = applicationState(self);NSEvent *previous=state.current;state.current=event;
    @try {
    [state.condition lock]; NSArray<CPMonitor *> *monitors = state.monitors.copy; [state.condition unlock];
    NSEvent *filtered = event;
    for (CPMonitor *monitor in monitors) {
        if (matches(monitor.mask, filtered)) { filtered = monitor.handler(filtered); if (!filtered) return; }
    }
    state.current=filtered;
    id<CPEventWindow> target = filtered.window ?: state.window;
    if (target) {
        if (![target respondsToSelector:@selector(sendEvent:)]) [NSException raise:NSInternalInconsistencyException format:@"Host window cannot dispatch NSEvent"];
        [target sendEvent:filtered];
    }
    } @finally {state.current=previous;}
}
@end
