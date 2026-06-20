#import "RNMapsMarker.h"

#import <QuartzCore/QuartzCore.h>

#import <react/renderer/components/RNMapsSpecs/ComponentDescriptors.h>
#import <react/renderer/components/RNMapsSpecs/EventEmitters.h>
#import <react/renderer/components/RNMapsSpecs/Props.h>
#import <react/renderer/components/RNMapsSpecs/RCTComponentViewHelpers.h>

#include <string>

using namespace facebook::react;

@interface RNMapsMarker () <RCTRNMapsMarkerViewProtocol>
@end

static NSString *RNMapsMarkerNSString(const std::string &value)
{
  return value.empty() ? nil : [NSString stringWithUTF8String:value.c_str()];
}

// Best-effort, dependency-free image loading (provider-agnostic): schemed URLs
// load async; a bare string falls back to a bundled image name. Completion always
// runs on the main queue.
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
  NSString *_imageUri;
  UIImage *_propImage;     // resolved from the `image` prop
  UIImage *_renderedImage; // rasterized from custom React children
  UIImage *_calloutImage;  // rasterized from the custom <Callout> child
  NSInteger _childCount;
  BOOL _tracksViewChanges;
  BOOL _didRasterize;
  RNMapsCallout *_calloutView;
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
    _tracksViewChanges = YES;
  }
  return self;
}

#pragma mark - Model

- (CNMarkerModel *)markerModel
{
  const auto &p = *std::static_pointer_cast<RNMapsMarkerProps const>(_props);
  CNMarkerModel *model = [CNMarkerModel new];
  model.identifier = RNMapsMarkerNSString(p.identifier);
  model.coordinate = CLLocationCoordinate2DMake(p.latitude, p.longitude);
  model.title = RNMapsMarkerNSString(p.title);
  model.subtitle = RNMapsMarkerNSString(p.description);
  model.pinColor = RNMapsMarkerNSString(p.pinColor);
  model.draggable = p.draggable;
  // Custom children win over the `image` prop, which wins over the default pin.
  model.image = [self hasCustomContent] ? _renderedImage : _propImage;
  model.centerOffset = CGPointMake(p.centerOffset.x, p.centerOffset.y);
  model.calloutOffset = CGPointMake(p.calloutAnchor.x, p.calloutAnchor.y);
  model.opacity = p.opacity;
  model.rotationDegrees = p.rotation;
  model.zIndex = p.overlayZIndex;
  model.hasCustomCallout = _calloutView != nil;
  model.calloutImage = _calloutImage;
  return model;
}

- (void)notifyHost
{
  [self.mapHost childDidUpdateModel:self];
}

#pragma mark - Custom React content

// Marker children DO render (offscreen): they are mounted as real subviews of this
// orphan view (never added to the map's UIView tree), then rasterized into the
// marker image. A <Callout> child is intercepted: it is kept out of the icon
// rasterization and shown separately on selection.
- (void)mountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView index:(NSInteger)index
{
  if ([childComponentView isKindOfClass:[RNMapsCallout class]]) {
    _calloutView = (RNMapsCallout *)childComponentView;
    _calloutView.calloutOwner = self;
    [self calloutContentChanged];
    [self notifyHost];
    return;
  }

  [super mountChildComponentView:childComponentView index:index];
  _childCount += 1;
  _didRasterize = NO;
  [self setNeedsLayout];
}

- (void)unmountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView index:(NSInteger)index
{
  if (childComponentView == _calloutView) {
    _calloutView.calloutOwner = nil;
    _calloutView = nil;
    _calloutImage = nil;
    [self notifyHost];
    return;
  }

  [super unmountChildComponentView:childComponentView index:index];
  _childCount = MAX((NSInteger)0, _childCount - 1);
  if (_childCount == 0) {
    _renderedImage = nil;
    _didRasterize = NO;
    [self notifyHost];
  }
}

- (BOOL)hasCustomContent
{
  return _childCount > 0;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  if ([self hasCustomContent] && (_tracksViewChanges || !_didRasterize)) {
    [self renderToImage];
  }
}

// Offscreen rasterization: the view is not in a window, so render its layer into an
// image context rather than -drawViewHierarchyInRect: (unreliable here).
- (void)renderToImage
{
  CGSize size = self.bounds.size;
  if (size.width <= 0 || size.height <= 0) {
    return;
  }
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
  _renderedImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext *rendererContext) {
    [self.layer renderInContext:rendererContext.CGContext];
  }];
  _didRasterize = YES;
  [self notifyHost];
}

#pragma mark - RNMapsCalloutOwner

- (void)calloutContentChanged
{
  UIImage *image = [_calloutView renderToImage];
  if (image != nil) {
    _calloutImage = image;
    [self notifyHost];
  }
}

#pragma mark - Props

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  // Use `_props`, not `oldProps`: the parameter is nullptr on the first updateProps
  // and dereferencing it crashes. `_props` holds the last-applied props.
  const auto &oldViewProps = *std::static_pointer_cast<RNMapsMarkerProps const>(_props);
  const auto &newViewProps = *std::static_pointer_cast<RNMapsMarkerProps const>(props);

  if (newViewProps.tracksViewChanges && !oldViewProps.tracksViewChanges) {
    _didRasterize = NO;
    [self setNeedsLayout];
  }
  _tracksViewChanges = newViewProps.tracksViewChanges;

  [self setImageUri:RNMapsMarkerNSString(newViewProps.image)];

  [super updateProps:props oldProps:oldProps];
  // Push the new model (reads from the now-updated _props) to the adapter.
  [self notifyHost];
}

- (void)setImageUri:(NSString *)uri
{
  NSString *normalized = uri.length > 0 ? uri : nil;
  if ((normalized == nil && _imageUri == nil) || [normalized isEqualToString:_imageUri]) {
    return;
  }
  _imageUri = normalized;

  if (normalized == nil) {
    _propImage = nil;
    [self notifyHost];
    return;
  }

  __weak RNMapsMarker *weakSelf = self;
  RNMapsLoadMarkerImage(normalized, ^(UIImage *image) {
    RNMapsMarker *strongSelf = weakSelf;
    // Ignore a stale load if the uri changed again before it resolved.
    if (strongSelf == nil || ![normalized isEqualToString:strongSelf->_imageUri]) {
      return;
    }
    strongSelf->_propImage = image;
    [strongSelf notifyHost];
  });
}

- (void)prepareForRecycle
{
  _calloutView.calloutOwner = nil;
  _calloutView = nil;
  _imageUri = nil;
  _propImage = nil;
  _renderedImage = nil;
  _calloutImage = nil;
  _childCount = 0;
  _didRasterize = NO;
  _tracksViewChanges = YES;
  self.cnHandle = nil;
  self.cnChildId = nil;
  self.mapHost = nil;
  [super prepareForRecycle];
}

#pragma mark - Commands

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args
{
  RCTRNMapsMarkerHandleCommand(self, commandName, args);
}

- (void)showCallout
{
  [self.mapHost.mapAdapter selectMarker:self.cnHandle animated:YES];
}

- (void)hideCallout
{
  [self.mapHost.mapAdapter deselectMarker:self.cnHandle animated:YES];
}

- (void)redrawCallout
{
  [self.mapHost.mapAdapter redrawCalloutForMarker:self.cnHandle];
}

- (void)redraw
{
  if ([self hasCustomContent]) {
    _didRasterize = NO;
    [self renderToImage];
  }
}

- (void)animateMarkerToCoordinate:(double)latitude longitude:(double)longitude duration:(NSInteger)duration
{
  [self.mapHost.mapAdapter animateMarker:self.cnHandle
                              toLatitude:latitude
                               longitude:longitude
                                duration:duration];
}

#pragma mark - Events

// All marker events share the `{ coordinate }` payload; the JS facade re-attaches
// the identifier and converts the coordinate back to the user's system.
#define RNMapsEmitMarkerEvent(EventStruct, emitterMethod, coord)                   \
  do {                                                                             \
    if (!_eventEmitter) {                                                          \
      break;                                                                       \
    }                                                                              \
    auto emitter = std::static_pointer_cast<RNMapsMarkerEventEmitter const>(_eventEmitter); \
    RNMapsMarkerEventEmitter::EventStruct event{};                                 \
    event.coordinate.latitude = (coord).latitude;                                 \
    event.coordinate.longitude = (coord).longitude;                               \
    emitter->emitterMethod(event);                                                 \
  } while (0)

- (void)emitAdapterEvent:(CNMarkerEventKind)event atCoordinate:(CLLocationCoordinate2D)coordinate
{
  switch (event) {
    case CNMarkerEventPress:
      RNMapsEmitMarkerEvent(OnPress, onPress, coordinate);
      break;
    case CNMarkerEventSelect:
      RNMapsEmitMarkerEvent(OnSelect, onSelect, coordinate);
      break;
    case CNMarkerEventDeselect:
      RNMapsEmitMarkerEvent(OnDeselect, onDeselect, coordinate);
      break;
    case CNMarkerEventCalloutPress:
      RNMapsEmitMarkerEvent(OnCalloutPress, onCalloutPress, coordinate);
      // The custom callout's own onPress fires alongside the marker's onCalloutPress.
      [_calloutView emitPress];
      break;
    case CNMarkerEventDragStart:
      RNMapsEmitMarkerEvent(OnDragStart, onDragStart, coordinate);
      break;
    case CNMarkerEventDrag:
      RNMapsEmitMarkerEvent(OnDrag, onDrag, coordinate);
      break;
    case CNMarkerEventDragEnd:
      RNMapsEmitMarkerEvent(OnDragEnd, onDragEnd, coordinate);
      break;
  }
}

#undef RNMapsEmitMarkerEvent

@end
