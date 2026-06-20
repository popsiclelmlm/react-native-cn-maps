#import "RNMapsCircle.h"

#import <React/RCTConversions.h>

#import <react/renderer/components/RNMapsSpecs/ComponentDescriptors.h>
#import <react/renderer/components/RNMapsSpecs/EventEmitters.h>
#import <react/renderer/components/RNMapsSpecs/Props.h>
#import <react/renderer/components/RNMapsSpecs/RCTComponentViewHelpers.h>

using namespace facebook::react;

@interface RNMapsCircle () <RCTRNMapsCircleViewProtocol>
@end

@implementation RNMapsCircle
@synthesize cnChildId = _cnChildId;
@synthesize cnHandle = _cnHandle;
@synthesize mapHost = _mapHost;

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNMapsCircleComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNMapsCircleProps>();
    _props = defaultProps;
  }
  return self;
}

- (CNOverlayModel *)overlayModel
{
  const auto &p = *std::static_pointer_cast<RNMapsCircleProps const>(_props);
  CNCircleModel *model = [CNCircleModel new];
  model.type = CNOverlayTypeCircle;
  model.center = CLLocationCoordinate2DMake(p.latitude, p.longitude);
  model.radius = p.radius;
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
