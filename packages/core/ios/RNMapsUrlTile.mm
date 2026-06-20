#import "RNMapsUrlTile.h"

#import <react/renderer/components/RNMapsSpecs/ComponentDescriptors.h>
#import <react/renderer/components/RNMapsSpecs/EventEmitters.h>
#import <react/renderer/components/RNMapsSpecs/Props.h>
#import <react/renderer/components/RNMapsSpecs/RCTComponentViewHelpers.h>

using namespace facebook::react;

@interface RNMapsUrlTile () <RCTRNMapsUrlTileViewProtocol>
@end

@implementation RNMapsUrlTile
@synthesize cnChildId = _cnChildId;
@synthesize cnHandle = _cnHandle;
@synthesize mapHost = _mapHost;

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNMapsUrlTileComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNMapsUrlTileProps>();
    _props = defaultProps;
  }
  return self;
}

- (CNOverlayModel *)overlayModel
{
  const auto &p = *std::static_pointer_cast<RNMapsUrlTileProps const>(_props);
  CNUrlTileModel *model = [CNUrlTileModel new];
  model.type = CNOverlayTypeUrlTile;
  model.urlTemplate = p.urlTemplate.empty()
    ? nil
    : [NSString stringWithUTF8String:p.urlTemplate.c_str()];
  model.wms = p.wms;
  model.minimumZ = p.minimumZ;
  model.maximumZ = p.maximumZ;
  model.tileSize = p.doubleTileSize ? 512 : (p.tileSize > 0 ? p.tileSize : 256);
  model.opacity = p.opacity;
  return model;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  [super updateProps:props oldProps:oldProps];
  [self.mapHost childDidUpdateModel:self];
}

@end
