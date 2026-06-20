#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>

#import "CNMapAdapterDelegate.h"
#import "CNMapModels.h"
#import "CNOverlayHandle.h"

NS_ASSUME_NONNULL_BEGIN

// The provider-agnostic contract the core host (RNMapsMapView) talks to. A
// concrete adapter (e.g. CNAMapAdapter) owns the real SDK map view and all SDK
// calls; the host owns Fabric lifecycle, child routing, gestures and event
// emission. No method here exposes a provider (AMap) or codegen (RNMapsSpecs) type.
@protocol CNMapAdapter <NSObject>

// Provider identity. The class method lets the registry pick a class by the JS
// `provider` prop ("amap"/"baidu"/"tencent") before instantiating; the instance
// getter lets the host track which provider is currently mounted.
+ (NSString *)providerName;
@property (nonatomic, readonly) NSString *providerName;

// The view to mount as the host's contentView. Gesture recognizers for the
// host-owned gestures (long press / double tap / pan) are installed on it.
@property (nonatomic, readonly) UIView *mapView;
@property (nonatomic, weak, nullable) id<CNMapAdapterDelegate> delegate;

#pragma mark Lifecycle
// The provider may ignore viewport changes before it is ready / sized; the host
// calls -didLayout from layoutSubviews so the adapter can apply a pending initial
// viewport once both conditions hold.
- (void)didLayout;
- (BOOL)isReady;
// Detach the provider delegate; called from the host's dealloc.
- (void)teardown;
// Clear all markers/overlays and viewport/option state for view recycling.
- (void)reset;

#pragma mark Configuration
- (void)applyOptions:(CNMapOptions *)options;

#pragma mark Viewport
- (void)setRegionLatitude:(double)latitude
                longitude:(double)longitude
            latitudeDelta:(double)latitudeDelta
           longitudeDelta:(double)longitudeDelta
                 animated:(BOOL)animated;
- (void)setCameraLatitude:(double)latitude
                longitude:(double)longitude
                  heading:(double)heading
                    pitch:(double)pitch
                     zoom:(double)zoom
                 animated:(BOOL)animated
                 duration:(NSTimeInterval)duration;
// Deferred initial viewport, applied once ready & sized. Camera supersedes region.
- (void)setPendingInitialRegionLatitude:(double)latitude
                              longitude:(double)longitude
                          latitudeDelta:(double)latitudeDelta
                         longitudeDelta:(double)longitudeDelta;
- (void)setPendingInitialCameraLatitude:(double)latitude
                              longitude:(double)longitude
                                heading:(double)heading
                                  pitch:(double)pitch
                                   zoom:(double)zoom;
- (CNRegion)currentRegion;
- (CNCamera)currentCamera;
- (void)fitToCoordinates:(NSArray<NSValue *> *)coordinates // boxed CLLocationCoordinate2D
             edgePadding:(UIEdgeInsets)edgePadding
                animated:(BOOL)animated;
- (void)fitToElementsAnimated:(BOOL)animated;
- (void)fitToMarkers:(NSArray<CNOverlayHandle *> *)handles
         edgePadding:(UIEdgeInsets)edgePadding
            animated:(BOOL)animated;
- (void)setLimitRegionNELatitude:(double)neLatitude
                     neLongitude:(double)neLongitude
                      swLatitude:(double)swLatitude
                     swLongitude:(double)swLongitude;

#pragma mark Projection
- (CGPoint)pointForCoordinate:(CLLocationCoordinate2D)coordinate;
- (CLLocationCoordinate2D)coordinateForPoint:(CGPoint)point;

#pragma mark Snapshot
// Async; replies with a file:// uri (or raw base64 when result == "base64", or an
// empty string on failure). The host wraps the reply into an onCommandResult event.
- (void)takeSnapshotWidth:(NSInteger)width
                   height:(NSInteger)height
                   format:(NSString *)format
                  quality:(double)quality
                   result:(NSString *)result
               completion:(void (^)(NSString *uri))completion;

#pragma mark Markers (annotations)
- (CNOverlayHandle *)addMarker:(CNMarkerModel *)model childId:(NSString *)childId;
- (void)updateMarker:(CNOverlayHandle *)handle model:(CNMarkerModel *)model;
- (void)removeMarker:(CNOverlayHandle *)handle;
- (void)selectMarker:(CNOverlayHandle *)handle animated:(BOOL)animated;
- (void)deselectMarker:(CNOverlayHandle *)handle animated:(BOOL)animated;
- (void)redrawCalloutForMarker:(CNOverlayHandle *)handle;
- (void)animateMarker:(CNOverlayHandle *)handle
           toLatitude:(double)latitude
            longitude:(double)longitude
             duration:(NSInteger)duration;
// Screen point of the marker's current coordinate (for getMarkersFrames).
- (CGPoint)pointForMarker:(CNOverlayHandle *)handle;

#pragma mark Overlays
- (CNOverlayHandle *)addOverlay:(CNOverlayModel *)model childId:(NSString *)childId;
- (void)updateOverlay:(CNOverlayHandle *)handle model:(CNOverlayModel *)model;
- (void)removeOverlay:(CNOverlayHandle *)handle;

@end

// Adapter classes that can forward a privacy-compliance declaration to their SDK.
// The registry fans -applyPrivacyConsent... out to every registered adapter class.
@protocol CNMapAdapterPrivacy <NSObject>
+ (void)applyPrivacyConsentAgreed:(BOOL)agreed contains:(BOOL)contains shown:(BOOL)shown;
@end

NS_ASSUME_NONNULL_END
