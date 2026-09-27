# 音律实验室 / Pitch Lab

以“比的原理”网站音乐工具的原理为灵感制作的原生 iPhone App。界面、代码和声音合成均为独立实现。

## 功能

- 实时测音高：麦克风输入、音名、频率、音分偏差、最近 10 秒曲线。
- 钢琴：C3–B5，支持同时按下多个琴键，离线合成标准音。
- 听音测试：每轮 10 题，作答后汇总成绩和逐题答案。
- 乐谱练唱：从 Files 导入 MusicXML、MXL、PDF，或从照片导入乐谱图片。PDF/图片支持看谱和实时音高；MusicXML/MXL 支持首个单声部旋律的手动逐音音准检查。
- MusicXML/MXL 练唱可按半音在 −12 到 +12 间移调，目标音与参考音同步变化；原始乐谱不被改写。
- 人声乐谱逐句练习：导入 SVP 或 MIDI 人声旋律，再导入 LRC/TXT 歌词或逐行粘贴。可调整句子边界和歌词，听示范、倒数跟唱、逐音查看偏高／偏低／漏唱并反复重练。
- 舒适音域测试和移调建议：测量稳定的最低音、最高音，推荐 −12 到 +12 半音中覆盖旋律较多且留有余量的调。推荐调会同步用于示范和练习。

`.lysc` 是来音制谱的专有格式，本版请从该软件导出 SVP 或 MIDI 后导入；PDF/照片只能看谱，无法自动逐音评分。MIDI 优先读取名为 Vocal 的轨道。歌词文件需单独导入。

## 构建

需要 macOS、Xcode 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。Xcode 首次打开时会自动拉取 [ZIPFoundation](https://github.com/weichsel/ZIPFoundation)，用于读取 MXL 压缩乐谱。

```sh
brew install xcodegen
xcodegen generate
xcodebuild test -project PitchLab.xcodeproj -scheme PitchLab -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

仓库的 GitHub Actions 工作流会运行测试并打包 `PitchLab-unsigned.ipa`。未签名 IPA **不能直接安装**；需要使用你的 Apple 开发者证书和描述文件重新签名。仓库不包含签名材料。

如需在 Mac 上自行签名，先运行 `xcodegen generate` 并打开生成的 `PitchLab.xcodeproj`，在 PitchLab target 的 Signing & Capabilities 中选择自己的 Team，并按需更改 Bundle Identifier。CI 会在构建命令中单独关闭签名，不影响本地 Xcode 的签名设置。

## 真机检查

在 iPhone 上检查麦克风授权和拒绝授权流程、稳定单音识别、钢琴多点触控、听音测试播放、Files/照片导入、PDF 缩放、逐音与逐句练唱、音域测量、音频打断与恢复。录音只在设备上分析，不保存或上传。导入的乐谱也仅存于设备。
