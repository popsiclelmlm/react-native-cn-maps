#import "CNMapAdapterRegistry.h"

@implementation CNMapAdapterRegistry

// Ordered list of registered adapter classes; first registered is the default.
static NSMutableArray<Class> *CNRegisteredAdapterClasses(void)
{
  static NSMutableArray<Class> *classes;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    classes = [NSMutableArray array];
  });
  return classes;
}

+ (void)registerAdapterClass:(Class)adapterClass
{
  if (adapterClass == Nil) {
    return;
  }
  NSMutableArray<Class> *classes = CNRegisteredAdapterClasses();
  @synchronized(classes) {
    if (![classes containsObject:adapterClass]) {
      [classes addObject:adapterClass];
    }
  }
}

+ (NSArray<Class> *)registeredAdapterClasses
{
  NSMutableArray<Class> *classes = CNRegisteredAdapterClasses();
  @synchronized(classes) {
    return [classes copy];
  }
}

+ (id<CNMapAdapter>)createAdapter
{
  Class adapterClass = [self registeredAdapterClasses].firstObject;
  if (adapterClass == Nil) {
    return nil;
  }
  return [[adapterClass alloc] init];
}

+ (void)applyPrivacyConsentAgreed:(BOOL)agreed contains:(BOOL)contains shown:(BOOL)shown
{
  for (Class adapterClass in [self registeredAdapterClasses]) {
    if ([adapterClass conformsToProtocol:@protocol(CNMapAdapterPrivacy)]) {
      [(id<CNMapAdapterPrivacy>)adapterClass applyPrivacyConsentAgreed:agreed
                                                             contains:contains
                                                                shown:shown];
    }
  }
}

@end
