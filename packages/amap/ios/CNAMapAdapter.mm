#import "CNAMapAdapter.h"
#import "CNMapAdapterRegistry.h"

#import <MAMapKit/MAMapKit.h>
#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapSearchKit/AMapSearchKit.h>
#import <QuartzCore/QuartzCore.h>

#include <vector>

#pragma mark - Provider helpers

static MAPinAnnotationColor CNPinColor(NSString *color)
{
  NSString *lowercase = [color lowercaseString];
  if ([lowercase containsString:@"green"] || [lowercase isEqualToString:@"#00ff00"]) {
    return MAPinAnnotationColorGreen;
  }
  if ([lowercase containsString:@"purple"] || [lowercase containsString:@"violet"]) {
    return MAPinAnnotationColorPurple;
  }
  return MAPinAnnotationColorRed;
}

static MAMapType CNMapTypeFromOptions(NSString *mapType, NSString *userInterfaceStyle)
{
  // AMap iOS has no dedicated hybrid/terrain/none surface; everything that is not
  // explicitly satellite collapses to the standard basemap (best-effort).
  MAMapType type = MAMapTypeStandard;
  if ([mapType isEqualToString:@"satellite"] || [mapType isEqualToString:@"hybrid"]) {
    type = MAMapTypeSatellite;
  }
  if (type == MAMapTypeStandard && [userInterfaceStyle isEqualToString:@"dark"]) {
    type = MAMapTypeStandardNight;
  }
  return type;
}

static MALineCapType CNLineCapType(NSString *cap)
{
  if ([cap isEqualToString:@"round"]) {
    return kMALineCapRound;
  }
  if ([cap isEqualToString:@"square"]) {
    return kMALineCapSquare;
  }
  return kMALineCapButt;
}

static MALineJoinType CNLineJoinType(NSString *join)
{
  if ([join isEqualToString:@"round"]) {
    return kMALineJoinRound;
  }
  if ([join isEqualToString:@"bevel"]) {
    return kMALineJoinBevel;
  }
  return kMALineJoinMiter;
}

static std::vector<CLLocationCoordinate2D> CNUnboxCoordinates(NSArray<NSValue *> *values)
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

// MAPointAnnotation carrying the marker's identity/appearance plus the childId the
// adapter uses to route callbacks back to the owning child. This is the AMap-side
// home of what used to be RNMapsMarkerAnnotation.
@interface CNAMapAnnotation : MAPointAnnotation
@property (nonatomic, copy, nullable) NSString *childId;
@property (nonatomic, copy, nullable) NSString *markerIdentifier;
@property (nonatomic, copy, nullable) NSString *pinColor;
@property (nonatomic, assign) BOOL draggable;
@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, assign) CGPoint centerOffset;
@property (nonatomic, assign) CGPoint calloutOffset;
@property (nonatomic, assign) CGFloat markerOpacity;
@property (nonatomic, assign) CGFloat rotationDegrees;
@property (nonatomic, assign) double zIndex;
@property (nonatomic, assign) BOOL hasCustomCallout;
@property (nonatomic, strong, nullable) UIImage *calloutImage;
// animateMarkerToCoordinate interpolation state.
@property (nonatomic, assign) CLLocationCoordinate2D animStart;
@property (nonatomic, assign) CLLocationCoordinate2D animTarget;
@property (nonatomic, assign) CFTimeInterval animStartTime;
@property (nonatomic, assign) CFTimeInterval animDuration;
- (void)applyModel:(CNMarkerModel *)model childId:(NSString *)childId;
- (void)applyAppearanceToView:(MAAnnotationView *)view;
@end

@implementation CNAMapAnnotation

- (void)applyModel:(CNMarkerModel *)model childId:(NSString *)childId
{
  self.childId = childId;
  self.markerIdentifier = model.identifier;
  // coordinate/title/subtitle are KVO-observed by MAMapView, so live updates after
  // the annotation is on the map reflect automatically.
  self.coordinate = model.coordinate;
  self.title = model.title;
  self.subtitle = model.subtitle;
  self.pinColor = model.pinColor;
  self.draggable = model.draggable;
  self.image = model.image;
  self.centerOffset = model.centerOffset;
  self.calloutOffset = model.calloutOffset;
  self.markerOpacity = model.opacity;
  self.rotationDegrees = model.rotationDegrees;
  self.zIndex = model.zIndex;
  self.hasCustomCallout = model.hasCustomCallout;
  self.calloutImage = model.calloutImage;
}

- (void)applyAppearanceToView:(MAAnnotationView *)view
{
  view.canShowCallout = !self.hasCustomCallout;
  view.draggable = self.draggable;
  view.centerOffset = self.centerOffset;
  view.calloutOffset = self.calloutOffset;
  view.alpha = self.markerOpacity;
  view.transform = CGAffineTransformMakeRotation(self.rotationDegrees * M_PI / 180.0);
  view.layer.zPosition = self.zIndex;
}

@end

#pragma mark - Tile overlays

// WMS GetMap tile overlay: substitutes the tile's EPSG:3857 bbox into the template.
@interface CNWMSTileOverlay : MATileOverlay
@property (nonatomic, copy, nullable) NSString *wmsTemplate;
@end

@implementation CNWMSTileOverlay
- (NSURL *)URLForTilePath:(MATileOverlayPath)path
{
  if (self.wmsTemplate == nil) {
    return nil;
  }
  double m = 20037508.342789244;
  double tileMeters = (2 * m) / (double)(1 << path.z);
  double minX = -m + path.x * tileMeters;
  double maxX = -m + (path.x + 1) * tileMeters;
  double maxY = m - path.y * tileMeters;
  double minY = m - (path.y + 1) * tileMeters;
  NSInteger size = (NSInteger)self.tileSize.width;
  NSString *url = self.wmsTemplate;
  url = [url stringByReplacingOccurrencesOfString:@"{minX}" withString:[@(minX) stringValue]];
  url = [url stringByReplacingOccurrencesOfString:@"{minY}" withString:[@(minY) stringValue]];
  url = [url stringByReplacingOccurrencesOfString:@"{maxX}" withString:[@(maxX) stringValue]];
  url = [url stringByReplacingOccurrencesOfString:@"{maxY}" withString:[@(maxY) stringValue]];
  url = [url stringByReplacingOccurrencesOfString:@"{width}" withString:[@(size) stringValue]];
  url = [url stringByReplacingOccurrencesOfString:@"{height}" withString:[@(size) stringValue]];
  return [NSURL URLWithString:url];
}
@end

// Local file tile overlay: loads tiles from a {x}/{y}/{z} file path template.
@interface CNLocalTileOverlay : MATileOverlay
@property (nonatomic, copy, nullable) NSString *pathTemplate;
@end

@implementation CNLocalTileOverlay
- (void)loadTileAtPath:(MATileOverlayPath)path
                result:(void (^)(NSData *_Nullable, NSError *_Nullable))result
{
  if (self.pathTemplate == nil) {
    result(nil, nil);
    return;
  }
  NSString *file = self.pathTemplate;
  file = [file stringByReplacingOccurrencesOfString:@"{x}" withString:[@(path.x) stringValue]];
  file = [file stringByReplacingOccurrencesOfString:@"{y}" withString:[@(path.y) stringValue]];
  file = [file stringByReplacingOccurrencesOfString:@"{z}" withString:[@(path.z) stringValue]];
  result([NSData dataWithContentsOfFile:file], nil);
}
@end

#pragma mark - Adapter

@interface CNAMapAdapter () <MAMapViewDelegate, AMapSearchDelegate>
@end

@implementation CNAMapAdapter {
  MAMapView *_mapView;
  BOOL _mapReady;
  BOOL _isGesture;

  // Reverse geocoding (AMapSearch). The delegate is single, so completions are
  // keyed by the request pointer; `_geocodeRequests` keeps the requests alive.
  AMapSearchAPI *_geocodeSearch;
  NSMutableDictionary<NSValue *, id> *_geocodeCompletions;
  NSMutableArray<AMapReGeocodeSearchRequest *> *_geocodeRequests;

  CNMapOptions *_lastOptions;

  // Deferred initial viewport (applied once ready & sized; camera supersedes region).
  BOOL _hasPendingInitialRegion;
  BOOL _hasPendingInitialCamera;
  BOOL _initialRegionApplied;
  BOOL _initialCameraApplied;
  CNRegion _pendingInitialRegion;
  CNCamera _pendingInitialCamera;

  // Active markers / overlays (handle keeps the SDK object; model drives rendering).
  NSMutableArray<CNOverlayHandle *> *_markerHandles;
  NSMutableArray<CNOverlayHandle *> *_overlayHandles;
  NSMapTable<CNOverlayHandle *, CNOverlayModel *> *_overlayModels;

  // Currently presented custom callout (single selection at a time).
  UIImageView *_presentedCalloutView;
  CNAMapAnnotation *_presentedCalloutAnnotation;

  // Marker coordinate animations.
  NSMutableSet<CNAMapAnnotation *> *_animatingAnnotations;
  CADisplayLink *_animationLink;
}

@synthesize delegate = _delegate;

// Self-register so the host can create the adapter via the registry without ever
// naming a concrete provider class. (In M2 this same hook lives in the amap pkg.)
+ (void)load
{
  [CNMapAdapterRegistry registerAdapterClass:self];
}

+ (NSString *)providerName
{
  return @"amap";
}

- (NSString *)providerName
{
  return [[self class] providerName];
}

- (instancetype)init
{
  if (self = [super init]) {
    _mapView = [[MAMapView alloc] initWithFrame:CGRectZero];
    _mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _mapView.delegate = self;
    _mapView.zoomEnabled = YES;
    _mapView.scrollEnabled = YES;
    _mapView.rotateEnabled = YES;
    _mapView.rotateCameraEnabled = YES;

    _markerHandles = [NSMutableArray array];
    _overlayHandles = [NSMutableArray array];
    _overlayModels = [NSMapTable strongToStrongObjectsMapTable];
    _animatingAnnotations = [NSMutableSet set];
  }
  return self;
}

- (UIView *)mapView
{
  return _mapView;
}

- (void)teardown
{
  [self stopAllAnimations];
  _mapView.delegate = nil;
}

- (void)reset
{
  [self stopAllAnimations];
  [_animatingAnnotations removeAllObjects];
  [self dismissPresentedCallout];

  for (CNOverlayHandle *handle in _markerHandles) {
    if (handle.sdkObject != nil) {
      [_mapView removeAnnotation:handle.sdkObject];
    }
  }
  [_markerHandles removeAllObjects];

  for (CNOverlayHandle *handle in _overlayHandles) {
    if (handle.sdkObject != nil) {
      [_mapView removeOverlay:handle.sdkObject];
    }
  }
  [_overlayHandles removeAllObjects];
  [_overlayModels removeAllObjects];

  _lastOptions = nil;
  _isGesture = NO;
  _mapReady = NO;
  _hasPendingInitialRegion = NO;
  _hasPendingInitialCamera = NO;
  _initialRegionApplied = NO;
  _initialCameraApplied = NO;
}

- (BOOL)isReady
{
  return _mapReady;
}

#pragma mark Configuration

- (void)applyOptions:(CNMapOptions *)options
{
  if (_lastOptions == nil ||
      ![_lastOptions.mapType isEqualToString:options.mapType] ||
      ![_lastOptions.userInterfaceStyle isEqualToString:options.userInterfaceStyle]) {
    _mapView.mapType = CNMapTypeFromOptions(options.mapType, options.userInterfaceStyle);
  }

  if (_lastOptions == nil || _lastOptions.minZoomLevel != options.minZoomLevel) {
    _mapView.minZoomLevel = options.minZoomLevel;
  }
  if (_lastOptions == nil || _lastOptions.maxZoomLevel != options.maxZoomLevel) {
    _mapView.maxZoomLevel = options.maxZoomLevel;
  }

  // showsUserLocation re-arms Core Location, so only assign it on change. The rest
  // are idempotent visual setters and stay unconditional (parity with H1).
  if (_lastOptions == nil || _lastOptions.showsUserLocation != options.showsUserLocation) {
    _mapView.showsUserLocation = options.showsUserLocation;
  }
  _mapView.showsCompass = options.showsCompass;
  _mapView.showsScale = options.showsScale;
  _mapView.showTraffic = options.showsTraffic;
  _mapView.showsBuildings = options.showsBuildings;
  _mapView.showsIndoorMap = options.showsIndoors;
  _mapView.showsLabels = options.showsPointsOfInterest;

  _mapView.zoomEnabled = options.zoomEnabled;
  _mapView.scrollEnabled = options.scrollEnabled;
  _mapView.rotateEnabled = options.rotateEnabled;
  _mapView.rotateCameraEnabled = options.pitchEnabled;

  _lastOptions = options;
}

#pragma mark Viewport

- (void)setRegionLatitude:(double)latitude
                longitude:(double)longitude
            latitudeDelta:(double)latitudeDelta
           longitudeDelta:(double)longitudeDelta
                 animated:(BOOL)animated
{
  MACoordinateRegion region = MACoordinateRegionMake(
    CLLocationCoordinate2DMake(latitude, longitude),
    MACoordinateSpanMake(latitudeDelta, longitudeDelta));
  [_mapView setRegion:region animated:animated];
}

- (void)setCameraLatitude:(double)latitude
                longitude:(double)longitude
                  heading:(double)heading
                    pitch:(double)pitch
                     zoom:(double)zoom
                 animated:(BOOL)animated
                 duration:(NSTimeInterval)duration
{
  if (latitude != 0.0 || longitude != 0.0) {
    [_mapView setCenterCoordinate:CLLocationCoordinate2DMake(latitude, longitude) animated:animated];
  }
  if (std::isfinite(zoom) && zoom > 0) {
    [_mapView setZoomLevel:zoom animated:animated];
  }
  [_mapView setRotationDegree:heading animated:animated duration:duration];
  [_mapView setCameraDegree:pitch animated:animated duration:duration];
}

- (void)setPendingInitialRegionLatitude:(double)latitude
                              longitude:(double)longitude
                          latitudeDelta:(double)latitudeDelta
                         longitudeDelta:(double)longitudeDelta
{
  if (_initialRegionApplied || _hasPendingInitialRegion) {
    return;
  }
  _pendingInitialRegion = (CNRegion){latitude, longitude, latitudeDelta, longitudeDelta};
  _hasPendingInitialRegion = YES;
  [self applyPendingInitialViewport];
}

- (void)setPendingInitialCameraLatitude:(double)latitude
                              longitude:(double)longitude
                                heading:(double)heading
                                  pitch:(double)pitch
                                   zoom:(double)zoom
{
  if (_initialCameraApplied || _hasPendingInitialCamera) {
    return;
  }
  _pendingInitialCamera = (CNCamera){latitude, longitude, heading, pitch, zoom, 0};
  _hasPendingInitialCamera = YES;
  [self applyPendingInitialViewport];
}

- (void)didLayout
{
  [self applyPendingInitialViewport];
}

// Apply the captured initial viewport once the engine is ready AND the view has a
// real size. setRegion on a zero-size or not-yet-ready map drops the span (zoom).
- (void)applyPendingInitialViewport
{
  if (!_mapReady || CGRectIsEmpty(_mapView.bounds)) {
    return;
  }
  if (_hasPendingInitialCamera && !_initialCameraApplied) {
    _mapView.centerCoordinate =
      CLLocationCoordinate2DMake(_pendingInitialCamera.latitude, _pendingInitialCamera.longitude);
    if (std::isfinite(_pendingInitialCamera.zoom) && _pendingInitialCamera.zoom > 0) {
      _mapView.zoomLevel = _pendingInitialCamera.zoom;
    }
    _mapView.rotationDegree = _pendingInitialCamera.heading;
    _mapView.cameraDegree = _pendingInitialCamera.pitch;
    _initialCameraApplied = YES;
    _initialRegionApplied = YES; // camera supersedes region
  } else if (_hasPendingInitialRegion && !_initialRegionApplied) {
    [_mapView setRegion:MACoordinateRegionMake(
                          CLLocationCoordinate2DMake(_pendingInitialRegion.latitude,
                                                     _pendingInitialRegion.longitude),
                          MACoordinateSpanMake(_pendingInitialRegion.latitudeDelta,
                                               _pendingInitialRegion.longitudeDelta))
               animated:NO];
    _initialRegionApplied = YES;
  }
}

- (CNRegion)currentRegion
{
  MACoordinateRegion region = _mapView.region;
  return (CNRegion){
    region.center.latitude, region.center.longitude,
    region.span.latitudeDelta, region.span.longitudeDelta};
}

- (CNCamera)currentCamera
{
  return (CNCamera){
    _mapView.centerCoordinate.latitude, _mapView.centerCoordinate.longitude,
    _mapView.rotationDegree, _mapView.cameraDegree, _mapView.zoomLevel, 0};
}

- (void)fitToCoordinates:(NSArray<NSValue *> *)coordinates
             edgePadding:(UIEdgeInsets)edgePadding
                animated:(BOOL)animated
{
  MAMapRect zoomRect = MAMapRectNull;
  for (NSValue *value in coordinates) {
    CLLocationCoordinate2D coordinate;
    [value getValue:&coordinate];
    MAMapPoint point = MAMapPointForCoordinate(coordinate);
    MAMapRect pointRect = MAMapRectMake(point.x, point.y, 0.1, 0.1);
    zoomRect = MAMapRectIsNull(zoomRect) ? pointRect : MAMapRectUnion(zoomRect, pointRect);
  }
  if (MAMapRectIsNull(zoomRect)) {
    return;
  }
  [_mapView setVisibleMapRect:zoomRect edgePadding:edgePadding animated:animated];
}

- (void)fitToElementsAnimated:(BOOL)animated
{
  [_mapView showAnnotations:_mapView.annotations animated:animated];
}

- (void)fitToMarkers:(NSArray<CNOverlayHandle *> *)handles
         edgePadding:(UIEdgeInsets)edgePadding
            animated:(BOOL)animated
{
  NSMutableArray *annotations = [NSMutableArray array];
  for (CNOverlayHandle *handle in handles) {
    if (handle.sdkObject != nil) {
      [annotations addObject:handle.sdkObject];
    }
  }
  if (annotations.count > 0) {
    [_mapView showAnnotations:annotations animated:animated];
  }
}

- (void)setLimitRegionNELatitude:(double)neLatitude
                     neLongitude:(double)neLongitude
                      swLatitude:(double)swLatitude
                     swLongitude:(double)swLongitude
{
  CLLocationCoordinate2D center = CLLocationCoordinate2DMake(
    (neLatitude + swLatitude) / 2.0, (neLongitude + swLongitude) / 2.0);
  MACoordinateSpan span = MACoordinateSpanMake(
    fabs(neLatitude - swLatitude), fabs(neLongitude - swLongitude));
  _mapView.limitRegion = MACoordinateRegionMake(center, span);
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

- (void)takeSnapshotWidth:(NSInteger)width
                   height:(NSInteger)height
                   format:(NSString *)format
                  quality:(double)quality
                   result:(NSString *)result
               completion:(void (^)(NSString *))completion
{
  [_mapView takeSnapshotInRect:_mapView.bounds
          withCompletionBlock:^(UIImage *image, NSInteger state) {
    // state != 1 is an intermediate (still-rendering) callback; wait for the final.
    if (state != 1) {
      return;
    }
    if (image == nil) {
      completion(@"");
      return;
    }

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
    if (data != nil) {
      if ([result isEqualToString:@"base64"]) {
        uri = [data base64EncodedStringWithOptions:0];
      } else {
        NSString *ext = isJpg ? @"jpg" : @"png";
        NSString *name = [NSString stringWithFormat:@"map-snapshot-%@.%@",
                          @((NSUInteger)(CACurrentMediaTime() * 1000)), ext];
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
        if ([data writeToFile:path atomically:YES]) {
          uri = [@"file://" stringByAppendingString:path];
        }
      }
    }
    completion(uri);
  }];
}

#pragma mark Geocoding

- (void)addressForCoordinate:(CLLocationCoordinate2D)coordinate
                  completion:(void (^)(NSDictionary *_Nullable))completion
{
  if (_geocodeSearch == nil) {
    _geocodeSearch = [[AMapSearchAPI alloc] init];
    _geocodeSearch.delegate = self;
    _geocodeCompletions = [NSMutableDictionary dictionary];
    _geocodeRequests = [NSMutableArray array];
  }
  AMapReGeocodeSearchRequest *request = [[AMapReGeocodeSearchRequest alloc] init];
  request.location = [AMapGeoPoint locationWithLatitude:coordinate.latitude
                                              longitude:coordinate.longitude];
  request.requireExtension = YES;
  NSValue *key = [NSValue valueWithNonretainedObject:request];
  _geocodeCompletions[key] = [completion copy];
  [_geocodeRequests addObject:request];
  [_geocodeSearch AMapReGoecodeSearch:request];
}

- (void)resolveGeocodeRequest:(id)request withAddress:(NSDictionary *)address
{
  NSValue *key = [NSValue valueWithNonretainedObject:request];
  void (^completion)(NSDictionary *) = _geocodeCompletions[key];
  [_geocodeCompletions removeObjectForKey:key];
  if (request != nil) {
    [_geocodeRequests removeObject:request];
  }
  if (completion != nil) {
    completion(address);
  }
}

- (void)onReGeocodeSearchDone:(AMapReGeocodeSearchRequest *)request
                     response:(AMapReGeocodeSearchResponse *)response
{
  AMapReGeocode *regeocode = response.regeocode;
  if (regeocode == nil) {
    [self resolveGeocodeRequest:request withAddress:@{}];
    return;
  }
  AMapAddressComponent *c = regeocode.addressComponent;
  NSString *city = c.city.length > 0 ? c.city : (c.province ?: @"");
  [self resolveGeocodeRequest:request
                  withAddress:@{
                    @"name" : regeocode.formattedAddress ?: @"",
                    @"thoroughfare" : c.streetNumber.street ?: (c.township ?: @""),
                    @"subThoroughfare" : c.streetNumber.number ?: @"",
                    @"locality" : city,
                    @"subLocality" : c.district ?: @"",
                    @"administrativeArea" : c.province ?: @"",
                    @"subAdministrativeArea" : c.district ?: @"",
                    @"postalCode" : @"",
                    @"countryCode" : @"CN",
                    @"country" : @"中国",
                  }];
}

- (void)AMapSearchRequest:(id)request didFailWithError:(NSError *)error
{
  [self resolveGeocodeRequest:request withAddress:@{}];
}

#pragma mark Markers

- (CNOverlayHandle *)addMarker:(CNMarkerModel *)model childId:(NSString *)childId
{
  CNOverlayHandle *handle = [[CNOverlayHandle alloc] initWithChildId:childId];
  CNAMapAnnotation *annotation = [CNAMapAnnotation new];
  [annotation applyModel:model childId:childId];
  handle.sdkObject = annotation;
  [_markerHandles addObject:handle];
  [_mapView addAnnotation:annotation];
  return handle;
}

- (void)updateMarker:(CNOverlayHandle *)handle model:(CNMarkerModel *)model
{
  CNAMapAnnotation *annotation = handle.sdkObject;
  if (annotation == nil) {
    return;
  }
  [annotation applyModel:model childId:handle.childId];
  [self refreshAnnotationView:annotation];
}

// Swap the annotation view class (pin↔image) by re-adding when the kind changes,
// otherwise refresh the image/appearance in place to avoid flicker (parity with
// the old markerImageDidChange).
- (void)refreshAnnotationView:(CNAMapAnnotation *)annotation
{
  MAAnnotationView *current = [_mapView viewForAnnotation:annotation];
  BOOL wantsImageView = annotation.image != nil;
  BOOL isImageView = current != nil && ![current isKindOfClass:[MAPinAnnotationView class]];

  if (current == nil || wantsImageView != isImageView) {
    [_mapView removeAnnotation:annotation];
    [_mapView addAnnotation:annotation];
  } else if (wantsImageView) {
    current.image = annotation.image;
    [annotation applyAppearanceToView:current];
  } else {
    [annotation applyAppearanceToView:current];
  }
}

- (void)removeMarker:(CNOverlayHandle *)handle
{
  CNAMapAnnotation *annotation = handle.sdkObject;
  if (annotation != nil) {
    [_animatingAnnotations removeObject:annotation];
    if (_presentedCalloutAnnotation == annotation) {
      [self dismissPresentedCallout];
    }
    [_mapView removeAnnotation:annotation];
  }
  [_markerHandles removeObject:handle];
}

- (void)selectMarker:(CNOverlayHandle *)handle animated:(BOOL)animated
{
  if (handle.sdkObject != nil) {
    [_mapView selectAnnotation:handle.sdkObject animated:animated];
  }
}

- (void)deselectMarker:(CNOverlayHandle *)handle animated:(BOOL)animated
{
  if (handle.sdkObject != nil) {
    [_mapView deselectAnnotation:handle.sdkObject animated:animated];
  }
}

- (void)redrawCalloutForMarker:(CNOverlayHandle *)handle
{
  id annotation = handle.sdkObject;
  if (annotation != nil) {
    [_mapView deselectAnnotation:annotation animated:NO];
    [_mapView selectAnnotation:annotation animated:NO];
  }
}

- (void)animateMarker:(CNOverlayHandle *)handle
           toLatitude:(double)latitude
            longitude:(double)longitude
             duration:(NSInteger)duration
{
  CNAMapAnnotation *annotation = handle.sdkObject;
  if (annotation == nil) {
    return;
  }
  [_animatingAnnotations removeObject:annotation];

  CLLocationCoordinate2D target = CLLocationCoordinate2DMake(latitude, longitude);
  if (duration <= 0) {
    annotation.coordinate = target;
    return;
  }
  annotation.animStart = annotation.coordinate;
  annotation.animTarget = target;
  annotation.animStartTime = CACurrentMediaTime();
  annotation.animDuration = duration / 1000.0; // RNM duration is milliseconds
  [_animatingAnnotations addObject:annotation];

  if (_animationLink == nil) {
    _animationLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(stepAnimations:)];
    [_animationLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
  }
}

- (void)stepAnimations:(CADisplayLink *)link
{
  CFTimeInterval now = CACurrentMediaTime();
  for (CNAMapAnnotation *annotation in [_animatingAnnotations copy]) {
    double progress = (now - annotation.animStartTime) / annotation.animDuration;
    if (progress >= 1.0) {
      progress = 1.0;
    }
    annotation.coordinate = CLLocationCoordinate2DMake(
      annotation.animStart.latitude +
        (annotation.animTarget.latitude - annotation.animStart.latitude) * progress,
      annotation.animStart.longitude +
        (annotation.animTarget.longitude - annotation.animStart.longitude) * progress);
    if (progress >= 1.0) {
      [_animatingAnnotations removeObject:annotation];
    }
  }
  if (_animatingAnnotations.count == 0) {
    [self stopAllAnimations];
  }
}

- (void)stopAllAnimations
{
  [_animationLink invalidate];
  _animationLink = nil;
}

- (CGPoint)pointForMarker:(CNOverlayHandle *)handle
{
  CNAMapAnnotation *annotation = handle.sdkObject;
  if (annotation == nil) {
    return CGPointZero;
  }
  return [_mapView convertCoordinate:annotation.coordinate toPointToView:_mapView];
}

#pragma mark Overlays

- (CNOverlayHandle *)addOverlay:(CNOverlayModel *)model childId:(NSString *)childId
{
  CNOverlayHandle *handle = [[CNOverlayHandle alloc] initWithChildId:childId];
  id<MAOverlay> overlay = [self buildOverlay:model];
  handle.sdkObject = overlay;
  [_overlayHandles addObject:handle];
  [_overlayModels setObject:model forKey:handle];
  if (overlay != nil) {
    [_mapView addOverlay:overlay];
  }
  return handle;
}

- (void)updateOverlay:(CNOverlayHandle *)handle model:(CNOverlayModel *)model
{
  id<MAOverlay> previous = handle.sdkObject;
  id<MAOverlay> overlay = [self buildOverlay:model];
  handle.sdkObject = overlay;
  [_overlayModels setObject:model forKey:handle];
  // Re-add so the map rebuilds the renderer with the latest styling/geometry.
  if (previous != nil) {
    [_mapView removeOverlay:previous];
  }
  if (overlay != nil) {
    [_mapView addOverlay:overlay];
  }
}

- (void)removeOverlay:(CNOverlayHandle *)handle
{
  if (handle.sdkObject != nil) {
    [_mapView removeOverlay:handle.sdkObject];
  }
  [_overlayHandles removeObject:handle];
  [_overlayModels removeObjectForKey:handle];
}

- (nullable id<MAOverlay>)buildOverlay:(CNOverlayModel *)model
{
  switch (model.type) {
    case CNOverlayTypePolyline:
      return [self buildPolyline:(CNPolylineModel *)model];
    case CNOverlayTypePolygon:
      return [self buildPolygon:(CNPolygonModel *)model];
    case CNOverlayTypeCircle:
      return [self buildCircle:(CNCircleModel *)model];
    case CNOverlayTypeHeatmap:
      return [self buildHeatmap:(CNHeatmapModel *)model];
    case CNOverlayTypeUrlTile:
      return [self buildUrlTile:(CNUrlTileModel *)model];
    case CNOverlayTypeLocalTile:
      return [self buildLocalTile:(CNLocalTileModel *)model];
    case CNOverlayTypeGroundOverlay:
      return [self buildGroundOverlay:(CNGroundOverlayModel *)model];
  }
  return nil;
}

- (nullable id<MAOverlay>)buildPolyline:(CNPolylineModel *)model
{
  std::vector<CLLocationCoordinate2D> points = CNUnboxCoordinates(model.coordinates);
  NSUInteger count = points.size();
  if (count == 0) {
    return nil;
  }
  if (model.strokeColors.count > 1 && count >= 2) {
    NSUInteger segments = count - 1;
    NSUInteger numColors = model.strokeColors.count;
    NSMutableArray<NSNumber *> *drawStyleIndexes = [NSMutableArray arrayWithCapacity:segments];
    for (NSUInteger i = 0; i < segments; i++) {
      NSUInteger idx = (i * numColors) / segments;
      if (idx >= numColors) {
        idx = numColors - 1;
      }
      [drawStyleIndexes addObject:@(idx)];
    }
    return [MAMultiPolyline polylineWithCoordinates:points.data()
                                              count:count
                                   drawStyleIndexes:drawStyleIndexes];
  }
  return [MAPolyline polylineWithCoordinates:points.data() count:count];
}

- (nullable id<MAOverlay>)buildPolygon:(CNPolygonModel *)model
{
  std::vector<CLLocationCoordinate2D> points = CNUnboxCoordinates(model.coordinates);
  NSUInteger count = points.size();
  if (count == 0) {
    return nil;
  }
  MAPolygon *polygon = [MAPolygon polygonWithCoordinates:points.data() count:count];
  if (model.holes.count > 0) {
    NSMutableArray<MAPolygon *> *holes = [NSMutableArray array];
    for (NSArray<NSValue *> *ring in model.holes) {
      std::vector<CLLocationCoordinate2D> ringPoints = CNUnboxCoordinates(ring);
      if (!ringPoints.empty()) {
        [holes addObject:[MAPolygon polygonWithCoordinates:ringPoints.data()
                                                     count:ringPoints.size()]];
      }
    }
    if (holes.count > 0) {
      polygon.hollowShapes = holes;
    }
  }
  return polygon;
}

- (nullable id<MAOverlay>)buildCircle:(CNCircleModel *)model
{
  return [MACircle circleWithCenterCoordinate:model.center radius:model.radius];
}

- (nullable id<MAOverlay>)buildHeatmap:(CNHeatmapModel *)model
{
  std::vector<CLLocationCoordinate2D> points = CNUnboxCoordinates(model.points);
  if (points.empty()) {
    return nil;
  }
  NSMutableArray<MAHeatMapNode *> *nodes = [NSMutableArray arrayWithCapacity:points.size()];
  for (NSUInteger i = 0; i < points.size(); i++) {
    MAHeatMapNode *node = [[MAHeatMapNode alloc] init];
    node.coordinate = points[i];
    node.intensity = (i < model.weights.count) ? model.weights[i].floatValue : 1.0;
    [nodes addObject:node];
  }
  MAHeatMapTileOverlay *overlay = [[MAHeatMapTileOverlay alloc] init];
  overlay.data = nodes;
  overlay.radius = model.radius > 0 ? model.radius : 20;
  if (model.gradientColors.count > 0 &&
      model.gradientColors.count == model.gradientStartPoints.count) {
    overlay.gradient = [[MAHeatMapGradient alloc] initWithColor:model.gradientColors
                                            andWithStartPoints:model.gradientStartPoints];
  }
  return overlay;
}

- (nullable id<MAOverlay>)buildUrlTile:(CNUrlTileModel *)model
{
  if (model.urlTemplate.length == 0) {
    return nil;
  }
  CGSize size = CGSizeMake(model.tileSize, model.tileSize);
  if (model.wms) {
    CNWMSTileOverlay *overlay = [[CNWMSTileOverlay alloc] init];
    overlay.wmsTemplate = model.urlTemplate;
    overlay.minimumZ = model.minimumZ;
    overlay.maximumZ = model.maximumZ;
    overlay.tileSize = size;
    return overlay;
  }
  MATileOverlay *overlay = [[MATileOverlay alloc] initWithURLTemplate:model.urlTemplate];
  overlay.minimumZ = model.minimumZ;
  overlay.maximumZ = model.maximumZ;
  overlay.tileSize = size;
  return overlay;
}

- (nullable id<MAOverlay>)buildLocalTile:(CNLocalTileModel *)model
{
  if (model.pathTemplate.length == 0) {
    return nil;
  }
  CNLocalTileOverlay *overlay = [[CNLocalTileOverlay alloc] init];
  overlay.pathTemplate = model.pathTemplate;
  NSInteger size = model.tileSize > 0 ? model.tileSize : 256;
  overlay.tileSize = CGSizeMake(size, size);
  return overlay;
}

- (nullable id<MAOverlay>)buildGroundOverlay:(CNGroundOverlayModel *)model
{
  if (model.image == nil) {
    return nil;
  }
  MACoordinateBounds bounds;
  bounds.southWest = model.southWest;
  bounds.northEast = model.northEast;
  return [MAGroundOverlay groundOverlayWithBounds:bounds icon:model.image];
}

#pragma mark Privacy

+ (void)applyPrivacyConsentAgreed:(BOOL)agreed contains:(BOOL)contains shown:(BOOL)shown
{
  [MAMapView updatePrivacyShow:(shown ? AMapPrivacyShowStatusDidShow : AMapPrivacyShowStatusNotShow)
                   privacyInfo:(contains ? AMapPrivacyInfoStatusDidContain : AMapPrivacyInfoStatusNotContain)];
  [MAMapView updatePrivacyAgree:(agreed ? AMapPrivacyAgreeStatusDidAgree : AMapPrivacyAgreeStatusNotAgree)];
}

#pragma mark Callout presentation

- (void)presentCalloutForAnnotation:(CNAMapAnnotation *)annotation inView:(MAAnnotationView *)view
{
  if (!annotation.hasCustomCallout || annotation.calloutImage == nil || view == nil) {
    return;
  }
  [self dismissPresentedCallout];

  UIImage *image = annotation.calloutImage;
  UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
  imageView.userInteractionEnabled = YES;
  imageView.frame = CGRectMake(
    (view.bounds.size.width - image.size.width) / 2.0,
    -image.size.height, image.size.width, image.size.height);

  UITapGestureRecognizer *tap =
    [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleCalloutTap)];
  [imageView addGestureRecognizer:tap];

  [view addSubview:imageView];
  _presentedCalloutView = imageView;
  _presentedCalloutAnnotation = annotation;
}

- (void)dismissPresentedCallout
{
  [_presentedCalloutView removeFromSuperview];
  _presentedCalloutView = nil;
  _presentedCalloutAnnotation = nil;
}

- (void)handleCalloutTap
{
  CNAMapAnnotation *annotation = _presentedCalloutAnnotation;
  if (annotation != nil) {
    [self deliverMarkerEvent:CNMarkerEventCalloutPress forAnnotation:annotation];
  }
}

- (void)deliverMarkerEvent:(CNMarkerEventKind)kind forAnnotation:(CNAMapAnnotation *)annotation
{
  id<CNMapAdapterDelegate> delegate = self.delegate;
  if (delegate == nil || annotation.childId == nil) {
    return;
  }
  [delegate mapAdapter:self
         markerChildId:annotation.childId
          didFireEvent:kind
            atCoordinate:annotation.coordinate];
}

#pragma mark - MAMapViewDelegate

- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation
{
  if (![annotation isKindOfClass:[CNAMapAnnotation class]]) {
    return nil;
  }
  CNAMapAnnotation *marker = (CNAMapAnnotation *)annotation;

  MAAnnotationView *annotationView;
  if (marker.image != nil) {
    static NSString *imageReuseIdentifier = @"CNMarkerImage";
    annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:imageReuseIdentifier];
    if (annotationView == nil) {
      annotationView = [[MAAnnotationView alloc] initWithAnnotation:marker
                                                   reuseIdentifier:imageReuseIdentifier];
    } else {
      annotationView.annotation = marker;
    }
    annotationView.image = marker.image;
  } else {
    static NSString *pinReuseIdentifier = @"CNMarkerPin";
    MAPinAnnotationView *pinView =
      (MAPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:pinReuseIdentifier];
    if (pinView == nil) {
      pinView = [[MAPinAnnotationView alloc] initWithAnnotation:marker
                                               reuseIdentifier:pinReuseIdentifier];
    } else {
      pinView.annotation = marker;
    }
    if (marker.pinColor != nil) {
      pinView.pinColor = CNPinColor(marker.pinColor);
    }
    annotationView = pinView;
  }

  [marker applyAppearanceToView:annotationView];
  return annotationView;
}

- (MAOverlayRenderer *)mapView:(MAMapView *)mapView rendererForOverlay:(id<MAOverlay>)overlay
{
  for (CNOverlayHandle *handle in _overlayHandles) {
    if (handle.sdkObject == overlay) {
      CNOverlayModel *model = [_overlayModels objectForKey:handle];
      return [self rendererForOverlay:overlay model:model];
    }
  }
  return nil;
}

- (nullable MAOverlayRenderer *)rendererForOverlay:(id<MAOverlay>)overlay model:(CNOverlayModel *)model
{
  if (model == nil) {
    return nil;
  }
  switch (model.type) {
    case CNOverlayTypePolyline: {
      CNPolylineModel *m = (CNPolylineModel *)model;
      MAPolylineRenderer *renderer;
      if (m.strokeColors.count > 1 && [overlay isKindOfClass:[MAMultiPolyline class]]) {
        MAMultiColoredPolylineRenderer *multi = [[MAMultiColoredPolylineRenderer alloc]
          initWithMultiPolyline:(MAMultiPolyline *)overlay];
        multi.strokeColors = m.strokeColors;
        multi.gradient = YES;
        renderer = multi;
      } else {
        renderer = [[MAPolylineRenderer alloc] initWithPolyline:(MAPolyline *)overlay];
        renderer.strokeColor = m.strokeColors.count == 1 ? m.strokeColors.firstObject : m.strokeColor;
      }
      renderer.lineWidth = m.strokeWidth;
      renderer.miterLimit = m.miterLimit;
      renderer.lineCapType = CNLineCapType(m.lineCap);
      renderer.lineJoinType = CNLineJoinType(m.lineJoin);
      if (m.lineDashPattern.count > 0) {
        renderer.lineDashType = kMALineDashTypeSquare;
      }
      return renderer;
    }
    case CNOverlayTypePolygon: {
      CNPolygonModel *m = (CNPolygonModel *)model;
      MAPolygonRenderer *renderer =
        [[MAPolygonRenderer alloc] initWithPolygon:(MAPolygon *)overlay];
      renderer.strokeColor = m.strokeColor;
      renderer.fillColor = m.fillColor;
      renderer.lineWidth = m.strokeWidth;
      return renderer;
    }
    case CNOverlayTypeCircle: {
      CNCircleModel *m = (CNCircleModel *)model;
      MACircleRenderer *renderer = [[MACircleRenderer alloc] initWithCircle:(MACircle *)overlay];
      renderer.strokeColor = m.strokeColor;
      renderer.fillColor = m.fillColor;
      renderer.lineWidth = m.strokeWidth;
      return renderer;
    }
    case CNOverlayTypeHeatmap:
    case CNOverlayTypeLocalTile: {
      return [[MATileOverlayRenderer alloc] initWithTileOverlay:(MATileOverlay *)overlay];
    }
    case CNOverlayTypeUrlTile: {
      CNUrlTileModel *m = (CNUrlTileModel *)model;
      MATileOverlayRenderer *renderer =
        [[MATileOverlayRenderer alloc] initWithTileOverlay:(MATileOverlay *)overlay];
      renderer.alpha = m.opacity;
      return renderer;
    }
    case CNOverlayTypeGroundOverlay: {
      CNGroundOverlayModel *m = (CNGroundOverlayModel *)model;
      MAGroundOverlayRenderer *renderer =
        [[MAGroundOverlayRenderer alloc] initWithGroundOverlay:(MAGroundOverlay *)overlay];
      renderer.alpha = m.opacity;
      return renderer;
    }
  }
  return nil;
}

- (void)mapInitComplete:(MAMapView *)mapView
{
  _mapReady = YES;
  [self applyPendingInitialViewport];
  [self.delegate mapAdapterDidBecomeReady:self];
}

- (void)mapView:(MAMapView *)mapView didSingleTappedAtCoordinate:(CLLocationCoordinate2D)coordinate
{
  [self.delegate mapAdapter:self didTapAtCoordinate:coordinate];
}

- (void)mapView:(MAMapView *)mapView didTouchPois:(NSArray<MATouchPoi *> *)pois
{
  if (pois.count == 0) {
    return;
  }
  MATouchPoi *poi = pois.firstObject;
  CNPoi *result = [CNPoi new];
  result.placeId = poi.uid;
  result.name = poi.name;
  result.coordinate = poi.coordinate;
  [self.delegate mapAdapter:self didTapPoi:result];
}

- (void)mapView:(MAMapView *)mapView
  didUpdateUserLocation:(MAUserLocation *)userLocation
       updatingLocation:(BOOL)updatingLocation
{
  CLLocation *location = userLocation.location;
  if (location != nil) {
    [self.delegate mapAdapter:self didUpdateUserLocation:location];
  }
}

- (void)mapViewRegionChanged:(MAMapView *)mapView
{
  [self.delegate mapAdapter:self didChangeRegionComplete:NO isGesture:_isGesture];
}

- (void)mapView:(MAMapView *)mapView regionWillChangeAnimated:(BOOL)animated wasUserAction:(BOOL)wasUserAction
{
  _isGesture = wasUserAction;
}

- (void)mapView:(MAMapView *)mapView regionDidChangeAnimated:(BOOL)animated wasUserAction:(BOOL)wasUserAction
{
  [self.delegate mapAdapter:self didChangeRegionComplete:YES isGesture:wasUserAction];
  _isGesture = NO;
}

- (void)mapView:(MAMapView *)mapView didSelectAnnotationView:(MAAnnotationView *)view
{
  if (![view.annotation isKindOfClass:[CNAMapAnnotation class]]) {
    return;
  }
  CNAMapAnnotation *annotation = (CNAMapAnnotation *)view.annotation;
  // RNM fires both onPress and onSelect on selection.
  [self deliverMarkerEvent:CNMarkerEventPress forAnnotation:annotation];
  [self deliverMarkerEvent:CNMarkerEventSelect forAnnotation:annotation];
  [self presentCalloutForAnnotation:annotation inView:view];
}

- (void)mapView:(MAMapView *)mapView didDeselectAnnotationView:(MAAnnotationView *)view
{
  if (![view.annotation isKindOfClass:[CNAMapAnnotation class]]) {
    return;
  }
  CNAMapAnnotation *annotation = (CNAMapAnnotation *)view.annotation;
  if (_presentedCalloutAnnotation == annotation) {
    [self dismissPresentedCallout];
  }
  [self deliverMarkerEvent:CNMarkerEventDeselect forAnnotation:annotation];
}

- (void)mapView:(MAMapView *)mapView didAnnotationViewCalloutTapped:(MAAnnotationView *)view
{
  if ([view.annotation isKindOfClass:[CNAMapAnnotation class]]) {
    [self deliverMarkerEvent:CNMarkerEventCalloutPress forAnnotation:(CNAMapAnnotation *)view.annotation];
  }
}

- (void)mapView:(MAMapView *)mapView
    annotationView:(MAAnnotationView *)view
 didChangeDragState:(MAAnnotationViewDragState)newState
       fromOldState:(MAAnnotationViewDragState)oldState
{
  if (![view.annotation isKindOfClass:[CNAMapAnnotation class]]) {
    return;
  }
  CNAMapAnnotation *annotation = (CNAMapAnnotation *)view.annotation;
  switch (newState) {
    case MAAnnotationViewDragStateStarting:
      [self deliverMarkerEvent:CNMarkerEventDragStart forAnnotation:annotation];
      break;
    case MAAnnotationViewDragStateDragging:
      [self deliverMarkerEvent:CNMarkerEventDrag forAnnotation:annotation];
      break;
    case MAAnnotationViewDragStateEnding:
      [self deliverMarkerEvent:CNMarkerEventDragEnd forAnnotation:annotation];
      break;
    default:
      break;
  }
}

@end
