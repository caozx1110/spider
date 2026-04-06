# Silken Spider

一个基于 Flutter 的跨平台蜘蛛纸牌游戏，目标平台覆盖 Linux、Android 和 iPhone。

## 功能概览

- 开始菜单与继续牌局入口
- 经典模式
- 肉鸽模式“织命远征”
- 单花色、双花色、四色三档难度
- 单击自动落位、长按手动选牌、动态提示动画
- 自动收走完整同花顺
- 工具系统，可用积分购买并在对局内使用
- 积分、经验、等级系统
- 肉鸽遗物与阶段事件，可形成不同 build 组合
- 皮肤系统，支持主题 / 卡牌 / 动画自由组合
- 本地成就系统、胜场统计与 meta 进度存档
- 当前对局断点续存

## 运行环境

- Flutter 3.41.x
- Dart 3.11.x
- Linux 桌面构建依赖：`cmake`、`ninja`、`pkg-config`、GTK 3 开发包
- Android 构建依赖：Android SDK、JDK 17
- iPhone 构建依赖：macOS、Xcode、iOS SDK

仓库提供了一个包装脚本 [tool/flutterw](/home/ubuntu/ws/spider/tool/flutterw)。

它会优先使用工作区里的：

- `.tools/flutter`
- `.tools/android-sdk`
- `.tools/jdk/jdk-17.0.18+8`

如果这些目录不存在，你也可以直接使用系统安装的 `flutter` 命令。

## 本地开发

安装依赖：

```bash
./tool/flutterw pub get
```

Linux 下直接运行：

```bash
./tool/flutterw run -d linux
```

程序启动后会先进入开始菜单。

你可以选择：

- `经典模式`：保留原本蜘蛛纸牌玩法，适合稳定推进成就和练习
- `织命远征`：肉鸽模式，开局与中途会获得随机遗物和事件
- `工坊与皮肤`：使用积分购买道具、主题、卡牌皮肤和动画皮肤

## 测试与静态检查

静态检查：

```bash
./tool/flutterw analyze
```

单元测试：

```bash
./tool/flutterw test
```

## 编译

### Linux

构建命令：

```bash
./tool/flutterw build linux
```

产物路径：

```text
build/linux/x64/release/bundle/spider_solitaire
```

### Android

构建调试 APK：

```bash
./tool/flutterw build apk --debug
```

产物路径：

```text
build/app/outputs/flutter-apk/app-debug.apk
```

如果你本机已经装好了 Android SDK 和 JDK 17，也可以直接使用系统环境：

```bash
flutter build apk --debug
```

### iPhone

iPhone 工程已经生成在 `ios/`，但必须在 macOS 上编译。

常见流程：

```bash
flutter pub get
flutter build ios
```

或者使用 Xcode 打开：

```text
ios/Runner.xcworkspace
```

注意：

- 当前 Linux 环境无法直接产出 iOS 可执行包
- 真机签名、证书和发布配置需要在 Xcode 中完成

## 项目结构

- `lib/main.dart`：主界面、开始菜单、模式入口、皮肤与菜单 UI
- `lib/src/spider_engine.dart`：核心蜘蛛纸牌规则引擎
- `lib/src/controller.dart`：对局控制、模式切换、奖励结算、商店与工具逻辑
- `lib/src/models.dart`：游戏状态与 meta 进度数据模型
- `lib/src/meta_catalog.dart`：道具、遗物、主题、卡牌和动画皮肤目录
- `lib/src/progress_repository.dart`：本地持久化
- `test/spider_engine_test.dart`：规则与自动落位偏好测试

## 当前验证结果

以下命令已经在当前仓库中验证通过：

```bash
./tool/flutterw analyze
./tool/flutterw test
./tool/flutterw build linux
./tool/flutterw build apk --debug
```

## 版本管理

仓库已经初始化 Git，并保留了分阶段提交历史。

当前主要提交包括：

- `6c42035` `chore: scaffold flutter spider solitaire app`
- `7ac0d96` `feat: add cross-platform spider solitaire game`
- `5b912b7` `feat: improve hints and tap interactions`
- `d34df28` `feat: add progression and roguelike mode`
