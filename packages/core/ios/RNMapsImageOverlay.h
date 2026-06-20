#import "RNMapsOverlay.h"
#import <React/RCTViewComponentView.h>

#ifndef RNMapsImageOverlay_h
#define RNMapsImageOverlay_h

NS_ASSUME_NONNULL_BEGIN

// Fabric component class for the `RNMapsOverlay` image ground-overlay. The file
// is named RNMapsImageOverlay to avoid clashing with RNMapsOverlay.h (the shared
// RNMapsOverlayView protocol header); the ObjC class is RNMapsOverlay so the
// generated component provider resolves it via NSClassFromString.
@interface RNMapsOverlay : RCTViewComponentView <RNMapsOverlayView>
@end

NS_ASSUME_NONNULL_END

#endif /* RNMapsImageOverlay_h */
