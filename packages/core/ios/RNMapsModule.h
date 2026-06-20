#import <Foundation/Foundation.h>
#import <RNMapsSpecs/RNMapsSpecs.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * TurboModule backing the `setPrivacyConsent` JS API on iOS (mirrors the Android
 * `RNMapsModule`). Forwards the host app's privacy-compliance declaration to the
 * AMap SDK, which otherwise refuses to initialize (blank map). Must be invoked
 * before any `<MapView>` mounts.
 */
@interface RNMapsModule : NSObject <NativeRNMapsModuleSpec>
@end

NS_ASSUME_NONNULL_END
