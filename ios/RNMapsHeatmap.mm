#import "RNMapsHeatmap.h"

#import <react/renderer/components/RNMapsSpecs/ComponentDescriptors.h>
#import <react/renderer/components/RNMapsSpecs/EventEmitters.h>
#import <react/renderer/components/RNMapsSpecs/Props.h>
#import <react/renderer/components/RNMapsSpecs/RCTComponentViewHelpers.h>

using namespace facebook::react;

static UIColor *RNMapsHeatmapColor(NSString *hexString)
{
  NSString *hex = [hexString stringByTrimmingCharactersInSet:
    [NSCharacterSet characterSetWithCharactersInString:@"#"]];
  unsigned int value = 0;
  if (![[NSScanner scannerWithString:hex] scanHexInt:&value]) {
    return nil;
  }
  CGFloat a = 1, r, g, b;
  if (hex.length == 8) {
    a = ((value >> 24) & 0xFF) / 255.0;
    r = ((value >> 16) & 0xFF) / 255.0;
    g = ((value >> 8) & 0xFF) / 255.0;
    b = (value & 0xFF) / 255.0;
  } else {
    r = ((value >> 16) & 0xFF) / 255.0;
    g = ((value >> 8) & 0xFF) / 255.0;
    b = (value & 0xFF) / 255.0;
  }
  return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

static NSString *RNMapsHeatmapNSString(const std::string &value)
{
  return value.empty() ? nil : [NSString stringWithUTF8String:value.c_str()];
}

@interface RNMapsHeatmap () <RCTRNMapsHeatmapViewProtocol>
@end

@implementation RNMapsHeatmap {
  __weak MAMapView *_map;
  MAHeatMapTileOverlay *_overlay;
  NSInteger _radius;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNMapsHeatmapComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNMapsHeatmapProps>();
    _props = defaultProps;
    _radius = 20;
  }
  return self;
}

- (id<MAOverlay>)overlay
{
  return _overlay;
}

- (void)addToMap:(MAMapView *)map
{
  _map = map;
  if (_overlay != nil) {
    [map addOverlay:_overlay];
  }
}

- (void)removeFromMap
{
  if (_map != nil && _overlay != nil) {
    [_map removeOverlay:_overlay];
  }
  _map = nil;
}

- (MAOverlayRenderer *)overlayRenderer
{
  return [[MATileOverlayRenderer alloc] initWithTileOverlay:_overlay];
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newViewProps = *std::static_pointer_cast<RNMapsHeatmapProps const>(props);

  _radius = newViewProps.radius > 0 ? newViewProps.radius : 20;

  NSArray<MAHeatMapNode *> *nodes =
    [self parseNodes:RNMapsHeatmapNSString(newViewProps.points)];
  MAHeatMapGradient *gradient =
    [self parseGradient:RNMapsHeatmapNSString(newViewProps.gradient)];

  MAHeatMapTileOverlay *previous = _overlay;
  if (nodes.count > 0) {
    MAHeatMapTileOverlay *overlay = [[MAHeatMapTileOverlay alloc] init];
    overlay.data = nodes;
    if (gradient != nil) {
      overlay.gradient = gradient;
    }
    _overlay = overlay;
  } else {
    _overlay = nil;
  }

  if (_map != nil) {
    if (previous != nil) {
      [_map removeOverlay:previous];
    }
    if (_overlay != nil) {
      [_map addOverlay:_overlay];
    }
  }

  [super updateProps:props oldProps:oldProps];
}

- (NSArray<MAHeatMapNode *> *)parseNodes:(NSString *)json
{
  if (json.length == 0) {
    return @[];
  }
  NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
  id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (![parsed isKindOfClass:[NSArray class]]) {
    return @[];
  }
  NSMutableArray<MAHeatMapNode *> *nodes = [NSMutableArray array];
  for (id entry in (NSArray *)parsed) {
    if (![entry isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    NSDictionary *dict = (NSDictionary *)entry;
    MAHeatMapNode *node = [[MAHeatMapNode alloc] init];
    node.coordinate = CLLocationCoordinate2DMake(
      [dict[@"latitude"] doubleValue], [dict[@"longitude"] doubleValue]);
    node.intensity = dict[@"weight"] ? [dict[@"weight"] floatValue] : 1.0;
    node.radius = (NSUInteger)_radius;
    [nodes addObject:node];
  }
  return nodes;
}

- (MAHeatMapGradient *)parseGradient:(NSString *)json
{
  if (json.length == 0) {
    return nil;
  }
  NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
  id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (![parsed isKindOfClass:[NSDictionary class]]) {
    return nil;
  }
  NSDictionary *dict = (NSDictionary *)parsed;
  NSArray *colorStrings = dict[@"colors"];
  NSArray *startPoints = dict[@"startPoints"];
  if (![colorStrings isKindOfClass:[NSArray class]] ||
      ![startPoints isKindOfClass:[NSArray class]] ||
      colorStrings.count == 0 || colorStrings.count != startPoints.count) {
    return nil;
  }
  NSMutableArray<UIColor *> *colors = [NSMutableArray array];
  for (id c in colorStrings) {
    UIColor *color = [c isKindOfClass:[NSString class]] ? RNMapsHeatmapColor(c) : nil;
    [colors addObject:color ?: [UIColor clearColor]];
  }
  NSUInteger size = dict[@"colorMapSize"] ? [dict[@"colorMapSize"] unsignedIntegerValue] : 256;
  return [[MAHeatMapGradient alloc] initWithColor:colors
                               andWithStartPoints:startPoints
                                      colorMapSize:size];
}

@end
