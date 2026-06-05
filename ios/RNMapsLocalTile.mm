#import "RNMapsLocalTile.h"

#import <react/renderer/components/RNMapsSpecs/ComponentDescriptors.h>
#import <react/renderer/components/RNMapsSpecs/EventEmitters.h>
#import <react/renderer/components/RNMapsSpecs/Props.h>
#import <react/renderer/components/RNMapsSpecs/RCTComponentViewHelpers.h>

using namespace facebook::react;

// MATileOverlay subclass that loads tiles from local files via a {x}/{y}/{z}
// path template instead of the network.
@interface RNMapsLocalTileOverlay : MATileOverlay
@property (nonatomic, copy, nullable) NSString *pathTemplate;
@end

@implementation RNMapsLocalTileOverlay
- (void)loadTileAtPath:(MATileOverlayPath)path
                result:(void (^)(NSData *_Nullable, NSError *_Nullable))result
{
  if (self.pathTemplate == nil) {
    result(nil, nil);
    return;
  }
  NSString *file = self.pathTemplate;
  file = [file stringByReplacingOccurrencesOfString:@"{x}"
                                         withString:[@(path.x) stringValue]];
  file = [file stringByReplacingOccurrencesOfString:@"{y}"
                                         withString:[@(path.y) stringValue]];
  file = [file stringByReplacingOccurrencesOfString:@"{z}"
                                         withString:[@(path.z) stringValue]];
  result([NSData dataWithContentsOfFile:file], nil);
}
@end

@interface RNMapsLocalTile () <RCTRNMapsLocalTileViewProtocol>
@end

@implementation RNMapsLocalTile {
  __weak MAMapView *_map;
  RNMapsLocalTileOverlay *_tileOverlay;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNMapsLocalTileComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNMapsLocalTileProps>();
    _props = defaultProps;
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
  return [[MATileOverlayRenderer alloc] initWithTileOverlay:_tileOverlay];
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newViewProps = *std::static_pointer_cast<RNMapsLocalTileProps const>(props);

  NSString *pathTemplate = newViewProps.pathTemplate.empty()
    ? nil
    : [NSString stringWithUTF8String:newViewProps.pathTemplate.c_str()];

  RNMapsLocalTileOverlay *previous = _tileOverlay;
  if (pathTemplate != nil) {
    RNMapsLocalTileOverlay *overlay = [[RNMapsLocalTileOverlay alloc] init];
    overlay.pathTemplate = pathTemplate;
    NSInteger size = newViewProps.tileSize > 0 ? newViewProps.tileSize : 256;
    overlay.tileSize = CGSizeMake(size, size);
    _tileOverlay = overlay;
  } else {
    _tileOverlay = nil;
  }

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
