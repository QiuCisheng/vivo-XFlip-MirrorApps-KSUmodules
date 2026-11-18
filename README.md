# 魔镜应用管理（mirrorapps）

一个 **KernelSU 模块**，用于在 vivo 折叠屏上**图形化管理外屏「魔镜」桌面的应用列表**。

模块会拉起一个只监听 `127.0.0.1:8898` 的本地网页控制台，点开就能添加、移除、排序、改名外屏应用，不需要每次手动去翻系统设置或改数据库。

- 版本：v2.0（versionCode 2）
- 作者：Cisheng & Minis
- 模块格式：KernelSU 模块（`module.prop` 在 zip 根目录，无 `META-INF`），用 KernelSU 管理器刷入
- 运行环境：已 Root 的 KernelSU 设备 + vivo 折叠屏（外屏桌面为 `com.vivo.fliplauncher`）

---

## 功能

| 功能 | 说明 |
| --- | --- |
| 查看已添加应用 | 显示外屏桌面当前的应用列表，按 rank 排序 |
| 添加应用 | 从「已安装第三方应用」中挑选，自动解析启动组件、写入列表 |
| 移除应用 | 同时清理列表项、名称表和外屏白名单 |
| 上移 / 下移 | 调整外屏图标顺序 |
| 改名 | 自定义外屏上显示的图标名称（支持中文） |
| 重启外屏桌面 | 手动让改动立即生效 |
| 同步外屏白名单 | 把列表里所有应用一次性补进白名单（修复「能添加但点不开」） |
| 写入后自动重启 | 开关项，开启后每次改动自动重启外屏桌面约 3 秒 |

---

## 安装（KernelSU）

1. 下载 `mirrorapps-v2.0.zip`（**不要解压**）。
2. 打开 **KernelSU 管理器** → 模块 → 「从本地安装」→ 选该 zip。
3. **重启手机**（模块在 `post-fs-data.sh` / `service.sh` 里会把载荷装到 `/data/local/mirrorapps` 并拉起 httpd）。
4. 回到模块列表，点该模块卡片上的 **「操作」/ Action 按钮**：
   - 以 root 执行一次 `action.sh`（内部调用 `install.sh`，幂等，可反复点）
   - 随后自动用浏览器打开 `http://127.0.0.1:8898/`

也可以随时自己用浏览器访问 `http://127.0.0.1:8898/`，或在页面里「添加到主屏幕」，当成一个独立 App 使用（带 PWA manifest 和图标）。

模块实现细节（KernelSU 相关）：

- 纯 KernelSU 格式：`module.prop` 位于 zip 根目录、无 `META-INF`，管理器直接可刷
- busybox 优先用模块自带的 `bin/busybox`，缺失时回退 `/data/adb/ksu/bin/busybox` → `/system/bin/busybox`
- **不使用 KSU WebUI（webroot）**：页面由模块自带的 busybox httpd 在 `127.0.0.1:8898` 提供，不依赖管理器版本
- 不依赖 Zygisk / Magisk 兼容层

> 日志：管理器的日志窗口不含本模块的日志，请用终端 `cat /data/local/mirrorapps/install.log`。

---

## 使用

**添加应用**：在「可添加（已安装应用）」里点「添加」，弹出输入框填外屏上想显示的名字 → 确定。

**排序**：在「已添加」里用 ↑ / ↓ 调整。

**改名**：点「改名」重新输入显示名称。

**移除**：点 ✕ 确认。

**生效时机**：默认不会自动重启外屏桌面，改动后点一次「重启外屏桌面」；或打开顶部「写入后自动重启外屏桌面」开关，之后每次操作都会自动重启。

> 若列表项后面出现橙色提示「· 未入外屏白名单」，说明该应用在 `fliplauncher` 的列表里但不在系统白名单里，点「同步外屏白名单」即可修好。

---

## 工作原理

vivo 外屏桌面把应用列表存在私有数据库里：

```
/data/user_de/0/com.vivo.fliplauncher/databases/launcher.db
  └─ location_lib   ← 外屏应用列表（intent / title / rank / 布局字段）
  └─ attribute      ← 桌面维护的已安装应用名表
```

模块的操作流程：

1. 用自带 `busybox httpd` 起一个本地静态站点 + 两个 CGI 脚本；
2. `cgi-bin/status` 把 `launcher.db` **复制一份快照**后只读查询（不动原库），输出 `ROW=` / `APP=` / `LABEL=` / `AUTO=` / `PID=` 纯文本行；
3. `cgi-bin/ctl` 收到操作后直接写原库：`delete` / `insert` / `update title` / 交换 `rank`，写完后把 rank 重新编号成 0,1,2…；
4. 写库前后配合系统设置项：
   - `secure fold_adaptive_screen_app_list` —— 「魔镜应用管理」的候选白名单
   - `secure fold_adaptive_app_not_in_lab` —— 真正决定应用**能否在外屏运行**的名单；不在里面时 vivo 桌面会拉起 FlipToContinue（「请翻开手机继续使用」），表现为点了打不开
5. 用 `am force-stop com.vivo.fliplauncher` + `am start --display 1 -c android.intent.category.HOME` 让外屏桌面重新读取数据库。

添加时用 `cmd package resolve-activity --brief <pkg>` 解析真实启动组件，写入格式为 `包名/组件`。

### HTTP 接口

```
GET cgi-bin/status                     列出应用与状态
GET cgi-bin/ctl?a=add&p=<pkg>&n=<name>  添加（可选 &x=完整intent）
GET cgi-bin/ctl?a=del&p=<pkg>           移除
GET cgi-bin/ctl?a=up|down&p=<pkg>       移动一位
GET cgi-bin/ctl?a=rename&p=<pkg>&n=<名> 改名
GET cgi-bin/ctl?a=restart               重启外屏桌面
GET cgi-bin/ctl?a=wlfix                 同步全部应用到白名单
GET cgi-bin/ctl?a=auto&v=0|1            开关自动重启
```

---

## 文件结构

```
module.prop         模块信息
post-fs-data.sh     开机早期启动安装（后台非阻塞）
service.sh          开机启动安装（后台非阻塞）
action.sh           「操作」按钮：安装 + 打开控制台
uninstall.sh        卸载：杀 httpd、删 /data/local/mirrorapps
bin/install.sh      载荷安装 + 启动 httpd（幂等，按 .payload_ver 判断是否重刷）
bin/busybox         内置 busybox（httpd / netstat）
bin/sqlite3         内置 sqlite3（musl 静态版）
www/index.html      控制台单页
www/manifest.json   PWA 清单
www/icon-192.png    图标
www/icon-512.png
www/cgi-bin/status  只读查询
www/cgi-bin/ctl     写库操作
```

运行时目录：`/data/local/mirrorapps/`

- `bin/`、`www/` —— 载荷副本
- `install.log` —— 安装 / 启动日志
- `run/autorestart` —— 自动重启开关（`1` / `0`）
- `run/db.snapshot` —— 查询用数据库快照

---

## 排错

| 现象 | 处理 |
| --- | --- |
| 打开 `127.0.0.1:8898` 无响应 | 点一次模块「操作」按钮；或 `cat /data/local/mirrorapps/install.log` 看是否 `httpd started` |
| 页面提示 `ERR=NO_DB` | 找不到 `fliplauncher/launcher.db`，确认机型/系统版本外屏桌面是 `com.vivo.fliplauncher`，且已 root 可读 `/data/user_de` |
| 添加成功但外屏打不开 | 点「同步外屏白名单」，或检查 `fold_adaptive_app_not_in_lab` |
| 改动没生效 | 点「重启外屏桌面」；确认外屏桌面进程（`pidof com.vivo.fliplauncher`）确实重启了 |
| 添加时报「找不到启动组件」 | 应用没有可启动的 MAIN/LAUNCHER 活动，或被禁用；确认包名正确 |

手动重跑安装：

```sh
sh /data/adb/modules/mirrorapps/bin/install.sh
```

---

## 卸载

在 **KernelSU 管理器**里卸载即可，`uninstall.sh` 会杀掉 8898 端口上的 httpd 并删除 `/data/local/mirrorapps`。

**注意**：卸载只删模块自身，不会回滚已经写进 `launcher.db` 的外屏列表——那是你本来就想保留的配置。

---

## 风险提示

- 模块直接改写系统应用私有数据库，属于 root 级操作。操作前请自行评估，出问题可用备份的 `launcher.db` 还原，或清除外屏桌面数据恢复默认。
- 系统 OTA 升级后 `launcher.db` 的表结构可能变化，届时需要重新适配。
- httpd 只监听 `127.0.0.1`，不对局域网开放，无鉴权——但任何本机应用理论上都能访问，请勿把端口转发出去。
