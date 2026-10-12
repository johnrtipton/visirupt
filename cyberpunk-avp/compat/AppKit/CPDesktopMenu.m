#import "CPDesktopMenu.h"
static BOOL requestedVisibility;
static void menuThread(void){if(!NSThread.isMainThread)[NSException raise:NSInternalInconsistencyException format:@"Desktop menu visibility requests require the main thread"];}
@implementation NSMenu
+ (void)setMenuBarVisible:(BOOL)visible {menuThread();requestedVisibility=visible;}
+ (BOOL)menuBarVisible {menuThread();return NO;}
+ (BOOL)cp_desktopMenuBarAvailable {return NO;}
+ (BOOL)cp_lastRequestedMenuBarVisible {menuThread();return requestedVisibility;}
@end
