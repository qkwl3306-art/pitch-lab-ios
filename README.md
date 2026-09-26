# 音律实验室 / Pitch Lab

以“比的原理”网站音乐工具的原理为灵感制作的原生 iPhone App。界面、代码和声音合成均为独立实现。

## 功能

- 实时测音高：麦克风输入、音名、频率、音分偏差、最近 10 秒曲线。
- 钢琴：C3–B5，支持同时按下多个琴键，离线合成标准音。
- 听音测试：每轮 10 题，作答后汇总成绩和逐题答案。

## 构建

需要 macOS、Xcode 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```sh
brew install xcodegen
xcodegen generate
xcodebuild test -project PitchLab.xcodeproj -scheme PitchLab -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

仓库的 GitHub Actions 工作流会运行测试并打包 `PitchLab-unsigned.ipa`。未签名 IPA **不能直接安装**；需要使用你的 Apple 开发者证书和描述文件重新签名。仓库不包含签名材料。

## 真机检查

在 iPhone 上检查麦克风授权和拒绝授权流程、稳定单音识别、钢琴多点触控、听音测试播放、音频打断与恢复。录音只在设备上分析，不保存或上传。
