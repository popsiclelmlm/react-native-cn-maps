#import "CNOverlayHandle.h"

@implementation CNOverlayHandle

- (instancetype)initWithChildId:(NSString *)childId
{
  if (self = [super init]) {
    _childId = [childId copy];
  }
  return self;
}

@end
