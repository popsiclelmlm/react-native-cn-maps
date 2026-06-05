#import "RNMapsMapView.h"

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

@interface RNMapsMarkerAnnotation : MAPointAnnotation
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy, nullable) NSString *pinColor;
@property (nonatomic, assign) BOOL draggable;
@end

@implementation RNMapsMarkerAnnotation
@end

@interface RNMapsMapView () <MAMapViewDelegate, UIGestureRecognizerDelegate, RCTRNMapsMapViewViewProtocol>
@end

static NSString *RNMapsNSStringFromString(const std::string &value)
{
  if (value.empty()) {
    return nil;
  }

  return [NSString stringWithUTF8String:value.c_str()];
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
// codegen default and means the prop was never set.
static BOOL RNMapsCameraIsValid(const RNMapsMapViewCameraStruct &camera)
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
  NSMutableDictionary<NSString *, RNMapsMarkerAnnotation *> *_annotationsByIdentifier;
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

    _annotationsByIdentifier = [NSMutableDictionary new];
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
  [_mapView removeAnnotations:_annotationsByIdentifier.allValues];
  [_annotationsByIdentifier removeAllObjects];
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
  _mapView.showsUserLocation = newViewProps.showsUserLocation;
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
      [self applyCamera:newViewProps.initialCamera];
      _initialCameraApplied = YES;
    }
  }

  if (RNMapsRegionIsValid(newViewProps.region) && RNMapsRegionChanged(oldViewProps.region, newViewProps.region)) {
    [_mapView setRegion:RNMapsMACoordinateRegionFromRegion(newViewProps.region) animated:NO];
  }

  // camera wins over region when both are controlled.
  if (RNMapsCameraIsValid(newViewProps.camera) && RNMapsCameraChanged(oldViewProps.camera, newViewProps.camera)) {
    [self applyCamera:newViewProps.camera];
  }

  // NOTE: mapPadding, customMapStyle (JSON), tintColor, kmlSrc, loading* and
  // showsMyLocationButton have no clean MAMapKit equivalent and are intentionally
  // ignored on iOS for M2; the JS facade warns where appropriate.

  [self updateMarkers:newViewProps.markers];

  [super updateProps:props oldProps:oldProps];
}

- (void)applyCamera:(const RNMapsMapViewCameraStruct &)camera
{
  _mapView.centerCoordinate = CLLocationCoordinate2DMake(camera.latitude, camera.longitude);
  if (std::isfinite(camera.zoom) && camera.zoom > 0) {
    _mapView.zoomLevel = camera.zoom;
  }
  _mapView.rotationDegree = camera.heading;
  _mapView.cameraDegree = camera.pitch;
}

- (void)updateMarkers:(const std::vector<RNMapsMapViewMarkersStruct> &)markers
{
  [_mapView removeAnnotations:_annotationsByIdentifier.allValues];
  [_annotationsByIdentifier removeAllObjects];

  for (const auto &marker : markers) {
    NSString *identifier = RNMapsNSStringFromString(marker.identifier);
    if (identifier == nil) {
      continue;
    }

    RNMapsMarkerAnnotation *annotation = [RNMapsMarkerAnnotation new];
    annotation.identifier = identifier;
    annotation.coordinate = CLLocationCoordinate2DMake(marker.latitude, marker.longitude);
    annotation.title = RNMapsNSStringFromString(marker.title);
    annotation.subtitle = RNMapsNSStringFromString(marker.description);
    annotation.pinColor = RNMapsNSStringFromString(marker.pinColor);
    annotation.draggable = marker.draggable;

    _annotationsByIdentifier[identifier] = annotation;
    [_mapView addAnnotation:annotation];
  }
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

  static NSString *reuseIdentifier = @"RNMapsMarker";
  MAPinAnnotationView *annotationView =
    (MAPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:reuseIdentifier];

  if (annotationView == nil) {
    annotationView = [[MAPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
  } else {
    annotationView.annotation = annotation;
  }

  RNMapsMarkerAnnotation *marker = (RNMapsMarkerAnnotation *)annotation;
  annotationView.canShowCallout = YES;
  annotationView.draggable = marker.draggable;

  if (marker.pinColor != nil) {
    annotationView.pinColor = RNMapsPinColor(marker.pinColor);
  }

  return annotationView;
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

- (void)mapView:(MAMapView *)mapView didSelectAnnotationView:(MAAnnotationView *)view
{
  auto mapViewEventEmitter = [self eventEmitterOrNull];
  if (!mapViewEventEmitter || ![view.annotation isKindOfClass:[RNMapsMarkerAnnotation class]]) {
    return;
  }

  RNMapsMarkerAnnotation *marker = (RNMapsMarkerAnnotation *)view.annotation;
  RNMapsMapViewEventEmitter::OnMarkerPress event = {
    .identifier = std::string([marker.identifier UTF8String]),
    .coordinate.latitude = marker.coordinate.latitude,
    .coordinate.longitude = marker.coordinate.longitude,
  };
  mapViewEventEmitter->onMarkerPress(event);
}

@end
