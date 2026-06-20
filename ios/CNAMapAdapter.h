#import <Foundation/Foundation.h>

#import "CNMapAdapter.h"

NS_ASSUME_NONNULL_BEGIN

// AMap (高德) implementation of CNMapAdapter. Owns the MAMapView, acts as its
// delegate, and is the single place in the iOS layer that references MAMapKit /
// AMapFoundation. The core host (RNMapsMapView) and the dumb child components hold
// only the provider-agnostic protocol/model types.
@interface CNAMapAdapter : NSObject <CNMapAdapter, CNMapAdapterPrivacy>
@end

NS_ASSUME_NONNULL_END
