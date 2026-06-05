#import "RNMapsCircle.h"

#import <React/RCTConversions.h>

#import <react/renderer/components/RNMapsSpecs/ComponentDescriptors.h>
#import <react/renderer/components/RNMapsSpecs/EventEmitters.h>
#import <react/renderer/components/RNMapsSpecs/Props.h>
#import <react/renderer/components/RNMapsSpecs/RCTComponentViewHelpers.h>

using namespace facebook::react;

@interface RNMapsCircle () <RCTRNMapsCircleViewProtocol>
@end

@implementation RNMapsCircle {
  __weak MAMapView *_map;
  MACircle *_circle;
  UIColor *_strokeColor;
  UIColor *_fillColor;
  CGFloat _strokeWidth;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNMapsCircleComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNMapsCircleProps>();
    _props = defaultProps;
    _strokeColor = [UIColor blackColor];
    _fillColor = [UIColor colorWithWhite:0 alpha:0.25];
    _strokeWidth = 1;
  }
  return self;
}

- (id<MAOverlay>)overlay
{
  return _circle;
}

- (void)addToMap:(MAMapView *)map
{
  _map = map;
  if (_circle != nil) {
    [map addOverlay:_circle];
  }
}

- (void)removeFromMap
{
  if (_map != nil && _circle != nil) {
    [_map removeOverlay:_circle];
  }
  _map = nil;
}

- (MAOverlayRenderer *)overlayRenderer
{
  MACircleRenderer *renderer = [[MACircleRenderer alloc] initWithCircle:_circle];
  renderer.strokeColor = _strokeColor;
  renderer.fillColor = _fillColor;
  renderer.lineWidth = _strokeWidth;
  return renderer;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &oldViewProps = *std::static_pointer_cast<RNMapsCircleProps const>(oldProps);
  const auto &newViewProps = *std::static_pointer_cast<RNMapsCircleProps const>(props);

  _strokeColor = RCTUIColorFromSharedColor(newViewProps.strokeColor) ?: [UIColor blackColor];
  _fillColor = RCTUIColorFromSharedColor(newViewProps.fillColor) ?: [UIColor colorWithWhite:0 alpha:0.25];
  _strokeWidth = newViewProps.strokeWidth;

  BOOL geometryChanged =
    oldViewProps.latitude != newViewProps.latitude ||
    oldViewProps.longitude != newViewProps.longitude ||
    oldViewProps.radius != newViewProps.radius;

  MACircle *previous = _circle;
  if (_circle == nil || geometryChanged) {
    _circle = [MACircle circleWithCenterCoordinate:CLLocationCoordinate2DMake(newViewProps.latitude, newViewProps.longitude)
                                            radius:newViewProps.radius];
  }

  if (_map != nil) {
    if (previous != nil) {
      [_map removeOverlay:previous];
    }
    if (_circle != nil) {
      [_map addOverlay:_circle];
    }
  }

  [super updateProps:props oldProps:oldProps];
}

@end
