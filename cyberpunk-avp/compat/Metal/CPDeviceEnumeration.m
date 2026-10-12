#import "CPDeviceEnumeration.h"
#include <string.h>
@interface CPMetalObserverToken : NSObject
@property (copy) CPMetalDeviceNotificationHandler handler;
@end
@implementation CPMetalObserverToken @end
static NSLock *registryLock;
static NSMutableSet<CPMetalObserverToken *> *registry;
static void InitializeRegistry(void) {
 static dispatch_once_t once;dispatch_once(&once,^{registryLock=[NSLock new];registry=[NSMutableSet new];});
}
NSArray<id<MTLDevice>> *CPMetalCopyAllDevicesWithObserver(id<NSObject> __strong *observer, CPMetalDeviceNotificationHandler handler) {
 if(!observer || !handler)[NSException raise:NSInvalidArgumentException format:@"A writable observer output and notification handler are required"];
 InitializeRegistry();
 NSArray<id<MTLDevice>> *devices=MTLCopyAllDevices();
 CPMetalObserverToken *token=[CPMetalObserverToken new];token.handler=handler;
 [registryLock lock];[registry addObject:token];[registryLock unlock];
 // The documented output owns +1 separately from the registry's retain.
 // Write an out value without assuming that the old slot contains an object.
 CFTypeRef ownedOutput=CFBridgingRetain(token);
 memcpy(observer,&ownedOutput,sizeof(ownedOutput));
 return devices;
}
void CPMetalRemoveDeviceObserver(id<NSObject> observer) {
 if(!observer)return;
 if(![observer isKindOfClass:CPMetalObserverToken.class])[NSException raise:NSInvalidArgumentException format:@"Observer does not belong to the native Apple Silicon enumeration adapter"];
 InitializeRegistry();[registryLock lock];[registry removeObject:(CPMetalObserverToken *)observer];[registryLock unlock];
 // Keep the copied handler for the caller-owned token's remaining lifetime,
 // matching the observed Mac behavior. No artificial callbacks are emitted.
}
