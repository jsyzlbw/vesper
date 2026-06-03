# Vesper 外部 TestFlight 测试发布说明

本文档用于将 Vesper 分发给同学试用。第一批采用 TestFlight 外部测试：同学无需加入你的 App Store Connect 团队，可以通过邀请邮件或公开链接安装。

## 1. 账号前置条件

发布 TestFlight 构建需要加入 [Apple Developer Program](https://developer.apple.com/programs/enroll/)。仅登录免费的 Apple ID 可以安装开发版到自己的 iPhone，但不能向外部测试者分发 TestFlight 构建。

开发者计划申请、身份验证、付费、协议接受，以及可能出现的人工审核，必须由账号持有人在 Apple 官方页面完成。脚本无法替你点击同意条款、付款或绕过审核。

申请后，在 Xcode 的 `Settings > Accounts` 中登录同一个 Apple ID，并确认团队可用。首次归档时，Xcode 自动签名通常会创建所需的发布证书和描述文件。

## 2. 创建 App Store Connect 记录

登录 [App Store Connect](https://appstoreconnect.apple.com/)：

1. 进入 `Apps`，点击 `+`，选择 `New App`。
2. 平台选择 `iOS`。
3. 名称填写 `Vesper`。
4. Bundle ID 选择或注册 `com.liangbowenbill.DiaryCompanion`。
5. SKU 可填写 `vesper-ios`。
6. 完成页面中要求接受的协议。

App Store Connect 中的 Bundle ID 必须与工程一致，否则上传会失败。

## 3. 创建 App Store Connect API Key

脚本使用 API Key 上传 IPA：

1. 先确认 Account Holder 已在 App Store Connect 中申请并启用 API access。Apple 可能要求审核或额外确认。
2. 在 App Store Connect 中进入 `Users and Access > Integrations > App Store Connect API`。
3. 创建 Team API Key，赋予能够上传构建的权限。
4. 下载 `.p8` 私钥。Apple 通常只允许下载一次，请妥善保存，不要提交到 Git。
5. 记录 Key ID 与 Issuer ID。

在终端设置环境变量：

```bash
export ASC_API_KEY_ID="你的 Key ID"
export ASC_API_ISSUER_ID="你的 Issuer ID"
export ASC_API_PRIVATE_KEY_PATH="/绝对路径/AuthKey_XXXXXXXXXX.p8"
```

## 4. 运行发布脚本

首先检查本机条件：

```bash
./scripts/testflight.sh preflight
```

生成 Release archive 和 App Store Connect IPA：

```bash
VERSION=0.1.0 BUILD_NUMBER=1 ./scripts/testflight.sh archive
```

上传：

```bash
./scripts/testflight.sh upload
```

默认产物位于 `artifacts/testflight/`。脚本使用 Xcode 自动签名；如果归档失败，请先确认 Apple Developer Program 会员状态、Xcode 团队、发布证书和描述文件。

## 5. 设置外部测试

上传后需要等待 App Store Connect 处理构建。处理完成后：

1. 在 App Store Connect 中打开 `Vesper > TestFlight`。
2. 填写 Beta App Review 要求的测试信息、联系信息和说明。
3. 先创建一个内部测试组。Apple 要求存在内部测试组后，才能创建外部测试组。
4. 创建一个外部测试组，例如 `Classmates`。
5. 将构建加入外部测试组。
6. 提交 Beta App Review。
7. 审核通过后，添加测试者邮箱或开启公开邀请链接。

首次外部测试构建必须经过 Beta App Review。后续构建是否再次审核由 Apple 决定。测试者通过 TestFlight App 安装 Vesper。

## 6. 递增构建号

每次上传都必须使用新的 `BUILD_NUMBER`。例如：

```bash
VERSION=0.1.0 BUILD_NUMBER=2 ./scripts/testflight.sh archive
./scripts/testflight.sh upload
```

`VERSION` 是用户可见版本号。`BUILD_NUMBER` 是每次上传递增的内部构建号。同一版本连续测试时，保持 `VERSION` 不变，只递增 `BUILD_NUMBER`。

## 7. 常见问题

- `preflight` 提示没有 `Apple Distribution` identity：确认已加入 Apple Developer Program，再让 Xcode 自动签名创建证书。
- 上传提示 Bundle ID 不存在：先在 Apple Developer 与 App Store Connect 中注册 `com.liangbowenbill.DiaryCompanion`。
- 上传提示构建号重复：将 `BUILD_NUMBER` 增加后重新归档上传。
- 上传提示 API Key 无效：检查 Key ID、Issuer ID、`.p8` 私钥路径和权限。
- Beta 构建不可见：等待 App Store Connect 完成处理，并检查是否有协议尚未接受。
