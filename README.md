# AstrBot-Android-App: AstrBot 安卓 app 版本 
# 🤖 移动端一键运行的 AstrBot 聊天机器人平台

## 项目简介 📝
![455484170-ffd99b6b-3272-4682-beaa-6fe74250f7d9](https://github.com/user-attachments/assets/77a04df3-9721-4e92-b2c3-975c11006167)

AstrBot-Android-App 是一款基于 **[AstrBot](https://docs.astrbot.app/) 聊天机器人框架** 、 **NapCatQQ消息适配器** 并借助了 **Code LFA 的 Ubuntu 容器环境、模拟终端 & WebView框架** 打造的移动端解决方案，让你在 Android 设备上一键启动、配置并运行强大的多平台 LLM 聊天机器人。

我们移除了原始 Code LFA 中与 code-server 相关的所有模块，深度集成 AstrBot 框架，借助其 Ubuntu 容器环境实现 AstrBot 在移动端的本地化运行，并通过内置 WebView 直接连接 AstrBot 浏览器仪表盘，让移动端部署 AI 聊天机器人变得前所未有的简单。


## 核心特性 ✨

- **一键启动 🚀**：在 Android 设备上无需复杂配置，点击即可启动 AstrBot 服务。
- **图形化配置 🖥️**：通过内置 WebView 直接访问 AstrBot 浏览器仪表盘，可视化配置 LLM 对接、消息平台适配、插件管理等功能（你也可以在本地浏览器输入 `http://localhost:端口名` [详见相应文档]访问 AstrBot 仪表盘和 napcat 等容器的 Web 配置界面）。
- **多平台支持 🌐**：默认支持 QQ 个人账号消息平台，可参考 AstrBot 文档扩展至企业微信、Telegram、Discord 等多种平台。
- **强大的 LLM 兼容 🧠**：支持对接 OpenAI、Llama、Gemini、Dify 等主流大语言模型。
- **本地 Ubuntu 容器 🐧**：基于 Code LFA 提供的 Ubuntu 容器环境，保障 AstrBot 依赖的稳定性与兼容性。
- **消息平台适配器 📡**：默认集成 napcatQQ 消息平台适配器并已完成 AstrBot 相关配置，直接登录即可使用 QQ 个人账号消息平台。

<!-- 5张图并排，各占18%宽度，保留间距，比例不变 -->
<img width="18%" alt="Screenshot_20251114-023227 AstrBot" src="https://github.com/user-attachments/assets/4fe35a68-96ff-4057-ac2a-15a9a0557865" style="margin-right: 2%;">
<img width="18%" alt="Screenshot_20251114-023211 AstrBot" src="https://github.com/user-attachments/assets/24bc91e7-e9b9-41bc-afff-ab7d4a03a19f" style="margin-right: 2%;">
<img width="18%" alt="Screenshot_20251114-023214 AstrBot" src="https://github.com/user-attachments/assets/d9e9915d-64d9-44f4-bf89-cbdac134bee4" style="margin-right: 2%;">
<img width="18%" alt="Screenshot_20251114-020817 AstrBot" src="https://github.com/user-attachments/assets/5edbd9f8-b743-4898-8927-6744709c42bc" style="margin-right: 2%;">
<img width="18%" alt="Screenshot_20251114-012715 AstrBot" src="https://github.com/user-attachments/assets/a966eae3-6378-4cc0-813b-45e961eb9325">

## 快速开始 🏁

### 环境要求 📋
- Android 设备（建议 Android 10 及以上版本）
- 至少 4GB 可用内存（运行 Ubuntu 容器与 AstrBot 需占用一定资源）


### 启动流程 🔄
1. 安装并启动 AstrBot-Android-App。
2. 应用会自动初始化 Ubuntu 容器并部署 AstrBot 服务 ⏳。
3. 命令行界面会显示 napcatQQ 登录二维码，扫描登录 QQ 账号。
3. 登录成功后，内置 WebView 会自动跳转至 **AstrBot 浏览器仪表盘** 🎯。
4. 在仪表盘内完成 LLM 服务配置、插件安装等操作 ⚙️。
5. 启动机器人，即可在对应消息平台上体验 AI 聊天能力 💬。


## 开发与构建 🔨

如果你想对项目进行二次开发或自行构建，可以执行以下步骤：


### 依赖安装 📥
确保你的开发环境已安装：
- Flutter SDK  🎯
- Android SDK


### 构建步骤 🛠️
1. 克隆本项目仓库：
   ```bash
   git clone https://github.com/zz6zz666/AstrBot-Android-App.git
   cd AstrBot-Android-App
   ```
2. 执行构建命令：
   ```bash
   flutter build apk
   ```
   或调试命令：
   ```bash
   flutter run
   ```


## 许可证说明 📜

本项目采用 **BSD-3-Clause 许可证**，尊重根基项目 Code LFA 的开源协议。


## 致谢 🙏

- 感谢 [Code LFA](https://github.com/nightmare-space/code_lfa) 提供的 Android 端 Ubuntu 容器运行环境，为本项目奠定了基础 🛠️。
- 感谢 [AstrBot](https://docs.astrbot.app/) 团队开发的优秀聊天机器人框架，让移动端部署 AI 机器人成为可能 🚀。
- 感谢 [napcatQQ](https://napneko.github.io/guide/napcat) 团队开发的 QQ 消息平台适配器，作为 AstrBot 框架的一部分为 QQ 机器人部署提供了重要支持 🔌。


如果你在使用过程中遇到问题或有功能建议，欢迎提交 Issues 或参与项目讨论！ 💬🌟
