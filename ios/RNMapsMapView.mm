#import "RNMapsMapView.h"
#import "RNMapsMarker.h"
#import "RNMapsOverlay.h"

#import <MAMapKit/MAMapKit.h>
#import <React/RCTConversions.h>
#import <React/RCTUtils.h>

#import <react/renderer/components/RNMapsSpecs/ComponentDescriptors.h>
#import <react/renderer/components/RNMapsSpecs/EventEmitters.h>
#import <react/renderer/components/RNMapsSpecs/Props.h>
#import <react/renderer/components/RNMapsSpecs/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"

#include <cmath>
#include <string>

using namespace facebook::react;

// onPress / onLongPress / onDoublePress / onPanDrag share an identical
// { coordinate, position } payload but route to distinct emitter methods.
typedef NS_ENUM(NSInteger, RNMapsPressKind) {
  RNMapsPressKindPress,
  RNMapsPressKindLongPress,
  RNMapsPressKindDoublePress,
  RNMapsPressKindPanDrag,
};

@interface RNMapsMapView () <MAMapViewDelegate, UIGestureRecognizerDelegate, RCTRNMapsMapViewViewProtocol>
@end

static NSArray *RNMapsJSONArray(NSString *json)
{
  if (json.length == 0) {
    return @[];
  }
  id parsed = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                              options:0
                                                error:nil];
  return [parsed isKindOfClass:[NSArray class]] ? parsed : @[];
}

static UIEdgeInsets RNMapsEdgeInsets(NSString *json)
{
  if (json.length == 0) {
    return UIEdgeInsetsZero;
  }
  id parsed = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                              options:0
                                                error:nil];
  if (![parsed isKindOfClass:[NSDictionary class]]) {
    return UIEdgeInsetsZero;
  }
  NSDictionary *d = parsed;
  return UIEdgeInsetsMake([d[@"top"] doubleValue], [d[@"left"] doubleValue],
                          [d[@"bottom"] doubleValue], [d[@"right"] doubleValue]);
}

static std::string RNMapsStdStringFromNSString(NSString *value)
{
  if (value.length == 0) {
    return std::string();
  }

  return std::string(value.UTF8String);
}

template <typename Region>
static BOOL RNMapsRegionIsValid(const Region &region)
{
  return std::isfinite(region.latitude) &&
    std::isfinite(region.longitude) &&
    std::isfinite(region.latitudeDelta) &&
    std::isfinite(region.longitudeDelta) &&
    region.latitudeDelta > 0 &&
    region.longitudeDelta > 0;
}

template <typename Region>
static MACoordinateRegion RNMapsMACoordinateRegionFromRegion(const Region &region)
{
  CLLocationCoordinate2D center = CLLocationCoordinate2DMake(region.latitude, region.longitude);
  MACoordinateSpan span = MACoordinateSpanMake(region.latitudeDelta, region.longitudeDelta);
  return MACoordinateRegionMake(center, span);
}

static BOOL RNMapsRegionChanged(
  const RNMapsMapViewRegionStruct &oldRegion,
  const RNMapsMapViewRegionStruct &newRegion)
{
  return oldRegion.latitude != newRegion.latitude ||
    oldRegion.longitude != newRegion.longitude ||
    oldRegion.latitudeDelta != newRegion.latitudeDelta ||
    oldRegion.longitudeDelta != newRegion.longitudeDelta;
}

// A camera is "present" once it carries a real center; a zero/zero struct is the
// codegen default and means the prop was never set. Templated because codegen
// emits distinct structs for the `camera` and `initialCamera` props.
template <typename Camera>
static BOOL RNMapsCameraIsValid(const Camera &camera)
{
  return std::isfinite(camera.latitude) &&
    std::isfinite(camera.longitude) &&
    (camera.latitude != 0.0 || camera.longitude != 0.0);
}

static BOOL RNMapsCameraChanged(
  const RNMapsMapViewCameraStruct &oldCamera,
  const RNMapsMapViewCameraStruct &newCamera)
{
  return oldCamera.latitude != newCamera.latitude ||
    oldCamera.longitude != newCamera.longitude ||
    oldCamera.heading != newCamera.heading ||
    oldCamera.pitch != newCamera.pitch ||
    oldCamera.zoom != newCamera.zoom ||
    oldCamera.altitude != newCamera.altitude;
}

// Apply a camera struct to the map. Templated so it accepts both the `camera`
// and `initialCamera` codegen structs (distinct types with the same fields).
template <typename Camera>
static void RNMapsApplyCamera(MAMapView *mapView, const Camera &camera)
{
  mapView.centerCoordinate = CLLocationCoordinate2DMake(camera.latitude, camera.longitude);
  if (std::isfinite(camera.zoom) && camera.zoom > 0) {
    mapView.zoomLevel = camera.zoom;
  }
  mapView.rotationDegree = camera.heading;
  mapView.cameraDegree = camera.pitch;
}

static MAMapType RNMapsMapTypeFromProps(
  const std::string &mapType,
  const std::string &userInterfaceStyle)
{
  // AMap iOS has no dedicated hybrid/terrain/none surface; everything that is
  // not explicitly satellite collapses to the standard basemap (best-effort).
  MAMapType type = MAMapTypeStandard;
  if (mapType == "satellite" || mapType == "hybrid") {
    type = MAMapTypeSatellite;
  }

  if (type == MAMapTypeStandard && userInterfaceStyle == "dark") {
    type = MAMapTypeStandardNight;
  }

  return type;
}

static MAPinAnnotationColor RNMapsPinColor(NSString *color)
{
  NSString *lowercaseColor = [color lowercaseString];

  if ([lowercaseColor containsString:@"green"] || [lowercaseColor isEqualToString:@"#00ff00"]) {
    return MAPinAnnotationColorGreen;
  }

  if ([lowercaseColor containsString:@"purple"] || [lowercaseColor containsString:@"violet"]) {
    return MAPinAnnotationColorPurple;
  }

  return MAPinAnnotationColorRed;
}

@implementation RNMapsMapView {
  MAMapView *_mapView;
  // Child <Marker> host components currently attached to the map. They are kept
  // in mount order so get/unmount can index into them; the annotation's weak
  // `marker` back-ref handles delegate routing.
  NSMutableArray<RNMapsMarker *> *_markers;
  // Polyline/Polygon/Circle child views; scanned in rendererForOverlay: to match
  // an overlay back to its styling view.
  NSMutableArray<id<RNMapsOverlayView>> *_overlayViews;
  BOOL _initialRegionApplied;
  BOOL _initialCameraApplied;
  BOOL _isGesture;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNMapsMapViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNMapsMapViewProps>();
    _props = defaultProps;

    _mapView = [[MAMapView alloc] initWithFrame:self.bounds];
    _mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _mapView.delegate = self;
    _mapView.zoomEnabled = YES;
    _mapView.scrollEnabled = YES;
    _mapView.rotateEnabled = YES;
    _mapView.rotateCameraEnabled = YES;

    _markers = [NSMutableArray new];
    _overlayViews = [NSMutableArray new];
    self.contentView = _mapView;

    [self installGestureRecognizers];
  }

  return self;
}

// onLongPress / onPanDrag / onDoublePress have no first-class delegate callback,
// so they ride on UIKit gesture recognizers that recognize alongside the map's
// own gestures (see the simultaneous-recognition delegate below).
- (void)installGestureRecognizers
{
  UILongPressGestureRecognizer *longPress =
    [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
  longPress.delegate = self;
  [_mapView addGestureRecognizer:longPress];

  UITapGestureRecognizer *doubleTap =
    [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoublePress:)];
  doubleTap.numberOfTapsRequired = 2;
  doubleTap.delegate = self;
  [_mapView addGestureRecognizer:doubleTap];

  UIPanGestureRecognizer *pan =
    [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanDrag:)];
  pan.delegate = self;
  [_mapView addGestureRecognizer:pan];
}

- (void)prepareForRecycle
{
  [super prepareForRecycle];
  for (RNMapsMarker *marker in _markers) {
    [marker removeFromMap];
  }
  [_markers removeAllObjects];
  for (id<RNMapsOverlayView> overlayView in _overlayViews) {
    [overlayView removeFromMap];
  }
  [_overlayViews removeAllObjects];
  _initialRegionApplied = NO;
  _initialCameraApplied = NO;
  _isGesture = NO;
}

- (void)dealloc
{
  _mapView.delegate = nil;
}

- (void)animateToRegion:(double)latitude
              longitude:(double)longitude
          latitudeDelta:(double)latitudeDelta
         longitudeDelta:(double)longitudeDelta
               duration:(NSInteger)duration
{
  MACoordinateRegion region = MACoordinateRegionMake(
    CLLocationCoordinate2DMake(latitude, longitude),
    MACoordinateSpanMake(latitudeDelta, longitudeDelta)
  );

  [_mapView setRegion:region animated:duration > 0];
}

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args
{
  RCTRNMapsMapViewHandleCommand(self, commandName, args);
}

#pragma mark - Imperative commands (M6)

- (void)applyCameraLatitude:(double)latitude
                  longitude:(double)longitude
                    heading:(double)heading
                      pitch:(double)pitch
                       zoom:(double)zoom
                   animated:(BOOL)animated
                   duration:(NSTimeInterval)duration
{
  if (latitude != 0.0 || longitude != 0.0) {
    [_mapView setCenterCoordinate:CLLocationCoordinate2DMake(latitude, longitude) animated:animated];
  }
  if (std::isfinite(zoom) && zoom > 0) {
    [_mapView setZoomLevel:zoom animated:animated];
  }
  [_mapView setRotationDegree:heading animated:animated duration:duration];
  [_mapView setCameraDegree:pitch animated:animated duration:duration];
}

- (void)animateCamera:(double)latitude
            longitude:(double)longitude
              heading:(double)heading
                pitch:(double)pitch
                 zoom:(double)zoom
             duration:(NSInteger)duration
{
  [self applyCameraLatitude:latitude longitude:longitude heading:heading pitch:pitch zoom:zoom
                   animated:duration > 0 duration:duration / 1000.0];
}

- (void)setCamera:(double)latitude
        longitude:(double)longitude
          heading:(double)heading
            pitch:(double)pitch
             zoom:(double)zoom
{
  [self applyCameraLatitude:latitude longitude:longitude heading:heading pitch:pitch zoom:zoom
                   animated:NO duration:0];
}

- (void)fitToCoordinates:(NSString *)coordinatesJSON
         edgePaddingJSON:(NSString *)edgePaddingJSON
                animated:(BOOL)animated
{
  NSArray *coords = RNMapsJSONArray(coordinatesJSON);
  if (coords.count == 0) {
    return;
  }

  MAMapRect zoomRect = MAMapRectNull;
  for (NSDictionary *c in coords) {
    if (![c isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    MAMapPoint point = MAMapPointForCoordinate(
      CLLocationCoordinate2DMake([c[@"latitude"] doubleValue], [c[@"longitude"] doubleValue]));
    MAMapRect pointRect = MAMapRectMake(point.x, point.y, 0.1, 0.1);
    zoomRect = MAMapRectIsNull(zoomRect) ? pointRect : MAMapRectUnion(zoomRect, pointRect);
  }
  if (MAMapRectIsNull(zoomRect)) {
    return;
  }
  [_mapView setVisibleMapRect:zoomRect edgePadding:RNMapsEdgeInsets(edgePaddingJSON) animated:animated];
}

- (void)fitToElements:(BOOL)animated
{
  [_mapView showAnnotations:_mapView.annotations animated:animated];
}

- (void)fitToSuppliedMarkers:(NSString *)markerIDsJSON
             edgePaddingJSON:(NSString *)edgePaddingJSON
                    animated:(BOOL)animated
{
  NSArray *ids = RNMapsJSONArray(markerIDsJSON);
  if (ids.count == 0) {
    return;
  }
  NSMutableArray *annotations = [NSMutableArray array];
  for (RNMapsMarker *marker in _markers) {
    if (marker.annotation.identifier != nil && [ids containsObject:marker.annotation.identifier]) {
      [annotations addObject:marker.annotation];
    }
  }
  if (annotations.count > 0) {
    [_mapView showAnnotations:annotations animated:animated];
  }
}

#pragma mark - Query commands (M6)

- (void)emitCommandResult:(NSInteger)requestId data:(NSDictionary *)data
{
  auto emitter = [self eventEmitterOrNull];
  if (!emitter) {
    return;
  }
  NSData *json = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
  NSString *string = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : @"{}";

  RNMapsMapViewEventEmitter::OnCommandResult event{};
  event.id = (int)requestId;
  event.data = std::string(string.UTF8String);
  emitter->onCommandResult(event);
}

- (void)getCamera:(NSInteger)requestId
{
  [self emitCommandResult:requestId
                     data:@{
                       @"latitude" : @(_mapView.centerCoordinate.latitude),
                       @"longitude" : @(_mapView.centerCoordinate.longitude),
                       @"heading" : @(_mapView.rotationDegree),
                       @"pitch" : @(_mapView.cameraDegree),
                       @"zoom" : @(_mapView.zoomLevel),
                       @"altitude" : @(0),
                     }];
}

- (void)getMapBoundaries:(NSInteger)requestId
{
  MACoordinateRegion region = _mapView.region;
  [self emitCommandResult:requestId
                     data:@{
                       @"northEast" : @{
                         @"latitude" : @(region.center.latitude + region.span.latitudeDelta / 2.0),
                         @"longitude" : @(region.center.longitude + region.span.longitudeDelta / 2.0),
                       },
                       @"southWest" : @{
                         @"latitude" : @(region.center.latitude - region.span.latitudeDelta / 2.0),
                         @"longitude" : @(region.center.longitude - region.span.longitudeDelta / 2.0),
                       },
                     }];
}

- (void)pointForCoordinate:(NSInteger)requestId latitude:(double)latitude longitude:(double)longitude
{
  CGPoint point = [_mapView convertCoordinate:CLLocationCoordinate2DMake(latitude, longitude)
                                toPointToView:_mapView];
  [self emitCommandResult:requestId data:@{ @"x" : @(point.x), @"y" : @(point.y) }];
}

- (void)coordinateForPoint:(NSInteger)requestId x:(double)x y:(double)y
{
  CLLocationCoordinate2D coordinate = [_mapView convertPoint:CGPointMake(x, y) toCoordinateFromView:_mapView];
  [self emitCommandResult:requestId
                     data:@{ @"latitude" : @(coordinate.latitude), @"longitude" : @(coordinate.longitude) }];
}

// Async map snapshot of the current viewport (the `region` option is ignored).
// Replies with a file:// uri, or raw base64 when result == "base64". AMap may
// invoke the callback more than once; the JS side resolves on the first reply.
- (void)takeSnapshot:(NSInteger)requestId
               width:(NSInteger)width
              height:(NSInteger)height
              format:(NSString *)format
             quality:(double)quality
              result:(NSString *)result
{
  __weak RNMapsMapView *weakSelf = self;
  [_mapView takeSnapshotInRect:_mapView.bounds
           withCompletionBlock:^(UIImage *image, NSInteger state) {
    RNMapsMapView *strongSelf = weakSelf;
    if (strongSelf == nil) {
      return;
    }
    // state != 1 is an intermediate (still-rendering) callback; wait for the
    // final one so we don't resolve early with a partial snapshot.
    if (state != 1) {
      return;
    }
    // A nil final image still resolves the JS promise (with an empty uri) rather
    // than letting it hang until the timeout.
    if (image == nil) {
      [strongSelf emitCommandResult:requestId data:@{ @"uri" : @"" }];
      return;
    }

    UIImage *output = image;
    if (width > 0 && height > 0) {
      CGSize size = CGSizeMake(width, height);
      UIGraphicsBeginImageContextWithOptions(size, NO, image.scale);
      [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
      output = UIGraphicsGetImageFromCurrentImageContext() ?: image;
      UIGraphicsEndImageContext();
    }

    BOOL isJpg = [format isEqualToString:@"jpg"] || [format isEqualToString:@"jpeg"];
    NSData *data = isJpg ? UIImageJPEGRepresentation(output, MAX(0.0, MIN(1.0, quality)))
                         : UIImagePNGRepresentation(output);

    NSString *uri = @"";
    if (data != nil) {
      if ([result isEqualToString:@"base64"]) {
        uri = [data base64EncodedStringWithOptions:0];
      } else {
        NSString *ext = isJpg ? @"jpg" : @"png";
        NSString *name = [NSString stringWithFormat:@"map-snapshot-%ld.%@", (long)requestId, ext];
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
        if ([data writeToFile:path atomically:YES]) {
          uri = [@"file://" stringByAppendingString:path];
        }
      }
    }
    [strongSelf emitCommandResult:requestId data:@{ @"uri" : uri }];
  }];
}

- (void)setMapBoundaries:(double)neLatitude
            neLongitude:(double)neLongitude
            swLatitude:(double)swLatitude
           swLongitude:(double)swLongitude
{
  CLLocationCoordinate2D center = CLLocationCoordinate2DMake(
    (neLatitude + swLatitude) / 2.0, (neLongitude + swLongitude) / 2.0);
  MACoordinateSpan span = MACoordinateSpanMake(
    fabs(neLatitude - swLatitude), fabs(neLongitude - swLongitude));
  _mapView.limitRegion = MACoordinateRegionMake(center, span);
}

// Screen frames (in points) of all child markers, keyed by identifier.
// width/height are best-effort 0.
- (void)getMarkersFrames:(NSInteger)requestId onlyVisible:(BOOL)onlyVisible
{
  NSMutableDictionary *out = [NSMutableDictionary dictionary];
  for (RNMapsMarker *marker in _markers) {
    NSString *identifier = marker.annotation.identifier;
    if (identifier == nil) {
      continue;
    }
    CGPoint point = [_mapView convertCoordinate:marker.annotation.coordinate
                                  toPointToView:_mapView];
    if (onlyVisible && !CGRectContainsPoint(_mapView.bounds, point)) {
      continue;
    }
    out[identifier] = @{
      @"point" : @{ @"x" : @(point.x), @"y" : @(point.y) },
      @"frame" : @{ @"x" : @(point.x), @"y" : @(point.y), @"width" : @(0), @"height" : @(0) },
    };
  }
  [self emitCommandResult:requestId data:out];
}

#pragma mark - Child mounting

// Marker children are intercepted: they never enter the UIView hierarchy (no
// super call), they register their annotation on the MAMapView instead. Any
// other child falls through to the default RCTViewComponentView behavior.
- (void)mountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView index:(NSInteger)index
{
  if ([childComponentView isKindOfClass:[RNMapsMarker class]]) {
    RNMapsMarker *marker = (RNMapsMarker *)childComponentView;
    NSUInteger insertionIndex = MIN((NSUInteger)index, _markers.count);
    [_markers insertObject:marker atIndex:insertionIndex];
    [marker addToMap:_mapView];
    return;
  }

  if ([childComponentView conformsToProtocol:@protocol(RNMapsOverlayView)]) {
    id<RNMapsOverlayView> overlayView = (id<RNMapsOverlayView>)childComponentView;
    [_overlayViews addObject:overlayView];
    [overlayView addToMap:_mapView];
    return;
  }

  [super mountChildComponentView:childComponentView index:index];
}

- (void)unmountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView index:(NSInteger)index
{
  if ([childComponentView isKindOfClass:[RNMapsMarker class]]) {
    RNMapsMarker *marker = (RNMapsMarker *)childComponentView;
    [marker removeFromMap];
    [_markers removeObject:marker];
    return;
  }

  if ([childComponentView conformsToProtocol:@protocol(RNMapsOverlayView)]) {
    id<RNMapsOverlayView> overlayView = (id<RNMapsOverlayView>)childComponentView;
    [overlayView removeFromMap];
    [_overlayViews removeObject:overlayView];
    return;
  }

  [super unmountChildComponentView:childComponentView index:index];
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &oldViewProps = *std::static_pointer_cast<RNMapsMapViewProps const>(_props);
  const auto &newViewProps = *std::static_pointer_cast<RNMapsMapViewProps const>(props);

  // Appearance ---------------------------------------------------------------
  if (oldViewProps.mapType != newViewProps.mapType ||
      oldViewProps.userInterfaceStyle != newViewProps.userInterfaceStyle) {
    _mapView.mapType = RNMapsMapTypeFromProps(newViewProps.mapType, newViewProps.userInterfaceStyle);
  }

  // Zoom bounds --------------------------------------------------------------
  if (oldViewProps.minZoomLevel != newViewProps.minZoomLevel) {
    _mapView.minZoomLevel = newViewProps.minZoomLevel;
  }
  if (oldViewProps.maxZoomLevel != newViewProps.maxZoomLevel) {
    _mapView.maxZoomLevel = newViewProps.maxZoomLevel;
  }

  // Display toggles ----------------------------------------------------------
  // Guard showsUserLocation specifically: re-asserting it on every unrelated
  // prop change re-arms Core Location. The rest below are idempotent visual
  // setters with no side effect, so they stay unconditional (guarding them would
  // risk skipping a first-apply where the RN default differs from the MAMapKit
  // default). (H1)
  if (oldViewProps.showsUserLocation != newViewProps.showsUserLocation) {
    _mapView.showsUserLocation = newViewProps.showsUserLocation;
  }
  _mapView.showsCompass = newViewProps.showsCompass;
  _mapView.showsScale = newViewProps.showsScale;
  _mapView.showTraffic = newViewProps.showsTraffic;
  _mapView.showsBuildings = newViewProps.showsBuildings;
  _mapView.showsIndoorMap = newViewProps.showsIndoors;
  _mapView.showsLabels = newViewProps.showsPointsOfInterest;

  // Gesture toggles ----------------------------------------------------------
  _mapView.zoomEnabled = newViewProps.zoomEnabled;
  _mapView.scrollEnabled = newViewProps.scrollEnabled;
  _mapView.rotateEnabled = newViewProps.rotateEnabled;
  _mapView.rotateCameraEnabled = newViewProps.pitchEnabled;

  // Initial camera/region apply once. A camera takes precedence over a region
  // (RNM semantics), so it is applied last and overwrites the region setup.
  if (!_initialCameraApplied) {
    if (!_initialRegionApplied && RNMapsRegionIsValid(newViewProps.initialRegion)) {
      [_mapView setRegion:RNMapsMACoordinateRegionFromRegion(newViewProps.initialRegion) animated:NO];
      _initialRegionApplied = YES;
    }
    if (RNMapsCameraIsValid(newViewProps.initialCamera)) {
      RNMapsApplyCamera(_mapView, newViewProps.initialCamera);
      _initialCameraApplied = YES;
    }
  }

  if (RNMapsRegionIsValid(newViewProps.region) && RNMapsRegionChanged(oldViewProps.region, newViewProps.region)) {
    [_mapView setRegion:RNMapsMACoordinateRegionFromRegion(newViewProps.region) animated:NO];
  }

  // camera wins over region when both are controlled.
  if (RNMapsCameraIsValid(newViewProps.camera) && RNMapsCameraChanged(oldViewProps.camera, newViewProps.camera)) {
    RNMapsApplyCamera(_mapView, newViewProps.camera);
  }

  // NOTE: mapPadding, customMapStyle (JSON), tintColor, kmlSrc, loading* and
  // showsMyLocationButton have no clean MAMapKit equivalent and are intentionally
  // ignored on iOS for M2; the JS facade warns where appropriate.

  // Markers are no longer a prop — they mount as child host components (see
  // mountChildComponentView:).

  [super updateProps:props oldProps:oldProps];
}

#pragma mark - Event emission

- (std::shared_ptr<const RNMapsMapViewEventEmitter>)eventEmitterOrNull
{
  if (!_eventEmitter) {
    return nullptr;
  }
  return std::static_pointer_cast<RNMapsMapViewEventEmitter const>(_eventEmitter);
}

- (void)emitPress:(RNMapsPressKind)kind atCoordinate:(CLLocationCoordinate2D)coordinate
{
  auto emitter = [self eventEmitterOrNull];
  if (!emitter) {
    return;
  }

  CGPoint point = [_mapView convertCoordinate:coordinate toPointToView:_mapView];

  switch (kind) {
    case RNMapsPressKindPress: {
      RNMapsMapViewEventEmitter::OnPress event{};
      event.coordinate.latitude = coordinate.latitude;
      event.coordinate.longitude = coordinate.longitude;
      event.position.x = point.x;
      event.position.y = point.y;
      emitter->onPress(event);
      break;
    }
    case RNMapsPressKindLongPress: {
      RNMapsMapViewEventEmitter::OnLongPress event{};
      event.coordinate.latitude = coordinate.latitude;
      event.coordinate.longitude = coordinate.longitude;
      event.position.x = point.x;
      event.position.y = point.y;
      emitter->onLongPress(event);
      break;
    }
    case RNMapsPressKindDoublePress: {
      RNMapsMapViewEventEmitter::OnDoublePress event{};
      event.coordinate.latitude = coordinate.latitude;
      event.coordinate.longitude = coordinate.longitude;
      event.position.x = point.x;
      event.position.y = point.y;
      emitter->onDoublePress(event);
      break;
    }
    case RNMapsPressKindPanDrag: {
      RNMapsMapViewEventEmitter::OnPanDrag event{};
      event.coordinate.latitude = coordinate.latitude;
      event.coordinate.longitude = coordinate.longitude;
      event.position.x = point.x;
      event.position.y = point.y;
      emitter->onPanDrag(event);
      break;
    }
  }
}

- (void)emitRegionChangeComplete:(BOOL)complete isGesture:(BOOL)isGesture
{
  auto mapViewEventEmitter = [self eventEmitterOrNull];
  if (!mapViewEventEmitter) {
    return;
  }

  MACoordinateRegion region = _mapView.region;

  if (complete) {
    RNMapsMapViewEventEmitter::OnRegionChangeComplete event = {
      .region.latitude = region.center.latitude,
      .region.longitude = region.center.longitude,
      .region.latitudeDelta = region.span.latitudeDelta,
      .region.longitudeDelta = region.span.longitudeDelta,
      .isGesture = static_cast<bool>(isGesture),
    };
    mapViewEventEmitter->onRegionChangeComplete(event);
  } else {
    RNMapsMapViewEventEmitter::OnRegionChange event = {
      .region.latitude = region.center.latitude,
      .region.longitude = region.center.longitude,
      .region.latitudeDelta = region.span.latitudeDelta,
      .region.longitudeDelta = region.span.longitudeDelta,
      .isGesture = static_cast<bool>(isGesture),
    };
    mapViewEventEmitter->onRegionChange(event);
  }
}

#pragma mark - Gesture handlers

- (void)handleLongPress:(UILongPressGestureRecognizer *)recognizer
{
  if (recognizer.state != UIGestureRecognizerStateBegan) {
    return;
  }

  CGPoint point = [recognizer locationInView:_mapView];
  CLLocationCoordinate2D coordinate = [_mapView convertPoint:point toCoordinateFromView:_mapView];
  [self emitPress:RNMapsPressKindLongPress atCoordinate:coordinate];
}

- (void)handleDoublePress:(UITapGestureRecognizer *)recognizer
{
  CGPoint point = [recognizer locationInView:_mapView];
  CLLocationCoordinate2D coordinate = [_mapView convertPoint:point toCoordinateFromView:_mapView];
  [self emitPress:RNMapsPressKindDoublePress atCoordinate:coordinate];
}

- (void)handlePanDrag:(UIPanGestureRecognizer *)recognizer
{
  if (recognizer.state != UIGestureRecognizerStateChanged) {
    return;
  }

  CGPoint point = [recognizer locationInView:_mapView];
  CLLocationCoordinate2D coordinate = [_mapView convertPoint:point toCoordinateFromView:_mapView];
  [self emitPress:RNMapsPressKindPanDrag atCoordinate:coordinate];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  return YES;
}

#pragma mark - MAMapViewDelegate

- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation
{
  if (![annotation isKindOfClass:[RNMapsMarkerAnnotation class]]) {
    return nil;
  }

  RNMapsMarkerAnnotation *marker = (RNMapsMarkerAnnotation *)annotation;

  MAAnnotationView *annotationView;
  if (marker.image != nil) {
    // Custom image marker: a plain MAAnnotationView carrying the loaded image.
    static NSString *imageReuseIdentifier = @"RNMapsMarkerImage";
    annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:imageReuseIdentifier];
    if (annotationView == nil) {
      annotationView = [[MAAnnotationView alloc] initWithAnnotation:marker reuseIdentifier:imageReuseIdentifier];
    } else {
      annotationView.annotation = marker;
    }
    annotationView.image = marker.image;
  } else {
    // Default pin (optionally color-tinted).
    static NSString *pinReuseIdentifier = @"RNMapsMarkerPin";
    MAPinAnnotationView *pinView =
      (MAPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:pinReuseIdentifier];
    if (pinView == nil) {
      pinView = [[MAPinAnnotationView alloc] initWithAnnotation:marker reuseIdentifier:pinReuseIdentifier];
    } else {
      pinView.annotation = marker;
    }
    if (marker.pinColor != nil) {
      pinView.pinColor = RNMapsPinColor(marker.pinColor);
    }
    annotationView = pinView;
  }

  [marker applyAppearanceToView:annotationView];

  return annotationView;
}

- (MAOverlayRenderer *)mapView:(MAMapView *)mapView rendererForOverlay:(id<MAOverlay>)overlay
{
  for (id<RNMapsOverlayView> overlayView in _overlayViews) {
    if (overlayView.overlay == overlay) {
      return [overlayView overlayRenderer];
    }
  }
  return nil;
}

- (void)mapInitComplete:(MAMapView *)mapView
{
  auto emitter = [self eventEmitterOrNull];
  if (!emitter) {
    return;
  }

  // AMap exposes a single init-complete callback; surface it as both RNM
  // lifecycle events (map is ready and the tiles have loaded).
  emitter->onMapReady(RNMapsMapViewEventEmitter::OnMapReady{});
  emitter->onMapLoaded(RNMapsMapViewEventEmitter::OnMapLoaded{});
}

- (void)mapView:(MAMapView *)mapView didSingleTappedAtCoordinate:(CLLocationCoordinate2D)coordinate
{
  [self emitPress:RNMapsPressKindPress atCoordinate:coordinate];
}

- (void)mapView:(MAMapView *)mapView didTouchPois:(NSArray<MATouchPoi *> *)pois
{
  auto emitter = [self eventEmitterOrNull];
  if (!emitter || pois.count == 0) {
    return;
  }

  MATouchPoi *poi = pois.firstObject;
  CGPoint point = [_mapView convertCoordinate:poi.coordinate toPointToView:_mapView];

  RNMapsMapViewEventEmitter::OnPoiClick event{};
  event.placeId = RNMapsStdStringFromNSString(poi.uid);
  event.name = RNMapsStdStringFromNSString(poi.name);
  event.coordinate.latitude = poi.coordinate.latitude;
  event.coordinate.longitude = poi.coordinate.longitude;
  event.position.x = point.x;
  event.position.y = point.y;
  emitter->onPoiClick(event);
}

- (void)mapView:(MAMapView *)mapView
  didUpdateUserLocation:(MAUserLocation *)userLocation
       updatingLocation:(BOOL)updatingLocation
{
  auto emitter = [self eventEmitterOrNull];
  CLLocation *location = userLocation.location;
  if (!emitter || location == nil) {
    return;
  }

  RNMapsMapViewEventEmitter::OnUserLocationChange event{};
  event.coordinate.latitude = location.coordinate.latitude;
  event.coordinate.longitude = location.coordinate.longitude;
  event.coordinate.altitude = location.altitude;
  event.coordinate.accuracy = location.horizontalAccuracy;
  event.coordinate.speed = location.speed;
  event.coordinate.heading = location.course;
  event.coordinate.isFromMockProvider = false;
  emitter->onUserLocationChange(event);
}

- (void)mapViewRegionChanged:(MAMapView *)mapView
{
  [self emitRegionChangeComplete:NO isGesture:_isGesture];
}

- (void)mapView:(MAMapView *)mapView
regionWillChangeAnimated:(BOOL)animated
  wasUserAction:(BOOL)wasUserAction
{
  _isGesture = wasUserAction;
}

- (void)mapView:(MAMapView *)mapView
regionDidChangeAnimated:(BOOL)animated
  wasUserAction:(BOOL)wasUserAction
{
  [self emitRegionChangeComplete:YES isGesture:wasUserAction];
  _isGesture = NO;
}

// AMap map-level annotation callbacks are routed back to the owning child marker
// view (annotation → weak `marker` ref), which owns its own event emitter.
- (RNMapsMarker *)markerForAnnotationView:(MAAnnotationView *)view
{
  if (![view.annotation isKindOfClass:[RNMapsMarkerAnnotation class]]) {
    return nil;
  }
  return ((RNMapsMarkerAnnotation *)view.annotation).marker;
}

- (void)mapView:(MAMapView *)mapView didSelectAnnotationView:(MAAnnotationView *)view
{
  // RNM fires both onPress and onSelect on selection.
  RNMapsMarker *marker = [self markerForAnnotationView:view];
  [marker emitPress];
  [marker emitSelect];
  [marker presentCalloutInAnnotationView:view];
}

- (void)mapView:(MAMapView *)mapView didDeselectAnnotationView:(MAAnnotationView *)view
{
  RNMapsMarker *marker = [self markerForAnnotationView:view];
  [marker dismissCallout];
  [marker emitDeselect];
}

- (void)mapView:(MAMapView *)mapView didAnnotationViewCalloutTapped:(MAAnnotationView *)view
{
  [[self markerForAnnotationView:view] emitCalloutPress];
}

- (void)mapView:(MAMapView *)mapView
    annotationView:(MAAnnotationView *)view
 didChangeDragState:(MAAnnotationViewDragState)newState
       fromOldState:(MAAnnotationViewDragState)oldState
{
  RNMapsMarker *marker = [self markerForAnnotationView:view];
  if (marker == nil) {
    return;
  }

  switch (newState) {
    case MAAnnotationViewDragStateStarting:
      [marker emitDragStart];
      break;
    case MAAnnotationViewDragStateDragging:
      [marker emitDrag];
      break;
    case MAAnnotationViewDragStateEnding:
      [marker emitDragEnd];
      break;
    default:
      break;
  }
}

@end
