#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
// visionOS has no macOS system menu bar. These void desktop visibility requests
// are recorded as unsupported; they do not change game menus or native controls.
@interface NSMenu : NSObject
+ (void)setMenuBarVisible:(BOOL)visible;
+ (BOOL)menuBarVisible;
+ (BOOL)cp_desktopMenuBarAvailable;
+ (BOOL)cp_lastRequestedMenuBarVisible;
@end
NS_ASSUME_NONNULL_END
