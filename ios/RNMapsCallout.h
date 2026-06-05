#import <React/RCTViewComponentView.h>
#import <UIKit/UIKit.h>

#ifndef RNMapsCallout_h
#define RNMapsCallout_h

NS_ASSUME_NONNULL_BEGIN

// Child host component of RNMapsMarker. Hosts the callout React subtree offscreen
// and exposes a rasterized snapshot the marker shows on selection.
@interface RNMapsCallout : RCTViewComponentView

@property (nonatomic, assign) BOOL tooltip;

- (nullable UIImage *)renderToImage;
- (void)emitPress;

@end

NS_ASSUME_NONNULL_END

#endif /* RNMapsCallout_h */
