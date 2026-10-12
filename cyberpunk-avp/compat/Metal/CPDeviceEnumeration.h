#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
NS_ASSUME_NONNULL_BEGIN
typedef void (^CPMetalDeviceNotificationHandler)(id<MTLDevice> device, NSString *name);
// Enumeration is native. Apple Silicon device-change notifications are not
// applicable; the opaque token preserves registration/ownership lifetime.
FOUNDATION_EXPORT NSArray<id<MTLDevice>> *CPMetalCopyAllDevicesWithObserver(id<NSObject> __strong *observer, CPMetalDeviceNotificationHandler handler) NS_RETURNS_RETAINED;
FOUNDATION_EXPORT void CPMetalRemoveDeviceObserver(id<NSObject> observer);
NS_ASSUME_NONNULL_END
