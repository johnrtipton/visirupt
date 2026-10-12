#import "CPApplicationEvents.h"
NS_ASSUME_NONNULL_BEGIN
@class NSView;
@interface NSTrackingArea : NSObject
- (instancetype)initWithRect:(CGRect)rect options:(NSUInteger)options owner:(nullable id)owner userInfo:(nullable NSDictionary *)userInfo;
@property (readonly) CGRect rect;
@property (readonly) NSUInteger options;
@property (nullable, readonly, weak) id owner;
@property (nullable, readonly, copy) NSDictionary *userInfo;
@property (nullable, weak) NSView *cp_attachedView;
@property BOOL cp_pointerInside;
@end
NS_ASSUME_NONNULL_END
