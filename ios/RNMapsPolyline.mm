#import "RNMapsPolyline.h"

#import <React/RCTConversions.h>

#import <react/renderer/components/RNMapsSpecs/ComponentDescriptors.h>
#import <react/renderer/components/RNMapsSpecs/EventEmitters.h>
#import <react/renderer/components/RNMapsSpecs/Props.h>
#import <react/renderer/components/RNMapsSpecs/RCTComponentViewHelpers.h>

#include <vector>

using namespace facebook::react;

static NSString *RNMapsPolylineNSString(const std::string &value)
{
  return value.empty() ? nil : [NSString stringWithUTF8String:value.c_str()];
}

@interface RNMapsPolyline () <RCTRNMapsPolylineViewProtocol>
@end

@implementation RNMapsPolyline {
  __weak MAMapView *_map;
  MAPolyline *_polyline;
  UIColor *_strokeColor;
  CGFloat _strokeWidth;
  NSArray<NSNumber *> *_lineDashPattern;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNMapsPolylineComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNMapsPolylineProps>();
    _props = defaultProps;
    _strokeColor = [UIColor blackColor];
    _strokeWidth = 1;
  }
  return self;
}

- (id<MAOverlay>)overlay
{
  return _polyline;
}

- (void)addToMap:(MAMapView *)map
{
  _map = map;
  if (_polyline != nil) {
    [map addOverlay:_polyline];
  }
}

- (void)removeFromMap
{
  if (_map != nil && _polyline != nil) {
    [_map removeOverlay:_polyline];
  }
  _map = nil;
}

- (MAOverlayRenderer *)overlayRenderer
{
  MAPolylineRenderer *renderer = [[MAPolylineRenderer alloc] initWithPolyline:_polyline];
  renderer.strokeColor = _strokeColor;
  renderer.lineWidth = _strokeWidth;
  if (_lineDashPattern.count > 0) {
    renderer.lineDashType = kMALineDashTypeSquare;
  }
  return renderer;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &oldViewProps = *std::static_pointer_cast<RNMapsPolylineProps const>(oldProps);
  const auto &newViewProps = *std::static_pointer_cast<RNMapsPolylineProps const>(props);

  _strokeColor = RCTUIColorFromSharedColor(newViewProps.strokeColor) ?: [UIColor blackColor];
  _strokeWidth = newViewProps.strokeWidth;
  _lineDashPattern = RNMapsParseDashPattern(RNMapsPolylineNSString(newViewProps.lineDashPattern));

  BOOL coordinatesChanged =
    !RNMapsCoordinatesEqual(oldViewProps.coordinates, newViewProps.coordinates);

  MAPolyline *previous = _polyline;
  if (_polyline == nil || coordinatesChanged) {
    _polyline = [self buildPolyline:newViewProps.coordinates];
  }

  // Re-add to force the map to rebuild the renderer with the latest styling.
  if (_map != nil) {
    if (previous != nil) {
      [_map removeOverlay:previous];
    }
    if (_polyline != nil) {
      [_map addOverlay:_polyline];
    }
  }

  [super updateProps:props oldProps:oldProps];
}

- (MAPolyline *)buildPolyline:(const std::vector<RNMapsPolylineCoordinatesStruct> &)coordinates
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
  return [MAPolyline polylineWithCoordinates:points.data() count:count];
}

@end
