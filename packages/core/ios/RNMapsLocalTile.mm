#import "RNMapsLocalTile.h"

#import <react/renderer/components/RNMapsSpecs/ComponentDescriptors.h>
#import <react/renderer/components/RNMapsSpecs/EventEmitters.h>
#import <react/renderer/components/RNMapsSpecs/Props.h>
#import <react/renderer/components/RNMapsSpecs/RCTComponentViewHelpers.h>

using namespace facebook::react;

@interface RNMapsLocalTile () <RCTRNMapsLocalTileViewProtocol>
@end

@implementation RNMapsLocalTile
@synthesize cnChildId = _cnChildId;
@synthesize cnHandle = _cnHandle;
@synthesize mapHost = _mapHost;

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

- (CNOverlayModel *)overlayModel
{
  const auto &p = *std::static_pointer_cast<RNMapsLocalTileProps const>(_props);
  CNLocalTileModel *model = [CNLocalTileModel new];
  model.type = CNOverlayTypeLocalTile;
  model.pathTemplate = p.pathTemplate.empty()
    ? nil
    : [NSString stringWithUTF8String:p.pathTemplate.c_str()];
  model.tileSize = p.tileSize > 0 ? p.tileSize : 256;
  return model;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  [super updateProps:props oldProps:oldProps];
  [self.mapHost childDidUpdateModel:self];
}

@end
