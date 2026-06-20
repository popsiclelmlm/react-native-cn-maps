#import "RNMapsMapView.h"
#import "RNMapsMarker.h"
#import "RNMapsOverlay.h"

#import "CNMapAdapter.h"
#import "CNMapAdapterRegistry.h"

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

@interface RNMapsMapView () <UIGestureRecognizerDelegate,
                             RCTRNMapsMapViewViewProtocol,
                             CNMapAdapterDelegate,
                             RNMapsChildHost>
@end

static NSString *RNMapsNSString(const std::string &value)
{
  return value.empty() ? nil : [NSString stringWithUTF8String:value.c_str()];
}

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

// Parse a JSON array of { latitude, longitude } into NSValue-boxed coordinates.
static NSArray<NSValue *> *RNMapsBoxedCoordinatesFromJSON(NSString *json)
{
  NSArray *raw = RNMapsJSONArray(json);
  NSMutableArray<NSValue *> *out = [NSMutableArray arrayWithCapacity:raw.count];
  for (id entry in raw) {
    if (![entry isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(
      [entry[@"latitude"] doubleValue], [entry[@"longitude"] doubleValue]);
    [out addObject:CNBoxCoordinate(coordinate)];
  }
  return out;
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
  return std::isfinite(region.latitude) && std::isfinite(region.longitude) &&
    std::isfinite(region.latitudeDelta) && std::isfinite(region.longitudeDelta) &&
    region.latitudeDelta > 0 && region.longitudeDelta > 0;
}

static BOOL RNMapsRegionChanged(
  const RNMapsMapViewRegionStruct &oldRegion, const RNMapsMapViewRegionStruct &newRegion)
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
  return std::isfinite(camera.latitude) && std::isfinite(camera.longitude) &&
    (camera.latitude != 0.0 || camera.longitude != 0.0);
}

static BOOL RNMapsCameraChanged(
  const RNMapsMapViewCameraStruct &oldCamera, const RNMapsMapViewCameraStruct &newCamera)
{
  return oldCamera.latitude != newCamera.latitude ||
    oldCamera.longitude != newCamera.longitude ||
    oldCamera.heading != newCamera.heading ||
    oldCamera.pitch != newCamera.pitch ||
    oldCamera.zoom != newCamera.zoom ||
    oldCamera.altitude != newCamera.altitude;
}

@implementation RNMapsMapView {
  id<CNMapAdapter> _adapter;
  // Child <Marker> host components, in mount order (for fit/frames).
  NSMutableArray<RNMapsMarker *> *_markers;
  // Polyline/Polygon/Circle/... overlay child views, in mount order.
  NSMutableArray<id<RNMapsOverlayView>> *_overlayViews;
  // childId → child, for routing adapter callbacks back to the owning child.
  NSMutableDictionary<NSString *, id> *_childrenById;
  NSUInteger _childIdCounter;
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

    _markers = [NSMutableArray new];
    _overlayViews = [NSMutableArray new];
    _childrenById = [NSMutableDictionary new];

    _adapter = [CNMapAdapterRegistry createAdapter];
    _adapter.delegate = self;
    if (_adapter.mapView != nil) {
      self.contentView = _adapter.mapView;
      [self installGestureRecognizers];
    }
  }

  return self;
}

// onLongPress / onPanDrag / onDoublePress have no first-class provider callback, so
// they ride on UIKit gesture recognizers installed on the adapter's map view, which
// recognize alongside the provider's own gestures.
- (void)installGestureRecognizers
{
  UIView *mapView = _adapter.mapView;

  UILongPressGestureRecognizer *longPress =
    [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
  longPress.delegate = self;
  [mapView addGestureRecognizer:longPress];

  UITapGestureRecognizer *doubleTap =
    [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoublePress:)];
  doubleTap.numberOfTapsRequired = 2;
  doubleTap.delegate = self;
  [mapView addGestureRecognizer:doubleTap];

  UIPanGestureRecognizer *pan =
    [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanDrag:)];
  pan.delegate = self;
  [mapView addGestureRecognizer:pan];
}

- (void)prepareForRecycle
{
  [super prepareForRecycle];
  for (RNMapsMarker *marker in _markers) {
    marker.mapHost = nil;
  }
  [_markers removeAllObjects];
  for (id<RNMapsOverlayView> overlayView in _overlayViews) {
    overlayView.mapHost = nil;
  }
  [_overlayViews removeAllObjects];
  [_childrenById removeAllObjects];
  [_adapter reset];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  [_adapter didLayout];
}

- (void)dealloc
{
  [_adapter teardown];
}

- (NSString *)nextChildId
{
  return [NSString stringWithFormat:@"cn-%lu", (unsigned long)(++_childIdCounter)];
}

#pragma mark - Child mounting

// Marker / overlay children never enter the UIView hierarchy: they are registered
// with the adapter (which owns the SDK map) instead. Any other child falls through
// to the default RCTViewComponentView behavior.
- (void)mountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView index:(NSInteger)index
{
  if ([childComponentView isKindOfClass:[RNMapsMarker class]]) {
    RNMapsMarker *marker = (RNMapsMarker *)childComponentView;
    NSString *childId = [self nextChildId];
    marker.cnChildId = childId;
    marker.mapHost = self;
    NSUInteger insertionIndex = MIN((NSUInteger)index, _markers.count);
    [_markers insertObject:marker atIndex:insertionIndex];
    _childrenById[childId] = marker;
    marker.cnHandle = [_adapter addMarker:marker.markerModel childId:childId];
    return;
  }

  if ([childComponentView conformsToProtocol:@protocol(RNMapsOverlayView)]) {
    id<RNMapsOverlayView> overlayView = (id<RNMapsOverlayView>)childComponentView;
    NSString *childId = [self nextChildId];
    overlayView.cnChildId = childId;
    overlayView.mapHost = self;
    [_overlayViews addObject:overlayView];
    _childrenById[childId] = overlayView;
    overlayView.cnHandle = [_adapter addOverlay:overlayView.overlayModel childId:childId];
    return;
  }

  [super mountChildComponentView:childComponentView index:index];
}

- (void)unmountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView index:(NSInteger)index
{
  if ([childComponentView isKindOfClass:[RNMapsMarker class]]) {
    RNMapsMarker *marker = (RNMapsMarker *)childComponentView;
    [_adapter removeMarker:marker.cnHandle];
    [_markers removeObject:marker];
    if (marker.cnChildId != nil) {
      [_childrenById removeObjectForKey:marker.cnChildId];
    }
    marker.mapHost = nil;
    return;
  }

  if ([childComponentView conformsToProtocol:@protocol(RNMapsOverlayView)]) {
    id<RNMapsOverlayView> overlayView = (id<RNMapsOverlayView>)childComponentView;
    [_adapter removeOverlay:overlayView.cnHandle];
    [_overlayViews removeObject:overlayView];
    if (overlayView.cnChildId != nil) {
      [_childrenById removeObjectForKey:overlayView.cnChildId];
    }
    overlayView.mapHost = nil;
    return;
  }

  [super unmountChildComponentView:childComponentView index:index];
}

#pragma mark - RNMapsChildHost

- (id<CNMapAdapter>)mapAdapter
{
  return _adapter;
}

// A child re-applies its model (prop change, or async image/raster) through the
// adapter. No-op until the child has been mounted (handle assigned).
- (void)childDidUpdateModel:(UIView *)child
{
  if ([child isKindOfClass:[RNMapsMarker class]]) {
    RNMapsMarker *marker = (RNMapsMarker *)child;
    if (marker.cnHandle != nil) {
      [_adapter updateMarker:marker.cnHandle model:marker.markerModel];
    }
    return;
  }
  if ([child conformsToProtocol:@protocol(RNMapsOverlayView)]) {
    id<RNMapsOverlayView> overlayView = (id<RNMapsOverlayView>)child;
    if (overlayView.cnHandle != nil) {
      [_adapter updateOverlay:overlayView.cnHandle model:overlayView.overlayModel];
    }
  }
}

#pragma mark - Props

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &oldViewProps = *std::static_pointer_cast<RNMapsMapViewProps const>(_props);
  const auto &newViewProps = *std::static_pointer_cast<RNMapsMapViewProps const>(props);

  CNMapOptions *options = [CNMapOptions new];
  options.mapType = RNMapsNSString(newViewProps.mapType) ?: @"";
  options.userInterfaceStyle = RNMapsNSString(newViewProps.userInterfaceStyle) ?: @"";
  options.minZoomLevel = newViewProps.minZoomLevel;
  options.maxZoomLevel = newViewProps.maxZoomLevel;
  options.showsUserLocation = newViewProps.showsUserLocation;
  options.showsCompass = newViewProps.showsCompass;
  options.showsScale = newViewProps.showsScale;
  options.showsTraffic = newViewProps.showsTraffic;
  options.showsBuildings = newViewProps.showsBuildings;
  options.showsIndoors = newViewProps.showsIndoors;
  options.showsPointsOfInterest = newViewProps.showsPointsOfInterest;
  options.zoomEnabled = newViewProps.zoomEnabled;
  options.scrollEnabled = newViewProps.scrollEnabled;
  options.rotateEnabled = newViewProps.rotateEnabled;
  options.pitchEnabled = newViewProps.pitchEnabled;
  [_adapter applyOptions:options];

  // Capture the initial region/camera; the adapter applies them once ready & sized.
  if (RNMapsRegionIsValid(newViewProps.initialRegion)) {
    [_adapter setPendingInitialRegionLatitude:newViewProps.initialRegion.latitude
                                    longitude:newViewProps.initialRegion.longitude
                                latitudeDelta:newViewProps.initialRegion.latitudeDelta
                               longitudeDelta:newViewProps.initialRegion.longitudeDelta];
  }
  if (RNMapsCameraIsValid(newViewProps.initialCamera)) {
    [_adapter setPendingInitialCameraLatitude:newViewProps.initialCamera.latitude
                                    longitude:newViewProps.initialCamera.longitude
                                      heading:newViewProps.initialCamera.heading
                                        pitch:newViewProps.initialCamera.pitch
                                         zoom:newViewProps.initialCamera.zoom];
  }

  if (RNMapsRegionIsValid(newViewProps.region) &&
      RNMapsRegionChanged(oldViewProps.region, newViewProps.region)) {
    [_adapter setRegionLatitude:newViewProps.region.latitude
                      longitude:newViewProps.region.longitude
                  latitudeDelta:newViewProps.region.latitudeDelta
                 longitudeDelta:newViewProps.region.longitudeDelta
                       animated:NO];
  }

  // camera wins over region when both are controlled.
  if (RNMapsCameraIsValid(newViewProps.camera) &&
      RNMapsCameraChanged(oldViewProps.camera, newViewProps.camera)) {
    [_adapter setCameraLatitude:newViewProps.camera.latitude
                      longitude:newViewProps.camera.longitude
                        heading:newViewProps.camera.heading
                          pitch:newViewProps.camera.pitch
                           zoom:newViewProps.camera.zoom
                       animated:NO
                       duration:0];
  }

  // NOTE: mapPadding, customMapStyle (JSON), tintColor, kmlSrc, loading* and
  // showsMyLocationButton have no clean provider equivalent and are intentionally
  // ignored on iOS; the JS facade warns where appropriate.

  [super updateProps:props oldProps:oldProps];
}

#pragma mark - Commands

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args
{
  RCTRNMapsMapViewHandleCommand(self, commandName, args);
}

- (void)animateToRegion:(double)latitude
              longitude:(double)longitude
          latitudeDelta:(double)latitudeDelta
         longitudeDelta:(double)longitudeDelta
               duration:(NSInteger)duration
{
  [_adapter setRegionLatitude:latitude
                    longitude:longitude
                latitudeDelta:latitudeDelta
               longitudeDelta:longitudeDelta
                     animated:duration > 0];
}

- (void)animateCamera:(double)latitude
            longitude:(double)longitude
              heading:(double)heading
                pitch:(double)pitch
                 zoom:(double)zoom
             duration:(NSInteger)duration
{
  [_adapter setCameraLatitude:latitude
                    longitude:longitude
                      heading:heading
                        pitch:pitch
                         zoom:zoom
                     animated:duration > 0
                     duration:duration / 1000.0];
}

- (void)setCamera:(double)latitude
        longitude:(double)longitude
          heading:(double)heading
            pitch:(double)pitch
             zoom:(double)zoom
{
  [_adapter setCameraLatitude:latitude
                    longitude:longitude
                      heading:heading
                        pitch:pitch
                         zoom:zoom
                     animated:NO
                     duration:0];
}

- (void)fitToCoordinates:(NSString *)coordinatesJSON
         edgePaddingJSON:(NSString *)edgePaddingJSON
                animated:(BOOL)animated
{
  NSArray<NSValue *> *coordinates = RNMapsBoxedCoordinatesFromJSON(coordinatesJSON);
  if (coordinates.count == 0) {
    return;
  }
  [_adapter fitToCoordinates:coordinates
                 edgePadding:RNMapsEdgeInsets(edgePaddingJSON)
                    animated:animated];
}

- (void)fitToElements:(BOOL)animated
{
  [_adapter fitToElementsAnimated:animated];
}

- (void)fitToSuppliedMarkers:(NSString *)markerIDsJSON
             edgePaddingJSON:(NSString *)edgePaddingJSON
                    animated:(BOOL)animated
{
  NSArray *ids = RNMapsJSONArray(markerIDsJSON);
  if (ids.count == 0) {
    return;
  }
  NSMutableArray<CNOverlayHandle *> *handles = [NSMutableArray array];
  for (RNMapsMarker *marker in _markers) {
    NSString *identifier = marker.markerModel.identifier;
    if (identifier != nil && [ids containsObject:identifier] && marker.cnHandle != nil) {
      [handles addObject:marker.cnHandle];
    }
  }
  [_adapter fitToMarkers:handles edgePadding:RNMapsEdgeInsets(edgePaddingJSON) animated:animated];
}

- (void)setMapBoundaries:(double)neLatitude
             neLongitude:(double)neLongitude
              swLatitude:(double)swLatitude
             swLongitude:(double)swLongitude
{
  [_adapter setLimitRegionNELatitude:neLatitude
                         neLongitude:neLongitude
                          swLatitude:swLatitude
                         swLongitude:swLongitude];
}

#pragma mark - Query commands

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
  CNCamera camera = [_adapter currentCamera];
  [self emitCommandResult:requestId
                     data:@{
                       @"latitude" : @(camera.latitude),
                       @"longitude" : @(camera.longitude),
                       @"heading" : @(camera.heading),
                       @"pitch" : @(camera.pitch),
                       @"zoom" : @(camera.zoom),
                       @"altitude" : @(camera.altitude),
                     }];
}

- (void)getMapBoundaries:(NSInteger)requestId
{
  CNRegion region = [_adapter currentRegion];
  [self emitCommandResult:requestId
                     data:@{
                       @"northEast" : @{
                         @"latitude" : @(region.latitude + region.latitudeDelta / 2.0),
                         @"longitude" : @(region.longitude + region.longitudeDelta / 2.0),
                       },
                       @"southWest" : @{
                         @"latitude" : @(region.latitude - region.latitudeDelta / 2.0),
                         @"longitude" : @(region.longitude - region.longitudeDelta / 2.0),
                       },
                     }];
}

- (void)pointForCoordinate:(NSInteger)requestId latitude:(double)latitude longitude:(double)longitude
{
  CGPoint point = [_adapter pointForCoordinate:CLLocationCoordinate2DMake(latitude, longitude)];
  [self emitCommandResult:requestId data:@{ @"x" : @(point.x), @"y" : @(point.y) }];
}

- (void)coordinateForPoint:(NSInteger)requestId x:(double)x y:(double)y
{
  CLLocationCoordinate2D coordinate = [_adapter coordinateForPoint:CGPointMake(x, y)];
  [self emitCommandResult:requestId
                     data:@{ @"latitude" : @(coordinate.latitude), @"longitude" : @(coordinate.longitude) }];
}

- (void)takeSnapshot:(NSInteger)requestId
               width:(NSInteger)width
              height:(NSInteger)height
              format:(NSString *)format
             quality:(double)quality
              result:(NSString *)result
{
  __weak RNMapsMapView *weakSelf = self;
  [_adapter takeSnapshotWidth:width
                       height:height
                       format:format
                      quality:quality
                       result:result
                   completion:^(NSString *uri) {
    [weakSelf emitCommandResult:requestId data:@{ @"uri" : uri ?: @"" }];
  }];
}

// Screen frames (in points) of all child markers, keyed by identifier.
- (void)getMarkersFrames:(NSInteger)requestId onlyVisible:(BOOL)onlyVisible
{
  NSMutableDictionary *out = [NSMutableDictionary dictionary];
  for (RNMapsMarker *marker in _markers) {
    NSString *identifier = marker.markerModel.identifier;
    if (identifier == nil || marker.cnHandle == nil) {
      continue;
    }
    CGPoint point = [_adapter pointForMarker:marker.cnHandle];
    if (onlyVisible && !CGRectContainsPoint(self.bounds, point)) {
      continue;
    }
    out[identifier] = @{
      @"point" : @{ @"x" : @(point.x), @"y" : @(point.y) },
      @"frame" : @{ @"x" : @(point.x), @"y" : @(point.y), @"width" : @(0), @"height" : @(0) },
    };
  }
  [self emitCommandResult:requestId data:out];
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

  CGPoint point = [_adapter pointForCoordinate:coordinate];

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
  auto emitter = [self eventEmitterOrNull];
  if (!emitter) {
    return;
  }

  CNRegion region = [_adapter currentRegion];

  if (complete) {
    RNMapsMapViewEventEmitter::OnRegionChangeComplete event = {
      .region.latitude = region.latitude,
      .region.longitude = region.longitude,
      .region.latitudeDelta = region.latitudeDelta,
      .region.longitudeDelta = region.longitudeDelta,
      .isGesture = static_cast<bool>(isGesture),
    };
    emitter->onRegionChangeComplete(event);
  } else {
    RNMapsMapViewEventEmitter::OnRegionChange event = {
      .region.latitude = region.latitude,
      .region.longitude = region.longitude,
      .region.latitudeDelta = region.latitudeDelta,
      .region.longitudeDelta = region.longitudeDelta,
      .isGesture = static_cast<bool>(isGesture),
    };
    emitter->onRegionChange(event);
  }
}

#pragma mark - Gesture handlers

- (void)handleLongPress:(UILongPressGestureRecognizer *)recognizer
{
  if (recognizer.state != UIGestureRecognizerStateBegan) {
    return;
  }
  CGPoint point = [recognizer locationInView:_adapter.mapView];
  [self emitPress:RNMapsPressKindLongPress atCoordinate:[_adapter coordinateForPoint:point]];
}

- (void)handleDoublePress:(UITapGestureRecognizer *)recognizer
{
  CGPoint point = [recognizer locationInView:_adapter.mapView];
  [self emitPress:RNMapsPressKindDoublePress atCoordinate:[_adapter coordinateForPoint:point]];
}

- (void)handlePanDrag:(UIPanGestureRecognizer *)recognizer
{
  if (recognizer.state != UIGestureRecognizerStateChanged) {
    return;
  }
  CGPoint point = [recognizer locationInView:_adapter.mapView];
  [self emitPress:RNMapsPressKindPanDrag atCoordinate:[_adapter coordinateForPoint:point]];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  return YES;
}

#pragma mark - CNMapAdapterDelegate

- (void)mapAdapterDidBecomeReady:(id<CNMapAdapter>)adapter
{
  auto emitter = [self eventEmitterOrNull];
  if (!emitter) {
    return;
  }
  // The provider exposes a single init-complete; surface it as both RNM lifecycle
  // events (map is ready and the tiles have loaded).
  emitter->onMapReady(RNMapsMapViewEventEmitter::OnMapReady{});
  emitter->onMapLoaded(RNMapsMapViewEventEmitter::OnMapLoaded{});
}

- (void)mapAdapter:(id<CNMapAdapter>)adapter didTapAtCoordinate:(CLLocationCoordinate2D)coordinate
{
  [self emitPress:RNMapsPressKindPress atCoordinate:coordinate];
}

- (void)mapAdapter:(id<CNMapAdapter>)adapter
    didChangeRegionComplete:(BOOL)complete
                  isGesture:(BOOL)isGesture
{
  [self emitRegionChangeComplete:complete isGesture:isGesture];
}

- (void)mapAdapter:(id<CNMapAdapter>)adapter didTapPoi:(CNPoi *)poi
{
  auto emitter = [self eventEmitterOrNull];
  if (!emitter) {
    return;
  }
  CGPoint point = [_adapter pointForCoordinate:poi.coordinate];
  RNMapsMapViewEventEmitter::OnPoiClick event{};
  event.placeId = RNMapsStdStringFromNSString(poi.placeId);
  event.name = RNMapsStdStringFromNSString(poi.name);
  event.coordinate.latitude = poi.coordinate.latitude;
  event.coordinate.longitude = poi.coordinate.longitude;
  event.position.x = point.x;
  event.position.y = point.y;
  emitter->onPoiClick(event);
}

- (void)mapAdapter:(id<CNMapAdapter>)adapter didUpdateUserLocation:(CLLocation *)location
{
  auto emitter = [self eventEmitterOrNull];
  if (!emitter) {
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

- (void)mapAdapter:(id<CNMapAdapter>)adapter
       markerChildId:(NSString *)childId
       didFireEvent:(CNMarkerEventKind)event
         atCoordinate:(CLLocationCoordinate2D)coordinate
{
  id child = _childrenById[childId];
  if ([child isKindOfClass:[RNMapsMarker class]]) {
    [(RNMapsMarker *)child emitAdapterEvent:event atCoordinate:coordinate];
  }
}

@end
