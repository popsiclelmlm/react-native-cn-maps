#import "RNMapsPolygon.h"

#import <React/RCTConversions.h>

#import <react/renderer/components/RNMapsSpecs/ComponentDescriptors.h>
#import <react/renderer/components/RNMapsSpecs/EventEmitters.h>
#import <react/renderer/components/RNMapsSpecs/Props.h>
#import <react/renderer/components/RNMapsSpecs/RCTComponentViewHelpers.h>

using namespace facebook::react;

static NSString *RNMapsPolygonNSString(const std::string &value)
{
  return value.empty() ? nil : [NSString stringWithUTF8String:value.c_str()];
}

// Parse the JSON string of LatLng[][] into boxed-coordinate rings for the model.
static NSArray<NSArray<NSValue *> *> *RNMapsParseHoles(NSString *json)
{
  if (json.length == 0) {
    return nil;
  }
  NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
  id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (![parsed isKindOfClass:[NSArray class]]) {
    return nil;
  }
  NSMutableArray<NSArray<NSValue *> *> *holes = [NSMutableArray array];
  for (id ring in (NSArray *)parsed) {
    if (![ring isKindOfClass:[NSArray class]]) {
      continue;
    }
    NSMutableArray<NSValue *> *points = [NSMutableArray array];
    for (id point in (NSArray *)ring) {
      if (![point isKindOfClass:[NSDictionary class]]) {
        continue;
      }
      CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(
        [point[@"latitude"] doubleValue], [point[@"longitude"] doubleValue]);
      [points addObject:CNBoxCoordinate(coordinate)];
    }
    if (points.count > 0) {
      [holes addObject:points];
    }
  }
  return holes.count > 0 ? holes : nil;
}

@interface RNMapsPolygon () <RCTRNMapsPolygonViewProtocol>
@end

@implementation RNMapsPolygon
@synthesize cnChildId = _cnChildId;
@synthesize cnHandle = _cnHandle;
@synthesize mapHost = _mapHost;

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNMapsPolygonComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNMapsPolygonProps>();
    _props = defaultProps;
  }
  return self;
}

- (CNOverlayModel *)overlayModel
{
  const auto &p = *std::static_pointer_cast<RNMapsPolygonProps const>(_props);
  CNPolygonModel *model = [CNPolygonModel new];
  model.type = CNOverlayTypePolygon;
  NSMutableArray<NSValue *> *coordinates = [NSMutableArray arrayWithCapacity:p.coordinates.size()];
  for (const auto &c : p.coordinates) {
    [coordinates addObject:CNBoxCoordinate(CLLocationCoordinate2DMake(c.latitude, c.longitude))];
  }
  model.coordinates = coordinates;
  model.holes = RNMapsParseHoles(RNMapsPolygonNSString(p.holes));
  model.strokeColor = RCTUIColorFromSharedColor(p.strokeColor) ?: [UIColor blackColor];
  model.fillColor = RCTUIColorFromSharedColor(p.fillColor) ?: [UIColor colorWithWhite:0 alpha:0.25];
  model.strokeWidth = p.strokeWidth;
  return model;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  [super updateProps:props oldProps:oldProps];
  [self.mapHost childDidUpdateModel:self];
}

@end
