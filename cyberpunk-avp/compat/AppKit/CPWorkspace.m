#import "CPWorkspace.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
@interface CPWorkspaceState : NSObject
@property(strong) NSLock *lock;
@property(strong) NSMutableDictionary *request;
@property NSUInteger sequence;
@end
@implementation CPWorkspaceState @end
static char workspaceKey;
static CPWorkspaceState *workspaceState(NSWorkspace *workspace) {
 @synchronized(workspace) {
  CPWorkspaceState *state=objc_getAssociatedObject(workspace,&workspaceKey);
  if(!state){state=[CPWorkspaceState new];state.lock=[NSLock new];state.request=[@{@"status":@"NO_REQUEST",@"completed":@NO,@"native_success":NSNull.null} mutableCopy];objc_setAssociatedObject(workspace,&workspaceKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}return state;
 }
}
@implementation NSWorkspace
+ (NSWorkspace *)sharedWorkspace {static NSWorkspace *workspace;static dispatch_once_t once;dispatch_once(&once,^{workspace=[NSWorkspace new];});return workspace;}
- (NSDictionary *)cp_lastURLRequest {CPWorkspaceState *state=workspaceState(self);[state.lock lock];NSDictionary *snapshot=state.request.copy;[state.lock unlock];return snapshot;}
- (BOOL)openURL:(NSURL *)url {
 if(url&&![url isKindOfClass:NSURL.class])[NSException raise:NSInvalidArgumentException format:@"Expected a native NSURL"];
 NSURL *target=url.copy;BOOL valid=target.scheme.length>0;
 CPWorkspaceState *state=workspaceState(self);[state.lock lock];NSUInteger sequence=++state.sequence;
 NSMutableDictionary *record=[@{@"sequence":@(sequence),@"status":valid?@"QUEUED":@"INVALID_URL",@"completed":@(!valid),@"native_request_issued":@NO,@"native_success":valid?(id)NSNull.null:@NO,@"synchronous_success_confirmed":@NO} mutableCopy];state.request=record;[state.lock unlock];
 if(!valid)return NO;
 // UIKit requires main-queue invocation. Capture each record separately so an old
 // completion cannot replace a later request's status. Do not log URL contents.
 dispatch_async(dispatch_get_main_queue(),^{
  [state.lock lock];record[@"native_request_issued"]=@YES;record[@"native_request_on_main_thread"]=@(NSThread.isMainThread);record[@"status"]=@"PENDING_NATIVE_COMPLETION";[state.lock unlock];
  [UIApplication.sharedApplication openURL:target options:@{} completionHandler:^(BOOL success){
   [state.lock lock];record[@"completed"]=@YES;record[@"native_success"]=@(success);record[@"native_completion_on_main_thread"]=@(NSThread.isMainThread);record[@"status"]=success?@"NATIVE_OPEN_SUCCEEDED":@"NATIVE_OPEN_FAILED";[state.lock unlock];
  }];
 });
 return NO;
}
@end
