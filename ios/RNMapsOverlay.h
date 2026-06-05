#import <MAMapKit/MAMapKit.h>

#ifndef RNMapsOverlay_h
#define RNMapsOverlay_h

NS_ASSUME_NONNULL_BEGIN

// Implemented by the polyline/polygon/circle child host components so the parent
// map can attach them and build a renderer from their styling in a uniform way.
@protocol RNMapsOverlayView <NSObject>
@property (nonatomic, readonly, nullable) id<MAOverlay> overlay;
- (void)addToMap:(MAMapView *)map;
- (void)removeFromMap;
- (MAOverlayRenderer *)overlayRenderer;
@end

// Parse a JSON-string lineDashPattern ("[4,4]") into the NSArray<NSNumber*> the
// MAMapKit renderers expect; nil for empty/invalid.
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
