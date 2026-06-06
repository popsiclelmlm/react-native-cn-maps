#import "RNMapsPolygon.h"

#import <React/RCTConversions.h>

#import <react/renderer/components/RNMapsSpecs/ComponentDescriptors.h>
#import <react/renderer/components/RNMapsSpecs/EventEmitters.h>
#import <react/renderer/components/RNMapsSpecs/Props.h>
#import <react/renderer/components/RNMapsSpecs/RCTComponentViewHelpers.h>

#include <vector>

using namespace facebook::react;

static NSString *RNMapsPolygonNSString(const std::string &value)
{
  return value.empty() ? nil : [NSString stringWithUTF8String:value.c_str()];
}

// Build interior hole polygons from the JSON string of LatLng[][].
static NSArray<MAPolygon *> *RNMapsParseHoles(NSString *json)
{
  if (json.length == 0) {
    return nil;
  }
  NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
  id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (![parsed isKindOfClass:[NSArray class]]) {
    return nil;
  }

  NSMutableArray<MAPolygon *> *holes = [NSMutableArray array];
  for (id ring in (NSArray *)parsed) {
    if (![ring isKindOfClass:[NSArray class]]) {
      continue;
    }
    std::vector<CLLocationCoordinate2D> points;
    for (id point in (NSArray *)ring) {
      if (![point isKindOfClass:[NSDictionary class]]) {
        continue;
      }
      double lat = [point[@"latitude"] doubleValue];
      double lng = [point[@"longitude"] doubleValue];
      points.push_back(CLLocationCoordinate2DMake(lat, lng));
    }
    if (!points.empty()) {
      [holes addObject:[MAPolygon polygonWithCoordinates:points.data() count:points.size()]];
    }
  }
  return holes.count > 0 ? holes : nil;
}

@interface RNMapsPolygon () <RCTRNMapsPolygonViewProtocol>
@end

@implementation RNMapsPolygon {
  __weak MAMapView *_map;
  MAPolygon *_polygon;
  UIColor *_strokeColor;
  UIColor *_fillColor;
  CGFloat _strokeWidth;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNMapsPolygonComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNMapsPolygonProps>();
    _props = defaultProps;
    _strokeColor = [UIColor blackColor];
    _fillColor = [UIColor colorWithWhite:0 alpha:0.25];
    _strokeWidth = 1;
  }
  return self;
}

- (id<MAOverlay>)overlay
{
  return _polygon;
}

- (void)addToMap:(MAMapView *)map
{
  _map = map;
  if (_polygon != nil) {
    [map addOverlay:_polygon];
  }
}

- (void)removeFromMap
{
  if (_map != nil && _polygon != nil) {
    [_map removeOverlay:_polygon];
  }
  _map = nil;
}

- (MAOverlayRenderer *)overlayRenderer
{
  MAPolygonRenderer *renderer = [[MAPolygonRenderer alloc] initWithPolygon:_polygon];
  renderer.strokeColor = _strokeColor;
  renderer.fillColor = _fillColor;
  renderer.lineWidth = _strokeWidth;
  return renderer;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  // Use `_props`, not `oldProps`: the parameter is nullptr on the first
  // updateProps and dereferencing it crashes. `_props` is always valid.
  const auto &oldViewProps = *std::static_pointer_cast<RNMapsPolygonProps const>(_props);
  const auto &newViewProps = *std::static_pointer_cast<RNMapsPolygonProps const>(props);

  _strokeColor = RCTUIColorFromSharedColor(newViewProps.strokeColor) ?: [UIColor blackColor];
  _fillColor = RCTUIColorFromSharedColor(newViewProps.fillColor) ?: [UIColor colorWithWhite:0 alpha:0.25];
  _strokeWidth = newViewProps.strokeWidth;

  BOOL geometryChanged =
    !RNMapsCoordinatesEqual(oldViewProps.coordinates, newViewProps.coordinates) ||
    oldViewProps.holes != newViewProps.holes;

  MAPolygon *previous = _polygon;
  if (_polygon == nil || geometryChanged) {
    _polygon = [self buildPolygon:newViewProps.coordinates
                            holes:RNMapsPolygonNSString(newViewProps.holes)];
  }

  if (_map != nil) {
    if (previous != nil) {
      [_map removeOverlay:previous];
    }
    if (_polygon != nil) {
      [_map addOverlay:_polygon];
    }
  }

  [super updateProps:props oldProps:oldProps];
}

- (MAPolygon *)buildPolygon:(const std::vector<RNMapsPolygonCoordinatesStruct> &)coordinates
                      holes:(NSString *)holesJson
{
  NSUInteger count = coordinates.size();
  if (count == 0) {
    return nil;
  }

  std::vector<CLLocationCoordinate2D> points;
  points.reserve(count);
  for (const auto &c : coordinates) {
    points.push_back(CLLocationCoordinate2DMake(c.latitude, c.longitude));
  }

  MAPolygon *polygon = [MAPolygon polygonWithCoordinates:points.data() count:count];

  // AMap renders holes via the `hollowShapes` property (members must be
  // MAPolygon/MACircle), not via a MapKit-style `interiorPolygons:` factory.
  NSArray<MAPolygon *> *holes = RNMapsParseHoles(holesJson);
  if (holes != nil) {
    polygon.hollowShapes = holes;
  }
  return polygon;
}

@end
