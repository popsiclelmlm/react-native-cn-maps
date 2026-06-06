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
  __weak MAMapView *_map;
  MAGroundOverlay *_overlay;
  NSString *_imageUri;
  UIImage *_image;
  MACoordinateBounds _bounds;
  CGFloat _opacity;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNMapsOverlayComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNMapsOverlayProps>();
    _props = defaultProps;
    _opacity = 1;
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
  MAGroundOverlayRenderer *renderer =
    [[MAGroundOverlayRenderer alloc] initWithGroundOverlay:_overlay];
  renderer.alpha = _opacity;
  return renderer;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newViewProps = *std::static_pointer_cast<RNMapsOverlayProps const>(props);

  _opacity = newViewProps.opacity;
  _bounds.southWest = CLLocationCoordinate2DMake(newViewProps.swLatitude, newViewProps.swLongitude);
  _bounds.northEast = CLLocationCoordinate2DMake(newViewProps.neLatitude, newViewProps.neLongitude);

  NSString *imageUri = newViewProps.image.empty()
    ? nil
    : [NSString stringWithUTF8String:newViewProps.image.c_str()];

  if (![imageUri isEqualToString:_imageUri]) {
    _imageUri = imageUri;
    __weak RNMapsOverlay *weakSelf = self;
    RNMapsLoadOverlayImage(imageUri, ^(UIImage *_Nullable image) {
      RNMapsOverlay *strongSelf = weakSelf;
      if (strongSelf == nil || ![imageUri isEqualToString:strongSelf->_imageUri]) {
        return;
      }
      strongSelf->_image = image;
      [strongSelf rebuildOverlay];
    });
  } else {
    [self rebuildOverlay];
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)rebuildOverlay
{
  MAGroundOverlay *previous = _overlay;
  if (_image != nil) {
    _overlay = [MAGroundOverlay groundOverlayWithBounds:_bounds icon:_image];
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
}

@end
