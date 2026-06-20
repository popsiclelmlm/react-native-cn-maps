#import "RNMapsModule.h"

#import "CNMapAdapterRegistry.h"

@implementation RNMapsModule

RCT_EXPORT_MODULE()

// Fan the host app's privacy-compliance declaration out to every registered map
// adapter (the AMap adapter forwards it to its SDK, which otherwise refuses to
// initialize). Must be invoked before any <MapView> mounts. The library never
// auto-agrees — the host app calls this after obtaining real user consent.
- (void)setPrivacyConsent:(BOOL)agreed contains:(BOOL)contains shown:(BOOL)shown
{
  [CNMapAdapterRegistry applyPrivacyConsentAgreed:agreed contains:contains shown:shown];
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeRNMapsModuleSpecJSI>(params);
}

@end
