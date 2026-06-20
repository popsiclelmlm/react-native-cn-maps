#import <Foundation/Foundation.h>

#import "CNMapAdapter.h"

NS_ASSUME_NONNULL_BEGIN

// Tencent (腾讯地图) implementation of CNMapAdapter. Owns the QMapView, acts as its
// delegate, and is the single place in this package that references the Tencent Map
// iOS SDK (QMapKit). Coordinates arriving from JS are already GCJ-02 (same as AMap),
// so they pass through to the SDK unchanged.
@interface CNTencentMapAdapter : NSObject <CNMapAdapter, CNMapAdapterPrivacy>
@end

NS_ASSUME_NONNULL_END
