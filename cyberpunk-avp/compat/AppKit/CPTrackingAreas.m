#import "CPTrackingAreas.h"
#import <objc/runtime.h>
#import <math.h>
@interface CPTrackingState : NSObject
@property CGRect rect;
@property NSUInteger options;
@property (nullable, weak) id owner;
@property (nullable, strong) NSDictionary *info;
@property (nullable, weak) NSView *view;
@property BOOL inside;
@end
@implementation CPTrackingState @end
static char trackingKey;
static CPTrackingState *trackingState(NSTrackingArea *area) {if(!NSThread.isMainThread)[NSException raise:NSInternalInconsistencyException format:@"Native tracking areas require the main thread"];CPTrackingState *state=objc_getAssociatedObject(area,&trackingKey);if(!state)[NSException raise:NSInternalInconsistencyException format:@"Tracking area has not initialized"];return state;}
@implementation NSTrackingArea
- (instancetype)initWithRect:(CGRect)rect options:(NSUInteger)options owner:(id)owner userInfo:(NSDictionary *)info {
 if(!NSThread.isMainThread)[NSException raise:NSInternalInconsistencyException format:@"Native tracking areas require the main thread"];
 if(options!=0x21)[NSException raise:NSInvalidArgumentException format:@"Only audited enter/exit tracking active in the key window is implemented"];
 if(!isfinite(rect.origin.x)||!isfinite(rect.origin.y)||!isfinite(rect.size.width)||!isfinite(rect.size.height)||rect.size.width<0||rect.size.height<0)[NSException raise:NSInvalidArgumentException format:@"Invalid tracking rectangle"];
 if((self=[super init])){CPTrackingState *state=[CPTrackingState new];state.rect=rect;state.options=options;state.owner=owner;state.info=info;objc_setAssociatedObject(self,&trackingKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}return self;
}
- (CGRect)rect {return trackingState(self).rect;}
- (NSUInteger)options {return trackingState(self).options;}
- (id)owner {return trackingState(self).owner;}
- (NSDictionary *)userInfo {return trackingState(self).info;}
- (NSView *)cp_attachedView {return trackingState(self).view;}
- (void)setCp_attachedView:(NSView *)view {trackingState(self).view=view;}
- (BOOL)cp_pointerInside {return trackingState(self).inside;}
- (void)setCp_pointerInside:(BOOL)inside {trackingState(self).inside=inside;}
@end
