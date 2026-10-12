#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
// The audited game caller ignores the synchronous BOOL. visionOS URL handoff is
// asynchronous: NO means not confirmed at return, not a completed native failure.
@interface NSWorkspace : NSObject
@property(class, readonly, strong) NSWorkspace *sharedWorkspace;
- (BOOL)openURL:(nullable NSURL *)url;
@property(readonly, copy) NSDictionary *cp_lastURLRequest;
@end
NS_ASSUME_NONNULL_END
