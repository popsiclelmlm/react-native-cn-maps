#import "RNMapsImageOverlay.h"

#import <react/renderer/components/RNMapsSpecs/ComponentDescriptors.h>
#import <react/renderer/components/RNMapsSpecs/EventEmitters.h>
#import <react/renderer/components/RNMapsSpecs/Props.h>
#import <react/renderer/components/RNMapsSpecs/RCTComponentViewHelpers.h>

using namespace facebook::react;

// Best-effort, dependency-free image loading (schemed URLs load async; a bare
// string falls back to a bundled image name). Completion runs on the main queue.
static void RNMapsLoadOverlayImage(NSString *uri, void (^completion)(UIImage *_Nullable))
{
  if (uri.length == 0) {
    completion(nil);
    return;
  }
  NSURL *url = [NSURL URLWithString:uri];
  if (url != nil && url.scheme.length > 0) {
    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
      dataTaskWithURL:url
      completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = (data != nil && error == nil) ? [UIImage imageWithData:data] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(image); });
      }];
    [task resume];
  } else {
    UIImage *image = [UIImage imageNamed:uri];
    dispatch_async(dispatch_get_main_queue(), ^{ completion(image); });
  }
}

@interface RNMapsOverlay () <RCTRNMapsOverlayViewProtocol>
@end

@implementation RNMapsOverlay {
  NSString *_imageUri;
  UIImage *_image;
}
@synthesize cnChildId = _cnChildId;
@synthesize cnHandle = _cnHandle;
@synthesize mapHost = _mapHost;

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNMapsOverlayComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNMapsOverlayProps>();
    _props = defaultProps;
  }
  return self;
}

- (CNOverlayModel *)overlayModel
{
  const auto &p = *std::static_pointer_cast<RNMapsOverlayProps const>(_props);
  CNGroundOverlayModel *model = [CNGroundOverlayModel new];
  model.type = CNOverlayTypeGroundOverlay;
  model.southWest = CLLocationCoordinate2DMake(p.swLatitude, p.swLongitude);
  model.northEast = CLLocationCoordinate2DMake(p.neLatitude, p.neLongitude);
  model.opacity = p.opacity;
  model.image = _image;
  return model;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newViewProps = *std::static_pointer_cast<RNMapsOverlayProps const>(props);

  NSString *imageUri = newViewProps.image.empty()
    ? nil
    : [NSString stringWithUTF8String:newViewProps.image.c_str()];

  [super updateProps:props oldProps:oldProps];

  if (![imageUri isEqualToString:_imageUri]) {
    _imageUri = imageUri;
    __weak RNMapsOverlay *weakSelf = self;
    RNMapsLoadOverlayImage(imageUri, ^(UIImage *_Nullable image) {
      RNMapsOverlay *strongSelf = weakSelf;
      if (strongSelf == nil || ![imageUri isEqualToString:strongSelf->_imageUri]) {
        return;
      }
      strongSelf->_image = image;
      [strongSelf.mapHost childDidUpdateModel:strongSelf];
    });
  } else {
    [self.mapHost childDidUpdateModel:self];
  }
}

@end
