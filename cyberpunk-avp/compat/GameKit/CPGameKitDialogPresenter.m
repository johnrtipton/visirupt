#import "CPGameKitDialogPresenter.h"

NSErrorDomain const CPGameKitPresentationErrorDomain = @"CPGameKitPresentationErrorDomain";

@implementation CPGameKitDialogPresenter {
    __weak id _parentWindow;
    UIViewController *_presentedController;
    UIViewController *_presentationParent;
    NSError *_lastError;
}
+ (instancetype)sharedDialogController {
    static CPGameKitDialogPresenter *presenter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ presenter = [self new]; });
    return presenter;
}
- (NSError *)lastError { @synchronized (self) { return _lastError; } }
- (id)parentWindow { @synchronized (self) { return _parentWindow; } }
- (BOOL)fail:(CPGameKitPresentationError)code message:(NSString *)message {
    @synchronized (self) {
        _lastError = [NSError errorWithDomain:CPGameKitPresentationErrorDomain code:code
                                    userInfo:@{NSLocalizedDescriptionKey:message}];
    }
    return NO;
}
- (void)clearError { @synchronized (self) { _lastError = nil; } }
- (void)reconcileExternalDismissal {
    if (_presentedController && !_presentedController.presentingViewController &&
        !_presentedController.isBeingPresented && !_presentedController.isBeingDismissed &&
        _presentationParent.presentedViewController != _presentedController) {
        _presentedController = nil;
        _presentationParent = nil;
    }
}
- (void)setParentWindow:(id)parent {
    if (!NSThread.isMainThread) {
        [self fail:CPGameKitPresentationNotMainThread message:@"Parent selection requires the main thread."];
        return;
    }
    [self reconcileExternalDismissal];
    if (_presentedController && parent != self.parentWindow) {
        [self fail:CPGameKitPresentationParentChangeWhilePresenting message:@"Dismiss the owned modal before selecting another parent."];
        return;
    }
    BOOL valid = !parent || [parent isKindOfClass:UIWindow.class] ||
        ([parent conformsToProtocol:@protocol(CPNativePresentingControllerProviding)] &&
         [parent respondsToSelector:@selector(cp_nativePresentingViewController)]);
    @synchronized (self) { _parentWindow = valid ? parent : nil; }
    if (!valid) { [self fail:CPGameKitPresentationInvalidParent message:@"Parent must be an actual UIWindow or explicit native controller provider."]; return; }
    [self clearError];
}
- (UIViewController *)resolveParent {
    id parent = self.parentWindow;
    if (!parent) { [self fail:CPGameKitPresentationNoParent message:@"No native parent was supplied."]; return nil; }
    UIViewController *controller;
    if ([parent isKindOfClass:UIWindow.class]) controller = ((UIWindow *)parent).rootViewController;
    else if ([parent conformsToProtocol:@protocol(CPNativePresentingControllerProviding)])
        controller = [(id<CPNativePresentingControllerProviding>)parent cp_nativePresentingViewController];
    if (![controller isKindOfClass:UIViewController.class]) {
        [self fail:CPGameKitPresentationInvalidParent message:@"The parent has no valid native UIViewController."];
        return nil;
    }
    if (!controller.viewIfLoaded.window || controller.viewIfLoaded.window.hidden) {
        [self fail:CPGameKitPresentationParentNotAttached message:@"The native presenter is not attached to a visible window."];
        return nil;
    }
    return controller;
}
- (BOOL)presentViewController:(UIViewController *)controller {
    if (!NSThread.isMainThread) return [self fail:CPGameKitPresentationNotMainThread message:@"Presentation requires the main thread."];
    [self reconcileExternalDismissal];
    if (_presentedController)
        return [self fail:CPGameKitPresentationAlreadyPresenting message:@"This presenter already owns a modal controller."];
    if (![controller isKindOfClass:UIViewController.class])
        return [self fail:CPGameKitPresentationInvalidController message:@"Presentation requires a real UIViewController."];
    UIViewController *parent = [self resolveParent];
    if (!parent) return NO;
    if (parent == controller || parent.presentedViewController || parent.isBeingPresented ||
        parent.isBeingDismissed || controller.presentingViewController || controller.parentViewController ||
        controller.isBeingPresented || controller.isBeingDismissed)
        return [self fail:CPGameKitPresentationAlreadyPresenting message:@"The supplied controller or parent is already in a presentation transition."];
    [self clearError];
    _presentedController = controller;
    _presentationParent = parent;
    [parent presentViewController:controller animated:NO completion:nil];
    if (parent.presentedViewController != controller) {
        _presentedController = nil;
        _presentationParent = nil;
        return [self fail:CPGameKitPresentationAlreadyPresenting message:@"UIKit did not accept the supplied modal controller."];
    }
    return YES; // UIKit presentation was requested; this is never authentication success.
}
- (void)dismiss:(id)sender {
    (void)sender;
    if (!NSThread.isMainThread) { [self fail:CPGameKitPresentationNotMainThread message:@"Dismissal requires the main thread."]; return; }
    [self reconcileExternalDismissal];
    UIViewController *controller = _presentedController;
    UIViewController *parent = _presentationParent;
    if (!controller || parent.presentedViewController != controller || controller.presentingViewController != parent) {
        [self fail:CPGameKitPresentationNothingToDismiss message:@"This presenter owns no modal controller on the supplied parent."];
        return;
    }
    [self clearError];
    [controller dismissViewControllerAnimated:NO completion:^{ self->_presentedController = nil; self->_presentationParent = nil; }];
}
@end
