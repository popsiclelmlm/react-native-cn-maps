#import "RNMapsMarker.h"
#import "RNMapsCallout.h"

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
  // Suppress the system callout when the marker manages its own custom callout.
  view.canShowCallout = !self.hasCustomCallout;
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
  UIImage *_propImage;     // resolved from the `image` prop
  UIImage *_renderedImage; // rasterized from custom React children
  NSInteger _childCount;
  BOOL _tracksViewChanges;
  BOOL _didRasterize;
  // animateMarkerToCoordinate interpolation state.
  CADisplayLink *_animationLink;
  CLLocationCoordinate2D _animationStart;
  CLLocationCoordinate2D _animationTarget;
  CFTimeInterval _animationStartTime;
  CFTimeInterval _animationDuration;
  // Custom <Callout> child (kept out of the marker's view tree / icon) + its
  // currently-presented rasterized image view.
  RNMapsCallout *_calloutView;
  UIImageView *_calloutImageView;
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

    _annotation = [RNMapsMarkerAnnotation new];
    _annotation.marker = self;
  }

  return self;
}

#pragma mark - Custom React content

// Marker children DO render (offscreen): they are mounted as real subviews of
// this orphan view — the view itself is never added to the map's UIView tree —
// then rasterized into the annotation image. So, unlike the map's interception
// of marker children, here we defer to super to actually host the subtree.
- (void)mountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView index:(NSInteger)index
{
  // A <Callout> child is intercepted: it is NOT added as a marker subview (so it
  // stays out of the icon rasterization and the marker's bounds) — it is shown
  // separately on selection.
  if ([childComponentView isKindOfClass:[RNMapsCallout class]]) {
    _calloutView = (RNMapsCallout *)childComponentView;
    _annotation.hasCustomCallout = YES;
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
    [self dismissCallout];
    _calloutView = nil;
    _annotation.hasCustomCallout = NO;
    return;
  }

  [super unmountChildComponentView:childComponentView index:index];
  _childCount = MAX((NSInteger)0, _childCount - 1);
  if (_childCount == 0) {
    _renderedImage = nil;
    _didRasterize = NO;
    [self updateEffectiveImage];
  }
}

#pragma mark - Custom callout presentation

- (void)presentCalloutInAnnotationView:(MAAnnotationView *)annotationView
{
  if (_calloutView == nil || annotationView == nil) {
    return;
  }

  UIImage *image = [_calloutView renderToImage];
  if (image == nil) {
    return;
  }

  [self dismissCallout];

  UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
  imageView.userInteractionEnabled = YES;
  // Centered horizontally, sitting just above the annotation view.
  imageView.frame = CGRectMake(
    (annotationView.bounds.size.width - image.size.width) / 2.0,
    -image.size.height,
    image.size.width,
    image.size.height);

  UITapGestureRecognizer *tap =
    [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleCalloutTap)];
  [imageView addGestureRecognizer:tap];

  [annotationView addSubview:imageView];
  _calloutImageView = imageView;
}

- (void)dismissCallout
{
  [_calloutImageView removeFromSuperview];
  _calloutImageView = nil;
}

- (void)handleCalloutTap
{
  [self emitCalloutPress];
  [_calloutView emitPress];
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

// Offscreen rasterization: the view is not in a window, so render its layer into
// an image context rather than using -drawViewHierarchyInRect: (unreliable here).
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
  [self updateEffectiveImage];
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

// Custom children win over the `image` prop, which wins over the default pin.
- (void)updateEffectiveImage
{
  _annotation.image = [self hasCustomContent] ? _renderedImage : _propImage;
  [self markerImageDidChange];
}

// Refresh the on-map view for an image change: swap the view class (pin↔image)
// by rebuilding, otherwise update the image in place to avoid flicker.
- (void)markerImageDidChange
{
  if (_map == nil) {
    return;
  }

  MAAnnotationView *current = [_map viewForAnnotation:_annotation];
  BOOL wantsImageView = _annotation.image != nil;
  BOOL isImageView = current != nil && ![current isKindOfClass:[MAPinAnnotationView class]];

  if (current == nil || wantsImageView != isImageView) {
    [self reapplyOnMap];
  } else if (wantsImageView) {
    current.image = _annotation.image;
    [_annotation applyAppearanceToView:current];
  }
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

  // Custom content (PR-3). When tracksViewChanges turns on, allow a re-render on
  // the next layout pass. `tracksInfoWindowChanges` is accepted for parity but
  // the system callout has nothing to re-rasterize here.
  if (newViewProps.tracksViewChanges && !oldViewProps.tracksViewChanges) {
    _didRasterize = NO;
    [self setNeedsLayout];
  }
  _tracksViewChanges = newViewProps.tracksViewChanges;

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
    _propImage = nil;
    [self updateEffectiveImage];
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
    [strongSelf updateEffectiveImage];
  });
}

- (void)prepareForRecycle
{
  [self stopCoordinateAnimation];
  [self dismissCallout];
  _calloutView = nil;
  [self removeFromMap];
  _imageUri = nil;
  _propImage = nil;
  _renderedImage = nil;
  _childCount = 0;
  _didRasterize = NO;
  _tracksViewChanges = YES;
  _annotation = [RNMapsMarkerAnnotation new];
  _annotation.marker = self;
  [super prepareForRecycle];
}

#pragma mark - Commands

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args
{
  RCTRNMapsMarkerHandleCommand(self, commandName, args);
}

- (void)showCallout
{
  [_map selectAnnotation:_annotation animated:YES];
}

- (void)hideCallout
{
  [_map deselectAnnotation:_annotation animated:YES];
}

- (void)redrawCallout
{
  // System callout has no React content yet (real <Callout> is M4); re-select to
  // refresh whatever it shows.
  if (_map != nil) {
    [_map deselectAnnotation:_annotation animated:NO];
    [_map selectAnnotation:_annotation animated:NO];
  }
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
  [self stopCoordinateAnimation];

  CLLocationCoordinate2D target = CLLocationCoordinate2DMake(latitude, longitude);
  if (duration <= 0) {
    _annotation.coordinate = target;
    return;
  }

  _animationStart = _annotation.coordinate;
  _animationTarget = target;
  _animationStartTime = CACurrentMediaTime();
  _animationDuration = duration / 1000.0; // RNM duration is milliseconds
  _animationLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(stepCoordinateAnimation:)];
  [_animationLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stepCoordinateAnimation:(CADisplayLink *)link
{
  double progress = (CACurrentMediaTime() - _animationStartTime) / _animationDuration;
  if (progress >= 1.0) {
    progress = 1.0;
  }

  _annotation.coordinate = CLLocationCoordinate2DMake(
    _animationStart.latitude + (_animationTarget.latitude - _animationStart.latitude) * progress,
    _animationStart.longitude + (_animationTarget.longitude - _animationStart.longitude) * progress);

  if (progress >= 1.0) {
    [self stopCoordinateAnimation];
  }
}

- (void)stopCoordinateAnimation
{
  [_animationLink invalidate];
  _animationLink = nil;
}

- (void)dealloc
{
  [_animationLink invalidate];
}

#pragma mark - Events

// All marker events share the `{ coordinate }` payload; the JS facade re-attaches
// the identifier and converts the coordinate back to the user's system.
#define RNMapsEmitMarkerEvent(EventStruct, emitterMethod)                          \
  do {                                                                             \
    if (!_eventEmitter) {                                                          \
      return;                                                                      \
    }                                                                              \
    auto emitter = std::static_pointer_cast<RNMapsMarkerEventEmitter const>(_eventEmitter); \
    RNMapsMarkerEventEmitter::EventStruct event{};                                 \
    event.coordinate.latitude = _annotation.coordinate.latitude;                  \
    event.coordinate.longitude = _annotation.coordinate.longitude;                \
    emitter->emitterMethod(event);                                                 \
  } while (0)

- (void)emitPress { RNMapsEmitMarkerEvent(OnPress, onPress); }
- (void)emitSelect { RNMapsEmitMarkerEvent(OnSelect, onSelect); }
- (void)emitDeselect { RNMapsEmitMarkerEvent(OnDeselect, onDeselect); }
- (void)emitCalloutPress { RNMapsEmitMarkerEvent(OnCalloutPress, onCalloutPress); }
- (void)emitDragStart { RNMapsEmitMarkerEvent(OnDragStart, onDragStart); }
- (void)emitDrag { RNMapsEmitMarkerEvent(OnDrag, onDrag); }
- (void)emitDragEnd { RNMapsEmitMarkerEvent(OnDragEnd, onDragEnd); }

#undef RNMapsEmitMarkerEvent

@end
