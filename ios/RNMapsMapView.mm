#import "RNMapsMapView.h"
#import "RNMapsMarker.h"

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
  // Child <Marker> host components currently attached to the map. They are kept
  // in mount order so get/unmount can index into them; the annotation's weak
  // `marker` back-ref handles delegate routing.
  NSMutableArray<RNMapsMarker *> *_markers;
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

  // Markers are no longer a prop — they mount as child host components (see
  // mountChildComponentView:).

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
}

- (void)mapView:(MAMapView *)mapView didDeselectAnnotationView:(MAAnnotationView *)view
{
  [[self markerForAnnotationView:view] emitDeselect];
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
