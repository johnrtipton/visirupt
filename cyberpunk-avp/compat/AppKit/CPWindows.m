#import "CPWindows.h"
#import "CPScreens.h"
#import "CPTrackingAreas.h"
#import <objc/runtime.h>
#include <math.h>
NSNotificationName const NSWindowDidResizeNotification=@"NSWindowDidResizeNotification";
NSNotificationName const NSWindowWillCloseNotification=@"NSWindowWillCloseNotification";
NSNotificationName const NSWindowDidMoveNotification=@"NSWindowDidMoveNotification";
static void Main(void) {if(!NSThread.isMainThread)[NSException raise:NSInternalInconsistencyException format:@"Window operations require the main thread"];}
@interface CPWindowContent : UIView
@property CGSize aspectRatio;
@property CGSize minimumSize;
@end
@implementation CPWindowContent
- (void)setFrame:(CGRect)frame {
 frame.size.width=MAX(frame.size.width,_minimumSize.width);
 frame.size.height=MAX(frame.size.height,_minimumSize.height);
 if(_aspectRatio.width>0&&_aspectRatio.height>0&&frame.size.width>0&&frame.size.height>0) {
  CGFloat ratio=_aspectRatio.width/_aspectRatio.height;
  CGSize fitted=frame.size;
  if(fitted.width/fitted.height>ratio)fitted.width=fitted.height*ratio;else fitted.height=fitted.width/ratio;
  CGFloat grow=MAX(1.0,MAX(_minimumSize.width/fitted.width,_minimumSize.height/fitted.height));
  fitted.width*=grow;fitted.height*=grow;
  frame=CGRectMake(CGRectGetMidX(frame)-fitted.width/2,CGRectGetMidY(frame)-fitted.height/2,fitted.width,fitted.height);
 }
 [super setFrame:frame];
}
- (void)setAspectRatio:(CGSize)ratio {_aspectRatio=ratio;self.frame=self.frame;[self setNeedsLayout];[self layoutIfNeeded];}
- (void)setMinimumSize:(CGSize)size {_minimumSize=size;self.frame=self.frame;[self setNeedsLayout];[self layoutIfNeeded];}
@end
@interface CPWindowState : NSObject
@property (strong) CPWindowContent *content;
@property (nullable,strong) NSView *guest;
@property (nullable,weak) NSView *focused;
@property (nullable,weak) UIWindow *nativeWindow;
@property (copy) NSString *title;
@property (nullable,weak) id delegate;
@property NSUInteger requestedCollectionBehavior;
@property NSUInteger requestedStyleMask;
@property BOOL acceptsMouseMovedEvents;
@property BOOL closed;
@end
@implementation CPWindowState @end
static char windowStateKey;
static CPWindowState *State(NSWindow *window) {
 Main();CPWindowState *state=objc_getAssociatedObject(window,&windowStateKey);
 if(!state)[NSException raise:NSInternalInconsistencyException format:@"Window not initialized"];
 return state;
}
static void NotifyWindow(NSWindow *window, NSNotificationName name, SEL selector) {
 NSNotification *notification=[NSNotification notificationWithName:name object:window];
 [NSNotificationCenter.defaultCenter postNotification:notification];
 id delegate=State(window).delegate;
 if([delegate respondsToSelector:selector]) {
  void (*send)(id,SEL,NSNotification *)=(void *)[delegate methodForSelector:selector];send(delegate,selector,notification);
 }
}
@implementation NSWindow
- (instancetype)init {return [self initWithContentRect:CGRectZero styleMask:0 backing:2 defer:NO];}
- (instancetype)initWithContentRect:(CGRect)rect styleMask:(NSUInteger)style backing:(NSUInteger)backing defer:(BOOL)defer {
 Main();(void)defer;
 if(style!=0&&style!=15)[NSException raise:NSInvalidArgumentException format:@"Unaudited desktop window chrome in native content host"];
 if(backing!=2)[NSException raise:NSInvalidArgumentException format:@"Only native buffered content is supported"];
 if((self=[super init])) {CPWindowState *state=[CPWindowState new];state.content=[[CPWindowContent alloc]initWithFrame:rect];state.content.hidden=YES;state.title=@"";state.requestedStyleMask=style;objc_setAssociatedObject(self,&windowStateKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
 return self;
}
- (instancetype)initWithContentRect:(CGRect)rect styleMask:(NSUInteger)style backing:(NSUInteger)backing defer:(BOOL)defer screen:(NSScreen *)screen {
 Main();
 NSURL *documents=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
 NSDictionary *request=@{@"style_mask":@(style),@"actual_desktop_style_mask":@0,@"chrome_policy":@"NATIVE_SCENE_CHROME_DESKTOP_STYLE_UNSUPPORTED",@"backing":@(backing),@"defer":@(defer),@"width":@(rect.size.width),@"height":@(rect.size.height),@"screen_matches_registered_viewport":@(!screen||screen==NSScreen.mainScreen)};
 [[NSJSONSerialization dataWithJSONObject:request options:NSJSONWritingPrettyPrinted error:nil] writeToURL:[documents URLByAppendingPathComponent:@"host-window-request.json"] options:NSDataWritingAtomic error:nil];
 NSScreen *target=screen?:NSScreen.mainScreen;
 if(!target||target!=NSScreen.mainScreen)[NSException raise:NSInvalidArgumentException format:@"Window screen must be the registered native viewport"];
 UIWindow *native=target.cp_nativeWindow;UIView *container=native.rootViewController.view;
 if(!container||container.window!=native)[NSException raise:NSInternalInconsistencyException format:@"Registered viewport has no attached native content container"];
 if((self=[self initWithContentRect:rect styleMask:style backing:backing defer:defer]))[self cp_attachToNativeWindow:native container:container];
 return self;
}
- (UIView *)cp_nativeContent {return State(self).content;}
- (void)invalidateCursorRectsForView:(NSView *)view {
 if(!view||view.window!=self)[NSException raise:NSInvalidArgumentException format:@"Cursor rectangles must belong to this window"];[view discardCursorRects];[view resetCursorRects];[view.cp_pointerInteraction invalidate];
}
- (void)sendEvent:(NSEvent *)event {
 Main();if(event.window && event.window!=self)[NSException raise:NSInvalidArgumentException format:@"Event belongs to another window"];
 if(event.type==8||event.type==9){NSTrackingArea *area=event.trackingArea;NSView *view=area.cp_attachedView;
  if(!area||!view||view.window!=self||!self.isKeyWindow||!self.isVisible)return;
  id owner=area.owner;if(!owner)return;SEL selector=event.type==8?@selector(mouseEntered:):@selector(mouseExited:);
  if([owner respondsToSelector:selector]){void (*send)(id,SEL,NSEvent *)=(void *)[owner methodForSelector:selector];send(owner,selector,event);}return;
 }
 if(event.type==1){[State(self).guest mouseDown:event];return;}
 if(event.type==2){[State(self).guest mouseUp:event];return;}
 if(event.type==6){[State(self).guest mouseDragged:event];return;}
 if(event.type==22){[State(self).guest scrollWheel:event];return;}
 if(event.type==5){if(self.acceptsMouseMovedEvents&&self.isKeyWindow&&self.isVisible)[State(self).guest mouseMoved:event];return;}
 NSResponder *responder=self.firstResponder;
 if(event.type==10){[responder keyDown:event];return;}if(event.type==11){[responder keyUp:event];return;}
 [NSException raise:NSInvalidArgumentException format:@"Unaudited event type in native window dispatcher"];
}
- (NSUInteger)collectionBehavior {Main();return 0; /* No macOS Spaces on this windowed viewport. */}
- (NSUInteger)styleMask {Main();return 0; /* Native scene chrome, no desktop chrome bits. */}
- (NSUInteger)cp_requestedStyleMask {return State(self).requestedStyleMask;}
- (void)setStyleMask:(NSUInteger)style {
 if(style!=0&&style!=15)[NSException raise:NSInvalidArgumentException format:@"Unaudited desktop window style"];
 State(self).requestedStyleMask=style;
 NSDictionary *policy=@{@"requested_style_mask":@(style),@"actual_desktop_style_mask":@0,@"policy":@"NATIVE_SCENE_CHROME_DESKTOP_STYLE_UNSUPPORTED"};
 NSURL *documents=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
 [[NSJSONSerialization dataWithJSONObject:policy options:NSJSONWritingPrettyPrinted error:nil] writeToURL:[documents URLByAppendingPathComponent:@"host-window-style-policy.json"] options:NSDataWritingAtomic error:nil];
}
- (NSUInteger)cp_requestedCollectionBehavior {return State(self).requestedCollectionBehavior;}
- (NSString *)cp_collectionBehaviorStatus {return self.cp_requestedCollectionBehavior?@"UNSUPPORTED_DESKTOP_FULLSCREEN_ELIGIBILITY":@"WINDOWED_NATIVE_VIEWPORT";}
- (void)setCollectionBehavior:(NSUInteger)behavior {
 if(behavior!=0&&behavior!=128)[NSException raise:NSInvalidArgumentException format:@"Unaudited desktop collection behavior"];
 State(self).requestedCollectionBehavior=behavior;
 NSDictionary *result=@{@"requested_behavior":@(behavior),@"actual_behavior":@0,@"status":self.cp_collectionBehaviorStatus};
 NSURL *documents=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
 [[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil] writeToURL:[documents URLByAppendingPathComponent:@"host-collection-policy.json"] options:NSDataWritingAtomic error:nil];
}
- (NSScreen *)screen {CPWindowState *s=State(self);NSScreen *screen=NSScreen.mainScreen;return s.nativeWindow&&screen.cp_nativeWindow==s.nativeWindow?screen:nil;}
- (BOOL)acceptsMouseMovedEvents {return State(self).acceptsMouseMovedEvents;}
- (void)setAcceptsMouseMovedEvents:(BOOL)enabled {State(self).acceptsMouseMovedEvents=enabled;}
- (id)delegate {return State(self).delegate;}
- (void)setDelegate:(id)delegate {State(self).delegate=delegate;}
- (NSView *)contentView {return State(self).guest;}
- (void)setContentView:(NSView *)view {
 CPWindowState *s=State(self);if(view==s.guest)return;
 if(view.cp_nativeView.superview && view.cp_nativeView.superview!=s.content)[NSException raise:NSInvalidArgumentException format:@"Content view already belongs to another native container"];
 if (s.focused && s.focused.cp_nativeView.isFirstResponder && ![s.focused.cp_nativeView resignFirstResponder])
  [NSException raise:NSInternalInconsistencyException format:@"Existing content refused to resign native focus"];
 s.focused=nil;[s.guest cp_setOwningWindow:nil];
 [s.guest cp_detachFromNativeContainer];s.guest.nextResponder=nil;s.guest=view;
 if(view){view.frame=s.content.bounds;view.autoresizingMask=2|16;view.nextResponder=self;[view cp_setOwningWindow:self];[view cp_attachToNativeContainer:s.content];}
}
- (NSResponder *)firstResponder {
 CPWindowState *s=State(self);return s.focused.cp_nativeView.isFirstResponder ? s.focused : nil;
}
- (BOOL)makeFirstResponder:(NSResponder *)responder {
 CPWindowState *s=State(self);
 if(!responder) {
  if(s.focused.cp_nativeView.isFirstResponder && ![s.focused.cp_nativeView resignFirstResponder])return NO;
  s.focused=nil;return YES;
 }
 if(![responder isKindOfClass:NSView.class])return NO;
 NSView *view=(NSView *)responder;
 if(view.window!=self || !s.nativeWindow || view.cp_nativeView.window!=s.nativeWindow || ![view acceptsFirstResponder])return NO;
 if(s.focused==view && view.cp_nativeView.isFirstResponder)return YES;
 if(s.focused.cp_nativeView.isFirstResponder && ![s.focused.cp_nativeView resignFirstResponder])return NO;
 if(![view.cp_nativeView becomeFirstResponder])return NO;
 s.focused=view;return YES;
}
- (CGSize)contentAspectRatio {return State(self).content.aspectRatio;}
- (CGSize)minSize {return State(self).content.minimumSize;}
- (CGSize)contentSize {return self.cp_nativeContent.bounds.size;}
- (void)setContentSize:(CGSize)size {
 if(!isfinite(size.width)||!isfinite(size.height)||size.width<0||size.height<0)[NSException raise:NSInvalidArgumentException format:@"Content size must be finite and nonnegative"];
 CGRect frame=self.frame;frame.size=size;[self setFrame:frame display:YES];
}
- (void)setMinSize:(CGSize)size {
 if(!isfinite(size.width)||!isfinite(size.height)||size.width<0||size.height<0)[NSException raise:NSInvalidArgumentException format:@"Minimum content size must be finite and nonnegative"];
 CPWindowContent *content=State(self).content;CGSize before=content.bounds.size;content.minimumSize=size;
 if(!CGSizeEqualToSize(before,content.bounds.size))NotifyWindow(self,NSWindowDidResizeNotification,NSSelectorFromString(@"windowDidResize:"));
}
- (void)setContentAspectRatio:(CGSize)ratio {
 if(!isfinite(ratio.width)||!isfinite(ratio.height)||!((ratio.width==0&&ratio.height==0)||(ratio.width>0&&ratio.height>0)))
  [NSException raise:NSInvalidArgumentException format:@"Content aspect ratio must be positive and finite, or zero to remove the constraint"];
 CPWindowContent *content=State(self).content;CGSize before=content.bounds.size;content.aspectRatio=ratio;
 if(!CGSizeEqualToSize(before,content.bounds.size))NotifyWindow(self,NSWindowDidResizeNotification,NSSelectorFromString(@"windowDidResize:"));
}
- (CGRect)contentLayoutRect {return self.cp_nativeContent.bounds;}
// Cocoa points use a bottom-left origin. UIKit performs the actual ancestor
// conversion; the registered scene viewport is the only screen we expose.
static CGPoint FlipPoint(CGPoint point,CGRect bounds) {
 return CGPointMake(point.x,CGRectGetMinY(bounds)+CGRectGetMaxY(bounds)-point.y);
}
- (CGPoint)cp_convertPoint:(CGPoint)point toScreen:(BOOL)toScreen {
 CPWindowState *s=State(self);
 if(!isfinite(point.x)||!isfinite(point.y))
  [NSException raise:NSInvalidArgumentException format:@"Coordinate conversion requires finite points"];
 if(!s.nativeWindow||s.content.window!=s.nativeWindow)
  [NSException raise:NSInternalInconsistencyException format:@"Coordinate conversion requires an attached native window"];
 if(toScreen) {
  CGPoint native=[s.content convertPoint:FlipPoint(point,s.content.bounds) toView:s.nativeWindow];
  return FlipPoint(native,s.nativeWindow.bounds);
 }
 CGPoint local=[s.content convertPoint:FlipPoint(point,s.nativeWindow.bounds) fromView:s.nativeWindow];
 return FlipPoint(local,s.content.bounds);
}
- (CGPoint)convertPointToScreen:(CGPoint)point {return [self cp_convertPoint:point toScreen:YES];}
- (CGPoint)convertPointFromScreen:(CGPoint)point {return [self cp_convertPoint:point toScreen:NO];}
static CGRect FlipRect(CGRect rect,CGRect bounds) {
 return CGRectMake(rect.origin.x,CGRectGetMinY(bounds)+CGRectGetMaxY(bounds)-CGRectGetMaxY(rect),rect.size.width,rect.size.height);
}
- (CGRect)frame {
 CPWindowState *s=State(self);
 if(!s.nativeWindow)return s.content.frame;
 CGRect native=[s.content convertRect:s.content.bounds toView:s.nativeWindow];
 return FlipRect(native,s.nativeWindow.bounds);
}
- (void)setFrame:(CGRect)frame { [self setFrame:frame display:YES]; }
- (void)setFrame:(CGRect)frame display:(BOOL)display {
 if(!isfinite(frame.origin.x)||!isfinite(frame.origin.y)||!isfinite(frame.size.width)||!isfinite(frame.size.height)||frame.size.width<0||frame.size.height<0)
  [NSException raise:NSInvalidArgumentException format:@"Window frame must be finite with nonnegative dimensions"];
 CPWindowState *s=State(self);UIView *v=s.content;CGSize old=v.bounds.size;CGPoint oldOrigin=self.frame.origin;
 CGRect native=frame;
 if(s.nativeWindow)native=[s.nativeWindow convertRect:FlipRect(frame,s.nativeWindow.bounds) toView:v.superview];
 v.frame=native;[v setNeedsLayout];[v layoutIfNeeded];
 if(display)[v setNeedsDisplay];
 if(!CGSizeEqualToSize(old,v.bounds.size))NotifyWindow(self,NSWindowDidResizeNotification,NSSelectorFromString(@"windowDidResize:"));
 if(!CGPointEqualToPoint(oldOrigin,self.frame.origin))NotifyWindow(self,NSWindowDidMoveNotification,NSSelectorFromString(@"windowDidMove:"));
}
- (void)setFrameOrigin:(CGPoint)point {CGRect frame=self.frame;frame.origin=point;[self setFrame:frame display:YES];}
- (NSString *)title {return State(self).title;}
- (void)setTitle:(NSString *)title {CPWindowState *s=State(self);s.title=[title copy];s.content.accessibilityLabel=title;}
- (BOOL)isVisible {UIView *v=self.cp_nativeContent;return v.window!=nil&&!v.hidden&&!v.window.hidden;}
- (BOOL)cp_acceptsNativeKeyWindow {return self.isVisible;}
- (BOOL)isKeyWindow {CPWindowState *s=State(self);return self.isVisible&&s.nativeWindow.isKeyWindow&&NSApplication.sharedApplication.keyWindow==self;}
- (void)cp_attachToNativeWindow:(UIWindow *)window container:(UIView *)container {
 CPWindowState *s=State(self);
 if(!window||!container||(container!=window&&container.window!=window))[NSException raise:NSInvalidArgumentException format:@"Container must belong to the supplied native window"];
 CGRect frame=self.frame;
 if(s.content.superview)[self cp_detachFromNativeWindow];
 s.closed=NO;s.nativeWindow=window;[container addSubview:s.content];
 s.content.frame=[window convertRect:FlipRect(frame,window.bounds) toView:container];
}
- (void)cp_detachFromNativeWindow {CPWindowState *s=State(self);CGRect frame=self.frame;if(s.focused.cp_nativeView.isFirstResponder && ![self makeFirstResponder:nil])[NSException raise:NSInternalInconsistencyException format:@"Focused content refused native detachment"];if(NSApplication.sharedApplication.keyWindow==self)[NSApplication.sharedApplication cp_setKeyWindow:nil];[s.content removeFromSuperview];s.nativeWindow=nil;s.content.frame=frame;}
- (void)makeKeyAndOrderFront:(id)sender {
 (void)sender;CPWindowState *s=State(self);
 if(!s.nativeWindow||s.content.window!=s.nativeWindow)[NSException raise:NSInternalInconsistencyException format:@"Attach a real native window before showing game content"];
 s.content.hidden=NO;[s.guest resetCursorRects];[s.nativeWindow makeKeyWindow];
 if(s.nativeWindow.isKeyWindow)[NSApplication.sharedApplication cp_setKeyWindow:self];
}
- (void)setIsVisible:(BOOL)visible {
 if(!visible){[self orderOut:nil];return;}
 CPWindowState *s=State(self);
 if(!s.nativeWindow||s.content.window!=s.nativeWindow)[NSException raise:NSInternalInconsistencyException format:@"Attach a real native window before showing game content"];
 s.content.hidden=NO;[s.guest resetCursorRects];
}
- (void)makeMainWindow {[NSApplication.sharedApplication cp_setMainWindow:self];}
- (void)orderOut:(id)sender {(void)sender;self.cp_nativeContent.hidden=YES;[self.contentView cp_deactivateCursorRegions];if(NSApplication.sharedApplication.keyWindow==self)[NSApplication.sharedApplication cp_setKeyWindow:nil];}
- (void)close {
 CPWindowState *s=State(self);if(s.closed)return;
 s.closed=YES;NotifyWindow(self,NSWindowWillCloseNotification,NSSelectorFromString(@"windowWillClose:"));[self orderOut:nil];[self cp_detachFromNativeWindow];
}
@end
@interface CPControllerState : NSObject
@property (nullable,strong) NSWindow *window;
@end
@implementation CPControllerState @end
static char controllerKey;
static CPControllerState *Controller(NSWindowController *controller) {
 Main();CPControllerState *state=objc_getAssociatedObject(controller,&controllerKey);
 if(!state){state=[CPControllerState new];objc_setAssociatedObject(controller,&controllerKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}return state;
}
@implementation NSWindowController
- (instancetype)init {return [self initWithWindow:nil];}
- (instancetype)initWithWindow:(NSWindow *)window {Main();if((self=[super init]))Controller(self).window=window;return self;}
- (NSWindow *)window {return Controller(self).window;}
- (void)setWindow:(NSWindow *)window {Controller(self).window=window;}
- (void)windowDidLoad { /* No nib is loaded: this host accepts an explicit native window. */ }
- (void)showWindow:(id)sender {[self.window makeKeyAndOrderFront:sender];}
- (void)close {[self.window close];}
@end
