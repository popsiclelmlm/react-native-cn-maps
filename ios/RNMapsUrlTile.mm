#import "RNMapsUrlTile.h"

#import <react/renderer/components/RNMapsSpecs/ComponentDescriptors.h>
#import <react/renderer/components/RNMapsSpecs/EventEmitters.h>
#import <react/renderer/components/RNMapsSpecs/Props.h>
#import <react/renderer/components/RNMapsSpecs/RCTComponentViewHelpers.h>

using namespace facebook::react;

// MATileOverlay subclass for WMS GetMap: substitutes the tile's EPSG:3857
// (Web Mercator) bbox into {minX}/{minY}/{maxX}/{maxY}/{width}/{height}.
@interface RNMapsWMSTileOverlay : MATileOverlay
@property (nonatomic, copy, nullable) NSString *wmsTemplate;
@end

@implementation RNMapsWMSTileOverlay
- (NSURL *)URLForTilePath:(MATileOverlayPath)path
{
  if (self.wmsTemplate == nil) {
    return nil;
  }
  double m = 20037508.342789244;
  double tileMeters = (2 * m) / (double)(1 << path.z);
  double minX = -m + path.x * tileMeters;
  double maxX = -m + (path.x + 1) * tileMeters;
  double maxY = m - path.y * tileMeters;
  double minY = m - (path.y + 1) * tileMeters;
  NSInteger size = (NSInteger)self.tileSize.width;
  NSString *url = self.wmsTemplate;
  url = [url stringByReplacingOccurrencesOfString:@"{minX}" withString:[@(minX) stringValue]];
  url = [url stringByReplacingOccurrencesOfString:@"{minY}" withString:[@(minY) stringValue]];
  url = [url stringByReplacingOccurrencesOfString:@"{maxX}" withString:[@(maxX) stringValue]];
  url = [url stringByReplacingOccurrencesOfString:@"{maxY}" withString:[@(maxY) stringValue]];
  url = [url stringByReplacingOccurrencesOfString:@"{width}" withString:[@(size) stringValue]];
  url = [url stringByReplacingOccurrencesOfString:@"{height}" withString:[@(size) stringValue]];
  return [NSURL URLWithString:url];
}
@end

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

  NSInteger size = newViewProps.doubleTileSize
    ? 512
    : (newViewProps.tileSize > 0 ? newViewProps.tileSize : 256);

  MATileOverlay *previous = _tileOverlay;
  if (urlTemplate != nil && newViewProps.wms) {
    RNMapsWMSTileOverlay *overlay = [[RNMapsWMSTileOverlay alloc] init];
    overlay.wmsTemplate = urlTemplate;
    overlay.minimumZ = newViewProps.minimumZ;
    overlay.maximumZ = newViewProps.maximumZ;
    overlay.tileSize = CGSizeMake(size, size);
    _tileOverlay = overlay;
  } else if (urlTemplate != nil) {
    MATileOverlay *overlay = [[MATileOverlay alloc] initWithURLTemplate:urlTemplate];
    overlay.minimumZ = newViewProps.minimumZ;
    overlay.maximumZ = newViewProps.maximumZ;
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
