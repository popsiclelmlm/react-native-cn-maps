#import "CNBaiduMapAdapter.h"
#import "CNMapAdapterRegistry.h"

#import <BaiduMapAPI_Map/BMKMapComponent.h>
#import <BaiduMapAPI_Base/BMKBaseComponent.h>
#import <QuartzCore/QuartzCore.h>

#include <vector>

// Baidu (百度地图) adapter. Coordinates from JS are already BD-09, so they pass
// straight through to the SDK. APIs that should be re-checked against the linked
// BaiduMapKit version are tagged `// VERIFY:`.

#pragma mark - Helpers

static BMKMapType CNBaiduMapType(NSString *mapType, NSString *userInterfaceStyle)
{
  // Baidu offers standard / satellite. There is no first-class night basemap
  // (it needs a custom style file), so dark collapses to standard.
  if ([mapType isEqualToString:@"satellite"] || [mapType isEqualToString:@"hybrid"]) {
    return BMKMapTypeSatellite;
  }
  return BMKMapTypeStandard;
}

static BMKPinAnnotationColor CNBaiduPinColor(NSString *color)
{
  NSString *lower = color.lowercaseString;
  if ([lower containsString:@"green"]) {
    return BMKPinAnnotationColorGreen;
  }
  if ([lower containsString:@"purple"] || [lower containsString:@"violet"]) {
    return BMKPinAnnotationColorPurple;
  }
  return BMKPinAnnotationColorRed;
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

@interface CNBaiduAnnotation : BMKPointAnnotation
@property (nonatomic, copy, nullable) NSString *childId;
@property (nonatomic, copy, nullable) NSString *markerIdentifier;
@property (nonatomic, copy, nullable) NSString *pinColor;
@property (nonatomic, assign) BOOL draggable;
@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, assign) CGPoint centerOffset;
@property (nonatomic, assign) CGFloat markerOpacity;
@property (nonatomic, assign) CGFloat rotationDegrees;
@property (nonatomic, assign) BOOL hasCustomCallout;
@property (nonatomic, strong, nullable) UIImage *calloutImage;
- (void)applyModel:(CNMarkerModel *)model childId:(NSString *)childId;
@end

@implementation CNBaiduAnnotation
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
  self.hasCustomCallout = model.hasCustomCallout;
  self.calloutImage = model.calloutImage;
}
@end

#pragma mark - Adapter

@interface CNBaiduMapAdapter () <BMKMapViewDelegate>
@end

@implementation CNBaiduMapAdapter {
  BMKMapView *_mapView;
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

+ (void)load
{
  [CNMapAdapterRegistry registerAdapterClass:self];
}

+ (NSString *)providerName { return @"baidu"; }
- (NSString *)providerName { return @"baidu"; }

- (instancetype)init
{
  if (self = [super init]) {
    _mapView = [[BMKMapView alloc] initWithFrame:CGRectZero];
    _mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _mapView.delegate = self;
    _markerHandles = [NSMutableArray array];
    _overlayHandles = [NSMutableArray array];
    _overlayModels = [NSMapTable strongToStrongObjectsMapTable];
  }
  return self;
}

- (UIView *)mapView { return _mapView; }

- (void)teardown
{
  _mapView.delegate = nil;
  // Baidu requires pausing the map view when it leaves the screen.
  [_mapView viewWillDisappear];
}

- (void)reset
{
  for (CNOverlayHandle *handle in _markerHandles) {
    if (handle.sdkObject) [_mapView removeAnnotation:handle.sdkObject];
  }
  [_markerHandles removeAllObjects];
  for (CNOverlayHandle *handle in _overlayHandles) {
    [self removeSdkOverlay:handle.sdkObject];
  }
  [_overlayHandles removeAllObjects];
  [_overlayModels removeAllObjects];
  _lastOptions = nil;
  _mapReady = NO;
  _hasPendingInitialRegion = _hasPendingInitialCamera = NO;
  _initialRegionApplied = _initialCameraApplied = NO;
}

- (BOOL)isReady { return _mapReady; }

- (void)didLayout { [self applyPendingInitialViewport]; }

#pragma mark Configuration

- (void)applyOptions:(CNMapOptions *)options
{
  if (_lastOptions == nil ||
      ![_lastOptions.mapType isEqualToString:options.mapType] ||
      ![_lastOptions.userInterfaceStyle isEqualToString:options.userInterfaceStyle]) {
    _mapView.mapType = CNBaiduMapType(options.mapType, options.userInterfaceStyle);
  }
  if (_lastOptions == nil || _lastOptions.minZoomLevel != options.minZoomLevel) {
    _mapView.minZoomLevel = options.minZoomLevel;
  }
  if (_lastOptions == nil || _lastOptions.maxZoomLevel != options.maxZoomLevel) {
    _mapView.maxZoomLevel = options.maxZoomLevel;
  }
  if (_lastOptions == nil || _lastOptions.showsUserLocation != options.showsUserLocation) {
    // Baidu shows the dot when fed locations via BMKLocationManager (host setup).
    _mapView.showsUserLocation = options.showsUserLocation;
  }
  _mapView.showMapScaleBar = options.showsScale;       // VERIFY: property name
  _mapView.trafficEnabled = options.showsTraffic;
  _mapView.buildingsEnabled = options.showsBuildings;
  _mapView.baseIndoorMapEnabled = options.showsIndoors; // VERIFY
  _mapView.showMapPoi = options.showsPointsOfInterest;  // VERIFY
  _mapView.zoomEnabled = options.zoomEnabled;
  _mapView.scrollEnabled = options.scrollEnabled;
  _mapView.rotateEnabled = options.rotateEnabled;
  _mapView.overlookEnabled = options.pitchEnabled;
  // Baidu has no compass toggle equivalent to AMap's; best-effort ignore showsCompass.
  _lastOptions = options;
}

#pragma mark Viewport

- (void)setRegionLatitude:(double)latitude longitude:(double)longitude
            latitudeDelta:(double)latitudeDelta longitudeDelta:(double)longitudeDelta
                 animated:(BOOL)animated
{
  BMKCoordinateRegion region = BMKCoordinateRegionMake(
    CLLocationCoordinate2DMake(latitude, longitude),
    BMKCoordinateSpanMake(latitudeDelta, longitudeDelta));
  [_mapView setRegion:region animated:animated];
}

- (void)setCameraLatitude:(double)latitude longitude:(double)longitude
                  heading:(double)heading pitch:(double)pitch zoom:(double)zoom
                 animated:(BOOL)animated duration:(NSTimeInterval)duration
{
  BMKMapStatus *status = [[BMKMapStatus alloc] init];
  if (latitude != 0.0 || longitude != 0.0) {
    status.targetGeoPt = CLLocationCoordinate2DMake(latitude, longitude);
  } else {
    status.targetGeoPt = _mapView.centerCoordinate;
  }
  status.fLevel = (std::isfinite(zoom) && zoom > 0) ? zoom : _mapView.zoomLevel;
  status.fRotation = heading;
  status.fOverlooking = -pitch; // Baidu overlooking is negative downward. VERIFY sign.
  [_mapView setMapStatus:status animated:animated];
}

- (void)setPendingInitialRegionLatitude:(double)latitude longitude:(double)longitude
                          latitudeDelta:(double)latitudeDelta longitudeDelta:(double)longitudeDelta
{
  if (_initialRegionApplied || _hasPendingInitialRegion) return;
  _pendingInitialRegion = (CNRegion){latitude, longitude, latitudeDelta, longitudeDelta};
  _hasPendingInitialRegion = YES;
  [self applyPendingInitialViewport];
}

- (void)setPendingInitialCameraLatitude:(double)latitude longitude:(double)longitude
                                heading:(double)heading pitch:(double)pitch zoom:(double)zoom
{
  if (_initialCameraApplied || _hasPendingInitialCamera) return;
  _pendingInitialCamera = (CNCamera){latitude, longitude, heading, pitch, zoom, 0};
  _hasPendingInitialCamera = YES;
  [self applyPendingInitialViewport];
}

- (void)applyPendingInitialViewport
{
  if (!_mapReady || CGRectIsEmpty(_mapView.bounds)) return;
  if (_hasPendingInitialCamera && !_initialCameraApplied) {
    [self setCameraLatitude:_pendingInitialCamera.latitude longitude:_pendingInitialCamera.longitude
                    heading:_pendingInitialCamera.heading pitch:_pendingInitialCamera.pitch
                       zoom:_pendingInitialCamera.zoom animated:NO duration:0];
    _initialCameraApplied = YES;
    _initialRegionApplied = YES;
  } else if (_hasPendingInitialRegion && !_initialRegionApplied) {
    [self setRegionLatitude:_pendingInitialRegion.latitude longitude:_pendingInitialRegion.longitude
              latitudeDelta:_pendingInitialRegion.latitudeDelta
             longitudeDelta:_pendingInitialRegion.longitudeDelta animated:NO];
    _initialRegionApplied = YES;
  }
}

- (CNRegion)currentRegion
{
  BMKCoordinateRegion region = _mapView.region;
  return (CNRegion){region.center.latitude, region.center.longitude,
                    region.span.latitudeDelta, region.span.longitudeDelta};
}

- (CNCamera)currentCamera
{
  return (CNCamera){_mapView.centerCoordinate.latitude, _mapView.centerCoordinate.longitude,
                    _mapView.rotation, -_mapView.overlooking, _mapView.zoomLevel, 0};
}

- (void)fitToCoordinates:(NSArray<NSValue *> *)coordinates edgePadding:(UIEdgeInsets)edgePadding animated:(BOOL)animated
{
  std::vector<CLLocationCoordinate2D> points = CNUnbox(coordinates);
  if (points.empty()) return;
  // Build a bounds and fit. BMKMapPointForCoordinate + BMKMapRect union.
  BMKMapRect rect = BMKMapRectNull;
  for (auto &c : points) {
    BMKMapPoint p = BMKMapPointForCoordinate(c);
    BMKMapRect r = BMKMapRectMake(p.x, p.y, 0.1, 0.1);
    rect = BMKMapRectIsNull(rect) ? r : BMKMapRectUnion(rect, r);
  }
  if (BMKMapRectIsNull(rect)) return;
  [_mapView fitVisibleMapRect:rect edgePadding:edgePadding withAnimated:animated]; // VERIFY signature
}

- (void)fitToElementsAnimated:(BOOL)animated
{
  [_mapView showAnnotations:_mapView.annotations animated:animated]; // VERIFY availability
}

- (void)fitToMarkers:(NSArray<CNOverlayHandle *> *)handles edgePadding:(UIEdgeInsets)edgePadding animated:(BOOL)animated
{
  NSMutableArray *annotations = [NSMutableArray array];
  for (CNOverlayHandle *handle in handles) {
    if (handle.sdkObject) [annotations addObject:handle.sdkObject];
  }
  if (annotations.count > 0) [_mapView showAnnotations:annotations animated:animated];
}

- (void)setLimitRegionNELatitude:(double)neLatitude neLongitude:(double)neLongitude
                      swLatitude:(double)swLatitude swLongitude:(double)swLongitude
{
  // Baidu: -setVisibleMapBounds restricts pan; there is no exact AMap limitRegion.
  BMKCoordinateBounds bounds;
  bounds.northEast = CLLocationCoordinate2DMake(neLatitude, neLongitude);
  bounds.southWest = CLLocationCoordinate2DMake(swLatitude, swLongitude);
  [_mapView setVisibleMapBounds:bounds]; // VERIFY availability
}

#pragma mark Projection

- (CGPoint)pointForCoordinate:(CLLocationCoordinate2D)coordinate
{
  return [_mapView convertCoordinate:coordinate toPointToView:_mapView];
}

- (CLLocationCoordinate2D)coordinateForPoint:(CGPoint)point
{
  return [_mapView convertPoint:point toCoordinateFromView:_mapView];
}

#pragma mark Snapshot

- (void)takeSnapshotWidth:(NSInteger)width height:(NSInteger)height
                   format:(NSString *)format quality:(double)quality
                   result:(NSString *)result completion:(void (^)(NSString *))completion
{
  // Baidu provides a synchronous snapshot of the current map content. VERIFY API.
  UIImage *image = [_mapView takeSnapshot];
  if (image == nil) { completion(@""); return; }
  UIImage *output = image;
  if (width > 0 && height > 0) {
    CGSize size = CGSizeMake(width, height);
    UIGraphicsBeginImageContextWithOptions(size, NO, image.scale);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    output = UIGraphicsGetImageFromCurrentImageContext() ?: image;
    UIGraphicsEndImageContext();
  }
  BOOL isJpg = [format isEqualToString:@"jpg"] || [format isEqualToString:@"jpeg"];
  NSData *data = isJpg ? UIImageJPEGRepresentation(output, MAX(0.0, MIN(1.0, quality)))
                       : UIImagePNGRepresentation(output);
  NSString *uri = @"";
  if (data) {
    if ([result isEqualToString:@"base64"]) {
      uri = [data base64EncodedStringWithOptions:0];
    } else {
      NSString *name = [NSString stringWithFormat:@"map-snapshot-%@.%@",
                        @((NSUInteger)(CACurrentMediaTime() * 1000)), isJpg ? @"jpg" : @"png"];
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
  CNBaiduAnnotation *annotation = [CNBaiduAnnotation new];
  [annotation applyModel:model childId:childId];
  handle.sdkObject = annotation;
  [_markerHandles addObject:handle];
  [_mapView addAnnotation:annotation];
  return handle;
}

- (void)updateMarker:(CNOverlayHandle *)handle model:(CNMarkerModel *)model
{
  CNBaiduAnnotation *annotation = handle.sdkObject;
  if (annotation == nil) return;
  [annotation applyModel:model childId:handle.childId];
  // Re-add to force the annotation view to rebuild (pin↔image swap, appearance).
  [_mapView removeAnnotation:annotation];
  [_mapView addAnnotation:annotation];
}

- (void)removeMarker:(CNOverlayHandle *)handle
{
  if (handle.sdkObject) [_mapView removeAnnotation:handle.sdkObject];
  [_markerHandles removeObject:handle];
}

- (void)selectMarker:(CNOverlayHandle *)handle animated:(BOOL)animated
{
  if (handle.sdkObject) [_mapView selectAnnotation:handle.sdkObject animated:animated];
}

- (void)deselectMarker:(CNOverlayHandle *)handle animated:(BOOL)animated
{
  if (handle.sdkObject) [_mapView deselectAnnotation:handle.sdkObject animated:animated];
}

- (void)redrawCalloutForMarker:(CNOverlayHandle *)handle
{
  if (handle.sdkObject) {
    [_mapView deselectAnnotation:handle.sdkObject animated:NO];
    [_mapView selectAnnotation:handle.sdkObject animated:NO];
  }
}

- (void)animateMarker:(CNOverlayHandle *)handle toLatitude:(double)latitude longitude:(double)longitude duration:(NSInteger)duration
{
  CNBaiduAnnotation *annotation = handle.sdkObject;
  if (annotation == nil) return;
  // Baidu animates an annotation's coordinate via setting it (no built-in tween);
  // a simple set keeps parity with a 0-duration move. VERIFY: BMKAnimatedAnnotation.
  annotation.coordinate = CLLocationCoordinate2DMake(latitude, longitude);
}

- (CGPoint)pointForMarker:(CNOverlayHandle *)handle
{
  CNBaiduAnnotation *annotation = handle.sdkObject;
  if (annotation == nil) return CGPointZero;
  return [_mapView convertCoordinate:annotation.coordinate toPointToView:_mapView];
}

#pragma mark Overlays

- (CNOverlayHandle *)addOverlay:(CNOverlayModel *)model childId:(NSString *)childId
{
  CNOverlayHandle *handle = [[CNOverlayHandle alloc] initWithChildId:childId];
  id<BMKOverlay> overlay = [self buildOverlay:model];
  handle.sdkObject = overlay;
  [_overlayHandles addObject:handle];
  [_overlayModels setObject:model forKey:handle];
  if (overlay) [_mapView addOverlay:overlay];
  return handle;
}

- (void)updateOverlay:(CNOverlayHandle *)handle model:(CNOverlayModel *)model
{
  [self removeSdkOverlay:handle.sdkObject];
  id<BMKOverlay> overlay = [self buildOverlay:model];
  handle.sdkObject = overlay;
  [_overlayModels setObject:model forKey:handle];
  if (overlay) [_mapView addOverlay:overlay];
}

- (void)removeOverlay:(CNOverlayHandle *)handle
{
  [self removeSdkOverlay:handle.sdkObject];
  [_overlayHandles removeObject:handle];
  [_overlayModels removeObjectForKey:handle];
}

- (void)removeSdkOverlay:(id)sdkObject
{
  if (sdkObject && [sdkObject conformsToProtocol:@protocol(BMKOverlay)]) {
    [_mapView removeOverlay:(id<BMKOverlay>)sdkObject];
  }
}

- (nullable id<BMKOverlay>)buildOverlay:(CNOverlayModel *)model
{
  switch (model.type) {
    case CNOverlayTypePolyline: {
      CNPolylineModel *m = (CNPolylineModel *)model;
      std::vector<CLLocationCoordinate2D> pts = CNUnbox(m.coordinates);
      if (pts.empty()) return nil;
      return [BMKPolyline polylineWithCoordinates:pts.data() count:(NSUInteger)pts.size()];
    }
    case CNOverlayTypePolygon: {
      CNPolygonModel *m = (CNPolygonModel *)model;
      std::vector<CLLocationCoordinate2D> pts = CNUnbox(m.coordinates);
      if (pts.empty()) return nil;
      // NOTE: Baidu BMKPolygon has no interior-holes API; `holes` is dropped.
      return [BMKPolygon polygonWithCoordinates:pts.data() count:(NSUInteger)pts.size()];
    }
    case CNOverlayTypeCircle: {
      CNCircleModel *m = (CNCircleModel *)model;
      return [BMKCircle circleWithCenterCoordinate:m.center radius:m.radius];
    }
    case CNOverlayTypeGroundOverlay: {
      CNGroundOverlayModel *m = (CNGroundOverlayModel *)model;
      if (m.image == nil) return nil;
      BMKCoordinateBounds bounds;
      bounds.northEast = m.northEast;
      bounds.southWest = m.southWest;
      return [BMKGroundOverlay groundOverlayWithBounds:bounds icon:m.image]; // VERIFY
    }
    case CNOverlayTypeUrlTile:
    case CNOverlayTypeLocalTile:
    case CNOverlayTypeHeatmap:
      // Tiles & heatmap are not BMKOverlay objects on Baidu (tiles use BMKTileLayer,
      // heatmap uses [mapView addHeatMap:]). Handled out-of-band below / TODO.
      return nil;
  }
  return nil;
}

#pragma mark Privacy

+ (void)applyPrivacyConsentAgreed:(BOOL)agreed contains:(BOOL)contains shown:(BOOL)shown
{
  // Baidu requires agreeing to the privacy policy before the SDK initializes.
  [BMKMapManager setAgreePrivacy:agreed]; // VERIFY: class method name
}

#pragma mark - BMKMapViewDelegate

- (BMKOverlayView *)mapView:(BMKMapView *)mapView viewForOverlay:(id<BMKOverlay>)overlay
{
  CNOverlayModel *model = nil;
  for (CNOverlayHandle *handle in _overlayHandles) {
    if (handle.sdkObject == overlay) { model = [_overlayModels objectForKey:handle]; break; }
  }
  if (model == nil) return nil;
  switch (model.type) {
    case CNOverlayTypePolyline: {
      CNPolylineModel *m = (CNPolylineModel *)model;
      BMKPolylineView *view = [[BMKPolylineView alloc] initWithOverlay:overlay];
      view.strokeColor = m.strokeColors.firstObject ?: m.strokeColor;
      view.lineWidth = m.strokeWidth;
      return view;
    }
    case CNOverlayTypePolygon: {
      CNPolygonModel *m = (CNPolygonModel *)model;
      BMKPolygonView *view = [[BMKPolygonView alloc] initWithOverlay:overlay];
      view.strokeColor = m.strokeColor;
      view.fillColor = m.fillColor;
      view.lineWidth = m.strokeWidth;
      return view;
    }
    case CNOverlayTypeCircle: {
      CNCircleModel *m = (CNCircleModel *)model;
      BMKCircleView *view = [[BMKCircleView alloc] initWithOverlay:overlay];
      view.strokeColor = m.strokeColor;
      view.fillColor = m.fillColor;
      view.lineWidth = m.strokeWidth;
      return view;
    }
    case CNOverlayTypeGroundOverlay:
      return [[BMKGroundOverlayView alloc] initWithOverlay:overlay]; // VERIFY
    default:
      return nil;
  }
}

- (BMKAnnotationView *)mapView:(BMKMapView *)mapView viewForAnnotation:(id<BMKAnnotation>)annotation
{
  if (![annotation isKindOfClass:[CNBaiduAnnotation class]]) return nil;
  CNBaiduAnnotation *marker = (CNBaiduAnnotation *)annotation;
  BMKAnnotationView *view;
  if (marker.image != nil) {
    static NSString *reuse = @"CNBaiduImage";
    view = [mapView dequeueReusableAnnotationViewWithIdentifier:reuse];
    if (view == nil) view = [[BMKAnnotationView alloc] initWithAnnotation:marker reuseIdentifier:reuse];
    else view.annotation = marker;
    view.image = marker.image;
  } else {
    static NSString *reuse = @"CNBaiduPin";
    BMKPinAnnotationView *pin = (BMKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:reuse];
    if (pin == nil) pin = [[BMKPinAnnotationView alloc] initWithAnnotation:marker reuseIdentifier:reuse];
    else pin.annotation = marker;
    if (marker.pinColor != nil) pin.pinColor = CNBaiduPinColor(marker.pinColor);
    view = pin;
  }
  view.draggable = marker.draggable;
  view.centerOffset = CGPointMake(marker.centerOffset.x, marker.centerOffset.y);
  view.alpha = marker.markerOpacity;
  view.transform = CGAffineTransformMakeRotation(marker.rotationDegrees * M_PI / 180.0);
  return view;
}

- (void)mapViewDidFinishLoading:(BMKMapView *)mapView
{
  _mapReady = YES;
  [self applyPendingInitialViewport];
  [self.delegate mapAdapterDidBecomeReady:self];
}

- (void)mapView:(BMKMapView *)mapView onClickedMapBlank:(CLLocationCoordinate2D)coordinate
{
  [self.delegate mapAdapter:self didTapAtCoordinate:coordinate];
}

- (void)mapView:(BMKMapView *)mapView onClickedMapPoi:(BMKMapPoi *)mapPoi
{
  CNPoi *poi = [CNPoi new];
  poi.placeId = mapPoi.uid;
  poi.name = mapPoi.text;
  poi.coordinate = mapPoi.pt;
  [self.delegate mapAdapter:self didTapPoi:poi];
}

- (void)mapView:(BMKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
  [self.delegate mapAdapter:self didChangeRegionComplete:YES isGesture:YES];
}

- (void)mapView:(BMKMapView *)mapView mapStatusDidChanged:(BMKMapStatus *)mapStatus
{
  [self.delegate mapAdapter:self didChangeRegionComplete:NO isGesture:YES];
}

- (void)mapView:(BMKMapView *)mapView didUpdateUserLocation:(BMKUserLocation *)userLocation
{
  CLLocation *location = userLocation.location;
  if (location) [self.delegate mapAdapter:self didUpdateUserLocation:location];
}

- (void)mapView:(BMKMapView *)mapView didSelectAnnotationView:(BMKAnnotationView *)view
{
  if (![view.annotation isKindOfClass:[CNBaiduAnnotation class]]) return;
  CNBaiduAnnotation *a = (CNBaiduAnnotation *)view.annotation;
  [self deliverMarkerEvent:CNMarkerEventPress forAnnotation:a];
  [self deliverMarkerEvent:CNMarkerEventSelect forAnnotation:a];
}

- (void)mapView:(BMKMapView *)mapView didDeselectAnnotationView:(BMKAnnotationView *)view
{
  if ([view.annotation isKindOfClass:[CNBaiduAnnotation class]]) {
    [self deliverMarkerEvent:CNMarkerEventDeselect forAnnotation:(CNBaiduAnnotation *)view.annotation];
  }
}

- (void)mapView:(BMKMapView *)mapView annotationView:(BMKAnnotationView *)view
 didChangeDragState:(NSUInteger)newState fromOldState:(NSUInteger)oldState
{
  if (![view.annotation isKindOfClass:[CNBaiduAnnotation class]]) return;
  CNBaiduAnnotation *a = (CNBaiduAnnotation *)view.annotation;
  // BMKAnnotationViewDragState: Starting=1, Dragging=2, Ending=3 (VERIFY enum).
  switch (newState) {
    case 1: [self deliverMarkerEvent:CNMarkerEventDragStart forAnnotation:a]; break;
    case 2: [self deliverMarkerEvent:CNMarkerEventDrag forAnnotation:a]; break;
    case 3: [self deliverMarkerEvent:CNMarkerEventDragEnd forAnnotation:a]; break;
    default: break;
  }
}

- (void)deliverMarkerEvent:(CNMarkerEventKind)kind forAnnotation:(CNBaiduAnnotation *)annotation
{
  if (self.delegate == nil || annotation.childId == nil) return;
  [self.delegate mapAdapter:self markerChildId:annotation.childId didFireEvent:kind atCoordinate:annotation.coordinate];
}

@end
