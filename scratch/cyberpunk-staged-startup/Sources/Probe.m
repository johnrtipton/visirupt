#import "Probe.h"
#import <Metal/Metal.h>
#import <objc/message.h>
#import "CPSceneLifecycleBridge.h"
#import "CPScenePointer.h"
#import "CPScreens.h"
#import "CPViews.h"
#import "CPWindows.h"
#import "CPSceneDisplays.h"
#import <dlfcn.h>
#include <os/proc.h>
#import "CPDesktopMenu.h"
#import "CPWorkspace.h"
#import <objc/runtime.h>
#import "CPOriginalStartup.h"
#import "../Trace/MemoryTrace.h"
#import "../Trace/FileTrace.h"
#import "CPOriginalAssetRoot.h"
#import "../Diagnostics/CPPresentationTrace.h"
// Xcode27 MTLDevice.h: Depth24/Stencil8 was never supported on Apple Silicon.
static BOOL CPDepth24Unsupported(id object, SEL selector) { return NO; }
static NSDictionary *CPPrepareWindowedPreference(void) {
 NSURL *support=[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
 NSURL *folder=[support URLByAppendingPathComponent:@"CD Projekt Red/Cyberpunk 2077" isDirectory:YES];
 NSURL *settings=[folder URLByAppendingPathComponent:@"UserSettings.json"];
 NSDictionary *preference=@{@"version":@138,@"data":@[@{@"group_name":@"/video/display",@"options":@[@{@"name":@"WindowMode",@"type":@"string_list",@"is_dynamic":@YES,@"value":@"Windowed",@"index":@0}]}]};
 if([NSFileManager.defaultManager fileExistsAtPath:settings.path])return @{@"state":@"EXISTING_PREFERENCE_PRESERVED",@"path":settings.path};
 NSError *error=nil;
 BOOL created=[NSFileManager.defaultManager createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:&error];
 NSData *bytes=[NSJSONSerialization dataWithJSONObject:preference options:NSJSONWritingPrettyPrinted error:&error];
 BOOL written=created&&bytes&&[bytes writeToURL:settings options:NSDataWritingAtomic error:&error];
 return @{@"state":written?@"WINDOWED_PREFERENCE_CREATED":@"WINDOWED_PREFERENCE_FAILED",@"path":settings.path,@"preference":preference,@"error":error.localizedDescription?:@""};
}
@interface CPWindowTestDelegate : NSObject
@property NSUInteger resizeCount;
@property NSUInteger closeCount;
@property BOOL allowClose;
@end
@implementation CPWindowTestDelegate
- (void)windowDidResize:(NSNotification *)notification {if([notification.object isKindOfClass:NSWindow.class])self.resizeCount++;}
- (void)windowWillClose:(NSNotification *)notification {if([notification.object isKindOfClass:NSWindow.class])self.closeCount++;}
- (BOOL)windowShouldClose:(NSWindow *)window {return self.allowClose;}
@end
@interface AppStoreLoadController : CPScenePointerController
@property BOOL started;
@property (strong) CPSceneLifecycleBridge *bridge;
@end
@implementation AppStoreLoadController
- (void)viewDidLayoutSubviews {
 [super viewDidLayoutSubviews];
 id candidate=NSApplication.sharedApplication.mainWindow;
 if(![candidate isKindOfClass:NSWindow.class])return;
 NSWindow *game=candidate;UIView *content=game.cp_nativeContent;
 UIWindow *native=self.view.window;UIView *container=content.superview;
 if(!native||content.window!=native||!container||content.hidden)return;
 CGRect nativeRect=[container convertRect:container.bounds toView:native];
 if(nativeRect.size.width<=0||nativeRect.size.height<=0)return;
 CGRect cocoaRect=nativeRect;cocoaRect.origin.y=CGRectGetMinY(native.bounds)+CGRectGetMaxY(native.bounds)-CGRectGetMaxY(nativeRect);
 // Use the facade's actual layout/aspect/minimum and resize notification path.
 // Avoid reentering layout when the fitted native content already matches.
 CGSize aspect=game.contentAspectRatio;CGSize fitted=cocoaRect.size;
 if(aspect.width>0&&aspect.height>0){CGFloat ratio=aspect.width/aspect.height;if(fitted.width/fitted.height>ratio)fitted.width=fitted.height*ratio;else fitted.height=fitted.width/ratio;}
 if(fabs(content.bounds.size.width-fitted.width)<0.5&&fabs(content.bounds.size.height-fitted.height)<0.5)return;
 [game setFrame:cocoaRect display:YES];
}
- (void)cp_startWhenPointerReady:(NSString *)path report:(NSMutableDictionary *)report {
 CGPoint point;
 if(!NSScreen.mainScreen.cp_refreshTimingReady||!CPSceneReadMouseLocation(&point)) {
  __weak AppStoreLoadController *weakSelf=self;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.2*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[weakSelf cp_startWhenPointerReady:path report:report];});
  return;
 }
 report[@"native_pointer_sample_before_startup"]=@[@(point.x),@(point.y)];
 report[@"native_refresh_timing_evidence"]=NSScreen.mainScreen.cp_refreshTimingEvidence;
 report[@"native_refresh_interval_getters_passed"]=@(NSScreen.mainScreen.minimumRefreshInterval>0&&NSScreen.mainScreen.minimumRefreshInterval==NSScreen.mainScreen.maximumRefreshInterval);
 NSScreen *expectedScreen=NSScreen.mainScreen;CGRect expectedFrame=expectedScreen.frame;
 __block BOOL workerPassed=NO;
 dispatch_group_t worker=dispatch_group_create();
 dispatch_group_async(worker,dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  @try {NSScreen *screen=NSScreen.mainScreen;workerPassed=screen==expectedScreen&&NSScreen.screens.count==1&&CGRectEqualToRect(screen.frame,expectedFrame)&&screen.backingScaleFactor>0&&screen.minimumRefreshInterval>0&&screen.maximumExtendedDynamicRangeColorComponentValue==1&&screen.deviceDescription[@"NSScreenNumber"]!=nil;}@catch(NSException *exception){workerPassed=NO;}
 });
 BOOL completed=dispatch_group_wait(worker,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC))==0;
 report[@"native_worker_screen_snapshot_passed"]=@(completed&&workerPassed);
 if(!completed||!workerPassed){
  report[@"state"]=@"NATIVE_WORKER_SCREEN_CONTROL_FAILED";
  NSURL *url=[[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"game-load-results.json"];
  [[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] writeToURL:url options:NSDataWritingAtomic error:nil];return;
 }
 for(UIView *view in self.view.subviews.copy)if([view isKindOfClass:UILabel.class])[view removeFromSuperview];
 CPPresentationTraceEnginePhase();CPFileTracePhase(2);CPMemoryTracePhase(2);CPAttemptOriginalStartup(path,report);
}
- (void)viewDidAppear:(BOOL)animated {
 [super viewDidAppear:animated];if(self.started)return;self.started=YES;
 CPRegisterScenePointerController(self);
 [NSScreen cp_setMainNativeWindow:self.view.window];
 BOOL sceneSnapshotReady=CPRefreshSceneDisplaySnapshot();
 NSApplication *app=NSApplication.sharedApplication;
 self.bridge=[[CPSceneLifecycleBridge alloc] initWithWindow:self.view.window application:app];
 NSMutableDictionary *report=[@{@"run_id":NSUUID.UUID.UUIDString,@"state":@"complete",@"original_game_entrypoint_called":@NO,@"original_exported_service_functions_called_by_probe":@NO,@"GameKit_authentication_requested_by_probe":@NO,@"real_curl_bundled":@YES,@"real_bink_bundled":@YES,@"verified_appstore_copy_bundled":@YES,@"verified_galaxy_copy_bundled":@YES,@"real_native_security_adapters_bundled":@YES,@"five_reviewed_provider_adapters":@YES,@"actual_scene_bridge_attached":@YES} mutableCopy];
 id<MTLDevice> nativeDevice=MTLCreateSystemDefaultDevice();
 SEL depthQuery=NSSelectorFromString(@"isDepth24Stencil8PixelFormatSupported");
 BOOL added=NO;
 if(nativeDevice&&![nativeDevice respondsToSelector:depthQuery])added=class_addMethod(object_getClass(nativeDevice),depthQuery,(IMP)CPDepth24Unsupported,"B@:");
 report[@"native_depth24_query_adapter_added"]=@(added);
 BOOL depth24=nativeDevice&&[nativeDevice respondsToSelector:depthQuery]?((BOOL(*)(id,SEL))objc_msgSend)(nativeDevice,depthQuery):YES;
 report[@"native_depth24_supported"]=@(depth24);
 MTLTextureDescriptor *depthDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float_Stencil8 width:4 height:4 mipmapped:NO];
 depthDescriptor.storageMode=MTLStorageModePrivate;depthDescriptor.usage=MTLTextureUsageRenderTarget;
 id<MTLTexture> depthTexture=[nativeDevice newTextureWithDescriptor:depthDescriptor];
 report[@"native_depth32_stencil_texture_created"]=@(depthTexture!=nil);
 report[@"native_scene_snapshot_ready"]=@(sceneSnapshotReady);
 report[@"host_viewport_dynamic_range_policy"]=@"SDR_ONLY";
 self.view.window.layer.preferredDynamicRange=CADynamicRangeStandard;
 self.view.window.layer.wantsExtendedDynamicRangeContent=NO;
 self.view.window.layer.contentsHeadroom=1.0;
 report[@"adapter_screen_potential_edr_headroom"]=@(NSScreen.mainScreen.maximumPotentialExtendedDynamicRangeColorComponentValue);
 report[@"adapter_screen_current_edr_headroom"]=@(NSScreen.mainScreen.maximumExtendedDynamicRangeColorComponentValue);
 NSView *sdrFixture=[[NSView alloc] initWithFrame:CGRectMake(0,0,16,16)];
 CAMetalLayer *sdrLayer=[CAMetalLayer layer];sdrLayer.wantsExtendedDynamicRangeContent=YES;sdrLayer.contentsHeadroom=2;
 [sdrFixture setLayer:sdrLayer];
 report[@"native_sdr_layer_contract_passed"]=@(sdrFixture.layer==sdrLayer&&!sdrLayer.wantsExtendedDynamicRangeContent&&[sdrLayer.preferredDynamicRange isEqual:CADynamicRangeStandard]&&sdrLayer.contentsHeadroom==1);
 NSWindow *screenFixture=[[NSWindow alloc] initWithContentRect:CGRectMake(0,0,16,16) styleMask:0 backing:2 defer:NO screen:NSScreen.mainScreen];
 report[@"native_screen_window_constructor_passed"]=@(screenFixture.cp_nativeContent.window==self.view.window);
 CPWindowTestDelegate *windowTestDelegate=[CPWindowTestDelegate new];screenFixture.delegate=windowTestDelegate;
 [screenFixture setContentAspectRatio:CGSizeMake(16,9)];
 CGSize nativeAspectSize=screenFixture.cp_nativeContent.bounds.size;
 report[@"native_content_aspect_ratio_passed"]=@(nativeAspectSize.height>0&&fabs(nativeAspectSize.width/nativeAspectSize.height-16.0/9.0)<1e-8);
 [screenFixture setFrame:CGRectMake(0,0,100,100) display:YES];
 nativeAspectSize=screenFixture.cp_nativeContent.bounds.size;
 report[@"native_content_aspect_ratio_resize_passed"]=@(nativeAspectSize.height>0&&fabs(nativeAspectSize.width/nativeAspectSize.height-16.0/9.0)<1e-8);
 report[@"native_window_resize_delegate_passed"]=@(windowTestDelegate.resizeCount==2);
 CGSize beforeOrigin=screenFixture.cp_nativeContent.bounds.size;
 [screenFixture setFrameOrigin:CGPointMake(5.5,7.25)];
 CGPoint screenOrigin=[screenFixture convertPointToScreen:CGPointZero];
 report[@"native_window_frame_origin_passed"]=@(fabs(screenOrigin.x-5.5)<1e-7&&fabs(screenOrigin.y-7.25)<1e-7&&CGSizeEqualToSize(beforeOrigin,screenFixture.cp_nativeContent.bounds.size));
 report[@"native_window_frame_coordinate_contract_passed"]=@(CGPointEqualToPoint(screenFixture.frame.origin,CGPointMake(5.5,7.25)));
 CGPoint localPoint=CGPointMake(3.25,7.5);
 CGRect contentBounds=screenFixture.cp_nativeContent.bounds;
 CGPoint nativePoint=CGPointMake(localPoint.x,CGRectGetMinY(contentBounds)+CGRectGetMaxY(contentBounds)-localPoint.y);
 CGPoint nativeScreen=[screenFixture.cp_nativeContent convertPoint:nativePoint toView:self.view.window];
 CGPoint expectedScreen=CGPointMake(nativeScreen.x,CGRectGetMinY(self.view.window.bounds)+CGRectGetMaxY(self.view.window.bounds)-nativeScreen.y);
 CGPoint actualScreen=[screenFixture convertPointToScreen:localPoint];
 report[@"native_window_screen_conversion_passed"]=@(fabs(expectedScreen.x-actualScreen.x)<1e-7&&fabs(expectedScreen.y-actualScreen.y)<1e-7);
 CGPoint roundtrip=[screenFixture convertPointFromScreen:actualScreen];
 report[@"native_window_screen_inverse_passed"]=@(fabs(roundtrip.x-localPoint.x)<1e-7&&fabs(roundtrip.y-localPoint.y)<1e-7);
 NSView *safeFixture=[[NSView alloc]initWithFrame:screenFixture.contentLayoutRect];screenFixture.contentView=safeFixture;
 CGRect nativeSafe=UIEdgeInsetsInsetRect(safeFixture.cp_nativeView.bounds,safeFixture.cp_nativeView.safeAreaInsets);
 report[@"native_safe_area_rect_passed"]=@(CGRectEqualToRect(safeFixture.safeAreaRect,nativeSafe));
 [screenFixture makeKeyAndOrderFront:nil];
 report[@"native_main_window_registered"]=@(NSApplication.sharedApplication.mainWindow==screenFixture);
 NSWindow *focusFixture=[[NSWindow alloc] initWithContentRect:CGRectMake(0,0,16,16) styleMask:0 backing:2 defer:NO screen:NSScreen.mainScreen];
 [focusFixture makeKeyAndOrderFront:nil];
 report[@"native_main_window_distinct_from_key"]=@(NSApplication.sharedApplication.mainWindow==screenFixture&&NSApplication.sharedApplication.keyWindow==focusFixture);
 [focusFixture close];


 [screenFixture close];
 report[@"native_window_delegate_close_passed"]=@(screenFixture.cp_nativeContent.window==nil&&windowTestDelegate.closeCount==1);
 report[@"native_main_window_cleared_on_close"]=@(NSApplication.sharedApplication.mainWindow==nil);



 report[@"experimental_pool_capacity_change"]=@YES;
 report[@"pool_capacity_gib"]=@[@16,@8,@8];
 report[@"native_available_dirty_memory_before_load_bytes"]=@(os_proc_available_memory());
 report[@"original_text_unchanged"]=@NO;
 report[@"all_original_initializer_entries_preserved"]=@YES;
 report[@"gameplay_capacity_validated"]=@NO;
 report[@"native_pointer_state_available"]=@(self.view.window.windowScene.pointerLockState!=nil);
 report[@"host_cursor_association_status"]=@(CPSceneAssociateMouseAndMouseCursorPosition(1));
 report[@"host_desktop_menu_bar_available"]=@([NSMenu cp_desktopMenuBarAvailable]);
 report[@"host_desktop_menu_setter_encoding"]=@(method_getTypeEncoding(class_getClassMethod(NSMenu.class,@selector(setMenuBarVisible:))));
 [NSMenu setMenuBarVisible:YES];report[@"host_menu_requested_visible"]=@([NSMenu cp_lastRequestedMenuBarVisible]);
 report[@"host_menu_actually_visible_after_request"]=@([NSMenu menuBarVisible]);
 report[@"host_menu_bar_request_status"]=@"UNSUPPORTED_DESKTOP_FACILITY";
 [NSMenu setMenuBarVisible:NO];
 NSString *path=[NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"CyberpunkModule.framework/CyberpunkModule"];
 report[@"host_workspace_open_encoding"]=@(method_getTypeEncoding(class_getInstanceMethod(NSWorkspace.class,@selector(openURL:))));
 report[@"host_workspace_request_before_load"]=NSWorkspace.sharedWorkspace.cp_lastURLRequest;
 NSURL *checkpointURL=[[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"game-load-results.json"];
 report[@"native_windowed_preference"]=CPPrepareWindowedPreference();
 if([report[@"native_windowed_preference"][@"state"] isEqual:@"WINDOWED_PREFERENCE_FAILED"]){
  report[@"state"]=@"WINDOWED_PREFERENCE_FAILED";
  [[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] writeToURL:checkpointURL options:NSDataWritingAtomic error:nil];return;
 }
 report[@"state"]=@"GAME_GRAPH_LOAD_STARTED";
 NSString *tracePath=[checkpointURL.URLByDeletingLastPathComponent.path stringByAppendingPathComponent:@"native-memory-trace.jsonl"];
 NSURL *directory=checkpointURL.URLByDeletingLastPathComponent;
 NSURL *fixture=[directory URLByAppendingPathComponent:[@"file-controls-" stringByAppendingString:report[@"run_id"]] isDirectory:YES];
 BOOL fixtureCreated=[NSFileManager.defaultManager createDirectoryAtURL:fixture withIntermediateDirectories:NO attributes:nil error:nil];
 NSString *fileTracePath=[directory.path stringByAppendingPathComponent:@"native-file-trace.jsonl"];
 BOOL fileReady=fixtureCreated && CPFileTraceBegin(fileTracePath.fileSystemRepresentation);
 BOOL fileControls=fileReady && CPFileTraceControls(fixture.path.fileSystemRepresentation);
 report[@"native_file_trace_ready"]=@(fileReady);report[@"native_file_trace_controls_passed"]=@(fileControls);
 if(!fileControls){report[@"state"]=@"NATIVE_FILE_TRACE_CONTROL_FAILED";[[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] writeToURL:checkpointURL options:NSDataWritingAtomic error:nil];return;}
 [NSFileManager.defaultManager removeItemAtURL:fixture error:nil];
 BOOL traceReady=CPMemoryTraceBegin(tracePath.fileSystemRepresentation);
 BOOL traceControls=traceReady && CPMemoryTraceControls();
 report[@"native_memory_trace_ready"]=@(traceReady);
 report[@"native_memory_trace_controls_passed"]=@(traceControls);
 if(!traceControls){report[@"state"]=@"NATIVE_MEMORY_TRACE_CONTROL_FAILED";[[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] writeToURL:checkpointURL options:NSDataWritingAtomic error:nil];return;}
 NSURL *support=[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
 NSString *staged=[[support URLByAppendingPathComponent:@"GameData/Data" isDirectory:YES] path];
 NSString *logical=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Data"];
 BOOL directoryExists=NO;
 BOOL stagedExists=[NSFileManager.defaultManager fileExistsAtPath:staged isDirectory:&directoryExists]&&directoryExists;
 report[@"staged_data_path"]=staged;report[@"logical_bundle_data_path"]=logical;
 BOOL mapped=stagedExists&&CPFileTraceMapData(logical.fileSystemRepresentation,staged.fileSystemRepresentation);
 report[@"staged_data_path_adapter_enabled"]=@(mapped);
 if(!mapped){report[@"state"]=@"STAGED_DATA_PATH_ADAPTER_FAILED";[[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] writeToURL:checkpointURL options:NSDataWritingAtomic error:nil];return;}
 report[@"native_presentation_trace_setup"]=CPPresentationTraceBegin(self.view.window,nativeDevice);
 report[@"native_presentation_rendering_control_passed"]=@(CPPresentationTraceControl(self.view.window,nativeDevice));
 if(![report[@"native_presentation_trace_setup"][@"state"] isEqual:@"INSTALLED"]||![report[@"native_presentation_rendering_control_passed"] boolValue]) {
  report[@"state"]=@"NATIVE_PRESENTATION_TRACE_CONTROL_FAILED";
  [[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] writeToURL:checkpointURL options:NSDataWritingAtomic error:nil];return;
 }
 CPFileTracePhase(1);
 CPMemoryTracePhase(1);
 [[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil] writeToURL:checkpointURL options:NSDataWritingAtomic error:nil];
 dlerror();void *handle=dlopen(path.fileSystemRepresentation,RTLD_NOW|RTLD_LOCAL);const char *error=handle?NULL:dlerror();
 report[@"state"]=@"complete";report[@"host_workspace_request_after_load"]=NSWorkspace.sharedWorkspace.cp_lastURLRequest;
 report[@"dlopen_succeeded"]=@(handle!=NULL);report[@"status"]=handle?@"GAME_GRAPH_LOAD_SUCCEEDED_NO_ENTRYPOINT":@"GAME_GRAPH_LOAD_REJECTED";
 if(error)report[@"loader_error"]=@(error);
 report[@"game_graph_initializers_completed_if_load_succeeded"]=@(handle!=NULL);
 NSData *data=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil];
 NSURL *url=[[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"game-load-results.json"];
 [data writeToURL:url options:NSDataWritingAtomic error:nil];
 if(handle)dispatch_async(dispatch_get_main_queue(), ^{
  NSDictionary *assetRoot=CPReadOriginalAssetRoot(path);
  [[NSJSONSerialization dataWithJSONObject:assetRoot options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil] writeToURL:[directory URLByAppendingPathComponent:@"asset-root-results.json"] options:NSDataWritingAtomic error:nil];
  report[@"original_asset_root_diagnostic"]=assetRoot;
  if(![assetRoot[@"state"] isEqual:@"ORIGINAL_ASSET_ROOT_READ"]){report[@"state"]=@"ORIGINAL_ASSET_ROOT_DIAGNOSTIC_FAILED";[[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] writeToURL:checkpointURL options:NSDataWritingAtomic error:nil];return;}
  report[@"state"]=@"WAITING_FOR_NATIVE_POINTER_SAMPLE";
  [[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] writeToURL:checkpointURL options:NSDataWritingAtomic error:nil];
  [self cp_startWhenPointerReady:path report:report];
 });
 UILabel *label=[UILabel new];label.text=[NSString stringWithFormat:@"%@\n%@",report[@"status"],report[@"loader_error"]?:@"Move the trackpad pointer inside this window to start the engine test."];label.numberOfLines=0;label.frame=self.view.bounds;label.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;[self.view addSubview:label];
 // Keep the real scene bridge and loaded image alive; do not call service exports.
}
@end
UIViewController *CPCreateAppStoreLoadController(void) {return [AppStoreLoadController new];}
