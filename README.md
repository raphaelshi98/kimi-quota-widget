# Kimi 额度

一个原生 macOS 小组件，通过本机 Kimi Code CLI 显示账号额度。包含后台 App 和 WidgetKit 小号、中号小组件。

## 功能

- 显示接口实际提供的 5 小时、每周等额度窗口
- 显示剩余比例、重置时间和最近更新时间
- 后台每 5 分钟刷新，点击小组件可打开管理窗口手动刷新
- 使用 App Group 在后台 App 与 Widget 之间共享额度快照
- 账号令牌只用于本机回环地址请求，不写入快照或日志

## 环境要求

- macOS 14.0 或更高版本
- 完整 Xcode 和免费 Apple 账号（Personal Team 即可）
- 已安装并登录 Kimi Code CLI
- 已使用 Xcode 27.1 和 Kimi Code CLI 2.3.3 验证

登录 CLI：

```bash
kimi login
```

## 一键构建

在项目目录运行：

```bash
./Scripts/build.sh YOUR_TEAM_ID
```

将 `YOUR_TEAM_ID` 替换成你的 10 位 Apple Team ID。也可以在 Xcode 的账号与签名设置中确认团队信息。

如果本机已有 Apple Development 证书，脚本也可以尝试自动识别 Team ID：

```bash
./Scripts/build.sh
```

脚本会检查环境、生成 Release 版、验证签名、注册并启用 Widget Extension，然后启动后台 App。重复运行会重启本项目旧实例。

构建产物位于：

```text
build/Build/Products/Release/KimiQuota.app
```

### 自定义标识

脚本默认根据 Team ID 生成独立标识。需要覆盖时：

```bash
DEVELOPMENT_TEAM=YOUR_TEAM_ID \
KIMI_QUOTA_BUNDLE_ID=com.example.KimiQuota \
APP_GROUP_IDENTIFIER=YOUR_TEAM_ID.com.example.KimiQuota.shared \
./Scripts/build.sh
```

在 macOS 本机开发中，App Group 应使用 Team ID 前缀。

## 添加到桌面

1. 点击屏幕右上角的日期和时间，打开通知中心。
2. 滚动到底部，点击“编辑小组件”。
3. 搜索“Kimi 额度”。
4. 将小号或中号小组件拖到桌面或通知中心。

后台 App 不会显示菜单栏图标。点击小组件可打开管理窗口，使用手动刷新、登录时启动或退出功能。

## 工作原理与隐私

后台 App 启动绑定 `127.0.0.1` 的 `kimi web`，调用本机 `/api/v1/oauth/usage`，再把不含凭据的额度快照写入 App Group。Widget 只读取快照，不读取账号令牌，也不启动 CLI。

沙盒例外仅用于：

- 读写 `~/.kimi-code`，运行 CLI 并使用其本机登录状态
- 读写 `~/Library/Caches/kimi-code`，加载 CLI Web 资源
- 只读 `~/.agents/skills`，避免 CLI 启动时的目录监视错误

本项目不会要求你把账号密码、OAuth 凭据或服务令牌上传到仓库。

## 限制

- 额度接口属于 Kimi Code 本机内部接口，不是承诺稳定的公开 API；CLI 升级后可能需要重新适配。
- 后台每 5 分钟查询一次，Widget 另有 15 分钟时间线请求，但 macOS 可能延迟刷新。
- 会员月度总额度目前不能由该本地接口取得，因此不会显示推算值。
- 后台 App 退出后，Widget 会保留上次数据并标记为可能过期。

## 源码结构

```text
KimiQuota/              后台 App、CLI 服务与额度客户端
KimiQuotaWidget/        WidgetKit 界面与 timeline
Shared/                 共享额度模型和快照读写
Scripts/build.sh        一键构建、签名验证与注册
KimiQuota.xcodeproj/    Xcode 工程
```

`build/`、签名描述文件、日志和本地快照均已加入 `.gitignore`，不应上传。

## 许可证

本项目采用 [MIT License](LICENSE)。
