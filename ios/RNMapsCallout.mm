#import "RNMapsCallout.h"

#import <QuartzCore/QuartzCore.h>

#import <react/renderer/components/RNMapsSpecs/ComponentDescriptors.h>
#import <react/renderer/components/RNMapsSpecs/EventEmitters.h>
#import <react/renderer/components/RNMapsSpecs/Props.h>
#import <react/renderer/components/RNMapsSpecs/RCTComponentViewHelpers.h>

using namespace facebook::react;

@interface RNMapsCallout () <RCTRNMapsCalloutViewProtocol>
@end

@implementation RNMapsCallout

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNMapsCalloutComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNMapsCalloutProps>();
    _props = defaultProps;
  }

  return self;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newViewProps = *std::static_pointer_cast<RNMapsCalloutProps const>(props);
  _tooltip = newViewProps.tooltip;
  [super updateProps:props oldProps:oldProps];
  [_calloutOwner calloutContentChanged];
}

// The callout subtree is laid out by Fabric even though it never enters a window;
// re-rasterize through the owner once it has a real size.
- (void)layoutSubviews
{
  [super layoutSubviews];
  [_calloutOwner calloutContentChanged];
}

// Offscreen rasterization (the callout never enters a window): render the layer.
- (UIImage *)renderToImage
{
  CGSize size = self.bounds.size;
  if (size.width <= 0 || size.height <= 0) {
    return nil;
  }

  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *rendererContext) {
    [self.layer renderInContext:rendererContext.CGContext];
  }];
}

- (void)emitPress
{
  if (!_eventEmitter) {
    return;
  }

  auto emitter = std::static_pointer_cast<RNMapsCalloutEventEmitter const>(_eventEmitter);
  emitter->onPress(RNMapsCalloutEventEmitter::OnPress{});
}

@end
