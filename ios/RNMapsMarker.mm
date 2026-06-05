#import "RNMapsMarker.h"

#import <react/renderer/components/RNMapsSpecs/ComponentDescriptors.h>
#import <react/renderer/components/RNMapsSpecs/EventEmitters.h>
#import <react/renderer/components/RNMapsSpecs/Props.h>
#import <react/renderer/components/RNMapsSpecs/RCTComponentViewHelpers.h>

#include <string>

using namespace facebook::react;

@implementation RNMapsMarkerAnnotation
@end

@interface RNMapsMarker () <RCTRNMapsMarkerViewProtocol>
@end

static NSString *RNMapsMarkerNSStringFromString(const std::string &value)
{
  if (value.empty()) {
    return nil;
  }

  return [NSString stringWithUTF8String:value.c_str()];
}

@implementation RNMapsMarker {
  __weak MAMapView *_map;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNMapsMarkerComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNMapsMarkerProps>();
    _props = defaultProps;

    _annotation = [RNMapsMarkerAnnotation new];
    _annotation.marker = self;
  }

  return self;
}

#pragma mark - Parent-driven map attachment

- (void)addToMap:(MAMapView *)map
{
  _map = map;
  [map addAnnotation:_annotation];
}

- (void)removeFromMap
{
  [_map removeAnnotation:_annotation];
  _map = nil;
}

#pragma mark - Props

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newViewProps = *std::static_pointer_cast<RNMapsMarkerProps const>(props);

  _annotation.identifier = RNMapsMarkerNSStringFromString(newViewProps.identifier);
  // Setting coordinate/title/subtitle is KVO-observed by MAMapView, so live
  // updates after the annotation is on the map reflect automatically.
  _annotation.coordinate = CLLocationCoordinate2DMake(newViewProps.latitude, newViewProps.longitude);
  _annotation.title = RNMapsMarkerNSStringFromString(newViewProps.title);
  _annotation.subtitle = RNMapsMarkerNSStringFromString(newViewProps.description);
  _annotation.pinColor = RNMapsMarkerNSStringFromString(newViewProps.pinColor);
  _annotation.draggable = newViewProps.draggable;

  [super updateProps:props oldProps:oldProps];
}

- (void)prepareForRecycle
{
  [self removeFromMap];
  _annotation = [RNMapsMarkerAnnotation new];
  _annotation.marker = self;
  [super prepareForRecycle];
}

#pragma mark - Events

- (void)emitPress
{
  if (!_eventEmitter) {
    return;
  }

  auto emitter = std::static_pointer_cast<RNMapsMarkerEventEmitter const>(_eventEmitter);
  RNMapsMarkerEventEmitter::OnPress event{};
  event.coordinate.latitude = _annotation.coordinate.latitude;
  event.coordinate.longitude = _annotation.coordinate.longitude;
  emitter->onPress(event);
}

@end
