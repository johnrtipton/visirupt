#import "CPPresentationTrace.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <stdatomic.h>
#include <pthread.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <dlfcn.h>
#import "CPApplicationEvents.h"
static int traceFD=-1;
static pthread_mutex_t logLock=PTHREAD_MUTEX_INITIALIZER;
static _Atomic unsigned phase;
static _Atomic unsigned long long acquired[3],missing[3],presented[3],committed[3],completed[3],failed[3];
static _Atomic unsigned long long mainPolls[3],nonblockingPolls[3];
static _Atomic double lastUIObservation;
static IMP originalNext,originalPresent,originalPresentAt,originalPresentAfter,originalCommit;
static IMP originalPoll;
static __weak UIWindow *traceWindow;
static CFRunLoopObserverRef observer;
static dispatch_source_t summaryTimer;
static void Log(NSDictionary *record) {
 int saved=errno;
 NSData *data=[NSJSONSerialization dataWithJSONObject:record options:0 error:nil];
 if(data){pthread_mutex_lock(&logLock);if(traceFD>=0){write(traceFD,data.bytes,data.length);write(traceFD,"\n",1);}pthread_mutex_unlock(&logLock);}
 errno=saved;
}
static BOOL Sample(unsigned long long count){return count<=8||count%300==0;}
static NSString *CallerImage(void *address){Dl_info info={0};return dladdr(address,&info)&&info.dli_fname?[@(info.dli_fname) lastPathComponent]:@"unknown";}
static id Next(id layer,SEL selector) {
 id<CAMetalDrawable> drawable=((id(*)(id,SEL))originalNext)(layer,selector);
 unsigned p=atomic_load(&phase);
 unsigned long long n=drawable?atomic_fetch_add(&acquired[p],1)+1:atomic_fetch_add(&missing[p],1)+1;
 int saved=errno;
 if(Sample(n))Log(@{@"event":@"next_drawable",@"phase":@(p),@"count":@(n),@"caller_image":CallerImage(__builtin_return_address(0)),@"returned_drawable":@(drawable!=nil),@"width":@(drawable.texture.width),@"height":@(drawable.texture.height)});
 errno=saved;
 return drawable;
}
static void RecordPresent(id<MTLDrawable> drawable,NSString *variant,void *caller) {
 int saved=errno;
 unsigned p=atomic_load(&phase);unsigned long long n=atomic_fetch_add(&presented[p],1)+1;
 if(Sample(n))Log(@{@"event":@"present_requested",@"phase":@(p),@"count":@(n),@"caller_image":CallerImage(caller),@"variant":variant,@"drawable_present":@(drawable!=nil)});
 errno=saved;
}
static void Present(id buffer,SEL selector,id<MTLDrawable> drawable){RecordPresent(drawable,@"immediate",__builtin_return_address(0));((void(*)(id,SEL,id))originalPresent)(buffer,selector,drawable);}
static void PresentAt(id buffer,SEL selector,id<MTLDrawable> drawable,double time){RecordPresent(drawable,@"at_time",__builtin_return_address(0));((void(*)(id,SEL,id,double))originalPresentAt)(buffer,selector,drawable,time);}
static void PresentAfter(id buffer,SEL selector,id<MTLDrawable> drawable,double time){RecordPresent(drawable,@"after_duration",__builtin_return_address(0));((void(*)(id,SEL,id,double))originalPresentAfter)(buffer,selector,drawable,time);}
static void Commit(id<MTLCommandBuffer> buffer,SEL selector) {
 unsigned p=atomic_load(&phase);unsigned long long n=atomic_fetch_add(&committed[p],1)+1;
 [buffer addCompletedHandler:^(id<MTLCommandBuffer> result){
  BOOL ok=result.status==MTLCommandBufferStatusCompleted;
  unsigned long long count=ok?atomic_fetch_add(&completed[p],1)+1:atomic_fetch_add(&failed[p],1)+1;
  if(!ok||Sample(count))Log(@{@"event":@"command_buffer_finished",@"phase":@(p),@"count":@(count),@"status":@(result.status),@"error":result.error.localizedDescription?:@""});
 }];
 if(Sample(n))Log(@{@"event":@"command_buffer_commit",@"phase":@(p),@"count":@(n)});
 ((void(*)(id,SEL))originalCommit)(buffer,selector);
}
static id Poll(id application,SEL selector,NSUInteger mask,NSDate *date,NSString *mode,BOOL dequeue) {
 if(NSThread.isMainThread) {
  int saved=errno;unsigned p=atomic_load(&phase);unsigned long long count=atomic_fetch_add(&mainPolls[p],1)+1;
  if(!date||date.timeIntervalSinceNow<=0)atomic_fetch_add(&nonblockingPolls[p],1);
  if(Sample(count))Log(@{@"event":@"native_event_poll",@"phase":@(p),@"count":@(count),@"until_date_nil":@(date==nil),@"mode":mode?:@"nil",@"caller_image":CallerImage(__builtin_return_address(0))});errno=saved;
 }
 return ((id(*)(id,SEL,NSUInteger,NSDate *,NSString *,BOOL))originalPoll)(application,selector,mask,date,mode,dequeue);
}
static BOOL Hook(Class cls,SEL selector,IMP replacement,IMP *original) {
 Method method=class_getInstanceMethod(cls,selector);if(!method)return NO;
 *original=method_getImplementation(method);
 class_replaceMethod(cls,selector,replacement,method_getTypeEncoding(method));return YES;
}
NSDictionary *CPPresentationTraceCounts(void) {
 unsigned p=atomic_load(&phase);
 return @{@"phase":@(p),@"drawables_acquired":@(atomic_load(&acquired[p])),@"drawables_nil":@(atomic_load(&missing[p])),@"presentation_requests":@(atomic_load(&presented[p])),@"command_buffers_committed":@(atomic_load(&committed[p])),@"command_buffers_completed":@(atomic_load(&completed[p])),@"command_buffers_failed":@(atomic_load(&failed[p])),@"main_event_polls":@(atomic_load(&mainPolls[p])),@"nonblocking_main_event_polls":@(atomic_load(&nonblockingPolls[p]))};
}
static void WalkLayer(CALayer *layer,NSMutableArray *layers,unsigned *visited) {
 if(++*visited>128)return;
 if([layer isKindOfClass:CAMetalLayer.class]) {
  CAMetalLayer *metal=(CAMetalLayer *)layer;
  [layers addObject:@{@"frame":NSStringFromCGRect(metal.frame),@"bounds":NSStringFromCGRect(metal.bounds),@"drawable_size":NSStringFromCGSize(metal.drawableSize),@"hidden":@(metal.hidden),@"attached_to_superlayer":@(metal.superlayer!=nil),@"device":metal.device.name?:@"none",@"pixel_format":@(metal.pixelFormat)}];
 }
 for(CALayer *child in layer.sublayers){if(*visited>=128)break;WalkLayer(child,layers,visited);}
}
static void ObserveUI(void) {
 if(!NSThread.isMainThread)return;
 UIWindow *window=traceWindow;if(!window)return;
 double now=CACurrentMediaTime();if(now-atomic_load(&lastUIObservation)<1)return;
 atomic_store(&lastUIObservation,now);NSMutableArray *layers=[NSMutableArray new];unsigned visited=0;WalkLayer(window.layer,layers,&visited);
 Log(@{@"event":@"native_ui_observation",@"phase":@(atomic_load(&phase)),@"time":@(now),@"window_bounds":NSStringFromCGRect(window.bounds),@"window_hidden":@(window.hidden),@"metal_layers":layers});
}
NSDictionary *CPPresentationTraceBegin(UIWindow *window,id<MTLDevice> device) {
 NSCAssert(NSThread.isMainThread,@"Presentation trace setup must be on the UI thread");
 if(originalNext)return @{@"state":@"ALREADY_INSTALLED"};
 NSURL *documents=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
 traceFD=open([documents URLByAppendingPathComponent:@"native-presentation-trace.jsonl"].fileSystemRepresentation,O_CREAT|O_WRONLY|O_TRUNC,0600);
 traceWindow=window;atomic_store(&phase,1);
 id<MTLCommandQueue> queue=[device newCommandQueue];id<MTLCommandBuffer> buffer=queue.commandBuffer;Class cls=object_getClass(buffer);
 BOOL next=Hook(CAMetalLayer.class,@selector(nextDrawable),(IMP)Next,&originalNext);
 BOOL present=Hook(cls,@selector(presentDrawable:),(IMP)Present,&originalPresent);
 BOOL commit=Hook(cls,@selector(commit),(IMP)Commit,&originalCommit);
 BOOL at=Hook(cls,@selector(presentDrawable:atTime:),(IMP)PresentAt,&originalPresentAt);
 BOOL after=Hook(cls,NSSelectorFromString(@"presentDrawable:afterMinimumDuration:"),(IMP)PresentAfter,&originalPresentAfter);
 BOOL poll=Hook(NSApplication.class,@selector(nextEventMatchingMask:untilDate:inMode:dequeue:),(IMP)Poll,&originalPoll);
 observer=CFRunLoopObserverCreateWithHandler(NULL,kCFRunLoopBeforeWaiting|kCFRunLoopExit,true,0,^(CFRunLoopObserverRef o,CFRunLoopActivity activity){ObserveUI();});
 CFRunLoopAddObserver(CFRunLoopGetMain(),observer,kCFRunLoopCommonModes);
 NSDictionary *result=@{@"state":traceFD>=0&&next&&present&&commit&&poll?@"INSTALLED":@"INCOMPLETE",@"command_buffer_class":NSStringFromClass(cls)?:@"none",@"next_drawable":@(next),@"present":@(present),@"commit":@(commit),@"present_at_time":@(at),@"present_after_duration":@(after),@"event_poll":@(poll),@"scope":@"process-local native forwarding trace; no frame or compositor success inferred"};
 Log(result);ObserveUI();return result;
}
void CPPresentationTraceEnginePhase(void) {
 atomic_store(&phase,2);
 summaryTimer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_global_queue(QOS_CLASS_UTILITY,0));
 dispatch_source_set_timer(summaryTimer,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),2*NSEC_PER_SEC,NSEC_PER_SEC/10);
 __block unsigned summaries=0;
 dispatch_source_set_event_handler(summaryTimer,^{
  NSMutableDictionary *state=[CPPresentationTraceCounts() mutableCopy];state[@"event"]=@"engine_presentation_summary";state[@"ui_observation_age_seconds"]=@(CACurrentMediaTime()-atomic_load(&lastUIObservation));Log(state);
  if(++summaries>=60)dispatch_source_cancel(summaryTimer);
 });dispatch_resume(summaryTimer);
}
BOOL CPPresentationTraceControl(UIWindow *window,id<MTLDevice> device) {
 UIView *host=[[UIView alloc]initWithFrame:CGRectMake(2,2,8,8)];[window addSubview:host];
 CAMetalLayer *layer=[CAMetalLayer layer];layer.device=device;layer.pixelFormat=MTLPixelFormatBGRA8Unorm;layer.frame=host.bounds;layer.drawableSize=CGSizeMake(8,8);[host.layer addSublayer:layer];[CATransaction flush];
 id<CAMetalDrawable> drawable=[layer nextDrawable];
 BOOL passed=NO;
 if(drawable){
  id<MTLCommandQueue> queue=[device newCommandQueue];id<MTLCommandBuffer> buffer=queue.commandBuffer;
  MTLRenderPassDescriptor *pass=[MTLRenderPassDescriptor renderPassDescriptor];pass.colorAttachments[0].texture=drawable.texture;pass.colorAttachments[0].loadAction=MTLLoadActionClear;pass.colorAttachments[0].storeAction=MTLStoreActionStore;pass.colorAttachments[0].clearColor=MTLClearColorMake(0.1,0.6,0.2,1);
  id<MTLRenderCommandEncoder> encoder=[buffer renderCommandEncoderWithDescriptor:pass];[encoder endEncoding];[buffer presentDrawable:drawable];[buffer commit];[buffer waitUntilCompleted];
  NSDictionary *counts=CPPresentationTraceCounts();passed=encoder&&buffer.status==MTLCommandBufferStatusCompleted&&[counts[@"drawables_acquired"] unsignedLongLongValue]>0&&[counts[@"presentation_requests"] unsignedLongLongValue]>0&&[counts[@"command_buffers_completed"] unsignedLongLongValue]>0;
 }
 [host removeFromSuperview];Log(@{@"event":@"own_rendering_control",@"passed":@(passed),@"original_game_executed":@NO});return passed;
}
