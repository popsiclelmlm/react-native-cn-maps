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

// Parse a JSON array of CSS hex color strings ("#rgb"/"#rrggbb"/"#aarrggbb")
// into UIColors for the gradient stroke; nil/invalid entries are skipped.
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

static MALineCapType RNMapsLineCapType(NSString *_Nullable cap)
{
  if ([cap isEqualToString:@"round"]) {
    return kMALineCapRound;
  }
  if ([cap isEqualToString:@"square"]) {
    return kMALineCapSquare;
  }
  return kMALineCapButt;
}

static MALineJoinType RNMapsLineJoinType(NSString *_Nullable join)
{
  if ([join isEqualToString:@"round"]) {
    return kMALineJoinRound;
  }
  if ([join isEqualToString:@"bevel"]) {
    return kMALineJoinBevel;
  }
  return kMALineJoinMiter;
}

@implementation RNMapsPolyline {
  __weak MAMapView *_map;
  // MAShape (not MAPolyline) because a multi-colored line is a MAMultiPolyline,
  // which is a sibling of MAPolyline under MAMultiPoint — not a subclass.
  MAShape *_polyline;
  UIColor *_strokeColor;
  NSArray<UIColor *> *_strokeColors;
  CGFloat _strokeWidth;
  NSArray<NSNumber *> *_lineDashPattern;
  NSString *_lineCap;
  NSString *_lineJoin;
  CGFloat _miterLimit;
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
    _strokeColors = @[];
    _strokeWidth = 1;
    _miterLimit = 10;
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
  MAPolylineRenderer *renderer;
  if (_strokeColors.count > 1 &&
      [_polyline isKindOfClass:[MAMultiPolyline class]]) {
    MAMultiColoredPolylineRenderer *multi = [[MAMultiColoredPolylineRenderer alloc]
      initWithMultiPolyline:(MAMultiPolyline *)_polyline];
    multi.strokeColors = _strokeColors;
    multi.gradient = YES;
    renderer = multi;
  } else {
    renderer = [[MAPolylineRenderer alloc] initWithPolyline:(MAPolyline *)_polyline];
    renderer.strokeColor =
      _strokeColors.count == 1 ? _strokeColors.firstObject : _strokeColor;
  }
  renderer.lineWidth = _strokeWidth;
  renderer.miterLimit = _miterLimit;
  renderer.lineCapType = RNMapsLineCapType(_lineCap);
  renderer.lineJoinType = RNMapsLineJoinType(_lineJoin);
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
  _lineCap = RNMapsPolylineNSString(newViewProps.lineCap);
  _lineJoin = RNMapsPolylineNSString(newViewProps.lineJoin);
  _miterLimit = newViewProps.miterLimit;

  BOOL wasMultiColored = _strokeColors.count > 1;
  _strokeColors = RNMapsParseStrokeColors(RNMapsPolylineNSString(newViewProps.strokeColors));
  BOOL isMultiColored = _strokeColors.count > 1;

  BOOL coordinatesChanged =
    !RNMapsCoordinatesEqual(oldViewProps.coordinates, newViewProps.coordinates);

  MAShape *previous = _polyline;
  // Rebuild the overlay when geometry changes or when toggling between a plain
  // and a multi-colored polyline (different overlay classes).
  if (_polyline == nil || coordinatesChanged || wasMultiColored != isMultiColored) {
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

- (MAShape *)buildPolyline:(const std::vector<RNMapsPolylineCoordinatesStruct> &)coordinates
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
  if (_strokeColors.count > 1 && count >= 2) {
    // MAMultiPolyline carries a per-segment style index (count = segments =
    // points - 1). Spread the stroke colors evenly across the segments; the
    // MAMultiColoredPolylineRenderer interpolates between them when gradient=YES.
    NSUInteger segments = count - 1;
    NSUInteger numColors = _strokeColors.count;
    NSMutableArray<NSNumber *> *drawStyleIndexes = [NSMutableArray arrayWithCapacity:segments];
    for (NSUInteger i = 0; i < segments; i++) {
      NSUInteger idx = (i * numColors) / segments;
      if (idx >= numColors) {
        idx = numColors - 1;
      }
      [drawStyleIndexes addObject:@(idx)];
    }
    return [MAMultiPolyline polylineWithCoordinates:points.data()
                                              count:count
                                   drawStyleIndexes:drawStyleIndexes];
  }
  return [MAPolyline polylineWithCoordinates:points.data() count:count];
}

@end
