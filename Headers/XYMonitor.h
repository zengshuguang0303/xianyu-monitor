#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>

// ====== 用户配置（可从 plist 覆盖）======
static NSString *kCity        = @"长沙";
static NSArray  *kCityAliases = nil;   // 区名等
static NSInteger kMinWant     = 3;     // 想要人数门槛
static NSArray  *kKeywords    = nil;   // nil = 不限制
// =======================================

@interface XYMonitor : NSObject
+ (instancetype)shared;
- (void)feedResponseBody:(NSData *)data url:(NSURL *)url;
@end
