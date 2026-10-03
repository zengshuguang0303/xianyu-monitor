#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>

// ====== roothide 越狱路径适配 ======
// roothide/theos 提供 roothide.h，jbroot() 会把路径映射到正确的越狱根
// 编译 rootful/rootless 时也能用（自动兼容）
#if __has_include(<roothide.h>)
#import <roothide.h>
#define XYJB(p) (jbroot(p) ?: (p))
#else
#define XYJB(p) (p)
#endif

// 偏好设置：走用户区，不需要越狱路径适配
static inline NSString *XYPrefPath(NSString *file) {
    return [@"/var/mobile/Library/Preferences/" stringByAppendingString:file];
}

// ====== 用户配置（可从 plist 覆盖）======
static NSString *kCity        = @"长沙";
static NSArray  *kCityAliases = nil;
static NSInteger kMinWant     = 3;
static NSArray  *kKeywords    = nil;
// =======================================

@interface XYMonitor : NSObject
+ (instancetype)shared;
- (void)feedResponseBody:(NSData *)data url:(NSURL *)url;
@end
