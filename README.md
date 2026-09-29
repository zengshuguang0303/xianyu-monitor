# XianyuMon V1 — 闲鱼同城捡漏监控插件

**版本**：V1（手动辅助模式）
**平台**：iOS 16.3 / Dopamine rootless / arm64e
**作用**：你在闲鱼刷商品时，自动筛选「同城 + 想要人数达标」的商品，弹通知提醒。

---

## V1 功能（就是这个版本）

| 条件 | 规则 |
|---|---|
| ① 同城 | 地区或标题含「长沙」或长沙区名（岳麓/雨花/天心/芙蓉/开福/望城/星沙/宁乡/浏阳） |
| ② 想要人数 | **≥ 3** |
| ③ 关键词 | 默认不限制（可配） |

命中 → **弹 iOS 通知** + 写日志。

---

## 使用流程

```
打开闲鱼 → 搜「二手手机」→ 往下滑
        ↓
插件自动筛每一页返回的商品
        ↓
符合条件的弹通知 + 记日志
```

---

## 配置文件

路径（手机上）：`/var/mobile/Library/Preferences/com.minis.xianyumon.plist`

```xml
<key>city</key>        <string>长沙</string>
<key>minWant</key>     <integer>3</integer>
<key>cityAliases</key> <array>... 长沙区名 ...</array>
<key>keywords</key>    <array/>          <!-- 空 = 不限 -->
```

改完**不用重编译**，重启闲鱼即可。

---

## 日志

**命中日志**：`/var/mobile/Library/Preferences/xianyumon.log`
```
[2026-09-30 14:23:11] 长沙·岳麓 | 5人想要 | ¥1850 | iPhone 13 128G 国行
```

**调试日志**（重要，排查用）：`/var/mobile/Library/Preferences/xianyumon_debug.log`
```
[..] APP ACTIVE - XianyuMon loaded
[..] NOTIFY_AUTH granted=1
[..] REQ https://h5api.m.goofish.com/h5/mtop.taobao.idlemtopsearch.pc.search/1.0/...
[..] RESP len=12345 ...
[..] parsed 30 items from ...
```

命令行看：
```bash
tail -f /var/mobile/Library/Preferences/xianyumon_debug.log
```

---

## 排查指南

### 情况 1：调试日志里完全没有 REQ
→ 插件没注入成功 / 闲鱼走的不是 NSURLSession
→ 检查：`dpkg -l | grep xianyu`，确认插件装上；重装后 `killall -9 Xianyu`

### 情况 2：有 REQ 但没有 RESP
→ 网络库路径不同，或数据被压缩（gzip）
→ 把调试日志发我

### 情况 3：有 RESP 但 "parsed 0 items"
→ 数据结构变了，extractItems 没挖到
→ 把某个 RESP 的 URL 发我，我改结构

### 情况 4：parsed 到 items 但不弹
→ 想要人数字段名不对，或城市没匹配
→ 日志会显示逐条判断，我按需调

---

## 已知限制

1. **不是后台自动**（V2 才加）—— 必须你打开闲鱼刷列表才触发
2. **可能闪退** —— 闲鱼有越狱检测，若闪退告诉我，加 bypass
3. **想要人数字段可能不叫 wantCnt** —— 用调试日志确认真实字段名后我改

---

## V2 计划（跑通后加）

- 后台定时自动刷（每 5~10 分钟）
- 个人卖家过滤（排除商家店铺）
- 一键跳转聊天
- 价格表比对（低于收货价提醒）
