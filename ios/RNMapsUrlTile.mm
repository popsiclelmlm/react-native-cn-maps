#import "RNMapsUrlTile.h"

#import <react/renderer/components/RNMapsSpecs/ComponentDescriptors.h>
#import <react/renderer/components/RNMapsSpecs/EventEmitters.h>
#import <react/renderer/components/RNMapsSpecs/Props.h>
#import <react/renderer/components/RNMapsSpecs/RCTComponentViewHelpers.h>

using namespace facebook::react;

@interface RNMapsUrlTile () <RCTRNMapsUrlTileViewProtocol>
@end

@implementation RNMapsUrlTile {
  __weak MAMapView *_map;
  MATileOverlay *_tileOverlay;
  CGFloat _opacity;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNMapsUrlTileComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNMapsUrlTileProps>();
    _props = defaultProps;
    _opacity = 1;
  }
  return self;
}

- (id<MAOverlay>)overlay
{
  return _tileOverlay;
}

- (void)addToMap:(MAMapView *)map
{
  _map = map;
  if (_tileOverlay != nil) {
    [map addOverlay:_tileOverlay];
  }
}

- (void)removeFromMap
{
  if (_map != nil && _tileOverlay != nil) {
    [_map removeOverlay:_tileOverlay];
  }
  _map = nil;
}

- (MAOverlayRenderer *)overlayRenderer
{
  MATileOverlayRenderer *renderer =
    [[MATileOverlayRenderer alloc] initWithTileOverlay:_tileOverlay];
  renderer.alpha = _opacity;
  return renderer;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newViewProps = *std::static_pointer_cast<RNMapsUrlTileProps const>(props);

  _opacity = newViewProps.opacity;

  NSString *urlTemplate = newViewProps.urlTemplate.empty()
    ? nil
    : [NSString stringWithUTF8String:newViewProps.urlTemplate.c_str()];

  MATileOverlay *previous = _tileOverlay;
  if (urlTemplate != nil) {
    MATileOverlay *overlay = [[MATileOverlay alloc] initWithURLTemplate:urlTemplate];
    overlay.minimumZ = newViewProps.minimumZ;
    overlay.maximumZ = newViewProps.maximumZ;
    NSInteger size = newViewProps.doubleTileSize
      ? 512
      : (newViewProps.tileSize > 0 ? newViewProps.tileSize : 256);
    overlay.tileSize = CGSizeMake(size, size);
    _tileOverlay = overlay;
  } else {
    _tileOverlay = nil;
  }

  // Re-add so the map rebuilds the renderer with the latest tile overlay.
  if (_map != nil) {
    if (previous != nil) {
      [_map removeOverlay:previous];
    }
    if (_tileOverlay != nil) {
      [_map addOverlay:_tileOverlay];
    }
  }

  [super updateProps:props oldProps:oldProps];
}

@end
