# CI 维护说明

## 触发与分组

| 事件 | Checks | Build firmware | Publish release |
| --- | --- | --- | --- |
| 任意分支 push | 执行 | 跳过 | 跳过 |
| 指向 master 的 PR | 执行 | 跳过 | 跳过 |
| master 最新提交信息含 `[publish]` | 执行 | 检查成功后执行 | 构建成功后执行 |

检查针对本次 push 的最新提交或 PR 合并结果，不会逐个重放一次 push 中的历史提交。
发布标记也只检查最新提交信息；支持带标记的空提交。没有手动绕过检查的发布入口。

`Checks` 先验证脚本、缺包/损坏镜像拦截、宿主机防误操作和通知隐私逻辑，
再运行 actionlint，最后在上游真实源码上安装固定 feeds、执行 `make defconfig`，
验证所有功能种子设置。普通检查不下载软件包源码、不编译目标固件，仍不能替代
完整编译和实机测试。工作流不会擅自修改仓库分支保护规则。

并发限制只放在耗时的固件构建上，`cancel-in-progress: false` 保留已开始的构建。
普通检查独立运行，不等待旧固件构建结束。修改 CI 不会改变已运行任务的代码快照。

带发布标记的提交通过检查后，`Reserve release tag` 先将本次源码 SHA 固定为
`<OpenWrt版本>-x86-64-<run ID>`，再允许编译。重试任务复用同一个 tag，绝不移动已有
tag；没有产物的预留 tag 不代表发布成功。若预留失败，立即停止，避免编译数小时后才
发现权限问题。普通提交和 PR 不创建 tag。

发布时再次核对 tag 与固件来源 SHA，使用 `gh release create --verify-tag` 关联已有
tag，不传 `--target`。这是为了避免构建期间 master 的工作流更新后，GitHub 将旧
`target_commitish` 与默认分支比较，额外要求内置 `GITHUB_TOKEN` 无法取得的 Workflows
写权限（[官方说明](https://docs.github.com/en/rest/releases/releases#create-a-release)）。
不使用移动中的 master 作为固件来源，也不添加额外的长期 Token。

## 脚本职责

| 文件 | 职责 |
| --- | --- |
| `ci/install-deps.sh` | 在 GitHub 官方临时 runner 上安装对应依赖；只有 build 模式回收 SDK 空间 |
| `ci/prepare-source.sh` | 两组任务共用：校验源提交、保留上游 feeds 文件、逐个核对 feed 提交、解析配置并保存来源记录 |
| `ci/compile-firmware.sh` | 下载包源码、并行编译，失败后单线程重试；仅允许官方临时 runner |
| `ci/validate-config.sh` | 拒绝丢失的功能设置和禁止的软件替代项 |
| `ci/stage-firmware.sh` | 校验镜像、全部显式选择的软件包及 SHA256，整理发布文件 |
| `ci/release-tag.sh` | 编译前预留源码 tag；发布时只验证，不创建或移动 tag |
| `ci/publish-release.sh` | 复核产物对应的配置/上游提交与校验和，上传完整草稿后再发布 |
| `ci/notify_discord.py` | 仅转发白名单 CI 状态，使用 Python 标准库，无第三方通知 Action |

`build-openwrt.yml` 只保留任务编排、权限、触发条件和产物传递。
上游版本及提交只在其顶层 env 维护。版本检查工作流读取同一处配置。
Checks 与固件构建分别在独立 runner 上使用同一个准备脚本，避免两套准备逻辑漂移；
不跨任务传递可执行构建目录。所有官方 Actions 固定完整提交 SHA。

上游模板已经归档，具体审查见 [上游记录](upstream-review.md)。适配以官方稳定版
和该版本的固定 feeds 为准。`diy-part1.sh` 保留为上游兼容入口，但不得改变 release
的 feed pins；`diy-part2.sh` 在功能种子和 files 合入后运行，其结果同样必须通过配置检查。

## Discord 通知与隐私

已配置私有文字频道 `ci`，其下私人话题 `ci/openwrt-wcloud-x64` 接收本工程通知。
频道/话题 ID 与专用 Webhook 凭据只通过仓库 Secret `DISCORD_CI_WEBHOOK_URL` 使用，
不写入代码、文档或工作流参数。创建时使用本机已有机器人凭据；机器人 Token
没有上传至 GitHub。此话题用于 CI 通知，不自动创建或绑定 Codex 会话。

通知路由遵循根目录 [CI 工作提示与独立报告分流规范](../CI_NOTIFICATION_POLICY.md)，
该规范不改变各工程独立报告的既有发送约定。

独立的 `notify-discord.yml` 监听 CI、旧版构建和上游检查的开始、完成事件，
标题明确标注 `[CI 开始]` / `[CI 结束]`；排队提示默认关闭。
完成后附检查/构建/发布状态及运行链接；发布成功时附 Releases 下载入口。
它不监听自身，通知失败也不会改变原 CI 的结果。

通知不包含日志、提交正文、作者、分支名、设备/宿主机信息、配置、附件或凭据；
禁止自动 @ 提及。发送错误仅记录脱敏状态，不输出 Webhook URL 或响应正文。
私人话题仍可能被有管理权限的服务器成员访问。

由于 `workflow_run` 可访问 Secrets，通知任务只检出默认分支的可信代码，不检出
触发它的 PR/分支，不读取或执行其产物。Checks 和构建任务仅有 contents-read 权限，
只有 tag 预留与发布任务有 contents-write；通知任务增加 actions-read 来读取任务结果。

## 本地检查

```bash
bash ci/test.sh
go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7 -shellcheck=
git diff --check
```

上游版本检查每周一运行，也支持手动运行；它只提示更新，不改版本、不触发固件发布。
Dependabot 对官方 Actions 提交版本更新 PR，仍须通过本工程检查并审查后合并。
