#import <Foundation/Foundation.h>

#import "CNMapAdapter.h"

NS_ASSUME_NONNULL_BEGIN

// Baidu (百度地图) implementation of CNMapAdapter. Owns the BMKMapView, acts as its
// delegate, and is the single place in this package that references the Baidu Map
// iOS SDK. The core host (RNMapsMapView) and the dumb child components hold only
// the provider-agnostic protocol/model types.
//
// Coordinates arriving from JS are already BD-09 (the JS layer converts per
// provider), so this adapter passes them through to the SDK unchanged.
@interface CNBaiduMapAdapter : NSObject <CNMapAdapter, CNMapAdapterPrivacy>
@end

NS_ASSUME_NONNULL_END
