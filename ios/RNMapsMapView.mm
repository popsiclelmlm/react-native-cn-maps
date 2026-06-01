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

using namespace facebook::react;

@interface RNMapsMarkerAnnotation : MAPointAnnotation
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy, nullable) NSString *pinColor;
@property (nonatomic, assign) BOOL draggable;
@end

@implementation RNMapsMarkerAnnotation
@end

@interface RNMapsMapView () <MAMapViewDelegate, RCTRNMapsMapViewViewProtocol>
@end

static NSString *RNMapsNSStringFromString(const std::string &value)
{
  if (value.empty()) {
    return nil;
  }

  return [NSString stringWithUTF8String:value.c_str()];
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
  }

  return self;
}

- (void)prepareForRecycle
{
  [super prepareForRecycle];
  [_mapView removeAnnotations:_annotationsByIdentifier.allValues];
  [_annotationsByIdentifier removeAllObjects];
  _initialRegionApplied = NO;
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

  if (!_initialRegionApplied && RNMapsRegionIsValid(newViewProps.initialRegion)) {
    [_mapView setRegion:RNMapsMACoordinateRegionFromRegion(newViewProps.initialRegion) animated:NO];
    _initialRegionApplied = YES;
  }

  if (RNMapsRegionIsValid(newViewProps.region) && RNMapsRegionChanged(oldViewProps.region, newViewProps.region)) {
    [_mapView setRegion:RNMapsMACoordinateRegionFromRegion(newViewProps.region) animated:NO];
  }

  _mapView.showsUserLocation = newViewProps.showsUserLocation;
  _mapView.zoomEnabled = newViewProps.zoomEnabled;
  _mapView.scrollEnabled = newViewProps.scrollEnabled;
  _mapView.rotateEnabled = newViewProps.rotateEnabled;
  _mapView.rotateCameraEnabled = newViewProps.pitchEnabled;

  [self updateMarkers:newViewProps.markers];

  [super updateProps:props oldProps:oldProps];
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

- (void)emitRegionChangeComplete:(BOOL)complete isGesture:(BOOL)isGesture
{
  if (!_eventEmitter) {
    return;
  }

  MACoordinateRegion region = _mapView.region;
  auto mapViewEventEmitter = std::static_pointer_cast<RNMapsMapViewEventEmitter const>(_eventEmitter);

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
  if (!_eventEmitter || ![view.annotation isKindOfClass:[RNMapsMarkerAnnotation class]]) {
    return;
  }

  RNMapsMarkerAnnotation *marker = (RNMapsMarkerAnnotation *)view.annotation;
  auto mapViewEventEmitter = std::static_pointer_cast<RNMapsMapViewEventEmitter const>(_eventEmitter);
  RNMapsMapViewEventEmitter::OnMarkerPress event = {
    .identifier = std::string([marker.identifier UTF8String]),
    .coordinate.latitude = marker.coordinate.latitude,
    .coordinate.longitude = marker.coordinate.longitude,
  };
  mapViewEventEmitter->onMarkerPress(event);
}

@end
