#import <React/RCTViewComponentView.h>
#import <UIKit/UIKit.h>

#ifndef RNMapsCallout_h
#define RNMapsCallout_h

NS_ASSUME_NONNULL_BEGIN

// Owner (the marker) notified when the callout's content/layout changes, so it can
// re-rasterize and push a fresh callout image into its model.
@protocol RNMapsCalloutOwner <NSObject>
- (void)calloutContentChanged;
@end

// Child host component of RNMapsMarker. Hosts the callout React subtree offscreen
// and exposes a rasterized snapshot the marker shows on selection.
@interface RNMapsCallout : RCTViewComponentView

@property (nonatomic, assign) BOOL tooltip;
@property (nonatomic, weak, nullable) id<RNMapsCalloutOwner> calloutOwner;

- (nullable UIImage *)renderToImage;
- (void)emitPress;

@end

NS_ASSUME_NONNULL_END

#endif /* RNMapsCallout_h */
