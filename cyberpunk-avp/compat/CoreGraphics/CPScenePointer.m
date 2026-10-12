#import "CPScenePointer.h"
#import "CPScreens.h"
#import <objc/runtime.h>
#include <math.h>
static char requestedKey;
static __weak CPScenePointerController *registeredController;
static __weak UIWindow *sampleWindow;
static CGPoint samplePoint;
static BOOL sampleKnown;
@implementation CPScenePointerController
- (void)viewDidLoad {
 [super viewDidLoad];
 UIHoverGestureRecognizer *hover=[[UIHoverGestureRecognizer alloc]initWithTarget:self action:@selector(cp_observeHover:)];
 [self.view addGestureRecognizer:hover];
}
- (void)cp_observeHover:(UIHoverGestureRecognizer *)gesture {
 BOOL present=gesture.state==UIGestureRecognizerStateBegan||gesture.state==UIGestureRecognizerStateChanged;
 CPSceneObserveMouseLocation(self.view,[gesture locationInView:self.view],present);
}
- (void)viewDidLayoutSubviews {
 [super viewDidLayoutSubviews];
 if(NSScreen.mainScreen.cp_nativeWindow==self.viewIfLoaded.window)[NSScreen cp_notifyNativeViewportChanged];
}
- (BOOL)cp_requestedPointerLock { return [objc_getAssociatedObject(self,&requestedKey) boolValue]; }
- (BOOL)prefersPointerLocked { return self.cp_requestedPointerLock; }
- (void)cp_requestPointerLock:(BOOL)locked {
 if(!NSThread.isMainThread)[NSException raise:NSInternalInconsistencyException format:@"Pointer preferences require the main thread"];
 objc_setAssociatedObject(self,&requestedKey,@(locked),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
 [self setNeedsUpdateOfPrefersPointerLocked];
}
@end
void CPRegisterScenePointerController(CPScenePointerController *controller) {
 if(!NSThread.isMainThread)[NSException raise:NSInternalInconsistencyException format:@"Pointer registration requires the main thread"];
 if(registeredController && registeredController!=controller)[registeredController cp_requestPointerLock:NO];
 if(registeredController!=controller){sampleKnown=NO;sampleWindow=nil;}
 registeredController=controller;
}
void CPSceneObserveMouseLocation(UIView *view,CGPoint point,BOOL present) {
 if(!NSThread.isMainThread)[NSException raise:NSInternalInconsistencyException format:@"Pointer samples require the main thread"];
 UIWindow *window=registeredController.viewIfLoaded.window;
 if(!window||view.window!=window)return;
 // A tracking exit ends region membership, not knowledge of the pointer.
 // Preserve only observed coordinates in this same live native scene.
 if(!present&&!sampleKnown)return;
 if(!isfinite(point.x)||!isfinite(point.y))[NSException raise:NSInvalidArgumentException format:@"Pointer sample must be finite"];
 samplePoint=[view convertPoint:point toView:window];sampleWindow=window;sampleKnown=YES;
}
BOOL CPSceneReadMouseLocation(CGPoint *point) {
 if(!NSThread.isMainThread)[NSException raise:NSInternalInconsistencyException format:@"Pointer queries require the main thread"];
 UIWindow *window=registeredController.viewIfLoaded.window;
 if(!point||!sampleKnown||!window||sampleWindow!=window||window!=NSScreen.mainScreen.cp_nativeWindow||window.hidden)return NO;
 *point=CGPointMake(samplePoint.x,CGRectGetMinY(window.bounds)+CGRectGetMaxY(window.bounds)-samplePoint.y);return YES;
}
CGError CPSceneAssociateMouseAndMouseCursorPosition(int32_t associate) {
 if(associate!=0 && associate!=1)return kCGErrorIllegalArgument;
 if(!NSThread.isMainThread)return kCGErrorInvalidOperation;
 CPScenePointerController *controller=registeredController;
 if(!controller)return kCGErrorNotImplemented;
 UIWindow *window=controller.viewIfLoaded.window;
 if(!window || !window.isKeyWindow || window.windowScene.activationState!=UISceneActivationStateForegroundActive)return kCGErrorInvalidOperation;
 UIPointerLockState *state=window.windowScene.pointerLockState;
 if(!state)return kCGErrorNotImplemented;
 BOOL locked=!associate;
 [controller cp_requestPointerLock:locked];
 // UIKit may decline or asynchronously honor the preference. Do not claim
 // success merely because the request was made.
 return state.isLocked==locked ? kCGErrorSuccess : kCGErrorCannotComplete;
}
