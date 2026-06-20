#import <React/RCTViewComponentView.h>
#import <UIKit/UIKit.h>

#import "CNMapModels.h"
#import "CNOverlayHandle.h"
#import "RNMapsCallout.h"
#import "RNMapsOverlay.h"

#ifndef RNMapsMarker_h
#define RNMapsMarker_h

NS_ASSUME_NONNULL_BEGIN

// Provider-agnostic Fabric child host component. It produces a CNMarkerModel and
// does the UIKit-side work (image loading, offscreen rasterization of custom React
// children and of the custom callout) but never touches the SDK map — the adapter
// owns the annotation. The host registers/updates it via the model and routes the
// adapter's marker callbacks back here by childId.
@interface RNMapsMarker : RCTViewComponentView <RNMapsCalloutOwner>

@property (nonatomic, readonly) CNMarkerModel *markerModel;

// Host bookkeeping.
@property (nonatomic, copy, nullable) NSString *cnChildId;
@property (nonatomic, strong, nullable) CNOverlayHandle *cnHandle;
@property (nonatomic, weak, nullable) id<RNMapsChildHost> mapHost;

// Routed from the adapter (via the host) by childId; emits the matching Fabric event.
- (void)emitAdapterEvent:(CNMarkerEventKind)event atCoordinate:(CLLocationCoordinate2D)coordinate;

@end

NS_ASSUME_NONNULL_END

#endif /* RNMapsMarker_h */
