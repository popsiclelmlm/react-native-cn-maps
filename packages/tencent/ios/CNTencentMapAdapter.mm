#import "CNTencentMapAdapter.h"
#import "CNMapAdapterRegistry.h"

#import <QMapKit/QMapKit.h>
#import <QuartzCore/QuartzCore.h>

#include <vector>

// Tencent (腾讯地图) adapter. QMapKit closely mirrors MapKit/MAMapKit. Coordinates
// from JS are already GCJ-02, so they pass through. APIs to re-check against the
// linked QMapKit version are tagged `// VERIFY:`.

static QMapType CNTencentMapType(NSString *mapType)
{
  if ([mapType isEqualToString:@"satellite"] || [mapType isEqualToString:@"hybrid"]) {
    return QMapTypeSatellite;
  }
  return QMapTypeStandard;
}

static std::vector<CLLocationCoordinate2D> CNUnbox(NSArray<NSValue *> *values)
{
  std::vector<CLLocationCoordinate2D> out;
  out.reserve(values.count);
  for (NSValue *value in values) {
    CLLocationCoordinate2D coordinate;
    [value getValue:&coordinate];
    out.push_back(coordinate);
  }
  return out;
}

#pragma mark - Annotation

@interface CNTencentAnnotation : QPointAnnotation
@property (nonatomic, copy, nullable) NSString *childId;
@property (nonatomic, copy, nullable) NSString *markerIdentifier;
@property (nonatomic, copy, nullable) NSString *pinColor;
@property (nonatomic, assign) BOOL draggable;
@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, assign) CGPoint centerOffset;
@property (nonatomic, assign) CGFloat markerOpacity;
@property (nonatomic, assign) CGFloat rotationDegrees;
- (void)applyModel:(CNMarkerModel *)model childId:(NSString *)childId;
@end

@implementation CNTencentAnnotation
- (void)applyModel:(CNMarkerModel *)model childId:(NSString *)childId
{
  self.childId = childId;
  self.markerIdentifier = model.identifier;
  self.coordinate = model.coordinate;
  self.title = model.title;
  self.subtitle = model.subtitle;
  self.pinColor = model.pinColor;
  self.draggable = model.draggable;
  self.image = model.image;
  self.centerOffset = model.centerOffset;
  self.markerOpacity = model.opacity;
  self.rotationDegrees = model.rotationDegrees;
}
@end

#pragma mark - Adapter

@interface CNTencentMapAdapter () <QMapViewDelegate>
@end

@implementation CNTencentMapAdapter {
  QMapView *_mapView;
  BOOL _mapReady;
  CNMapOptions *_lastOptions;

  BOOL _hasPendingInitialRegion;
  BOOL _hasPendingInitialCamera;
  BOOL _initialRegionApplied;
  BOOL _initialCameraApplied;
  CNRegion _pendingInitialRegion;
  CNCamera _pendingInitialCamera;

  NSMutableArray<CNOverlayHandle *> *_markerHandles;
  NSMutableArray<CNOverlayHandle *> *_overlayHandles;
  NSMapTable<CNOverlayHandle *, CNOverlayModel *> *_overlayModels;
}

@synthesize delegate = _delegate;

+ (void)load { [CNMapAdapterRegistry registerAdapterClass:self]; }
+ (NSString *)providerName { return @"tencent"; }
- (NSString *)providerName { return @"tencent"; }

- (instancetype)init
{
  if (self = [super init]) {
    _mapView = [[QMapView alloc] initWithFrame:CGRectZero];
    _mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _mapView.delegate = self;
    _markerHandles = [NSMutableArray array];
    _overlayHandles = [NSMutableArray array];
    _overlayModels = [NSMapTable strongToStrongObjectsMapTable];
  }
  return self;
}

- (UIView *)mapView { return _mapView; }
- (void)teardown { _mapView.delegate = nil; }
- (BOOL)isReady { return _mapReady; }
- (void)didLayout { [self applyPendingInitialViewport]; }

- (void)reset
{
  for (CNOverlayHandle *h in _markerHandles) { if (h.sdkObject) [_mapView removeAnnotation:h.sdkObject]; }
  [_markerHandles removeAllObjects];
  for (CNOverlayHandle *h in _overlayHandles) { if (h.sdkObject) [_mapView removeOverlay:h.sdkObject]; }
  [_overlayHandles removeAllObjects];
  [_overlayModels removeAllObjects];
  _lastOptions = nil; _mapReady = NO;
  _hasPendingInitialRegion = _hasPendingInitialCamera = NO;
  _initialRegionApplied = _initialCameraApplied = NO;
}

#pragma mark Configuration

- (void)applyOptions:(CNMapOptions *)options
{
  if (_lastOptions == nil || ![_lastOptions.mapType isEqualToString:options.mapType]) {
    _mapView.mapType = CNTencentMapType(options.mapType);
  }
  if (_lastOptions == nil || _lastOptions.minZoomLevel != options.minZoomLevel) _mapView.minZoomLevel = options.minZoomLevel;
  if (_lastOptions == nil || _lastOptions.maxZoomLevel != options.maxZoomLevel) _mapView.maxZoomLevel = options.maxZoomLevel;
  if (_lastOptions == nil || _lastOptions.showsUserLocation != options.showsUserLocation) _mapView.showsUserLocation = options.showsUserLocation;
  _mapView.showsCompass = options.showsCompass;       // VERIFY
  _mapView.showsScale = options.showsScale;           // VERIFY
  _mapView.showTraffic = options.showsTraffic;        // VERIFY
  _mapView.showsBuildings = options.showsBuildings;   // VERIFY
  _mapView.zoomEnabled = options.zoomEnabled;
  _mapView.scrollEnabled = options.scrollEnabled;
  _mapView.rotateEnabled = options.rotateEnabled;
  _mapView.overlookingEnabled = options.pitchEnabled; // VERIFY
  _lastOptions = options;
}

#pragma mark Viewport

- (void)setRegionLatitude:(double)latitude longitude:(double)longitude
            latitudeDelta:(double)latitudeDelta longitudeDelta:(double)longitudeDelta animated:(BOOL)animated
{
  QCoordinateRegion region = QCoordinateRegionMake(
    CLLocationCoordinate2DMake(latitude, longitude), QCoordinateSpanMake(latitudeDelta, longitudeDelta));
  [_mapView setRegion:region animated:animated];
}

- (void)setCameraLatitude:(double)latitude longitude:(double)longitude
                  heading:(double)heading pitch:(double)pitch zoom:(double)zoom
                 animated:(BOOL)animated duration:(NSTimeInterval)duration
{
  if (latitude != 0.0 || longitude != 0.0) [_mapView setCenterCoordinate:CLLocationCoordinate2DMake(latitude, longitude) animated:animated];
  if (std::isfinite(zoom) && zoom > 0) [_mapView setZoomLevel:zoom animated:animated];
  _mapView.rotation = heading;     // VERIFY property
  _mapView.overlooking = pitch;    // VERIFY property
}

- (void)setPendingInitialRegionLatitude:(double)latitude longitude:(double)longitude
                          latitudeDelta:(double)latitudeDelta longitudeDelta:(double)longitudeDelta
{
  if (_initialRegionApplied || _hasPendingInitialRegion) return;
  _pendingInitialRegion = (CNRegion){latitude, longitude, latitudeDelta, longitudeDelta};
  _hasPendingInitialRegion = YES; [self applyPendingInitialViewport];
}

- (void)setPendingInitialCameraLatitude:(double)latitude longitude:(double)longitude
                                heading:(double)heading pitch:(double)pitch zoom:(double)zoom
{
  if (_initialCameraApplied || _hasPendingInitialCamera) return;
  _pendingInitialCamera = (CNCamera){latitude, longitude, heading, pitch, zoom, 0};
  _hasPendingInitialCamera = YES; [self applyPendingInitialViewport];
}

- (void)applyPendingInitialViewport
{
  if (!_mapReady || CGRectIsEmpty(_mapView.bounds)) return;
  if (_hasPendingInitialCamera && !_initialCameraApplied) {
    [self setCameraLatitude:_pendingInitialCamera.latitude longitude:_pendingInitialCamera.longitude
                    heading:_pendingInitialCamera.heading pitch:_pendingInitialCamera.pitch
                       zoom:_pendingInitialCamera.zoom animated:NO duration:0];
    _initialCameraApplied = YES; _initialRegionApplied = YES;
  } else if (_hasPendingInitialRegion && !_initialRegionApplied) {
    [self setRegionLatitude:_pendingInitialRegion.latitude longitude:_pendingInitialRegion.longitude
              latitudeDelta:_pendingInitialRegion.latitudeDelta longitudeDelta:_pendingInitialRegion.longitudeDelta animated:NO];
    _initialRegionApplied = YES;
  }
}

- (CNRegion)currentRegion
{
  QCoordinateRegion r = _mapView.region;
  return (CNRegion){r.center.latitude, r.center.longitude, r.span.latitudeDelta, r.span.longitudeDelta};
}

- (CNCamera)currentCamera
{
  return (CNCamera){_mapView.centerCoordinate.latitude, _mapView.centerCoordinate.longitude,
                    _mapView.rotation, _mapView.overlooking, _mapView.zoomLevel, 0};
}

- (void)fitToCoordinates:(NSArray<NSValue *> *)coordinates edgePadding:(UIEdgeInsets)edgePadding animated:(BOOL)animated
{
  std::vector<CLLocationCoordinate2D> pts = CNUnbox(coordinates);
  if (pts.empty()) return;
  QMapRect rect = QMapRectNull;
  for (auto &c : pts) {
    QMapPoint p = QMapPointForCoordinate(c);
    QMapRect r = QMapRectMake(p.x, p.y, 0.1, 0.1);
    rect = QMapRectIsNull(rect) ? r : QMapRectUnion(rect, r);
  }
  if (QMapRectIsNull(rect)) return;
  [_mapView setVisibleMapRect:rect edgePadding:edgePadding animated:animated]; // VERIFY
}

- (void)fitToElementsAnimated:(BOOL)animated { [_mapView showAnnotations:_mapView.annotations animated:animated]; }

- (void)fitToMarkers:(NSArray<CNOverlayHandle *> *)handles edgePadding:(UIEdgeInsets)edgePadding animated:(BOOL)animated
{
  NSMutableArray *annotations = [NSMutableArray array];
  for (CNOverlayHandle *h in handles) { if (h.sdkObject) [annotations addObject:h.sdkObject]; }
  if (annotations.count) [_mapView showAnnotations:annotations animated:animated];
}

- (void)setLimitRegionNELatitude:(double)neLatitude neLongitude:(double)neLongitude
                      swLatitude:(double)swLatitude swLongitude:(double)swLongitude
{
  CLLocationCoordinate2D center = CLLocationCoordinate2DMake((neLatitude + swLatitude) / 2.0, (neLongitude + swLongitude) / 2.0);
  QCoordinateSpan span = QCoordinateSpanMake(fabs(neLatitude - swLatitude), fabs(neLongitude - swLongitude));
  _mapView.limitRegion = QCoordinateRegionMake(center, span); // VERIFY
}

#pragma mark Projection

- (CGPoint)pointForCoordinate:(CLLocationCoordinate2D)coordinate { return [_mapView convertCoordinate:coordinate toPointToView:_mapView]; }
- (CLLocationCoordinate2D)coordinateForPoint:(CGPoint)point { return [_mapView convertPoint:point toCoordinateFromView:_mapView]; }

#pragma mark Snapshot

- (void)takeSnapshotWidth:(NSInteger)width height:(NSInteger)height format:(NSString *)format
                  quality:(double)quality result:(NSString *)result completion:(void (^)(NSString *))completion
{
  // VERIFY: QMapView snapshot API. Best-effort renders the layer into an image.
  CGSize size = _mapView.bounds.size;
  if (size.width <= 0 || size.height <= 0) { completion(@""); return; }
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
  UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
    [_mapView drawViewHierarchyInRect:_mapView.bounds afterScreenUpdates:NO];
  }];
  UIImage *output = image;
  if (width > 0 && height > 0) {
    CGSize target = CGSizeMake(width, height);
    UIGraphicsBeginImageContextWithOptions(target, NO, image.scale);
    [image drawInRect:CGRectMake(0, 0, target.width, target.height)];
    output = UIGraphicsGetImageFromCurrentImageContext() ?: image;
    UIGraphicsEndImageContext();
  }
  BOOL isJpg = [format isEqualToString:@"jpg"] || [format isEqualToString:@"jpeg"];
  NSData *data = isJpg ? UIImageJPEGRepresentation(output, MAX(0.0, MIN(1.0, quality))) : UIImagePNGRepresentation(output);
  NSString *uri = @"";
  if (data) {
    if ([result isEqualToString:@"base64"]) uri = [data base64EncodedStringWithOptions:0];
    else {
      NSString *name = [NSString stringWithFormat:@"map-snapshot-%@.%@", @((NSUInteger)(CACurrentMediaTime() * 1000)), isJpg ? @"jpg" : @"png"];
      NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
      if ([data writeToFile:path atomically:YES]) uri = [@"file://" stringByAppendingString:path];
    }
  }
  completion(uri);
}

#pragma mark Markers

- (CNOverlayHandle *)addMarker:(CNMarkerModel *)model childId:(NSString *)childId
{
  CNOverlayHandle *handle = [[CNOverlayHandle alloc] initWithChildId:childId];
  CNTencentAnnotation *a = [CNTencentAnnotation new];
  [a applyModel:model childId:childId];
  handle.sdkObject = a;
  [_markerHandles addObject:handle];
  [_mapView addAnnotation:a];
  return handle;
}

- (void)updateMarker:(CNOverlayHandle *)handle model:(CNMarkerModel *)model
{
  CNTencentAnnotation *a = handle.sdkObject;
  if (a == nil) return;
  [a applyModel:model childId:handle.childId];
  [_mapView removeAnnotation:a];
  [_mapView addAnnotation:a];
}

- (void)removeMarker:(CNOverlayHandle *)handle { if (handle.sdkObject) [_mapView removeAnnotation:handle.sdkObject]; [_markerHandles removeObject:handle]; }
- (void)selectMarker:(CNOverlayHandle *)handle animated:(BOOL)animated { if (handle.sdkObject) [_mapView selectAnnotation:handle.sdkObject animated:animated]; }
- (void)deselectMarker:(CNOverlayHandle *)handle animated:(BOOL)animated { if (handle.sdkObject) [_mapView deselectAnnotation:handle.sdkObject animated:animated]; }
- (void)redrawCalloutForMarker:(CNOverlayHandle *)handle
{
  if (handle.sdkObject) { [_mapView deselectAnnotation:handle.sdkObject animated:NO]; [_mapView selectAnnotation:handle.sdkObject animated:NO]; }
}
- (void)animateMarker:(CNOverlayHandle *)handle toLatitude:(double)latitude longitude:(double)longitude duration:(NSInteger)duration
{
  CNTencentAnnotation *a = handle.sdkObject;
  if (a) a.coordinate = CLLocationCoordinate2DMake(latitude, longitude); // VERIFY: tween API
}
- (CGPoint)pointForMarker:(CNOverlayHandle *)handle
{
  CNTencentAnnotation *a = handle.sdkObject;
  return a ? [_mapView convertCoordinate:a.coordinate toPointToView:_mapView] : CGPointZero;
}

#pragma mark Overlays

- (CNOverlayHandle *)addOverlay:(CNOverlayModel *)model childId:(NSString *)childId
{
  CNOverlayHandle *handle = [[CNOverlayHandle alloc] initWithChildId:childId];
  id<QOverlay> overlay = [self buildOverlay:model];
  handle.sdkObject = overlay;
  [_overlayHandles addObject:handle];
  [_overlayModels setObject:model forKey:handle];
  if (overlay) [_mapView addOverlay:overlay];
  return handle;
}

- (void)updateOverlay:(CNOverlayHandle *)handle model:(CNOverlayModel *)model
{
  if (handle.sdkObject) [_mapView removeOverlay:handle.sdkObject];
  id<QOverlay> overlay = [self buildOverlay:model];
  handle.sdkObject = overlay;
  [_overlayModels setObject:model forKey:handle];
  if (overlay) [_mapView addOverlay:overlay];
}

- (void)removeOverlay:(CNOverlayHandle *)handle
{
  if (handle.sdkObject) [_mapView removeOverlay:handle.sdkObject];
  [_overlayHandles removeObject:handle];
  [_overlayModels removeObjectForKey:handle];
}

- (nullable id<QOverlay>)buildOverlay:(CNOverlayModel *)model
{
  switch (model.type) {
    case CNOverlayTypePolyline: {
      CNPolylineModel *m = (CNPolylineModel *)model;
      std::vector<CLLocationCoordinate2D> pts = CNUnbox(m.coordinates);
      if (pts.empty()) return nil;
      return [QPolyline polylineWithCoordinates:pts.data() count:(NSUInteger)pts.size()];
    }
    case CNOverlayTypePolygon: {
      CNPolygonModel *m = (CNPolygonModel *)model;
      std::vector<CLLocationCoordinate2D> pts = CNUnbox(m.coordinates);
      if (pts.empty()) return nil;
      return [QPolygon polygonWithCoordinates:pts.data() count:(NSUInteger)pts.size()];
    }
    case CNOverlayTypeCircle: {
      CNCircleModel *m = (CNCircleModel *)model;
      return [QCircle circleWithCenterCoordinate:m.center radius:m.radius];
    }
    case CNOverlayTypeGroundOverlay:
    case CNOverlayTypeUrlTile:
    case CNOverlayTypeLocalTile:
    case CNOverlayTypeHeatmap:
      // Ground overlay / tiles / heatmap use Tencent-specific classes; TODO (see README).
      return nil;
  }
  return nil;
}

#pragma mark Privacy

+ (void)applyPrivacyConsentAgreed:(BOOL)agreed contains:(BOOL)contains shown:(BOOL)shown
{
  // VERIFY: Tencent privacy agreement entry point.
  [[QMapServices sharedServices] setPrivacyAgreement:agreed];
}

#pragma mark - QMapViewDelegate

- (QOverlayView *)mapView:(QMapView *)mapView viewForOverlay:(id<QOverlay>)overlay
{
  CNOverlayModel *model = nil;
  for (CNOverlayHandle *h in _overlayHandles) { if (h.sdkObject == overlay) { model = [_overlayModels objectForKey:h]; break; } }
  if (model == nil) return nil;
  switch (model.type) {
    case CNOverlayTypePolyline: {
      CNPolylineModel *m = (CNPolylineModel *)model;
      QPolylineView *v = [[QPolylineView alloc] initWithPolyline:(QPolyline *)overlay];
      v.strokeColor = m.strokeColors.firstObject ?: m.strokeColor;
      v.lineWidth = m.strokeWidth;
      return v;
    }
    case CNOverlayTypePolygon: {
      CNPolygonModel *m = (CNPolygonModel *)model;
      QPolygonView *v = [[QPolygonView alloc] initWithPolygon:(QPolygon *)overlay];
      v.strokeColor = m.strokeColor; v.fillColor = m.fillColor; v.lineWidth = m.strokeWidth;
      return v;
    }
    case CNOverlayTypeCircle: {
      CNCircleModel *m = (CNCircleModel *)model;
      QCircleView *v = [[QCircleView alloc] initWithCircle:(QCircle *)overlay];
      v.strokeColor = m.strokeColor; v.fillColor = m.fillColor; v.lineWidth = m.strokeWidth;
      return v;
    }
    default: return nil;
  }
}

- (QAnnotationView *)mapView:(QMapView *)mapView viewForAnnotation:(id<QAnnotation>)annotation
{
  if (![annotation isKindOfClass:[CNTencentAnnotation class]]) return nil;
  CNTencentAnnotation *marker = (CNTencentAnnotation *)annotation;
  QAnnotationView *view;
  if (marker.image != nil) {
    static NSString *reuse = @"CNTencentImage";
    view = [mapView dequeueReusableAnnotationViewWithIdentifier:reuse];
    if (view == nil) view = [[QAnnotationView alloc] initWithAnnotation:marker reuseIdentifier:reuse];
    else view.annotation = marker;
    view.image = marker.image;
  } else {
    static NSString *reuse = @"CNTencentPin";
    QPinAnnotationView *pin = (QPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:reuse];
    if (pin == nil) pin = [[QPinAnnotationView alloc] initWithAnnotation:marker reuseIdentifier:reuse];
    else pin.annotation = marker;
    view = pin;
  }
  view.draggable = marker.draggable;
  view.centerOffset = CGPointMake(marker.centerOffset.x, marker.centerOffset.y);
  view.alpha = marker.markerOpacity;
  view.transform = CGAffineTransformMakeRotation(marker.rotationDegrees * M_PI / 180.0);
  return view;
}

- (void)mapViewInitComplete:(QMapView *)mapView // VERIFY callback name (or mapViewDidFinishLoadingMap:)
{
  _mapReady = YES;
  [self applyPendingInitialViewport];
  [self.delegate mapAdapterDidBecomeReady:self];
}

- (void)mapView:(QMapView *)mapView didSingleTappedAtCoordinate:(CLLocationCoordinate2D)coordinate // VERIFY
{
  [self.delegate mapAdapter:self didTapAtCoordinate:coordinate];
}

- (void)mapView:(QMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
  [self.delegate mapAdapter:self didChangeRegionComplete:YES isGesture:YES];
}

- (void)mapView:(QMapView *)mapView regionWillChangeAnimated:(BOOL)animated
{
  [self.delegate mapAdapter:self didChangeRegionComplete:NO isGesture:YES];
}

- (void)mapView:(QMapView *)mapView didUpdateUserLocation:(QUserLocation *)userLocation fromHeading:(BOOL)fromHeading // VERIFY
{
  CLLocation *location = userLocation.location;
  if (location) [self.delegate mapAdapter:self didUpdateUserLocation:location];
}

- (void)mapView:(QMapView *)mapView didSelectAnnotationView:(QAnnotationView *)view
{
  if (![view.annotation isKindOfClass:[CNTencentAnnotation class]]) return;
  CNTencentAnnotation *a = (CNTencentAnnotation *)view.annotation;
  [self deliverMarkerEvent:CNMarkerEventPress forAnnotation:a];
  [self deliverMarkerEvent:CNMarkerEventSelect forAnnotation:a];
}

- (void)mapView:(QMapView *)mapView didDeselectAnnotationView:(QAnnotationView *)view
{
  if ([view.annotation isKindOfClass:[CNTencentAnnotation class]])
    [self deliverMarkerEvent:CNMarkerEventDeselect forAnnotation:(CNTencentAnnotation *)view.annotation];
}

- (void)mapView:(QMapView *)mapView annotationView:(QAnnotationView *)view
 didChangeDragState:(NSUInteger)newState fromOldState:(NSUInteger)oldState
{
  if (![view.annotation isKindOfClass:[CNTencentAnnotation class]]) return;
  CNTencentAnnotation *a = (CNTencentAnnotation *)view.annotation;
  switch (newState) { // VERIFY drag-state enum values
    case 2: [self deliverMarkerEvent:CNMarkerEventDragStart forAnnotation:a]; break;
    case 3: [self deliverMarkerEvent:CNMarkerEventDrag forAnnotation:a]; break;
    case 4: [self deliverMarkerEvent:CNMarkerEventDragEnd forAnnotation:a]; break;
    default: break;
  }
}

- (void)deliverMarkerEvent:(CNMarkerEventKind)kind forAnnotation:(CNTencentAnnotation *)annotation
{
  if (self.delegate == nil || annotation.childId == nil) return;
  [self.delegate mapAdapter:self markerChildId:annotation.childId didFireEvent:kind atCoordinate:annotation.coordinate];
}

@end
