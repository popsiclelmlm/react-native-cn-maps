#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>

#import "CNMapModels.h"

NS_ASSUME_NONNULL_BEGIN

@protocol CNMapAdapter;

// Adapter → host callbacks. The adapter owns the provider's map delegate and
// translates its callbacks into these provider-agnostic ones. Map-level gestures
// that have no first-class provider callback (long press / double tap / pan) stay
// in the host on its own recognizers, so they are intentionally NOT here.
@protocol CNMapAdapterDelegate <NSObject>

// Lifecycle — the provider reports a single init-complete; the host surfaces it as
// both onMapReady and onMapLoaded.
- (void)mapAdapterDidBecomeReady:(id<CNMapAdapter>)adapter;

// Single tap on the basemap (→ onPress).
- (void)mapAdapter:(id<CNMapAdapter>)adapter didTapAtCoordinate:(CLLocationCoordinate2D)coordinate;

// Region changes. `complete` distinguishes the in-flight (onRegionChange) from the
// settled (onRegionChangeComplete) callback.
- (void)mapAdapter:(id<CNMapAdapter>)adapter
    didChangeRegionComplete:(BOOL)complete
                  isGesture:(BOOL)isGesture;

- (void)mapAdapter:(id<CNMapAdapter>)adapter didTapPoi:(CNPoi *)poi;

- (void)mapAdapter:(id<CNMapAdapter>)adapter didUpdateUserLocation:(CLLocation *)location;

// Marker callbacks, routed back to the owning child by childId. The coordinate is
// the annotation's current position (so drag end carries the dropped location).
- (void)mapAdapter:(id<CNMapAdapter>)adapter
       markerChildId:(NSString *)childId
       didFireEvent:(CNMarkerEventKind)event
         atCoordinate:(CLLocationCoordinate2D)coordinate;

@end

NS_ASSUME_NONNULL_END
