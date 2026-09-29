#!/bin/sh
# 闲鱼 cookie 一键导出（越狱机本机跑）
# 用法：在 NewTerm 里 sudo sh export_cookie.sh
# 或把本文件放到 /var/mobile/ 后用 Filza 长按 → 执行

OUT=/var/mobile/Documents/xianyu_cookie.txt
mkdir -p /var/mobile/Documents

echo "[1] 定位闲鱼 App 容器..."
# rootless 越狱，闲鱼 bundle id: com.taobao.idlefish
BID=com.taobao.idlefish

# 用 mdfind 或遍历容器找
APP_DIR=""
for d in /var/mobile/Containers/Data/Application/*/; do
    plist="$d/.com.apple.mobile_container_manager.metadata.plist"
    [ -f "$plist" ] || continue
    id=$(plutil -extract MCMMetadataIdentifier raw -o - "$plist" 2>/dev/null)
    if [ "$id" = "$BID" ]; then
        APP_DIR="$d"
        break
    fi
done

if [ -z "$APP_DIR" ]; then
    echo "[!] 没找到闲鱼容器，检查 bundle id 是否为 $BID"
    exit 1
fi
echo "    找到: $APP_DIR"

COOKIE_FILE="${APP_DIR}Library/Cookies/Cookies.binarycookies"
if [ ! -f "$COOKIE_FILE" ]; then
    echo "[!] 没有 cookie 文件: $COOKIE_FILE"
    echo "    请先打开闲鱼 App 登录一次"
    exit 1
fi
echo "[2] cookie 文件: $COOKIE_FILE"
cp "$COOKIE_FILE" /var/mobile/Documents/xianyu.binarycookies
echo "    已复制到 /var/mobile/Documents/xianyu.binarycookies"
echo ""
echo "[3] 接下来用 python 解析（见 parse_cookie.py），"
echo "    或在 iSH/Minits 里粘贴该文件内容。"
echo ""
echo "完成。文件：/var/mobile/Documents/xianyu.binarycookies"
