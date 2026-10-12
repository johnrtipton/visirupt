#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
// A future native window facade must explicitly expose its real presenter.
@protocol CPNativePresentingControllerProviding <NSObject>
- (nullable UIViewController *)cp_nativePresentingViewController;
@end

FOUNDATION_EXPORT NSErrorDomain const CPGameKitPresentationErrorDomain;
typedef NS_ENUM(NSInteger, CPGameKitPresentationError) {
    CPGameKitPresentationNotMainThread = 1,
    CPGameKitPresentationNoParent,
    CPGameKitPresentationInvalidParent,
    CPGameKitPresentationInvalidController,
    CPGameKitPresentationParentNotAttached,
    CPGameKitPresentationAlreadyPresenting,
    CPGameKitPresentationNothingToDismiss,
    CPGameKitPresentationParentChangeWhilePresenting,
};

// UI presentation only. This class never authenticates or changes GameKit state.
@interface CPGameKitDialogPresenter : NSObject
+ (instancetype)sharedDialogController;
@property (nullable, weak) id parentWindow;
@property (nullable, readonly) NSError *lastError;
- (BOOL)presentViewController:(UIViewController *)viewController;
- (void)dismiss:(nullable id)sender;
@end
NS_ASSUME_NONNULL_END
