#import "XYMonitor.h"

// 长沙区名（卖家常只写区，不写市）
static NSArray *kDefaultCityAliases(void) {
    return @[@"长沙", @"岳麓", @"雨花", @"天心", @"芙蓉", @"开福", @"望城", @"星沙", @"宁乡", @"浏阳"];
}

@implementation XYMonitor {
    NSMutableSet<NSString *> *_seen;
    NSArray  *_cityAliases;
    NSString *_city;
    NSInteger _minWant;
    NSArray  *_kws;
}

+ (instancetype)shared {
    static XYMonitor *s; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [XYMonitor new]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        _seen = [NSMutableSet set];
        _city = kCity;
        _cityAliases = kCityAliases ?: kDefaultCityAliases();
        _minWant = kMinWant;
        _kws = kKeywords;   // nil = 不限
        [self loadPrefs];
    }
    return self;
}

- (void)loadPrefs {
    NSString *p = @"/var/mobile/Library/Preferences/com.minis.xianyumon.plist";
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:p];
    if (!d) return;
    if ([d[@"city"] length]) _city = d[@"city"];
    if ([d[@"cityAliases"] count]) _cityAliases = d[@"cityAliases"];
    if (d[@"minWant"]) _minWant = [d[@"minWant"] integerValue];
    if ([d[@"keywords"] count]) _kws = d[@"keywords"];
    NSLog(@"[XYMon] prefs city=%@ minWant=%ld", _city, (long)_minWant);
}

#pragma mark - 入口

- (void)feedResponseBody:(NSData *)data url:(NSURL *)url {
    if (!data.length || data.length > 4 * 1024 * 1024) return;
    NSString *u = url.absoluteString ?: @"";
    if (![u containsString:@"mtop.taobao.idle"]) return;

    NSError *e = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&e];
    if (!json || e) return;

    NSArray *items = [self extractItems:json];
    if (!items.count) return;
    NSLog(@"[XYMon] parsed %lu items from %@", (unsigned long)items.count, u);

    for (NSDictionary *it in items) [self handleItem:it];
}

- (NSArray *)extractItems:(id)json {
    __block NSArray *found = nil;
    void (^walk)(id) = nil;
    walk = ^(id o) {
        if (found) return;
        if ([o isKindOfClass:[NSDictionary class]]) {
            for (NSString *key in o) {
                id v = o[key];
                if ([v isKindOfClass:[NSArray class]] && [v count] &&
                    [v[0] isKindOfClass:[NSDictionary class]] &&
                    (v[0][@"itemId"] || v[0][@"id"] || v[0][@"title"] || v[0][@"wantCnt"])) {
                    found = v; return;
                }
                walk(v);
                if (found) return;
            }
        } else if ([o isKindOfClass:[NSArray class]]) {
            for (id v in o) { walk(v); if (found) return; }
        }
    };
    walk(json);
    return found ?: @[];
}

- (void)handleItem:(NSDictionary *)it {
    NSString *iid   = [self str:it[@"itemId"] ?: it[@"id"]];
    NSString *title = [self str:it[@"title"] ?: it[@"itemTitle"]];
    if (!iid.length || !title.length) return;
    if ([_seen containsObject:iid]) return;

    // ---- 条件1：同城 ----
    NSString *areaRaw = [self flatten:it[@"area"] ?: it[@"city"] ?: it[@"location"]
                                    ?: it[@"sellerArea"] ?: @""];
    if (_cityAliases.count) {
        BOOL sameCity = NO;
        for (NSString *a in _cityAliases) {
            if ([areaRaw containsString:a] || [title containsString:a]) { sameCity = YES; break; }
        }
        if (!sameCity) return;
    }

    // ---- 条件2：想要人数 >= N ----
    NSInteger want = [self wantCountOf:it];
    if (want < _minWant) return;

    // ---- 条件3：关键词（可选）----
    if (_kws.count) {
        BOOL hit = NO;
        for (NSString *k in _kws) if ([title containsString:k]) { hit = YES; break; }
        if (!hit) return;
    }

    [_seen addObject:iid];
    [self notifyTitle:title area:areaRaw want:want price:[self priceOf:it] itemId:iid];
}

// 想要人数：兼容 wantCnt / wantNum / 等字段
- (NSInteger)wantCountOf:(NSDictionary *)it {
    for (NSString *k in @[@"wantCnt", @"wantNum", @"wantCount", @"wantedCnt"]) {
        id v = it[k];
        if ([v isKindOfClass:[NSNumber class]]) return [v integerValue];
        if ([v isKindOfClass:[NSString class]]) {
            NSString *s = [(NSString *)v stringByReplacingOccurrencesOfString:@"人想要" withString:@""];
            return [[s stringByTrimmingCharactersInSet:[NSCharacterSet nonDigitCharacterSet]] integerValue];
        }
    }
    // 有些结构放在推荐理由里，形如 "5人想要"
    for (NSString *k in @[@"recommendReason", @"label", @"subTitle", @"tag"]) {
        NSString *s = [self str:it[k]];
        if ([s containsString:@"人想要"]) {
            return [[s stringByTrimmingCharactersInSet:[NSCharacterSet nonDigitCharacterSet]] integerValue];
        }
    }
    return 0;
}

- (NSInteger)priceOf:(NSDictionary *)it {
    id p = it[@"price"] ?: it[@"priceText"] ?: it[@"soldPrice"];
    if ([p isKindOfClass:[NSNumber class]]) return [p integerValue];
    if ([p isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)p stringByReplacingOccurrencesOfString:@"¥" withString:@""];
        return (NSInteger)([s doubleValue] * 100);
    }
    return -1;
}

- (NSString *)str:(id)o {
    if ([o isKindOfClass:[NSString class]]) return o;
    if ([o isKindOfClass:[NSNumber class]]) return [o stringValue];
    if ([o isKindOfClass:[NSDictionary class]]) {
        for (NSString *k in @[@"text", @"title", @"value", @"name"]) {
            if (o[k]) return [self str:o[k]];
        }
    }
    if ([o isKindOfClass:[NSArray class]]) {
        NSMutableArray *a = [NSMutableArray array];
        for (id v in o) { NSString *s = [self str:v]; if (s) [a addObject:s]; }
        return [a componentsJoinedByString:@" "];
    }
    return nil;
}

- (NSString *)flatten:(id)o { return [self str:o] ?: @""; }

#pragma mark - 通知

- (void)notifyTitle:(NSString *)title area:(NSString *)area
               want:(NSInteger)want price:(NSInteger)price itemId:(NSString *)iid {
    UNMutableNotificationContent *c = [UNMutableNotificationContent new];
    c.title = [NSString stringWithFormat:@"🔥 闲鱼命中 %@", area.length ? area : _city];
    NSString *ps = price >= 0 ? [NSString stringWithFormat:@"¥%.0f", price / 100.0] : @"";
    c.body = [NSString stringWithFormat:@"%ld人想要 %@\n%@", (long)want, ps, title];
    c.sound = [UNNotificationSound defaultSound];
    c.userInfo = @{@"itemId": iid};

    UNNotificationRequest *r = [UNNotificationRequest requestWithIdentifier:iid content:c trigger:nil];
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:r withCompletionHandler:nil];

    [self log:[NSString stringWithFormat:@"%@ | %ld人想要 | %@ | %@",
               area, (long)want, ps, title]];
}

- (void)log:(NSString *)msg {
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], msg];
    NSString *path = @"/var/mobile/Library/Preferences/xianyumon.log";
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) {
        [line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        [fh seekToEndOfFile];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    }
}

@end
