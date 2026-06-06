#import "RNMapsModule.h"

#import <MAMapKit/MAMapKit.h>
#import <AMapFoundationKit/AMapFoundationKit.h>

@implementation RNMapsModule

RCT_EXPORT_MODULE()

// Mirror of the Android implementation: declare privacy "shown"/"contains" first,
// then the user's agreement. AMap reads these globally, so any MAMapView created
// afterwards initializes normally. The library never auto-agrees — the host app
// must call this after obtaining real user consent.
- (void)setPrivacyConsent:(BOOL)agreed contains:(BOOL)contains shown:(BOOL)shown
{
  [MAMapView updatePrivacyShow:(shown ? AMapPrivacyShowStatusDidShow : AMapPrivacyShowStatusNotShow)
                   privacyInfo:(contains ? AMapPrivacyInfoStatusDidContain : AMapPrivacyInfoStatusNotContain)];
  [MAMapView updatePrivacyAgree:(agreed ? AMapPrivacyAgreeStatusDidAgree : AMapPrivacyAgreeStatusNotAgree)];
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeRNMapsModuleSpecJSI>(params);
}

@end
