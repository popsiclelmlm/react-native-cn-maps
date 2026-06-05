#import "RNMapsMarker.h"

#import <QuartzCore/QuartzCore.h>

#import <react/renderer/components/RNMapsSpecs/ComponentDescriptors.h>
#import <react/renderer/components/RNMapsSpecs/EventEmitters.h>
#import <react/renderer/components/RNMapsSpecs/Props.h>
#import <react/renderer/components/RNMapsSpecs/RCTComponentViewHelpers.h>

#include <cmath>
#include <string>

using namespace facebook::react;

@implementation RNMapsMarkerAnnotation

- (void)applyAppearanceToView:(MAAnnotationView *)view
{
  view.canShowCallout = YES;
  view.draggable = self.draggable;
  view.centerOffset = self.centerOffset;
  view.calloutOffset = self.calloutOffset;
  view.alpha = self.markerOpacity;
  // RNM rotation is clockwise degrees; UIKit's positive rotation is clockwise too
  // (y-axis points down), so the conversion is a straight degrees → radians.
  view.transform = CGAffineTransformMakeRotation(self.rotationDegrees * M_PI / 180.0);
  view.layer.zPosition = self.zIndex;
}

@end

@interface RNMapsMarker () <RCTRNMapsMarkerViewProtocol>
@end

static NSString *RNMapsMarkerNSStringFromString(const std::string &value)
{
  if (value.empty()) {
    return nil;
  }

  return [NSString stringWithUTF8String:value.c_str()];
}

// Best-effort, dependency-free image loading: schemed URLs (the Metro-served dev
// asset uri, remote https, file://) load asynchronously; a bare string falls
// back to a bundled image name. The completion always runs on the main queue.
static void RNMapsLoadMarkerImage(NSString *uri, void (^completion)(UIImage *_Nullable))
{
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

@implementation RNMapsMarker {
  __weak MAMapView *_map;
  NSString *_imageUri;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNMapsMarkerComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNMapsMarkerProps>();
    _props = defaultProps;

    _annotation = [RNMapsMarkerAnnotation new];
    _annotation.marker = self;
  }

  return self;
}

#pragma mark - Parent-driven map attachment

- (void)addToMap:(MAMapView *)map
{
  _map = map;
  [map addAnnotation:_annotation];
}

- (void)removeFromMap
{
  [_map removeAnnotation:_annotation];
  _map = nil;
}

// Rebuild the annotation view by re-adding the annotation, so pin↔image swaps and
// appearance changes both flow through the parent's viewForAnnotation: again.
// Only used for runtime updates — the initial mount applies props while detached.
- (void)reapplyOnMap
{
  if (_map == nil) {
    return;
  }

  MAMapView *map = _map;
  [map removeAnnotation:_annotation];
  [map addAnnotation:_annotation];
}

#pragma mark - Props

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &oldViewProps = *std::static_pointer_cast<RNMapsMarkerProps const>(oldProps);
  const auto &newViewProps = *std::static_pointer_cast<RNMapsMarkerProps const>(props);

  _annotation.identifier = RNMapsMarkerNSStringFromString(newViewProps.identifier);
  // Setting coordinate/title/subtitle is KVO-observed by MAMapView, so live
  // updates after the annotation is on the map reflect automatically.
  _annotation.coordinate = CLLocationCoordinate2DMake(newViewProps.latitude, newViewProps.longitude);
  _annotation.title = RNMapsMarkerNSStringFromString(newViewProps.title);
  _annotation.subtitle = RNMapsMarkerNSStringFromString(newViewProps.description);

  // Appearance. `anchor`/`flat` have no MAAnnotationView equivalent on iOS
  // (annotation views are billboarded and positioned via centerOffset), so they
  // are intentionally ignored here; centerOffset/calloutAnchor carry positioning.
  _annotation.pinColor = RNMapsMarkerNSStringFromString(newViewProps.pinColor);
  _annotation.draggable = newViewProps.draggable;
  _annotation.centerOffset = CGPointMake(newViewProps.centerOffset.x, newViewProps.centerOffset.y);
  _annotation.calloutOffset = CGPointMake(newViewProps.calloutAnchor.x, newViewProps.calloutAnchor.y);
  _annotation.markerOpacity = newViewProps.opacity;
  _annotation.rotationDegrees = newViewProps.rotation;
  _annotation.zIndex = newViewProps.zIndex;

  [self setImageUri:RNMapsMarkerNSStringFromString(newViewProps.image)];

  BOOL appearanceChanged =
    oldViewProps.pinColor != newViewProps.pinColor ||
    oldViewProps.draggable != newViewProps.draggable ||
    oldViewProps.centerOffset.x != newViewProps.centerOffset.x ||
    oldViewProps.centerOffset.y != newViewProps.centerOffset.y ||
    oldViewProps.calloutAnchor.x != newViewProps.calloutAnchor.x ||
    oldViewProps.calloutAnchor.y != newViewProps.calloutAnchor.y ||
    oldViewProps.opacity != newViewProps.opacity ||
    oldViewProps.rotation != newViewProps.rotation ||
    oldViewProps.zIndex != newViewProps.zIndex;

  // Image changes refresh through setImageUri's async completion; non-image
  // appearance changes refresh the live view here.
  if (_map != nil && appearanceChanged) {
    [self reapplyOnMap];
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)setImageUri:(NSString *)uri
{
  NSString *normalized = uri.length > 0 ? uri : nil;
  if ((normalized == nil && _imageUri == nil) || [normalized isEqualToString:_imageUri]) {
    return;
  }

  _imageUri = normalized;

  if (normalized == nil) {
    _annotation.image = nil;
    [self reapplyOnMap];
    return;
  }

  __weak RNMapsMarker *weakSelf = self;
  RNMapsLoadMarkerImage(normalized, ^(UIImage *image) {
    RNMapsMarker *strongSelf = weakSelf;
    // Ignore a stale load if the uri changed again before it resolved.
    if (strongSelf == nil || ![normalized isEqualToString:strongSelf->_imageUri]) {
      return;
    }

    strongSelf.annotation.image = image;
    [strongSelf reapplyOnMap];
  });
}

- (void)prepareForRecycle
{
  [self removeFromMap];
  _imageUri = nil;
  _annotation = [RNMapsMarkerAnnotation new];
  _annotation.marker = self;
  [super prepareForRecycle];
}

#pragma mark - Events

- (void)emitPress
{
  if (!_eventEmitter) {
    return;
  }

  auto emitter = std::static_pointer_cast<RNMapsMarkerEventEmitter const>(_eventEmitter);
  RNMapsMarkerEventEmitter::OnPress event{};
  event.coordinate.latitude = _annotation.coordinate.latitude;
  event.coordinate.longitude = _annotation.coordinate.longitude;
  emitter->onPress(event);
}

@end
