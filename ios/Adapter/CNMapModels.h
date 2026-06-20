#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>

#ifndef CNMapModels_h
#define CNMapModels_h

NS_ASSUME_NONNULL_BEGIN

// Provider-agnostic value types shared between the core host/children and a map
// provider adapter. Nothing here references a concrete SDK (AMap/etc.) or the
// codegen (RNMapsSpecs) types, so the adapter protocol stays independent of both.
// CoreLocation / UIKit are OS frameworks, not a map provider, so they are fair
// game for coordinates, colors and images.

// Box/encode a coordinate into an NSValue for the model's coordinate arrays.
// (+valueWithMKCoordinate: is MapKit-only, so encode the raw struct.)
static inline NSValue *CNBoxCoordinate(CLLocationCoordinate2D coordinate)
{
  return [NSValue valueWithBytes:&coordinate objCType:@encode(CLLocationCoordinate2D)];
}

#pragma mark - Viewport value structs

typedef struct {
  double latitude;
  double longitude;
  double latitudeDelta;
  double longitudeDelta;
} CNRegion;

typedef struct {
  double latitude;
  double longitude;
  double heading;
  double pitch;
  double zoom;
  double altitude;
} CNCamera;

#pragma mark - Map options

// The full set of map-level options, rebuilt from props on every diff and handed
// to the adapter via -applyOptions:. The adapter is responsible for any guarding
// (e.g. not re-arming user location when the flag is unchanged).
@interface CNMapOptions : NSObject
@property (nonatomic, copy) NSString *mapType;            // standard|satellite|hybrid|...
@property (nonatomic, copy) NSString *userInterfaceStyle; // light|dark|...
@property (nonatomic, assign) double minZoomLevel;
@property (nonatomic, assign) double maxZoomLevel;
@property (nonatomic, assign) BOOL showsUserLocation;
@property (nonatomic, assign) BOOL showsCompass;
@property (nonatomic, assign) BOOL showsScale;
@property (nonatomic, assign) BOOL showsTraffic;
@property (nonatomic, assign) BOOL showsBuildings;
@property (nonatomic, assign) BOOL showsIndoors;
@property (nonatomic, assign) BOOL showsPointsOfInterest;
@property (nonatomic, assign) BOOL zoomEnabled;
@property (nonatomic, assign) BOOL scrollEnabled;
@property (nonatomic, assign) BOOL rotateEnabled;
@property (nonatomic, assign) BOOL pitchEnabled;
@end

#pragma mark - Marker (annotation) model

// Marker model. Custom icons / rasterized React children and rasterized custom
// callouts are resolved to UIImages by the child (provider-agnostic UIKit work)
// and handed over ready to display, so the adapter only deals with placement.
@interface CNMarkerModel : NSObject
@property (nonatomic, copy, nullable) NSString *identifier;
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *subtitle;
@property (nonatomic, copy, nullable) NSString *pinColor;
@property (nonatomic, assign) BOOL draggable;
@property (nonatomic, strong, nullable) UIImage *image; // custom/rendered icon; nil → pin
@property (nonatomic, assign) CGPoint centerOffset;
@property (nonatomic, assign) CGPoint calloutOffset;
@property (nonatomic, assign) CGFloat opacity;
@property (nonatomic, assign) CGFloat rotationDegrees;
@property (nonatomic, assign) double zIndex;
@property (nonatomic, assign) BOOL hasCustomCallout;
@property (nonatomic, strong, nullable) UIImage *calloutImage; // rasterized custom callout
@end

#pragma mark - Overlay models

typedef NS_ENUM(NSInteger, CNOverlayType) {
  CNOverlayTypePolyline,
  CNOverlayTypePolygon,
  CNOverlayTypeCircle,
  CNOverlayTypeHeatmap,
  CNOverlayTypeUrlTile,
  CNOverlayTypeLocalTile,
  CNOverlayTypeGroundOverlay,
};

// Base overlay model. The adapter switches on `type`, downcasts to the concrete
// subclass below, and builds the SDK overlay + its renderer.
@interface CNOverlayModel : NSObject
@property (nonatomic, assign) CNOverlayType type;
@property (nonatomic, assign) double zIndex;
@end

// Coordinates everywhere are NSValue-boxed CLLocationCoordinate2D
// (+[NSValue valueWithMKCoordinate:] is MapKit-only, so use a plain struct box:
// [NSValue valueWithBytes:&c objCType:@encode(CLLocationCoordinate2D)]).

@interface CNPolylineModel : CNOverlayModel
@property (nonatomic, copy) NSArray<NSValue *> *coordinates;
@property (nonatomic, strong, nullable) UIColor *strokeColor;
@property (nonatomic, copy) NSArray<UIColor *> *strokeColors; // gradient; >1 → multi-colored
@property (nonatomic, assign) CGFloat strokeWidth;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *lineDashPattern;
@property (nonatomic, copy, nullable) NSString *lineCap;
@property (nonatomic, copy, nullable) NSString *lineJoin;
@property (nonatomic, assign) CGFloat miterLimit;
@end

@interface CNPolygonModel : CNOverlayModel
@property (nonatomic, copy) NSArray<NSValue *> *coordinates;
@property (nonatomic, copy, nullable) NSArray<NSArray<NSValue *> *> *holes;
@property (nonatomic, strong, nullable) UIColor *strokeColor;
@property (nonatomic, strong, nullable) UIColor *fillColor;
@property (nonatomic, assign) CGFloat strokeWidth;
@end

@interface CNCircleModel : CNOverlayModel
@property (nonatomic, assign) CLLocationCoordinate2D center;
@property (nonatomic, assign) CLLocationDistance radius;
@property (nonatomic, strong, nullable) UIColor *strokeColor;
@property (nonatomic, strong, nullable) UIColor *fillColor;
@property (nonatomic, assign) CGFloat strokeWidth;
@end

@interface CNHeatmapModel : CNOverlayModel
@property (nonatomic, copy) NSArray<NSValue *> *points;   // boxed CLLocationCoordinate2D
@property (nonatomic, copy) NSArray<NSNumber *> *weights; // parallel to points; default 1
@property (nonatomic, assign) NSInteger radius;
@property (nonatomic, copy, nullable) NSArray<UIColor *> *gradientColors;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *gradientStartPoints;
@end

@interface CNUrlTileModel : CNOverlayModel
@property (nonatomic, copy, nullable) NSString *urlTemplate;
@property (nonatomic, assign) BOOL wms;
@property (nonatomic, assign) NSInteger minimumZ;
@property (nonatomic, assign) NSInteger maximumZ;
@property (nonatomic, assign) NSInteger tileSize; // already resolved (512/explicit/256)
@property (nonatomic, assign) CGFloat opacity;
@end

@interface CNLocalTileModel : CNOverlayModel
@property (nonatomic, copy, nullable) NSString *pathTemplate;
@property (nonatomic, assign) NSInteger tileSize;
@end

@interface CNGroundOverlayModel : CNOverlayModel
@property (nonatomic, assign) CLLocationCoordinate2D southWest;
@property (nonatomic, assign) CLLocationCoordinate2D northEast;
@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, assign) CGFloat opacity;
@end

#pragma mark - Map callback value types

// Point-of-interest tapped on the basemap.
@interface CNPoi : NSObject
@property (nonatomic, copy, nullable) NSString *placeId;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;
@end

// Marker callbacks the adapter routes back to a child by childId.
typedef NS_ENUM(NSInteger, CNMarkerEventKind) {
  CNMarkerEventPress,
  CNMarkerEventSelect,
  CNMarkerEventDeselect,
  CNMarkerEventCalloutPress,
  CNMarkerEventDragStart,
  CNMarkerEventDrag,
  CNMarkerEventDragEnd,
};

NS_ASSUME_NONNULL_END

#endif /* CNMapModels_h */
