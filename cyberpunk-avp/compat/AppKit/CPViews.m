#import "CPViews.h"
#import "CPCursors.h"
#import "CPTrackingAreas.h"
#import "CPWindows.h"
#import "CPScenePointer.h"
#import <objc/runtime.h>
#import <math.h>

static void requireMainThread(void) {
    if (!NSThread.isMainThread)
        [NSException raise:NSInternalInconsistencyException format:@"Native view operations require the main UI thread"];
}
@interface CPCursorRegion : NSObject
@property CGRect rect;
@property (strong) NSCursor *cursor;
@end
@implementation CPCursorRegion @end
@interface CPViewState : NSObject
@property (strong) UIView *native;
@property (strong) NSMutableArray<NSTrackingArea *> *tracking;
@property (strong) UIHoverGestureRecognizer *hover;
@property NSUInteger nativeHoverSamples;
@property CGPoint lastHoverPoint;
@property BOOL hasLastHoverPoint;
@property BOOL trackingTransition;
@property BOOL pendingTracking;
@property CGPoint requestedPoint;
@property BOOL requestedPresent;
@property NSTimeInterval requestedTime;
@property NSUInteger requestedModifiers;
@property (strong) NSMutableArray<CPCursorRegion *> *cursorRegions;
@property (strong) UIPointerInteraction *pointer;
@property (strong) NSArray *cursorObservers;
@property BOOL primaryDown;
@property CGPoint primaryPoint;
@property (strong) UIPanGestureRecognizer *scroll;
@property (nullable, weak) NSWindow *window;
@property (nullable, strong) CALayer *guestLayer;
@end
@implementation CPViewState
- (void)dealloc {for(id token in _cursorObservers)[NSNotificationCenter.defaultCenter removeObserver:token];}
@end
static char viewKey;
static CPViewState *viewState(NSView *view) {
    requireMainThread();
    CPViewState *state = objc_getAssociatedObject(view, &viewKey);
    if (!state) [NSException raise:NSInternalInconsistencyException format:@"NSView has not initialized its native view"];
    return state;
}
@interface CPBackingView : UIView <UIPointerInteractionDelegate,UIGestureRecognizerDelegate>
@property (nullable, weak) NSView *owner;
@end
@implementation CPBackingView
- (void)cp_hoverChanged:(UIHoverGestureRecognizer *)gesture {
 if(!self.owner)return;CPViewState *state=viewState(self.owner);state.nativeHoverSamples++;
 NSWindow *window=self.owner.window;CGPoint point=[gesture locationInView:self];
 CPSceneObserveMouseLocation(self,point,gesture.state==UIGestureRecognizerStateBegan||gesture.state==UIGestureRecognizerStateChanged);
 if(gesture.state==UIGestureRecognizerStateBegan||gesture.state==UIGestureRecognizerStateChanged) {
  if(gesture.state==UIGestureRecognizerStateChanged&&window.acceptsMouseMovedEvents&&window.isVisible&&window.isKeyWindow) {
   CGPoint native=[self convertPoint:point toView:window.cp_nativeContent];
   CGPoint location=CGPointMake(native.x,window.cp_nativeContent.bounds.size.height-native.y);
   CGPoint delta=state.hasLastHoverPoint?CGPointMake(point.x-state.lastHoverPoint.x,point.y-state.lastHoverPoint.y):CGPointZero;
   NSEvent *event=[NSEvent cp_eventWithType:5 keyCode:0 modifierFlags:gesture.modifierFlags timestamp:NSProcessInfo.processInfo.systemUptime location:location delta:delta preciseScroll:NO window:window];
   [NSApplication.sharedApplication postEvent:event atStart:NO];
  }
  state.lastHoverPoint=point;state.hasLastHoverPoint=YES;
 } else {state.hasLastHoverPoint=NO;}
 BOOL present=gesture.state==UIGestureRecognizerStateBegan||gesture.state==UIGestureRecognizerStateChanged;
 if(present||gesture.state==UIGestureRecognizerStateEnded||gesture.state==UIGestureRecognizerStateCancelled)
  [self.owner cp_updateTrackingAtNativePoint:[gesture locationInView:self] present:present timestamp:NSProcessInfo.processInfo.systemUptime modifierFlags:gesture.modifierFlags];
}
- (UIPointerRegion *)pointerInteraction:(UIPointerInteraction *)interaction regionForRequest:(UIPointerRegionRequest *)request defaultRegion:(UIPointerRegion *)defaultRegion {
 return self.owner ? [self.owner cp_cursorRegionAtPoint:request.location] : nil;
}
- (UIPointerStyle *)pointerInteraction:(UIPointerInteraction *)interaction styleForRegion:(UIPointerRegion *)region {
 CPCursorRegion *record=(id)region.identifier;
 if(!self.owner || ![viewState(self.owner).cursorRegions containsObject:record])return nil;
 return [record.cursor cp_nativePointerStyle];
}
- (void)pointerInteraction:(UIPointerInteraction *)interaction willEnterRegion:(UIPointerRegion *)region animator:(id<UIPointerInteractionAnimating>)animator {
 CPCursorRegion *record=(id)region.identifier;
 if(self.owner && [viewState(self.owner).cursorRegions containsObject:record])[NSCursor cp_nativeRegionEntered:record cursor:record.cursor];
}
- (void)pointerInteraction:(UIPointerInteraction *)interaction willExitRegion:(UIPointerRegion *)region animator:(id<UIPointerInteractionAnimating>)animator { [NSCursor cp_nativeRegionExited:region.identifier]; }
// Log only bounded event types/codes, never typed text. This records native
// callback delivery; it does not assert that the original game consumed it.
- (void)cp_traceInput:(NSEvent *)event {
 static NSUInteger count;if(count++>=128)return;
 NSURL *url=[[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"native-input-events.jsonl"];
 NSDictionary *record=@{@"type":@(event.type),@"key_code":@(event.keyCode),@"timestamp":@(event.timestamp),@"delta_x":@(event.deltaX),@"delta_y":@(event.deltaY),@"source":@"UIKit backing view callback"};
 NSMutableData *data=[[NSJSONSerialization dataWithJSONObject:record options:0 error:nil] mutableCopy];[data appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
 if(![NSFileManager.defaultManager fileExistsAtPath:url.path])[NSData.data writeToURL:url atomically:YES];
 NSFileHandle *file=[NSFileHandle fileHandleForWritingToURL:url error:nil];[file seekToEndOfFile];[file writeData:data];[file closeFile];
}
- (BOOL)cp_inputEligible {NSWindow *window=self.owner.window;return window&&window.isKeyWindow&&window.isVisible&&self.window!=nil&&!self.hidden;}
- (BOOL)cp_translateTouch:(NSSet<UITouch *> *)touches event:(UIEvent *)native down:(BOOL)down {
 if(!self.owner||touches.count!=1)return NO;CPViewState *state=viewState(self.owner);UITouch *touch=touches.anyObject;
 if(touch.type!=UITouchTypeIndirectPointer&&touch.type!=UITouchTypeDirect)return NO;
 if(down&&touch.type==UITouchTypeIndirectPointer&&!(native.buttonMask&UIEventButtonMaskPrimary))return NO;
 if(!down&&!state.primaryDown)return NO;
 if(![self cp_inputEligible]){state.primaryDown=NO;return NO;}
 CGPoint point=[touch locationInView:self];CPSceneObserveMouseLocation(self,point,YES);
 CGPoint content=[self convertPoint:point toView:self.owner.window.cp_nativeContent];content.y=CGRectGetMinY(self.owner.window.cp_nativeContent.bounds)+CGRectGetMaxY(self.owner.window.cp_nativeContent.bounds)-content.y;
 if(down){if(state.primaryDown)return YES;[self.owner.window makeFirstResponder:self.owner];}
 NSEvent *event=[NSEvent cp_eventWithType:down?1:2 keyCode:0 modifierFlags:native.modifierFlags timestamp:touch.timestamp location:content delta:CGPointZero preciseScroll:NO window:self.owner.window];[event cp_setClickCount:touch.tapCount];
 state.primaryPoint=point;state.primaryDown=down;[self cp_traceInput:event];[NSApplication.sharedApplication postEvent:event atStart:NO];return YES;
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {if(![self cp_translateTouch:touches event:event down:YES])[super touchesBegan:touches withEvent:event];}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {if(![self cp_translateTouch:touches event:event down:NO])[super touchesEnded:touches withEvent:event];}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)native {
 if(!self.owner||touches.count!=1){[super touchesMoved:touches withEvent:native];return;}
 CPViewState *state=viewState(self.owner);if(!state.primaryDown||![self cp_inputEligible]){[super touchesMoved:touches withEvent:native];return;}
 UITouch *touch=touches.anyObject;CGPoint point=[touch locationInView:self];CPSceneObserveMouseLocation(self,point,YES);
 CGPoint content=[self convertPoint:point toView:self.owner.window.cp_nativeContent];content.y=CGRectGetMinY(self.owner.window.cp_nativeContent.bounds)+CGRectGetMaxY(self.owner.window.cp_nativeContent.bounds)-content.y;
 CGPoint delta=CGPointMake(point.x-state.primaryPoint.x,point.y-state.primaryPoint.y);state.primaryPoint=point;
 NSEvent *event=[NSEvent cp_eventWithType:6 keyCode:0 modifierFlags:native.modifierFlags timestamp:touch.timestamp location:content delta:delta preciseScroll:NO window:self.owner.window];[self cp_traceInput:event];[NSApplication.sharedApplication postEvent:event atStart:NO];
}
- (void)cp_scrollChanged:(UIPanGestureRecognizer *)gesture {
 CGPoint delta=[gesture translationInView:self];[gesture setTranslation:CGPointZero inView:self];
 if(![self cp_inputEligible]||!isfinite(delta.x)||!isfinite(delta.y))return;
 NSUInteger phase;
 switch(gesture.state){case UIGestureRecognizerStateBegan:phase=1;break;case UIGestureRecognizerStateChanged:phase=4;break;case UIGestureRecognizerStateEnded:phase=8;break;case UIGestureRecognizerStateCancelled:phase=16;break;default:return;}
 if(phase==4&&CGPointEqualToPoint(delta,CGPointZero))return;
 CGPoint point=[gesture locationInView:self];CPSceneObserveMouseLocation(self,point,YES);
 CGPoint content=[self convertPoint:point toView:self.owner.window.cp_nativeContent];content.y=CGRectGetMinY(self.owner.window.cp_nativeContent.bounds)+CGRectGetMaxY(self.owner.window.cp_nativeContent.bounds)-content.y;
 // Continuous UIKit trackpad translation is delivered in points. Preserve its
 // signed content-motion delta; physical direction acceptance is tested separately.
 NSEvent *event=[NSEvent cp_eventWithType:22 keyCode:0 modifierFlags:gesture.modifierFlags timestamp:NSProcessInfo.processInfo.systemUptime location:content delta:delta preciseScroll:YES window:self.owner.window];[event cp_setScrollPhase:phase];[self cp_traceInput:event];[NSApplication.sharedApplication postEvent:event atStart:NO];
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
 if(!self.owner)return NO;CPViewState *state=viewState(self.owner);return (gesture==state.scroll&&other==state.hover)||(gesture==state.hover&&other==state.scroll);
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {if(![self cp_translateTouch:touches event:event down:NO])[super touchesCancelled:touches withEvent:event];}
- (NSSet<UIPress *> *)cp_translatePresses:(NSSet<UIPress *> *)presses down:(BOOL)down {
 NSMutableSet *unhandled=[NSMutableSet new];
 for(UIPress *press in presses){UIKey *key=press.key;unsigned short code;
  switch(key.keyCode){case UIKeyboardHIDUsageKeyboardLeftArrow:code=123;break;case UIKeyboardHIDUsageKeyboardRightArrow:code=124;break;case UIKeyboardHIDUsageKeyboardW:code=13;break;case UIKeyboardHIDUsageKeyboardA:code=0;break;case UIKeyboardHIDUsageKeyboardS:code=1;break;case UIKeyboardHIDUsageKeyboardD:code=2;break;case UIKeyboardHIDUsageKeyboardSpacebar:code=49;break;case UIKeyboardHIDUsageKeyboardReturnOrEnter:code=36;break;case UIKeyboardHIDUsageKeyboardEscape:code=53;break;default:[unhandled addObject:press];continue;}
  if(!key||![self cp_inputEligible]||!self.isFirstResponder){[unhandled addObject:press];continue;}
  NSEvent *event=[NSEvent cp_eventWithType:down?10:11 keyCode:code modifierFlags:key.modifierFlags timestamp:press.timestamp location:CGPointZero delta:CGPointZero preciseScroll:NO window:self.owner.window];[event cp_setKeyCharacters:key.characters ignoringModifiers:key.charactersIgnoringModifiers];
  [self cp_traceInput:event];[NSApplication.sharedApplication postEvent:event atStart:NO];
 }return unhandled;
}
- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {NSSet *unhandled=[self cp_translatePresses:presses down:YES];if(unhandled.count)[super pressesBegan:unhandled withEvent:event];}
- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {NSSet *unhandled=[self cp_translatePresses:presses down:NO];if(unhandled.count)[super pressesEnded:unhandled withEvent:event];}
- (void)pressesCancelled:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {NSSet *unhandled=[self cp_translatePresses:presses down:NO];if(unhandled.count)[super pressesCancelled:unhandled withEvent:event];}
- (void)didMoveToWindow {
 [super didMoveToWindow];if(!self.window && self.owner){for(CPCursorRegion *record in viewState(self.owner).cursorRegions)[NSCursor cp_nativeRegionExited:record];for(NSTrackingArea *area in viewState(self.owner).tracking)area.cp_pointerInside=NO;}
}
- (BOOL)canBecomeFirstResponder { return self.owner && [self.owner acceptsFirstResponder]; }
- (BOOL)becomeFirstResponder {
    if (!self.owner || ![self.owner acceptsFirstResponder] || ![self.owner becomeFirstResponder]) return NO;
    return [super becomeFirstResponder];
}
- (BOOL)resignFirstResponder {
    if (self.owner && ![self.owner resignFirstResponder]) return NO;
    return [super resignFirstResponder];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CALayer *layer = self.owner ? viewState(self.owner).guestLayer : nil;
    if(self.owner){[self.owner updateTrackingAreas];[self.owner resetCursorRects];[viewState(self.owner).pointer invalidate];}
    if (layer) { [CATransaction begin]; [CATransaction setDisableActions:YES]; layer.frame = self.bounds; [CATransaction commit]; }
}
@end

@implementation NSView
- (instancetype)init { return [self initWithFrame:CGRectZero]; }
- (instancetype)initWithFrame:(CGRect)frame {
    requireMainThread();
    if ((self = [super init])) {
        CPViewState *state = [CPViewState new];
        CPBackingView *native = [[CPBackingView alloc] initWithFrame:frame];
        native.owner = self; state.native = native;state.cursorRegions=[NSMutableArray new];state.tracking=[NSMutableArray new];state.hover=[[UIHoverGestureRecognizer alloc]initWithTarget:native action:@selector(cp_hoverChanged:)];state.pointer=[[UIPointerInteraction alloc]initWithDelegate:native];
        objc_setAssociatedObject(self, &viewKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);[native addInteraction:state.pointer];[native addGestureRecognizer:state.hover];
        state.scroll=[[UIPanGestureRecognizer alloc]initWithTarget:native action:@selector(cp_scrollChanged:)];state.scroll.allowedScrollTypesMask=UIScrollTypeMaskContinuous;state.scroll.allowedTouchTypes=@[];state.scroll.cancelsTouchesInView=NO;state.scroll.delegate=native;[native addGestureRecognizer:state.scroll];
        __weak NSView *weakView=self;NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
        id resignWindow=[center addObserverForName:NSWindowDidResignKeyNotification object:nil queue:nil usingBlock:^(NSNotification *note){NSView *view=weakView;if(view && view.window==note.object)[view cp_deactivateCursorRegions];}];
        id resignApplication=[center addObserverForName:NSApplicationDidResignActiveNotification object:NSApplication.sharedApplication queue:nil usingBlock:^(NSNotification *note){NSView *view=weakView;if(view)[view cp_deactivateCursorRegions];}];
        state.cursorObservers=@[resignWindow,resignApplication];
    }
    return self;
}
- (void)updateTrackingAreas { /* Subclass supplies areas using current native geometry. */ }
- (NSArray<NSTrackingArea *> *)trackingAreas {return viewState(self).tracking.copy;}
- (UIHoverGestureRecognizer *)cp_hoverRecognizer {return viewState(self).hover;}
- (UIPanGestureRecognizer *)cp_scrollRecognizer {return viewState(self).scroll;}
- (NSUInteger)cp_nativeHoverSampleCount {return viewState(self).nativeHoverSamples;}
- (void)addTrackingArea:(NSTrackingArea *)area {
 CPViewState *state=viewState(self);if(![area isKindOfClass:NSTrackingArea.class]||(area.cp_attachedView&&area.cp_attachedView!=self))[NSException raise:NSInvalidArgumentException format:@"Tracking area is already attached to another view"];
 if([state.tracking containsObject:area])return;area.cp_attachedView=self;area.cp_pointerInside=NO;[state.tracking addObject:area];
}
- (void)removeTrackingArea:(NSTrackingArea *)area {CPViewState *state=viewState(self);if(![state.tracking containsObject:area])return;area.cp_pointerInside=NO;area.cp_attachedView=nil;[state.tracking removeObject:area];}
- (void)cp_updateTrackingAtNativePoint:(CGPoint)point present:(BOOL)present timestamp:(NSTimeInterval)timestamp modifierFlags:(NSUInteger)flags {
 CPViewState *state=viewState(self);if(!isfinite(point.x)||!isfinite(point.y)||!isfinite(timestamp)||timestamp<0)[NSException raise:NSInvalidArgumentException format:@"Invalid native pointer sample"];
 state.requestedPoint=point;state.requestedPresent=present;state.requestedTime=timestamp;state.requestedModifiers=flags;state.pendingTracking=YES;if(state.trackingTransition)return;state.trackingTransition=YES;
 @try {while(state.pendingTracking){point=state.requestedPoint;present=state.requestedPresent;timestamp=state.requestedTime;flags=state.requestedModifiers;state.pendingTracking=NO;
  BOOL eligible=self.window.isKeyWindow&&self.window.isVisible&&state.native.window!=nil;
  for(UIView *ancestor=state.native;ancestor;ancestor=ancestor.superview)if(ancestor.hidden)eligible=NO;
  NSArray *areas=state.tracking.copy;
  for(NSTrackingArea *area in areas){if(area.cp_attachedView!=self)continue;
   if(!eligible){area.cp_pointerInside=NO;continue;}
   CGRect rect=area.rect;if(!self.isFlipped)rect.origin.y=CGRectGetMinY(state.native.bounds)+CGRectGetMaxY(state.native.bounds)-CGRectGetMaxY(rect);
   BOOL inside=present&&CGRectContainsPoint(CGRectIntersection(rect,state.native.bounds),point);
   if(inside==area.cp_pointerInside)continue;area.cp_pointerInside=inside;
   CGPoint windowPoint=[state.native convertPoint:point toView:self.window.cp_nativeContent];windowPoint.y=CGRectGetMinY(self.window.cp_nativeContent.bounds)+CGRectGetMaxY(self.window.cp_nativeContent.bounds)-windowPoint.y;
   NSEvent *event=[NSEvent cp_eventWithType:inside?8:9 keyCode:0 modifierFlags:flags timestamp:timestamp location:windowPoint delta:CGPointZero preciseScroll:NO window:self.window];[event cp_setTrackingArea:area];
   [NSApplication.sharedApplication sendEvent:event];if(state.pendingTracking)break;
  }
 }} @finally {state.trackingTransition=NO;}
}
- (UIPointerInteraction *)cp_pointerInteraction {return viewState(self).pointer;}
- (BOOL)isFlipped {return NO;}
- (void)cp_deactivateCursorRegions {CPViewState *state=viewState(self);for(NSTrackingArea *area in state.tracking)area.cp_pointerInside=NO;for(CPCursorRegion *record in state.cursorRegions)[NSCursor cp_nativeRegionExited:record];[state.pointer invalidate];}
- (void)discardCursorRects {
 CPViewState *state=viewState(self);for(CPCursorRegion *record in state.cursorRegions)[NSCursor cp_nativeRegionExited:record];[state.cursorRegions removeAllObjects];[state.pointer invalidate];
}
- (void)resetCursorRects {[self discardCursorRects];}
- (void)addCursorRect:(CGRect)rect cursor:(NSCursor *)cursor {
 CPViewState *state=viewState(self);
 if(!cursor||!isfinite(rect.origin.x)||!isfinite(rect.origin.y)||!isfinite(rect.size.width)||!isfinite(rect.size.height)||rect.size.width<0||rect.size.height<0)[NSException raise:NSInvalidArgumentException format:@"Invalid scene cursor rectangle"];
 // Validate presentation before publishing a region; do not silently hide an unknown image.
 [cursor cp_nativePointerStyle];CPCursorRegion *record=[CPCursorRegion new];record.rect=rect;record.cursor=cursor;[state.cursorRegions addObject:record];[state.pointer invalidate];
}
- (UIPointerRegion *)cp_cursorRegionAtPoint:(CGPoint)point {
 CPViewState *state=viewState(self);if(!state.native.window||!CGRectContainsPoint(state.native.bounds,point))return nil;for(UIView *ancestor=state.native;ancestor;ancestor=ancestor.superview)if(ancestor.hidden)return nil;
 for(CPCursorRegion *record in state.cursorRegions.reverseObjectEnumerator){CGRect nativeRect=record.rect;if(!self.isFlipped)nativeRect.origin.y=CGRectGetMinY(state.native.bounds)+CGRectGetMaxY(state.native.bounds)-CGRectGetMaxY(nativeRect);CGRect rect=CGRectIntersection(nativeRect,state.native.bounds);if(!CGRectIsEmpty(rect)&&CGRectContainsPoint(rect,point))return [UIPointerRegion regionWithRect:rect identifier:record];}return nil;
}
- (NSWindow *)window { return viewState(self).window; }
- (void)cp_setOwningWindow:(NSWindow *)window { viewState(self).window = window; }
- (UIView *)cp_nativeView { return viewState(self).native; }
- (CGRect)frame { return self.cp_nativeView.frame; }
- (void)setFrame:(CGRect)frame { UIView *view = self.cp_nativeView; view.frame = frame; [view setNeedsLayout]; [view layoutIfNeeded]; }
- (CGRect)bounds { return self.cp_nativeView.bounds; }
- (CGRect)safeAreaRect {
 UIView *view=self.cp_nativeView;
 CGRect rect=UIEdgeInsetsInsetRect(view.bounds,view.safeAreaInsets);
 return CGRectIsEmpty(rect)?CGRectZero:rect;
}
- (void)setBounds:(CGRect)bounds { UIView *view = self.cp_nativeView; view.bounds = bounds; [view setNeedsLayout]; [view layoutIfNeeded]; }
- (CALayer *)layer { CPViewState *state = viewState(self); return state.guestLayer ?: state.native.layer; }
- (void)setLayer:(CALayer *)layer {
    CPViewState *state = viewState(self);
    if (layer == state.guestLayer) return;
    if (layer == state.native.layer || (layer.superlayer && layer.superlayer != state.native.layer))
        [NSException raise:NSInvalidArgumentException format:@"Guest layer must be independently owned by this host view"];
    [state.guestLayer removeFromSuperlayer]; state.guestLayer = layer;
    if (layer) {
        // Match the explicit SDR capability of the port-local NSScreen viewport.
        layer.preferredDynamicRange = CADynamicRangeStandard;
        layer.wantsExtendedDynamicRangeContent = NO;
        layer.contentsHeadroom = 1.0;
        [state.native.layer addSublayer:layer]; [state.native setNeedsLayout]; [state.native layoutIfNeeded]; }
}
- (BOOL)isHidden { return self.cp_nativeView.hidden; }
- (void)setHidden:(BOOL)hidden {self.cp_nativeView.hidden=hidden;if(hidden){for(CPCursorRegion *record in viewState(self).cursorRegions)[NSCursor cp_nativeRegionExited:record];}[self.cp_pointerInteraction invalidate];}
- (NSUInteger)autoresizingMask {
    UIViewAutoresizing mask = self.cp_nativeView.autoresizingMask;
    // NSView's min/max Y margins use bottom/top, whereas UIKit uses top/bottom.
    return (mask & 7) | (mask & UIViewAutoresizingFlexibleHeight) |
        ((mask & UIViewAutoresizingFlexibleBottomMargin) ? 8 : 0) |
        ((mask & UIViewAutoresizingFlexibleTopMargin) ? 32 : 0);
}
- (void)setAutoresizingMask:(NSUInteger)mask {
    if (mask & ~63UL) [NSException raise:NSInvalidArgumentException format:@"Unsupported NSView autoresizing bits"];
    self.cp_nativeView.autoresizingMask = (mask & 7) | (mask & 16) |
        ((mask & 8) ? UIViewAutoresizingFlexibleBottomMargin : 0) |
        ((mask & 32) ? UIViewAutoresizingFlexibleTopMargin : 0);
}
- (void)cp_attachToNativeContainer:(UIView *)container {
    requireMainThread();
    if (!container || container == self.cp_nativeView)
        [NSException raise:NSInvalidArgumentException format:@"A distinct native container is required"];
    [container addSubview:self.cp_nativeView];
}
- (void)cp_detachFromNativeContainer { [self.cp_nativeView removeFromSuperview]; }
@end
