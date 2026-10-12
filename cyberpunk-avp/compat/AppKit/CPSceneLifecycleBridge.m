#import "CPSceneLifecycleBridge.h"

@implementation CPSceneLifecycleBridge {
    __weak UIWindow *_window;
    __weak id _keyWindowTarget;
    NSApplication *_application;
    NSMutableArray<id> *_observers;
    BOOL _invalidated;
}
- (instancetype)initWithWindow:(UIWindow *)window application:(NSApplication *)application {
    return [self initWithWindow:window application:application keyWindowTarget:window];
}
- (instancetype)initWithWindow:(UIWindow *)window application:(NSApplication *)application keyWindowTarget:(id)target {
    if (!NSThread.isMainThread || !window.windowScene || !application || !target)
        [NSException raise:NSInvalidArgumentException format:@"Scene bridge requires an actual scene window and application on the main thread"];
    if ((self = [super init])) {
        _window = window;
        _keyWindowTarget = target;
        _application = application;
        _observers = [NSMutableArray array];
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        __weak CPSceneLifecycleBridge *weakSelf = self;
        for (NSNotificationName name in @[UISceneDidActivateNotification, UISceneWillDeactivateNotification, UISceneDidDisconnectNotification]) {
            id observer = [center addObserverForName:name object:window.windowScene queue:nil usingBlock:^(NSNotification *note) {
                CPSceneLifecycleBridge *bridge = weakSelf;
                if (!bridge || bridge->_invalidated) return;
                if (!NSThread.isMainThread) [NSException raise:NSInternalInconsistencyException format:@"UIKit scene notification arrived outside the main thread"];
                if ([note.name isEqualToString:UISceneDidDisconnectNotification]) [bridge invalidate];
                else [bridge->_application cp_setActiveFromNativeScene:[note.name isEqualToString:UISceneDidActivateNotification]];
            }];
            [_observers addObject:observer];
        }
        for (NSNotificationName name in @[UIWindowDidBecomeKeyNotification, UIWindowDidResignKeyNotification]) {
            id observer = [center addObserverForName:name object:window queue:nil usingBlock:^(NSNotification *note) {
                CPSceneLifecycleBridge *bridge = weakSelf;
                if (!bridge || bridge->_invalidated) return;
                if (!NSThread.isMainThread) [NSException raise:NSInternalInconsistencyException format:@"UIKit window notification arrived outside the main thread"];
                if ([note.name isEqualToString:UIWindowDidBecomeKeyNotification]) [bridge updateNativeKeyWindow];
                else if (bridge->_application.keyWindow == bridge->_keyWindowTarget) [bridge->_application cp_setKeyWindow:nil];
            }];
            [_observers addObject:observer];
        }
        if (window.isKeyWindow) [self updateNativeKeyWindow];
        [application cp_setActiveFromNativeScene:window.windowScene.activationState == UISceneActivationStateForegroundActive];
    }
    return self;
}
- (void)updateNativeKeyWindow {
    id target = _keyWindowTarget;
    BOOL accepts = target && (![target respondsToSelector:@selector(cp_acceptsNativeKeyWindow)] || [(id<CPSceneKeyWindowTarget>)target cp_acceptsNativeKeyWindow]);
    [_application cp_setKeyWindow:accepts ? target : nil];
}
- (UIWindow *)window { return _window; }
- (void)invalidate {
    if (!NSThread.isMainThread) [NSException raise:NSInternalInconsistencyException format:@"Scene bridge invalidation requires the main thread"];
    if (_invalidated) return;
    _invalidated = YES;
    for (id observer in _observers) [NSNotificationCenter.defaultCenter removeObserver:observer];
    [_observers removeAllObjects];
    if (_application.keyWindow == _keyWindowTarget) [_application cp_setKeyWindow:nil];
    [_application cp_setActiveFromNativeScene:NO];
}
- (void)dealloc {
    for (id observer in _observers) [NSNotificationCenter.defaultCenter removeObserver:observer];
}
@end
