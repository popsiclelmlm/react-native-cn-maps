#import <MAMapKit/MAMapKit.h>
#import <React/RCTViewComponentView.h>
#import <UIKit/UIKit.h>

#ifndef RNMapsMarker_h
#define RNMapsMarker_h

NS_ASSUME_NONNULL_BEGIN

@class RNMapsMarker;

// MAPointAnnotation subclass that carries the marker's identifier/appearance and
// a weak back-reference to its owning view, so the parent map's delegate can
// route annotation callbacks (select/drag/…) back to the child marker.
@interface RNMapsMarkerAnnotation : MAPointAnnotation
@property (nonatomic, copy, nullable) NSString *identifier;
@property (nonatomic, copy, nullable) NSString *pinColor;
@property (nonatomic, assign) BOOL draggable;
@property (nonatomic, weak, nullable) RNMapsMarker *marker;
@end

// Fabric child host component. The view itself never enters the UIView hierarchy;
// the parent `RNMapsMapView` intercepts its mount/unmount (without calling super)
// and registers/unregisters its annotation on the `MAMapView`.
@interface RNMapsMarker : RCTViewComponentView

@property (nonatomic, readonly) RNMapsMarkerAnnotation *annotation;

- (void)addToMap:(MAMapView *)map;
- (void)removeFromMap;
- (void)emitPress;

@end

NS_ASSUME_NONNULL_END

#endif /* RNMapsMarker_h */
