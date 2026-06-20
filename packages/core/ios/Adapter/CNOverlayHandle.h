#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Opaque token returned by the adapter when a marker/overlay is added, and handed
// back for later update/remove. The host keeps it alongside the child; only the
// adapter that created it knows what `sdkObject`/`auxObject` concretely are, which
// keeps this header provider-agnostic (typed `id`, no SDK import).
@interface CNOverlayHandle : NSObject

@property (nonatomic, copy, readonly) NSString *childId;
// The provider's overlay/annotation object (e.g. MAPointAnnotation, MAShape).
@property (nonatomic, strong, nullable) id sdkObject;
// A secondary provider object when one isn't enough (e.g. a cached renderer, or
// the MAAnnotationView a custom callout is presented in).
@property (nonatomic, strong, nullable) id auxObject;

- (instancetype)initWithChildId:(NSString *)childId NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
