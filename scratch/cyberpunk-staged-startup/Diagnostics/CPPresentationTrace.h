#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
NSDictionary *CPPresentationTraceBegin(UIWindow *window,id<MTLDevice> device);
void CPPresentationTraceEnginePhase(void);
NSDictionary *CPPresentationTraceCounts(void);
BOOL CPPresentationTraceControl(UIWindow *window,id<MTLDevice> device);
