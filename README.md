# AstrBot-Android-App: 🤖 移动端一键运行的 AstrBot 聊天机器人平台

## 项目简介 📝

AstrBot-Android-App 是一款基于 **AstrBot 聊天机器人框架** 与 **Code LFA 的 Ubuntu 容器环境 & 浏览器框架** 打造的移动端解决方案，让你在 Android 设备上一键启动、配置并运行强大的多平台 LLM 聊天机器人。

我们砍掉了原始 Code LFA 中与 code-server 相关的所有模块，深度集成 AstrBot 框架，借助其 Ubuntu 容器环境实现 AstrBot 在移动端的本地化运行，并通过内置 WebView 直接连接 AstrBot 浏览器仪表盘，让移动端部署 AI 聊天机器人变得前所未有的简单。


## 核心特性 ✨

- **一键启动 🚀**：在 Android 设备上无需复杂配置，点击即可启动 AstrBot 服务。
- **图形化配置 🖥️**：通过内置 WebView 直接访问 AstrBot 浏览器仪表盘，可视化配置 LLM 对接、消息平台适配、插件管理等功能（你也可以在浏览器输入 `http://localhost:端口名` 访问 AstrBot 仪表盘和 napcat 等容器的 Web 配置界面）。
- **多平台支持 🌐**：默认支持 QQ、QQ 频道、微信，可通过插件扩展至 Telegram 等任意消息平台。
- **强大的 LLM 兼容 🧠**：支持对接 OpenAI、Llama、Gemini、Dify 等主流大语言模型。
- **本地 Ubuntu 容器 🐧**：基于 Code LFA 提供的 Ubuntu 容器环境，保障 AstrBot 依赖的稳定性与兼容性。
- **消息平台适配器 📡**：默认集成 napcat 消息平台适配器，支持 QQ 个人账号消息平台。


## 快速开始 🏁

### 环境要求 📋
- Android 设备（建议 Android 10 及以上版本）
- 至少 4GB 可用内存（运行 Ubuntu 容器与 AstrBot 需占用一定资源）


### 启动流程 🔄
1. 安装并启动 AstrBot-Android-App。
2. 应用会自动初始化 Ubuntu 容器并部署 AstrBot 服务 ⏳。
3. 等待初始化完成后，内置 WebView 会自动跳转至 **AstrBot 浏览器仪表盘** 🎯。
4. 在仪表盘内完成 LLM 服务配置、消息平台适配器设置、插件安装等操作 ⚙️。
5. 启动机器人，即可在对应消息平台上体验 AI 聊天能力 💬。


## 项目结构说明 📂

```
AstrBot-Android-App/
├── code_lfa-1.6.1/       # 基于 Code LFA 的 Ubuntu 容器环境基础 🐳
├── overrides/
│   ├── assets/
│   │   ├── AstrBot-4.5.4.zip   # AstrBot 框架核心资源包 📦
│   │   └── napcat.sh           # napcat 消息平台适配器 (qq) 安装脚本 📜
│   └── lib/                    # 替换的 lib 目录，包含 Dart 脚本 🔧
│       ├── config.dart
│       ├── script.dart
│       ├── terminal_controller.dart  
│       └── utils.dart
├── build.bat               # Windows 构建脚本 🪟
├── build.sh                # Linux/Mac 构建脚本 🐧
└── README.md               # 项目说明文档（你正在阅读的内容） 📖
```


## 开发与构建 🔨

如果你想对项目进行二次开发或自行构建，可以执行以下步骤：

### 依赖安装 📥
确保你的开发环境已安装：
- Flutter SDK（支持 Android 开发） 🎯


### 构建步骤 🛠️
1. 克隆本项目仓库：
   ```bash
   git clone https://github.com/你的用户名/AstrBot-Android-App.git
   cd AstrBot-Android-App
   ```

2. 执行构建脚本：
   - Windows：`./build.bat`
   - Linux/Mac：`./build.sh`

3. 构建完成后，在 `build/app/outputs/apk/` 目录下找到生成的 APK 文件，安装到 Android 设备即可 📱。


## 许可证说明 📜

本项目采用**多许可证组合**，具体如下：

- **AstrBot 相关模块**：遵循 **AGPL-v3 许可证**（因深度集成 AstrBot 框架，需遵守其开源协议要求）。
  - 商业使用规则：若修改后用于商业性质网络服务，必须开源修改内容；若需闭源商业使用，需联系 `community@astrbot.app` 申请商业授权。
- **Code LFA 衍生的容器环境模块**：遵循 **BSD-3-Clause 许可证**（尊重原始 Code LFA 项目的开源协议）。


## 致谢 🙏

- 感谢 [Code LFA](https://github.com/xxx/code_lfa) 提供的 Android 端 Ubuntu 容器运行环境，为本项目奠定了基础 🛠️。
- 感谢 [AstrBot](https://docs.astrbot.app/) 团队开发的优秀聊天机器人框架，让移动端部署 AI 机器人成为可能 🚀。


如果你在使用过程中遇到问题或有功能建议，欢迎提交 Issues 或参与项目讨论！ 💬🌟