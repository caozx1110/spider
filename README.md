# Silken Spider

一个基于 Flutter 的跨平台蜘蛛纸牌游戏，目标平台覆盖 Linux、Android 和 iPhone。

## 已实现

- 经典蜘蛛纸牌核心规则
- 单花色、双花色、四色三档难度
- 提示、新局、撤销、库存发牌
- 自动收走完整同花顺
- 本地成就系统与胜场统计
- 当前对局断点续存
- 针对桌面和移动端做过自适应的自定义 UI

## 本地运行

```bash
./tool/flutterw pub get
./tool/flutterw run -d linux
```

## 测试与构建

```bash
./tool/flutterw analyze
./tool/flutterw test
./tool/flutterw build linux
./tool/flutterw build apk --debug
```

Linux 构建产物位于：

```text
build/linux/x64/release/bundle/spider_solitaire
```

Android 调试 APK 位于：

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Android / iPhone

- Android 工程已经生成在 `android/`，仓库内 `./tool/flutterw` 会自动接入当前工作区里的 Flutter、Android SDK 和 JDK。
- iPhone 工程已经生成在 `ios/`，需要在 macOS + Xcode 环境中编译。

## 版本管理

仓库已初始化 Git，并保留了项目骨架提交。后续功能修改可以继续沿着当前历史提交演进。
