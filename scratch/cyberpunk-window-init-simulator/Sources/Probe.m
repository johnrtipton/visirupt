#import "Probe.h"
#import "CPWindows.h"
#import "CPScreens.h"
#import "CPSceneLifecycleBridge.h"
#import "CPScenePointer.h"
#import "CPTrackingAreas.h"
#import <QuartzCore/QuartzCore.h>
#import "../../cyberpunk-staged-startup/Diagnostics/CPPresentationTrace.h"
#include <math.h>
// Declare the audited AppKit contract independently so a missing selector is
// reported by this fixture before its implementation is added to the facade.
@interface NSWindow (CoordinateContract)
- (CGPoint)convertPointToScreen:(CGPoint)point;
- (CGPoint)convertPointFromScreen:(CGPoint)point;
- (void)setFrameOrigin:(CGPoint)point;
@end
static BOOL Near(CGPoint a,CGPoint b){return fabs(a.x-b.x)<1e-7&&fabs(a.y-b.y)<1e-7;}
@interface TestDelegate : NSObject
@property NSUInteger resizeCount;
@property NSUInteger closeCount;
@property NSUInteger moveCount;
@end
@implementation TestDelegate
- (void)windowDidResize:(NSNotification *)notification {self.resizeCount++;}
- (void)windowWillClose:(NSNotification *)notification {self.closeCount++;}
- (void)windowDidMove:(NSNotification *)notification {self.moveCount++;}
- (BOOL)windowShouldClose:(NSWindow *)window {return NO;}
@end
@interface TestView : NSView
@property NSUInteger movedCount;
@property BOOL exitQueryPassed;
@property NSUInteger downCount,upCount,keyDownCount,keyUpCount,dragCount,scrollCount;
@end
@implementation TestView
- (BOOL)acceptsFirstResponder {return YES;}
- (void)mouseDown:(NSEvent *)event {self.downCount++;}
- (void)mouseUp:(NSEvent *)event {self.upCount++;}
- (void)mouseDragged:(NSEvent *)event {self.dragCount++;}
- (void)scrollWheel:(NSEvent *)event {self.scrollCount++;}
- (void)keyDown:(NSEvent *)event {self.keyDownCount++;}
- (void)keyUp:(NSEvent *)event {self.keyUpCount++;}
- (void)mouseMoved:(NSEvent *)event {self.movedCount++;}
- (void)mouseExited:(NSEvent *)event {@try {self.exitQueryPassed=Near([NSEvent mouseLocation],[event.window convertPointToScreen:event.locationInWindow]);}@catch(NSException *e){self.exitQueryPassed=NO;}}
@end
// Controlled recognizer samples exercise the actual native-view event path;
// they do not represent physical trackpad acceptance.
@interface TestHover : UIHoverGestureRecognizer
@property UIGestureRecognizerState sampleState;
@property CGPoint samplePoint;
@end
@implementation TestHover
- (UIGestureRecognizerState)state {return self.sampleState;}
- (CGPoint)locationInView:(UIView *)view {return self.samplePoint;}
- (UIKeyModifierFlags)modifierFlags {return UIKeyModifierShift;}
@end
@interface TestScroll : UIPanGestureRecognizer
@property UIGestureRecognizerState sampleState;
@property CGPoint sampleTranslation,samplePoint;
@end
@implementation TestScroll
- (UIGestureRecognizerState)state {return self.sampleState;}
- (CGPoint)translationInView:(UIView *)view {return self.sampleTranslation;}
- (void)setTranslation:(CGPoint)point inView:(UIView *)view {self.sampleTranslation=point;}
- (CGPoint)locationInView:(UIView *)view {return self.samplePoint;}
- (UIKeyModifierFlags)modifierFlags {return UIKeyModifierShift;}
@end
@interface TestTouch : UITouch
@property CGPoint samplePoint;
@end
@implementation TestTouch
- (CGPoint)locationInView:(UIView *)view {return self.samplePoint;}
- (UITouchType)type {return UITouchTypeIndirectPointer;}
- (NSTimeInterval)timestamp {return 123.5;}
- (NSUInteger)tapCount {return 1;}
@end
@interface TestInputEvent : UIEvent
@property UIEventButtonMask sampleButtons;
@end
@implementation TestInputEvent
- (UIEventButtonMask)buttonMask {return self.sampleButtons;}
- (UIKeyModifierFlags)modifierFlags {return UIKeyModifierShift;}
@end
@interface TestKey : UIKey
@property UIKeyboardHIDUsage sampleCode;
@end
@implementation TestKey
- (UIKeyboardHIDUsage)keyCode {return self.sampleCode;}
- (NSString *)characters {return @" ";}
- (NSString *)charactersIgnoringModifiers {return @" ";}
- (UIKeyModifierFlags)modifierFlags {return UIKeyModifierShift;}
@end
@interface TestPress : UIPress
@property (strong) TestKey *sampleKey;
@end
@implementation TestPress
- (UIKey *)key {return self.sampleKey;}
- (NSTimeInterval)timestamp {return 124.5;}
@end
@interface ChecksController : CPScenePointerController
@property BOOL started;
@property BOOL unobservedTimingRejected;
@property (strong) CPSceneLifecycleBridge *bridge;
@end
@implementation ChecksController
- (void)viewDidAppear:(BOOL)animated {
 [super viewDidAppear:animated];if(self.started)return;self.started=YES;
 [NSScreen cp_setMainNativeWindow:self.view.window];
 @try { (void)NSScreen.mainScreen.minimumRefreshInterval; }
 @catch(NSException *exception){self.unobservedTimingRejected=[exception.name isEqual:NSInternalInconsistencyException];}
 [self cp_runWhenTimingReady];
}
- (void)cp_runWhenTimingReady {
 if(!NSScreen.mainScreen.cp_refreshTimingReady) {
  __weak ChecksController *weakSelf=self;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.1*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[weakSelf cp_runWhenTimingReady];});return;
 }
 NSMutableDictionary *checks=[NSMutableDictionary new];
 NSMutableDictionary *report=[@{@"run_id":NSUUID.UUID.UUIDString,@"original_game_code_executed":@NO,@"source":@"visionOS simulator native views plus controlled hover samples"} mutableCopy];
 @try {
  [NSScreen cp_setMainNativeWindow:self.view.window];CPRegisterScenePointerController(self);
  self.bridge=[[CPSceneLifecycleBridge alloc]initWithWindow:self.view.window application:NSApplication.sharedApplication];
  id<MTLDevice> traceDevice=MTLCreateSystemDefaultDevice();
  NSDictionary *traceSetup=CPPresentationTraceBegin(self.view.window,traceDevice);report[@"native_presentation_trace_setup"]=traceSetup;
  checks[@"native_presentation_hooks_installed"]=@([traceSetup[@"state"] isEqual:@"INSTALLED"]);
  checks[@"native_present_and_complete_rendering_control"]=@(CPPresentationTraceControl(self.view.window,traceDevice));
  NSDictionary *timing=NSScreen.mainScreen.cp_refreshTimingEvidence;
  checks[@"unobserved_refresh_interval_rejected"]=@(self.unobservedTimingRejected);
  report[@"native_refresh_timing_evidence"]=timing;
  checks[@"refresh_period_from_native_display_link"]=@(NSScreen.mainScreen.cp_refreshTimingReady&&NSScreen.mainScreen.minimumRefreshInterval>0&&NSScreen.mainScreen.minimumRefreshInterval==[timing[@"observed_duration_seconds"] doubleValue]);
  checks[@"refresh_single_scene_mode_no_panel_vrr_claim"]=@(NSScreen.mainScreen.minimumRefreshInterval==NSScreen.mainScreen.maximumRefreshInterval&&![timing[@"physical_panel_range_measured"] boolValue]&&[timing[@"policy"] isEqual:@"SINGLE_OBSERVED_SCENE_CADENCE_NO_VRR_NEGOTIATION"]);
  NSScreen *expectedScreen=NSScreen.mainScreen;CGRect expectedFrame=expectedScreen.frame,expectedVisible=expectedScreen.visibleFrame;CGFloat expectedScale=expectedScreen.backingScaleFactor;
  __block BOOL workerPassed=NO,workerNativeRejected=NO;__block NSString *workerError=nil;
  dispatch_group_t worker=dispatch_group_create();
  dispatch_group_async(worker,dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
   @try {NSScreen *screen=NSScreen.mainScreen;workerPassed=screen==expectedScreen&&NSScreen.screens.count==1&&CGRectEqualToRect(screen.frame,expectedFrame)&&CGRectEqualToRect(screen.visibleFrame,expectedVisible)&&screen.backingScaleFactor==expectedScale&&screen.minimumRefreshInterval>0&&screen.minimumRefreshInterval==screen.maximumRefreshInterval&&screen.maximumExtendedDynamicRangeColorComponentValue==1&&screen.deviceDescription[@"NSScreenNumber"]!=nil;}
   @catch(NSException *exception){workerError=exception.reason;}
   @try {(void)expectedScreen.cp_nativeWindow;}@catch(NSException *exception){workerNativeRejected=[exception.name isEqual:NSInternalInconsistencyException];}
  });
  BOOL workerCompleted=dispatch_group_wait(worker,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC))==0;
  checks[@"worker_reads_observed_screen_metadata_without_uikit"]=@(workerCompleted&&workerPassed);
  checks[@"worker_native_uikit_access_still_rejected"]=@(workerCompleted&&workerNativeRejected);
  if(workerCompleted&&workerError)report[@"worker_screen_query_error"]=workerError;
  BOOL unavailable=NO;@try {[NSEvent mouseLocation];}@catch(NSException *e){unavailable=[e.name isEqual:NSInternalInconsistencyException];}
  checks[@"mouse_location_without_sample_rejected"]=@(unavailable);
  checks[@"sdr_viewport_range"]=@(NSScreen.mainScreen.maximumPotentialExtendedDynamicRangeColorComponentValue==1&&NSScreen.mainScreen.maximumExtendedDynamicRangeColorComponentValue==1);
  NSWindow *window=[[NSWindow alloc]initWithContentRect:CGRectMake(0,0,100,100) styleMask:0 backing:2 defer:NO screen:NSScreen.mainScreen];
  checks[@"real_window_screen_attachment"]=@(window.cp_nativeContent.window==self.view.window&&window.screen==NSScreen.mainScreen);
  TestDelegate *delegate=[TestDelegate new];window.delegate=delegate;
  window.contentAspectRatio=CGSizeMake(16,9);CGSize size=window.cp_nativeContent.bounds.size;
  checks[@"real_aspect_initial"]=@(fabs(size.width/size.height-16.0/9)<1e-8);
  [window setFrame:CGRectMake(0,0,200,200) display:YES];size=window.cp_nativeContent.bounds.size;
  checks[@"real_aspect_after_resize"]=@(fabs(size.width/size.height-16.0/9)<1e-8);
  checks[@"resize_delegate_delivered"]=@(delegate.resizeCount==2);
  BOOL rejected=NO;@try {window.contentAspectRatio=CGSizeMake(0,1);}@catch(NSException *e){rejected=YES;}
  checks[@"invalid_aspect_rejected"]=@(rejected);
  CGRect beforeStyle=window.frame;window.styleMask=15;
  checks[@"desktop_style_request_not_advertised_as_native_chrome"]=@(window.styleMask==0&&window.cp_requestedStyleMask==15&&CGRectEqualToRect(beforeStyle,window.frame));
  rejected=NO;@try {window.styleMask=128;}@catch(NSException *e){rejected=[e.name isEqual:NSInvalidArgumentException];}
  checks[@"unaudited_desktop_style_rejected"]=@(rejected);
  NSWindow *normalStyle=[[NSWindow alloc]initWithContentRect:CGRectMake(0,0,20,20) styleMask:15 backing:2 defer:NO screen:NSScreen.mainScreen];
  checks[@"normal_style_constructor_uses_real_native_scene"]=@(normalStyle.cp_nativeContent.window==self.view.window&&normalStyle.cp_requestedStyleMask==15&&normalStyle.styleMask==0&&CGRectEqualToRect(normalStyle.frame,CGRectMake(0,0,20,20)));[normalStyle close];
  rejected=NO;@try {[[NSWindow alloc]initWithContentRect:CGRectZero styleMask:128 backing:2 defer:NO];}@catch(NSException *e){rejected=[e.name isEqual:NSInvalidArgumentException];}
  checks[@"unaudited_style_constructor_rejected"]=@(rejected);
  NSWindow *minimumFixture=[[NSWindow alloc]initWithContentRect:CGRectMake(0,0,20,20) styleMask:0 backing:2 defer:NO screen:NSScreen.mainScreen];
  minimumFixture.minSize=CGSizeMake(40,30);
  checks[@"minimum_size_applies_to_native_content"]=@(CGSizeEqualToSize(minimumFixture.minSize,CGSizeMake(40,30))&&CGSizeEqualToSize(minimumFixture.cp_nativeContent.bounds.size,CGSizeMake(40,30)));
  minimumFixture.frame=CGRectMake(0,0,10,10);
  checks[@"minimum_size_clamps_native_resize"]=@(CGSizeEqualToSize(minimumFixture.cp_nativeContent.bounds.size,CGSizeMake(40,30)));
  minimumFixture.contentAspectRatio=CGSizeMake(2,1);CGSize constrained=minimumFixture.cp_nativeContent.bounds.size;
  checks[@"minimum_size_and_aspect_both_enforced"]=@(constrained.width>=40&&constrained.height>=30&&fabs(constrained.width/constrained.height-2)<1e-8);
  minimumFixture.minSize=CGSizeZero;minimumFixture.frame=CGRectMake(0,0,10,10);
  checks[@"minimum_size_reset_allows_smaller_content"]=@(CGSizeEqualToSize(minimumFixture.cp_nativeContent.bounds.size,CGSizeMake(10,5)));
  rejected=NO;@try {minimumFixture.minSize=CGSizeMake(NAN,1);}@catch(NSException *e){rejected=[e.name isEqual:NSInvalidArgumentException];}
  checks[@"invalid_minimum_size_rejected"]=@(rejected);
  CGPoint previousOrigin=minimumFixture.frame.origin;minimumFixture.contentSize=CGSizeMake(100,50);
  checks[@"content_size_changes_native_bounds_preserves_origin"]=@(CGSizeEqualToSize(minimumFixture.contentSize,CGSizeMake(100,50))&&CGSizeEqualToSize(minimumFixture.cp_nativeContent.bounds.size,CGSizeMake(100,50))&&Near(previousOrigin,minimumFixture.frame.origin));
  rejected=NO;@try {minimumFixture.contentSize=CGSizeMake(-1,20);}@catch(NSException *e){rejected=[e.name isEqual:NSInvalidArgumentException];}
  checks[@"invalid_content_size_rejected"]=@(rejected);[minimumFixture close];
  window.collectionBehavior=128;
  checks[@"fullscreen_policy_not_falsely_advertised"]=@(window.collectionBehavior==0&&window.cp_requestedCollectionBehavior==128&&[window.cp_collectionBehaviorStatus isEqual:@"UNSUPPORTED_DESKTOP_FULLSCREEN_ELIGIBILITY"]);
  rejected=NO;@try {window.collectionBehavior=256;}@catch(NSException *e){rejected=YES;}
  checks[@"unaudited_collection_policy_rejected"]=@(rejected);
  NSApplication.sharedApplication.presentationOptions=4096;
  checks[@"desktop_presentation_not_falsely_advertised"]=@(NSApplication.sharedApplication.presentationOptions==0&&NSApplication.sharedApplication.cp_requestedPresentationOptions==4096);
  TestView *view=[[TestView alloc]initWithFrame:window.contentLayoutRect];window.contentView=view;
  CAMetalLayer *layer=[CAMetalLayer layer];layer.wantsExtendedDynamicRangeContent=YES;layer.contentsHeadroom=2;view.layer=layer;
  checks[@"real_sdr_layer_configuration"]=@(!layer.wantsExtendedDynamicRangeContent&&layer.contentsHeadroom==1&&[layer.preferredDynamicRange isEqual:CADynamicRangeStandard]);
  [window setIsVisible:YES];
  checks[@"visibility_shows_without_claiming_key_or_main"]=@(window.isVisible&&!window.isKeyWindow&&NSApplication.sharedApplication.mainWindow==nil);
  [window makeMainWindow];checks[@"explicit_main_role_without_key"]=@(NSApplication.sharedApplication.mainWindow==window&&!window.isKeyWindow);
  [window setIsVisible:NO];checks[@"visibility_hides_without_detaching"]=@(!window.isVisible&&window.cp_nativeContent.window==self.view.window&&NSApplication.sharedApplication.mainWindow==nil);
  [window makeKeyAndOrderFront:nil];checks[@"native_key_and_visible"]=@(window.isKeyWindow&&window.isVisible);
  NSTrackingArea *exitArea=[[NSTrackingArea alloc]initWithRect:view.bounds options:0x21 owner:view userInfo:nil];[view addTrackingArea:exitArea];
  TestHover *hover=[TestHover new];SEL selector=NSSelectorFromString(@"cp_hoverChanged:");
  void (*sendHover)(id,SEL,UIHoverGestureRecognizer *)=(void *)[view.cp_nativeView methodForSelector:selector];
  hover.sampleState=UIGestureRecognizerStateBegan;hover.samplePoint=CGPointMake(2,2);sendHover(view.cp_nativeView,selector,hover);
  hover.sampleState=UIGestureRecognizerStateChanged;hover.samplePoint=CGPointMake(4,4);sendHover(view.cp_nativeView,selector,hover);
  NSEvent *event=[NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<5) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  checks[@"disabled_mouse_moves_not_queued"]=@(event==nil);
  window.acceptsMouseMovedEvents=YES;
  hover.samplePoint=CGPointMake(10,8);sendHover(view.cp_nativeView,selector,hover);
  event=[NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<5) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  checks[@"native_hover_translates_mouse_event"]=@(event&&event.window==window&&event.type==5&&event.locationInWindow.x==10&&fabs(event.locationInWindow.y-(window.cp_nativeContent.bounds.size.height-8))<1e-8&&event.deltaX==6&&event.deltaY==4&&event.modifierFlags==UIKeyModifierShift);
  checks[@"mouse_location_from_native_hover"]=@(Near([NSEvent mouseLocation],[window convertPointToScreen:event.locationInWindow]));
  hover.sampleState=UIGestureRecognizerStateEnded;hover.samplePoint=CGPointMake(11,9);sendHover(view.cp_nativeView,selector,hover);
  BOOL exitPositionPassed=NO;@try {CGPoint exitNative=[view.cp_nativeView convertPoint:hover.samplePoint toView:self.view.window];exitNative.y=CGRectGetMinY(self.view.window.bounds)+CGRectGetMaxY(self.view.window.bounds)-exitNative.y;exitPositionPassed=Near([NSEvent mouseLocation],exitNative);}@catch(NSException *e){}
  checks[@"mouse_location_records_real_exit_sample"]=@(exitPositionPassed);
  checks[@"mouse_exited_callback_can_read_native_exit_position"]=@(view.exitQueryPassed&&!exitArea.cp_pointerInside);
  hover.sampleState=UIGestureRecognizerStateChanged;hover.samplePoint=CGPointMake(12.5,14.25);[self cp_observeHover:hover];
  CGPoint expectedRoot=[self.view convertPoint:hover.samplePoint toView:self.view.window];
  expectedRoot.y=CGRectGetMinY(self.view.window.bounds)+CGRectGetMaxY(self.view.window.bounds)-expectedRoot.y;
  checks[@"mouse_location_from_root_hover"]=@(Near([NSEvent mouseLocation],expectedRoot));
  if(event)[NSApplication.sharedApplication sendEvent:event];
  checks[@"mouse_move_dispatches_to_content"]=@(view.movedCount==1);
  [NSEvent setMouseCoalescingEnabled:NO];
  checks[@"host_mouse_coalescing_disabled"]=@(![NSEvent isMouseCoalescingEnabled]);
  hover.sampleState=UIGestureRecognizerStateChanged;hover.samplePoint=CGPointMake(14,15);sendHover(view.cp_nativeView,selector,hover);
  hover.samplePoint=CGPointMake(18,19);sendHover(view.cp_nativeView,selector,hover);
  NSEvent *firstMotion=[NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<5) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  NSEvent *secondMotion=[NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<5) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  NSEvent *extraMotion=[NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<5) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  checks[@"delivered_hover_samples_remain_separate_and_ordered"]=@(firstMotion&&secondMotion&&!extraMotion&&firstMotion.locationInWindow.x==14&&secondMotion.locationInWindow.x==18&&secondMotion.deltaX==4&&secondMotion.deltaY==4);
  rejected=NO;@try {[NSEvent setMouseCoalescingEnabled:YES];}@catch(NSException *e){rejected=[e.name isEqual:NSInvalidArgumentException];}
  checks[@"unimplemented_mouse_coalescing_enable_rejected"]=@(rejected);
  TestTouch *touch=[TestTouch new];touch.samplePoint=CGPointMake(15,17);NSSet *touches=[NSSet setWithObject:touch];
  TestInputEvent *input=[TestInputEvent new];input.sampleButtons=UIEventButtonMaskPrimary;
  [view.cp_nativeView touchesBegan:touches withEvent:input];input.sampleButtons=0;[view.cp_nativeView touchesEnded:touches withEvent:input];
  NSEvent *down=[NSApplication.sharedApplication nextEventMatchingMask:2 untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  NSEvent *up=[NSApplication.sharedApplication nextEventMatchingMask:4 untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  checks[@"native_primary_click_queues_down_and_up"]=@(down&&up&&down.type==1&&up.type==2&&down.timestamp==123.5&&down.modifierFlags==UIKeyModifierShift&&down.locationInWindow.x==15&&fabs(down.locationInWindow.y-(window.cp_nativeContent.bounds.size.height-17))<1e-7);
  checks[@"native_click_metadata_preserved"]=@(down&&down.buttonNumber==0&&down.clickCount==1);
  if(down)[NSApplication.sharedApplication sendEvent:down];if(up)[NSApplication.sharedApplication sendEvent:up];
  checks[@"primary_click_dispatches_to_content"]=@(view.downCount==1&&view.upCount==1);
  checks[@"native_keyboard_focus_available"]=@([window makeFirstResponder:view]);
  TestKey *key=[TestKey new];key.sampleCode=UIKeyboardHIDUsageKeyboardSpacebar;TestPress *press=[TestPress new];press.sampleKey=key;NSSet *presses=[NSSet setWithObject:press];
  [view.cp_nativeView pressesBegan:presses withEvent:nil];[view.cp_nativeView pressesEnded:presses withEvent:nil];
  NSEvent *keyDown=[NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<10) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  NSEvent *keyUp=[NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<11) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  checks[@"native_space_maps_to_mac_keycode_49"]=@(keyDown&&keyUp&&keyDown.keyCode==49&&keyUp.keyCode==49&&keyDown.timestamp==124.5&&keyDown.modifierFlags==UIKeyModifierShift);
  checks[@"native_space_text_preserved"]=@(keyDown&&[keyDown.characters isEqual:@" "]&&[keyDown.charactersIgnoringModifiers isEqual:@" "]&&!keyDown.isARepeat);
  if(keyDown)[NSApplication.sharedApplication sendEvent:keyDown];if(keyUp)[NSApplication.sharedApplication sendEvent:keyUp];
  checks[@"space_dispatches_to_focused_content"]=@(view.keyDownCount==1&&view.keyUpCount==1);
  BOOL navigationKeys=YES;
  for(NSNumber *usage in @[@(UIKeyboardHIDUsageKeyboardReturnOrEnter),@(UIKeyboardHIDUsageKeyboardEscape)]) {
   key.sampleCode=usage.unsignedIntegerValue;[view.cp_nativeView pressesBegan:presses withEvent:nil];[view.cp_nativeView pressesEnded:presses withEvent:nil];
   NSEvent *d=[NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<10) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
   NSEvent *u=[NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<11) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];unsigned short expected=usage.unsignedIntegerValue==UIKeyboardHIDUsageKeyboardEscape?53:36;
   navigationKeys=navigationKeys&&d&&u&&d.keyCode==expected&&u.keyCode==expected;
  }
  checks[@"return_and_escape_have_mac_navigation_keycodes"]=@(navigationKeys);
  input.sampleButtons=UIEventButtonMaskSecondary;[view.cp_nativeView touchesBegan:touches withEvent:input];input.sampleButtons=0;[view.cp_nativeView touchesEnded:touches withEvent:input];
  checks[@"secondary_button_not_fabricated_as_primary"]=@([NSApplication.sharedApplication nextEventMatchingMask:6 untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES]==nil);
  input.sampleButtons=UIEventButtonMaskPrimary;[view.cp_nativeView touchesBegan:touches withEvent:input];[view.cp_nativeView touchesCancelled:touches withEvent:input];
  NSEvent *cancelDown=[NSApplication.sharedApplication nextEventMatchingMask:2 untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  NSEvent *cancelUp=[NSApplication.sharedApplication nextEventMatchingMask:4 untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  checks[@"cancelled_native_click_releases_primary_button"]=@(cancelDown&&cancelUp&&cancelUp.type==2);
  input.sampleButtons=UIEventButtonMaskPrimary;touch.samplePoint=CGPointMake(15,17);[view.cp_nativeView touchesBegan:touches withEvent:input];
  NSEvent *dragDown=[NSApplication.sharedApplication nextEventMatchingMask:2 untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  touch.samplePoint=CGPointMake(20,26);[view.cp_nativeView touchesMoved:touches withEvent:input];
  NSEvent *drag=[NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<6) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  checks[@"native_held_button_movement_queues_drag"]=@(dragDown&&drag&&drag.type==6&&drag.deltaX==5&&drag.deltaY==9&&drag.locationInWindow.x==20&&fabs(drag.locationInWindow.y-(window.cp_nativeContent.bounds.size.height-26))<1e-7);
  if(drag)[NSApplication.sharedApplication sendEvent:drag];checks[@"native_drag_dispatches_to_content"]=@(view.dragCount==1);
  input.sampleButtons=0;[view.cp_nativeView touchesEnded:touches withEvent:input];[NSApplication.sharedApplication nextEventMatchingMask:4 untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  TestScroll *scroll=[TestScroll new];scroll.sampleState=UIGestureRecognizerStateChanged;scroll.sampleTranslation=CGPointMake(3,12);scroll.samplePoint=CGPointMake(22,30);
  SEL scrollAction=NSSelectorFromString(@"cp_scrollChanged:");BOOL hasScroll=[view.cp_nativeView respondsToSelector:scrollAction];checks[@"native_trackpad_scroll_callback_connected"]=@(hasScroll);
  if(hasScroll){void (*action)(id,SEL,UIPanGestureRecognizer *)=(void *)[view.cp_nativeView methodForSelector:scrollAction];action(view.cp_nativeView,scrollAction,scroll);}
  NSEvent *wheel=[NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<22) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  checks[@"native_trackpad_scroll_preserves_precise_delta"]=@(wheel&&wheel.type==22&&wheel.scrollingDeltaX==3&&wheel.scrollingDeltaY==12&&wheel.hasPreciseScrollingDeltas&&wheel.modifierFlags==UIKeyModifierShift&&Near(scroll.sampleTranslation,CGPointZero));
  if(wheel)[NSApplication.sharedApplication sendEvent:wheel];checks[@"native_scroll_dispatches_to_content"]=@(view.scrollCount==1);
  checks[@"trackpad_recognizer_excludes_click_drag_touches"]=@(view.cp_scrollRecognizer.allowedScrollTypesMask==UIScrollTypeMaskContinuous&&view.cp_scrollRecognizer.allowedTouchTypes.count==0&&!view.cp_scrollRecognizer.cancelsTouchesInView&&[view.cp_nativeView.gestureRecognizers containsObject:view.cp_scrollRecognizer]);
  [view.cp_nativeView touchesMoved:touches withEvent:input];checks[@"movement_without_held_button_not_dragged"]=@([NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<6) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES]==nil);
  if(hasScroll){void (*action)(id,SEL,UIPanGestureRecognizer *)=(void *)[view.cp_nativeView methodForSelector:scrollAction];scroll.sampleState=UIGestureRecognizerStateChanged;scroll.sampleTranslation=CGPointZero;action(view.cp_nativeView,scrollAction,scroll);}
  checks[@"zero_changed_scroll_does_not_repeat_previous_delta"]=@([NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<22) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES]==nil);
  if(hasScroll){void (*action)(id,SEL,UIPanGestureRecognizer *)=(void *)[view.cp_nativeView methodForSelector:scrollAction];scroll.sampleState=UIGestureRecognizerStateEnded;action(view.cp_nativeView,scrollAction,scroll);}
  NSEvent *scrollEnd=[NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<22) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  checks[@"scroll_end_keeps_observed_phase_without_inventing_momentum"]=@(wheel.phase==4&&scrollEnd&&scrollEnd.phase==8&&scrollEnd.momentumPhase==0&&scrollEnd.scrollingDeltaY==0);
  NSArray *walkingUsages=@[@(UIKeyboardHIDUsageKeyboardW),@(UIKeyboardHIDUsageKeyboardA),@(UIKeyboardHIDUsageKeyboardS),@(UIKeyboardHIDUsageKeyboardD)];
  NSArray *walkingCodes=@[@13,@0,@1,@2];BOOL walkingMappings=YES;
  for(NSUInteger i=0;i<walkingUsages.count;i++) {
   key.sampleCode=[walkingUsages[i] unsignedIntegerValue];[view.cp_nativeView pressesBegan:presses withEvent:nil];[view.cp_nativeView pressesEnded:presses withEvent:nil];
   NSEvent *d=[NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<10) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
   NSEvent *u=[NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<11) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];unsigned short expected=[walkingCodes[i] unsignedShortValue];
   walkingMappings=walkingMappings&&d&&u&&d.keyCode==expected&&u.keyCode==expected;
  }
  checks[@"wasd_native_hid_maps_to_mac_down_and_up"]=@(walkingMappings);
  key.sampleCode=UIKeyboardHIDUsageKeyboardW;[view.cp_nativeView pressesBegan:presses withEvent:nil];[view.cp_nativeView pressesCancelled:presses withEvent:nil];
  NSEvent *walkingDown=[NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<10) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  NSEvent *walkingRelease=[NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<11) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  checks[@"cancelled_walk_press_releases_key"]=@(walkingDown&&walkingRelease&&walkingRelease.keyCode==13);
  BOOL arrowMappings=YES;
  for(NSNumber *usage in @[@(UIKeyboardHIDUsageKeyboardLeftArrow),@(UIKeyboardHIDUsageKeyboardRightArrow)]) {
   key.sampleCode=usage.unsignedIntegerValue;[view.cp_nativeView pressesBegan:presses withEvent:nil];[view.cp_nativeView pressesEnded:presses withEvent:nil];
   NSEvent *d=[NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<10) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
   NSEvent *u=[NSApplication.sharedApplication nextEventMatchingMask:((NSUInteger)1<<11) untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];unsigned short expected=usage.unsignedIntegerValue==UIKeyboardHIDUsageKeyboardLeftArrow?123:124;
   arrowMappings=arrowMappings&&d&&u&&d.keyCode==expected&&u.keyCode==expected;
  }
  checks[@"left_right_arrows_native_mac_codes_and_release"]=@(arrowMappings);
  window.delegate=nil;
  @autoreleasepool {TestDelegate *temporary=[TestDelegate new];window.delegate=temporary;}
  checks[@"delegate_is_weak"]=@(window.delegate==nil);window.delegate=delegate;
  [window close];
  checks[@"direct_close_delivers_callback_and_detaches"]=@(delegate.closeCount==1&&window.cp_nativeContent.window==nil);
  checks[@"detached_window_has_no_screen"]=@(window.screen==nil);
  rejected=NO;@try {[window setIsVisible:YES];}@catch(NSException *e){rejected=[e.name isEqual:NSInternalInconsistencyException];}
  checks[@"detached_visibility_show_rejected"]=@(rejected);
  UIView *container=[[UIView alloc]initWithFrame:CGRectMake(17,31,400,300)];[self.view.window addSubview:container];
  NSWindow *coordinates=[[NSWindow alloc]initWithContentRect:CGRectMake(23,41,120,80) styleMask:0 backing:2 defer:NO];
  [coordinates cp_attachToNativeWindow:self.view.window container:container];
  checks[@"constructor_frame_matches_screen_origin"]=@(Near([coordinates convertPointToScreen:CGPointZero],CGPointMake(23,41)));
  // An independently positioned native view verifies ancestor conversion,
  // without using the facade's setter as the expected-value oracle.
  coordinates.cp_nativeContent.frame=CGRectMake(23,41,120,80);
  CGFloat screenTop=CGRectGetMinY(self.view.window.bounds)+CGRectGetMaxY(self.view.window.bounds);
  CGPoint bottomLeft=[coordinates convertPointToScreen:CGPointZero];
  checks[@"screen_conversion_known_nested_translation"]=@(Near(bottomLeft,CGPointMake(40,screenTop-152)));
  CGPoint topRight=[coordinates convertPointToScreen:CGPointMake(120,80)];
  checks[@"screen_conversion_corner_orientation"]=@(Near(topRight,CGPointMake(160,screenTop-72)));
  CGPoint outside=CGPointMake(-2.5,100.25);
  checks[@"screen_conversion_fractional_outside_bounds"]=@(Near([coordinates convertPointToScreen:outside],CGPointMake(37.5,screenTop-51.75)));
  checks[@"screen_conversion_inverse_known_point"]=@(Near([coordinates convertPointFromScreen:CGPointMake(160,screenTop-72)],CGPointMake(120,80)));
  checks[@"screen_conversion_roundtrip"]=@(Near([coordinates convertPointFromScreen:[coordinates convertPointToScreen:outside]],outside));
  [coordinates setFrame:CGRectMake(9,13,60,40) display:NO];
  checks[@"screen_conversion_tracks_resize_and_move"]=@(Near([coordinates convertPointToScreen:CGPointMake(4,7)],CGPointMake(13,20)));
  checks[@"frame_getter_matches_cocoa_screen_rect"]=@(CGRectEqualToRect(coordinates.frame,CGRectMake(9,13,60,40)));
  TestDelegate *movement=[TestDelegate new];coordinates.delegate=movement;
  [coordinates setFrameOrigin:CGPointMake(-11.5,39.25)];
  checks[@"frame_origin_moves_native_content_preserves_size"]=@(Near([coordinates convertPointToScreen:CGPointZero],CGPointMake(-11.5,39.25))&&CGSizeEqualToSize(coordinates.cp_nativeContent.bounds.size,CGSizeMake(60,40)));
  checks[@"frame_origin_and_inverse_conversion_agree"]=@(Near([coordinates convertPointFromScreen:coordinates.frame.origin],CGPointZero));
  checks[@"native_move_delegate_callback"]=@(movement.moveCount==1&&movement.resizeCount==0);
  rejected=NO;@try {[coordinates setFrameOrigin:CGPointMake(INFINITY,0)];}@catch(NSException *e){rejected=[e.name isEqual:NSInvalidArgumentException];}
  checks[@"nonfinite_frame_origin_rejected"]=@(rejected);
  rejected=NO;@try {[coordinates convertPointToScreen:CGPointMake(NAN,0)];}@catch(NSException *e){rejected=[e.name isEqual:NSInvalidArgumentException];}
  checks[@"screen_conversion_nan_rejected"]=@(rejected);
  rejected=NO;@try {[coordinates convertPointFromScreen:CGPointMake(0,INFINITY)];}@catch(NSException *e){rejected=[e.name isEqual:NSInvalidArgumentException];}
  checks[@"screen_conversion_infinity_rejected"]=@(rejected);
  NSView *safe=[[NSView alloc]initWithFrame:coordinates.contentLayoutRect];coordinates.contentView=safe;
  CGRect nativeSafe=UIEdgeInsetsInsetRect(safe.cp_nativeView.bounds,safe.cp_nativeView.safeAreaInsets);
  if(CGRectIsEmpty(nativeSafe))nativeSafe=CGRectZero;
  checks[@"safe_area_matches_native_geometry"]=@(CGRectEqualToRect(safe.safeAreaRect,nativeSafe));
  [coordinates makeKeyAndOrderFront:nil];
  checks[@"native_main_window_registered"]=@(NSApplication.sharedApplication.mainWindow==coordinates);
  NSWindow *secondary=[[NSWindow alloc]initWithContentRect:CGRectMake(0,0,10,10) styleMask:0 backing:2 defer:NO screen:NSScreen.mainScreen];[secondary makeKeyAndOrderFront:nil];
  checks[@"native_main_window_distinct_from_key"]=@(NSApplication.sharedApplication.mainWindow==coordinates&&NSApplication.sharedApplication.keyWindow==secondary);
  [secondary close];CGRect beforeDetach=coordinates.frame;[coordinates close];
  checks[@"detached_window_preserves_cocoa_frame"]=@(CGRectEqualToRect(beforeDetach,coordinates.frame));
  checks[@"native_main_window_cleared_on_close"]=@(NSApplication.sharedApplication.mainWindow==nil);
  rejected=NO;@try {[coordinates convertPointToScreen:CGPointZero];}@catch(NSException *e){rejected=[e.name isEqual:NSInternalInconsistencyException];}
  checks[@"screen_conversion_detached_rejected"]=@(rejected);
  rejected=NO;@try {[coordinates convertPointFromScreen:CGPointZero];}@catch(NSException *e){rejected=[e.name isEqual:NSInternalInconsistencyException];}
  checks[@"inverse_screen_conversion_detached_rejected"]=@(rejected);
  [container removeFromSuperview];
  __block BOOL dueTimerFired=NO;
  NSTimer *dueTimer=[NSTimer timerWithTimeInterval:1 repeats:NO block:^(NSTimer *timer){dueTimerFired=YES;}];dueTimer.fireDate=NSDate.distantPast;
  [NSRunLoop.mainRunLoop addTimer:dueTimer forMode:NSDefaultRunLoopMode];
  // UIKit may service focus/input sources first. The game polls repeatedly;
  // verify bounded progress without assuming one iteration drains all sources.
  for(NSUInteger poll=0;poll<8&&!dueTimerFired;poll++)[NSApplication.sharedApplication nextEventMatchingMask:0 untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  checks[@"nonblocking_event_poll_services_due_native_timer"]=@(dueTimerFired);[dueTimer invalidate];
  __block BOOL expiredTimerFired=NO;
  NSTimer *expiredTimer=[NSTimer timerWithTimeInterval:1 repeats:NO block:^(NSTimer *timer){expiredTimerFired=YES;}];expiredTimer.fireDate=NSDate.distantPast;
  [NSRunLoop.mainRunLoop addTimer:expiredTimer forMode:NSDefaultRunLoopMode];
  for(NSUInteger poll=0;poll<8&&!expiredTimerFired;poll++)[NSApplication.sharedApplication nextEventMatchingMask:0 untilDate:NSDate.distantPast inMode:NSDefaultRunLoopMode dequeue:YES];
  checks[@"expired_event_poll_services_due_native_timer"]=@(expiredTimerFired);[expiredTimer invalidate];
  __block BOOL futureTimerFired=NO;
  NSTimer *futureTimer=[NSTimer timerWithTimeInterval:1 repeats:NO block:^(NSTimer *timer){futureTimerFired=YES;}];
  [NSRunLoop.mainRunLoop addTimer:futureTimer forMode:NSDefaultRunLoopMode];
  [NSApplication.sharedApplication nextEventMatchingMask:0 untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
  checks[@"nonblocking_event_poll_does_not_wait_for_future_timer"]=@(!futureTimerFired);[futureTimer invalidate];
  NSScreen *retired=NSScreen.mainScreen;[NSScreen cp_setMainNativeWindow:nil];
  checks[@"disconnected_screen_inventory_empty"]=@(NSScreen.mainScreen==nil&&NSScreen.screens.count==0);
  rejected=NO;@try {(void)retired.frame;}@catch(NSException *exception){rejected=[exception.name isEqual:NSInternalInconsistencyException];}
  checks[@"retired_screen_snapshot_rejected"]=@(rejected);
 } @catch(NSException *exception){report[@"exception"]=exception.reason?:exception.name;}
 report[@"checks"]=checks;BOOL passed=checks.count==95&&report[@"exception"]==nil;
 for(NSNumber *value in checks.allValues)passed=passed&&value.boolValue;
 report[@"state"]=passed?@"passed":@"failed";report[@"check_count"]=@(checks.count);
 NSURL *documents=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
 [[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil] writeToURL:[documents URLByAppendingPathComponent:@"adapter-check-results.json"] options:NSDataWritingAtomic error:nil];
 UILabel *label=[UILabel new];label.frame=self.view.bounds;label.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;label.numberOfLines=0;label.text=[NSString stringWithFormat:@"Adapter checks: %@ (%lu checks)",report[@"state"],(unsigned long)checks.count];[self.view addSubview:label];
}
@end
UIViewController *CPCreateAdapterChecksController(void){return [ChecksController new];}
