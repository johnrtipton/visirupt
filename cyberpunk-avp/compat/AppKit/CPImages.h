#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN
// Bitmap image focus used by the audited cursor construction. File/resource
// loading, image representations and flipped AppKit drawing contexts remain absent.
@interface NSImage : NSObject
- (instancetype)initWithSize:(CGSize)size;
@property (readonly) CGSize size;
- (void)lockFocus;
- (void)unlockFocus;
- (void)drawInRect:(CGRect)destination fromRect:(CGRect)source
        operation:(NSUInteger)operation fraction:(CGFloat)fraction
   respectFlipped:(BOOL)respectFlipped hints:(nullable NSDictionary *)hints;
// Own integration helpers retain genuine CG images; returned snapshots own +1.
- (instancetype)initWithCGImage:(CGImageRef)image size:(CGSize)size;
- (nullable CGImageRef)cp_copyCGImage CF_RETURNS_RETAINED;
@end
NS_ASSUME_NONNULL_END
