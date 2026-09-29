#import "XYMonitor.h"

#pragma mark - Swizzle 工具

static void xy_swizzle(Class c, SEL orig, SEL newS) {
    if (!c) return;
    Method m0 = class_getInstanceMethod(c, orig);
    Method m1 = class_getInstanceMethod(c, newS);
    if (!m0 || !m1) return;
    method_exchangeImplementations(m0, m1);
}

// 诊断：记录所有闲鱼请求 URL（排查用，正式版可关）
static BOOL kDebugAll = YES;
static NSString *kDebugLog = @"/var/mobile/Library/Preferences/xianyumon_debug.log";

static void xy_debug(NSString *s) {
    if (!kDebugAll) return;
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], s];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:kDebugLog];
    if (!fh) [line writeToFile:kDebugLog atomically:YES encoding:NSUTF8StringEncoding error:nil];
    else { [fh seekToEndOfFile]; [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; [fh closeFile]; }
}

#pragma mark - NSURLSession

@interface NSURLSession (XYMon)
@end

@implementation NSURLSession (XYMon)

+ (void)load {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        for (NSString *cn in @[@"__NSCFURLSession", @"NSURLSession"]) {
            Class cls = NSClassFromString(cn);
            if (cls) {
                xy_swizzle(cls,
                    @selector(dataTaskWithRequest:completionHandler:),
                    @selector(xy_dataTaskWithRequest:completionHandler:));
            }
        }
    });
}

- (NSURLSessionDataTask *)xy_dataTaskWithRequest:(NSURLRequest *)req
                               completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))origHandler {
    NSURL *u = req.URL;
    if ([u.absoluteString containsString:@"idlefish"] || [u.absoluteString containsString:@"goofish"]) {
        xy_debug([NSString stringWithFormat:@"REQ %@", u.absoluteString]);
    }
    void (^wrapped)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *resp, NSError *err) {
        @try {
            NSURL *ru = resp.URL ?: u;
            if (data.length && !err) {
                if ([ru.absoluteString containsString:@"goofish"] || [ru.absoluteString containsString:@"idlefish"]) {
                    xy_debug([NSString stringWithFormat:@"RESP len=%lu %@", (unsigned long)data.length, ru.absoluteString]);
                }
                [[XYMonitor shared] feedResponseBody:data url:ru];
            }
        } @catch (NSException *e) {}
        if (origHandler) origHandler(data, resp, err);
    };
    return [self xy_dataTaskWithRequest:req completionHandler:wrapped];
}

@end

#pragma mark - NSURLConnection 兜底

@interface NSURLConnection (XYMon)
@end

@implementation NSURLConnection (XYMon)

+ (void)load {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        xy_swizzle(objc_getClass("NSURLConnection"),
            @selector(sendSynchronousRequest:returningResponse:error:),
            @selector(xy_sendSync:returningResponse:error:));
    });
}

+ (NSData *)xy_sendSync:(NSURLRequest *)req
      returningResponse:(NSURLResponse **)resp
                  error:(NSError **)err {
    NSData *d = [self xy_sendSync:req returningResponse:resp error:err];
    @try {
        if (d.length && resp && *resp) {
            [[XYMonitor shared] feedResponseBody:d url:(*resp).URL ?: req.URL];
        }
    } @catch (NSException *e) {}
    return d;
}

@end

#pragma mark - 启动请求通知权限

%hook UIApplication

- (void)applicationDidBecomeActive:(UIApplication *)app {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [[UNUserNotificationCenter currentNotificationCenter]
            requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge)
            completionHandler:^(BOOL granted, NSError *e) {
                xy_debug([NSString stringWithFormat:@"NOTIFY_AUTH granted=%d", granted]);
            }];
        xy_debug(@"APP ACTIVE - XianyuMon loaded");
    });
}

%end
