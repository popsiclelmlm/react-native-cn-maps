#import <Foundation/Foundation.h>

#import "CNMapAdapter.h"

NS_ASSUME_NONNULL_BEGIN

// Registry of map provider adapters. A provider package self-registers its adapter
// class (via +load in M2; directly in M1) and the host asks the registry for an
// instance instead of naming a concrete SDK class. Keeping the host one step
// removed is what lets core carry zero provider references.
@interface CNMapAdapterRegistry : NSObject

// Register an adapter class conforming to CNMapAdapter. Idempotent.
+ (void)registerAdapterClass:(Class)adapterClass;

+ (NSArray<Class> *)registeredAdapterClasses;

// Instantiate the default (first-registered) adapter, or nil if none registered.
+ (nullable id<CNMapAdapter>)createAdapter;

// Instantiate the adapter whose +providerName matches `provider`, falling back to
// the default (first-registered) when `provider` is empty or unmatched.
+ (nullable id<CNMapAdapter>)createAdapterForProvider:(nullable NSString *)provider;

// Fan a privacy-compliance declaration out to every registered adapter class that
// conforms to CNMapAdapterPrivacy.
+ (void)applyPrivacyConsentAgreed:(BOOL)agreed contains:(BOOL)contains shown:(BOOL)shown;

@end

NS_ASSUME_NONNULL_END
