#import <React/RCTViewComponentView.h>
#import <UIKit/UIKit.h>

#import "CNMapAdapter.h"
#import "CNMapModels.h"
#import "CNOverlayHandle.h"

#ifndef RNMapsOverlay_h
#define RNMapsOverlay_h

NS_ASSUME_NONNULL_BEGIN

// Implemented by the host (RNMapsMapView). A child calls -childDidUpdateModel:
// when its model changes (a prop diff, or an async image load / rasterization),
// and the host re-applies the new model to the adapter. This replaces the old
// pattern where the child mutated the SDK map view directly. `mapAdapter` lets a
// child route its imperative commands (e.g. marker showCallout) through the
// provider-agnostic adapter without touching any SDK type.
@protocol RNMapsChildHost <NSObject>
- (void)childDidUpdateModel:(UIView *)child;
@property (nonatomic, readonly, nullable) id<CNMapAdapter> mapAdapter;
@end

// Implemented by the polyline/polygon/circle/heatmap/tile/ground-overlay children
// so the parent map can attach them through the adapter in a uniform, provider-
// agnostic way. The child only produces a CNOverlayModel; the adapter owns the SDK
// overlay and its renderer. cnChildId / cnHandle / mapHost are bookkeeping set by
// the host on mount.
@protocol RNMapsOverlayView <NSObject>
@property (nonatomic, readonly) CNOverlayModel *overlayModel;
@property (nonatomic, copy, nullable) NSString *cnChildId;
@property (nonatomic, strong, nullable) CNOverlayHandle *cnHandle;
@property (nonatomic, weak, nullable) id<RNMapsChildHost> mapHost;
@end

// Parse a JSON-string lineDashPattern ("[4,4]") into the NSArray<NSNumber*> the
// renderers expect; nil for empty/invalid. Provider-agnostic; stays in core.
static inline NSArray<NSNumber *> *_Nullable RNMapsParseDashPattern(NSString *_Nullable json)
{
  if (json.length == 0) {
    return nil;
  }
  NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
  id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  return [parsed isKindOfClass:[NSArray class]] ? parsed : nil;
}

#ifdef __cplusplus
// Element-wise equality for two codegen coordinate vectors (any struct exposing
// .latitude/.longitude).
template <typename Vector>
static inline BOOL RNMapsCoordinatesEqual(const Vector &a, const Vector &b)
{
  if (a.size() != b.size()) {
    return NO;
  }
  for (size_t i = 0; i < a.size(); i++) {
    if (a[i].latitude != b[i].latitude || a[i].longitude != b[i].longitude) {
      return NO;
    }
  }
  return YES;
}
#endif

NS_ASSUME_NONNULL_END

#endif /* RNMapsOverlay_h */
