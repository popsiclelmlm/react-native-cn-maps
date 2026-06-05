#import <MAMapKit/MAMapKit.h>
#import <React/RCTViewComponentView.h>
#import <UIKit/UIKit.h>

#ifndef RNMapsMarker_h
#define RNMapsMarker_h

NS_ASSUME_NONNULL_BEGIN

@class RNMapsMarker;

// MAPointAnnotation subclass that carries the marker's identifier/appearance and
// a weak back-reference to its owning view, so the parent map's delegate can
// route annotation callbacks (select/drag/…) back to the child marker. The
// parent's viewForAnnotation: reads these to build/refresh the annotation view.
@interface RNMapsMarkerAnnotation : MAPointAnnotation
@property (nonatomic, copy, nullable) NSString *identifier;
@property (nonatomic, copy, nullable) NSString *pinColor;
@property (nonatomic, assign) BOOL draggable;
// Custom image (loaded asynchronously by the marker); nil → fall back to a pin.
@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, assign) CGPoint centerOffset;
@property (nonatomic, assign) CGPoint calloutOffset;
@property (nonatomic, assign) CGFloat markerOpacity;
@property (nonatomic, assign) CGFloat rotationDegrees;
@property (nonatomic, assign) double zIndex;
@property (nonatomic, weak, nullable) RNMapsMarker *marker;

// Applies the appearance fields above onto a freshly built / reused view.
- (void)applyAppearanceToView:(MAAnnotationView *)view;
@end

// Fabric child host component. The view itself never enters the UIView hierarchy;
// the parent `RNMapsMapView` intercepts its mount/unmount (without calling super)
// and registers/unregisters its annotation on the `MAMapView`.
@interface RNMapsMarker : RCTViewComponentView

@property (nonatomic, readonly) RNMapsMarkerAnnotation *annotation;

- (void)addToMap:(MAMapView *)map;
- (void)removeFromMap;

// Called by the parent map's delegate, which receives AMap's map-level callbacks
// and routes them to the matching child marker (annotation → weak `marker` ref).
- (void)emitPress;
- (void)emitSelect;
- (void)emitDeselect;
- (void)emitCalloutPress;
- (void)emitDragStart;
- (void)emitDrag;
- (void)emitDragEnd;

@end

NS_ASSUME_NONNULL_END

#endif /* RNMapsMarker_h */
