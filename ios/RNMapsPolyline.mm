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

// Parse a JSON array of CSS hex color strings ("#rgb"/"#rrggbb"/"#aarrggbb") into
// UIColors for the gradient stroke; nil/invalid entries are skipped.
static NSArray<UIColor *> *RNMapsParseStrokeColors(NSString *_Nullable json)
{
  if (json.length == 0) {
    return @[];
  }
  NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
  id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (![parsed isKindOfClass:[NSArray class]]) {
    return @[];
  }
  NSMutableArray<UIColor *> *colors = [NSMutableArray array];
  for (id entry in (NSArray *)parsed) {
    if (![entry isKindOfClass:[NSString class]]) {
      continue;
    }
    NSString *hex = [(NSString *)entry stringByTrimmingCharactersInSet:
      [NSCharacterSet characterSetWithCharactersInString:@"#"]];
    unsigned int value = 0;
    if (![[NSScanner scannerWithString:hex] scanHexInt:&value]) {
      continue;
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
    [colors addObject:[UIColor colorWithRed:r green:g blue:b alpha:a]];
  }
  return colors;
}

@interface RNMapsPolyline () <RCTRNMapsPolylineViewProtocol>
@end

@implementation RNMapsPolyline
@synthesize cnChildId = _cnChildId;
@synthesize cnHandle = _cnHandle;
@synthesize mapHost = _mapHost;

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNMapsPolylineComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNMapsPolylineProps>();
    _props = defaultProps;
  }
  return self;
}

- (CNOverlayModel *)overlayModel
{
  const auto &p = *std::static_pointer_cast<RNMapsPolylineProps const>(_props);
  CNPolylineModel *model = [CNPolylineModel new];
  model.type = CNOverlayTypePolyline;
  NSMutableArray<NSValue *> *coordinates = [NSMutableArray arrayWithCapacity:p.coordinates.size()];
  for (const auto &c : p.coordinates) {
    [coordinates addObject:CNBoxCoordinate(CLLocationCoordinate2DMake(c.latitude, c.longitude))];
  }
  model.coordinates = coordinates;
  model.strokeColor = RCTUIColorFromSharedColor(p.strokeColor) ?: [UIColor blackColor];
  model.strokeColors = RNMapsParseStrokeColors(RNMapsPolylineNSString(p.strokeColors));
  model.strokeWidth = p.strokeWidth;
  model.lineDashPattern = RNMapsParseDashPattern(RNMapsPolylineNSString(p.lineDashPattern));
  model.lineCap = RNMapsPolylineNSString(p.lineCap);
  model.lineJoin = RNMapsPolylineNSString(p.lineJoin);
  model.miterLimit = p.miterLimit;
  return model;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  [super updateProps:props oldProps:oldProps];
  [self.mapHost childDidUpdateModel:self];
}

@end
