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

@implementation RNMapsHeatmap
@synthesize cnChildId = _cnChildId;
@synthesize cnHandle = _cnHandle;
@synthesize mapHost = _mapHost;

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNMapsHeatmapComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNMapsHeatmapProps>();
    _props = defaultProps;
  }
  return self;
}

- (CNOverlayModel *)overlayModel
{
  const auto &p = *std::static_pointer_cast<RNMapsHeatmapProps const>(_props);
  CNHeatmapModel *model = [CNHeatmapModel new];
  model.type = CNOverlayTypeHeatmap;
  model.radius = p.radius > 0 ? p.radius : 20;

  NSMutableArray<NSValue *> *points = [NSMutableArray array];
  NSMutableArray<NSNumber *> *weights = [NSMutableArray array];
  [self parsePoints:RNMapsHeatmapNSString(p.points) intoPoints:points weights:weights];
  model.points = points;
  model.weights = weights;

  NSMutableArray<UIColor *> *colors = [NSMutableArray array];
  NSMutableArray<NSNumber *> *startPoints = [NSMutableArray array];
  [self parseGradient:RNMapsHeatmapNSString(p.gradient) intoColors:colors startPoints:startPoints];
  model.gradientColors = colors;
  model.gradientStartPoints = startPoints;
  return model;
}

- (void)parsePoints:(NSString *)json
         intoPoints:(NSMutableArray<NSValue *> *)points
            weights:(NSMutableArray<NSNumber *> *)weights
{
  if (json.length == 0) {
    return;
  }
  NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
  id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (![parsed isKindOfClass:[NSArray class]]) {
    return;
  }
  for (id entry in (NSArray *)parsed) {
    if (![entry isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    NSDictionary *dict = (NSDictionary *)entry;
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(
      [dict[@"latitude"] doubleValue], [dict[@"longitude"] doubleValue]);
    [points addObject:CNBoxCoordinate(coordinate)];
    [weights addObject:dict[@"weight"] ? @([dict[@"weight"] floatValue]) : @(1.0)];
  }
}

- (void)parseGradient:(NSString *)json
           intoColors:(NSMutableArray<UIColor *> *)colors
          startPoints:(NSMutableArray<NSNumber *> *)startPoints
{
  if (json.length == 0) {
    return;
  }
  NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
  id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (![parsed isKindOfClass:[NSDictionary class]]) {
    return;
  }
  NSDictionary *dict = (NSDictionary *)parsed;
  NSArray *colorStrings = dict[@"colors"];
  NSArray *points = dict[@"startPoints"];
  if (![colorStrings isKindOfClass:[NSArray class]] ||
      ![points isKindOfClass:[NSArray class]] ||
      colorStrings.count == 0 || colorStrings.count != points.count) {
    return;
  }
  for (id c in colorStrings) {
    UIColor *color = [c isKindOfClass:[NSString class]] ? RNMapsHeatmapColor(c) : nil;
    [colors addObject:color ?: [UIColor clearColor]];
  }
  [startPoints addObjectsFromArray:points];
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  [super updateProps:props oldProps:oldProps];
  [self.mapHost childDidUpdateModel:self];
}

@end
