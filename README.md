# TransmissionRemote

[English](README.en.md) · **简体中文**

面向 **[Transmission](https://transmissionbt.com/) BitTorrent 守护进程**的 **HarmonyOS 客户端** ——
在手机或平板上管理你的下载机：查看进度、添加磁力链接与 `.torrent` 文件、调整单个种子与会话设置，
并在多台服务器之间随时切换。

仓库包含两部分：

| 目录 | 内容 |
|:--|:--|
| **`entry/`** | 应用本体 —— 用 ArkUI 编写的完整 Transmission 远程控制客户端 |
| **`transmission_sdk/`** | `transmission_sdk`，应用所依赖的 ArkTS RPC 客户端，以 HAR 形式打包 |

SDK 是一等交付物，而非实现细节。它同时支持 Transmission 历史上出现过的**两代 RPC 协议**，
因此同一个应用既能驱动最新的 4.1.x 守护进程，也能驱动一台跑了十来年的老 NAS：

| Transmission 版本 | RPC 版本 | 报文风格 | 支持 |
|:--|:--|:--|:--|
| **4.1.0 及更新** | `rpc-version-semver` ≥ `6.0.0` | JSON-RPC 2.0，snake_case 键名 | ✅ 首选 |
| **4.0.x 及更早**（1.30 → 4.0.x） | `rpc-version` ≤ `17` | 早期私有协议，kebab-case / camelCase 混用 | ✅ 自动降级 |

业务代码**只写一遍**，统一使用现代的 snake_case 词汇；兼容层会为老版本服务端转换方法名、字段名与
取值编码，因此一次调用即可驱动所有 4.x 守护进程。

---

## 功能

**种子管理**

- 种子列表支持滑动操作：开始、暂停、校验、重新汇报、移除、删除数据、编辑。
- 详情页五个标签页：信息、文件、Tracker、节点、选项。
- 单种子编辑：带宽限速及其开关、队列位置、节点上限、做种空闲设置、分享率限制、带宽组、标签、
  顺序下载、文件优先级。
- 添加种子：磁力链接、HTTP(S) 的 `.torrent` 地址，或本地 `.torrent` 文件。
- 过滤：全部、活动、下载中、做种中、已暂停、已下载、已完成；12 个排序字段加升降序切换。
  过滤与排序都在本地完成，不产生额外请求。

**服务器与会话**

- 可保存多台服务器，地址形如 `scheme://host:port/path`，可选 HTTP Basic 认证，因此 HTTP 与
  HTTPS 都支持。
- 在编辑界面即可测试连通性，无需先保存。
- 会话设置：下载目录、上下行限速、加密模式、首选传输协议，以及 RPC 规范中所有可写设置。

**界面**

- 明暗两套配色，默认跟随系统，也可在应用内指定。
- 中英文双语。
- 所有图标均为 HarmonyOS **系统符号（system symbol）**，可随无障碍字号缩放，并跟随系统字重。
- 列表在有任务实际传输时自动加快轮询，空闲时回落至用户配置的间隔。

## 界面

| 界面 | 文件 | 入口 |
|:--|:--|:--|
| 种子列表（首页） | `entry/src/main/ets/pages/Index.ets` | 启动 |
| 种子详情（5 个标签页） | `pages/TorrentDetailPage.ets` | 点击列表项 |
| 添加种子 | `pages/AddTorrentPage.ets` | 悬浮按钮或溢出菜单 |
| 服务器 | `pages/ServersPage.ets` | 抽屉或溢出菜单 |
| 选项 | `pages/SettingsPage.ets` | 抽屉 |

首页是唯一的 `@Entry` 页面，其余均为压入其 `NavPathStack` 的 `NavDestination`。

```
Index (Navigation + SideBarContainer)
├── DrawerContent      服务器 · 过滤 · 排序 · 夜间模式 · 选项 · 可用空间
├── topBar             ☰ · 服务器 ▾ · ▶ · ‖ · ⋮（或搜索框）
├── listArea           Refresh > List > TorrentRowView，逐行 swipeAction
│   └── floatingButton ＋ 展开为 文件 / 链接
└── bottomBar          ↓ 总下行 · ↑ 总上行 · ⌕
```

## 环境要求

**运行**应用需要：

- HarmonyOS 设备（手机 / 平板 / 二合一），系统版本 5.0.0（API 12）及以上。
  `compatibleSdkVersion` 保持在 API 12，因此仍可安装在 HarmonyOS 5.0 设备上；`targetSdkVersion`
  为 API 26（HarmonyOS 7.0.0）。
- 一台开启 RPC 且可访问的 Transmission 守护进程 —— 在 Transmission 图形界面的*偏好设置 → 远程*
  中开启，或修改 `settings.json` 的 `rpc-enabled`。
- `ohos.permission.INTERNET` 权限，已在 `module.json5` 中声明。

**构建**需要：

- 装有 HarmonyOS SDK 的 DevEco Studio，**或**华为命令行工具（见「构建」一节）。
- Node.js 18+ —— 仅宿主机测试框架与构建包装脚本需要。

## 目录结构

```
TransmissionRemote/
├── AppScope/                      # 应用级清单与资源
├── entry/                         # 应用模块（HAP）
│   └── src/main/ets/
│       ├── entryability/          # UIAbility 入口
│       ├── pages/                 # 列表 · 详情（5 标签页）· 添加 · 服务器 · 选项
│       ├── components/            # 抽屉、种子行、详情字段行
│       ├── model/                 # 服务器、设置、排序/过滤/主题枚举
│       ├── store/                 # 持久化状态 + 共享的 SDK 客户端
│       ├── theme/                 # 配色、主题管理、系统符号名
│       └── viewmodel/             # 列表模型、详情模型、格式化、文件选择
├── transmission_sdk/              # SDK，以 HAR 形式打包
│   ├── index.ets                  # 模块入口（再导出 src/main/ets/index.ets）
│   ├── oh-package.json5           # HAR 清单；"main": "index.ets"
│   ├── obfuscation-rules.txt      # 混淆下保留协议键名
│   └── src/
│       ├── main/ets/
│       │   ├── index.ets          # 公有 API 汇总导出
│       │   ├── api/               # TorrentApi · SessionApi · SystemApi · BandwidthGroupApi
│       │   ├── client/            # TransmissionClient · TransmissionClientBuilder
│       │   ├── core/              # RpcClient · RpcBatch · TransmissionConfig
│       │   ├── compat/            # 两代协议编解码、键名转换、协商
│       │   ├── constants/         # 方法名、字段名、协议常量
│       │   ├── error/             # TransmissionError、RpcErrorCode
│       │   ├── model/             # 类型化模型与请求构造器
│       │   ├── platform/          # 各端口的 ArkTS 实现
│       │   ├── transport/         # HttpTransport 端口 + 请求/响应值对象
│       │   └── util/              # Json、Base64、Semver、Logger
│       └── test/                  # hypium 单元测试（真机或 Node 上运行）
├── hvigorw · hvigorw.bat          # 构建包装脚本：先解析工具链，再调用 hvigor
├── scripts/                       # 宿主机测试框架、构建包装、表格生成器
└── docs/                          # ARCHITECTURE · COMPATIBILITY · API · APP
```

## SDK

`transmission_sdk` 是应用中唯一与网络打交道的部分，是一个不依赖应用的独立 HAR 模块。

- **一套 API，两代协议。** 从新到旧的协商在最坏情况下也只在首次请求时多一次 HTTP 往返，通常为零。
- **完整类型化模型。** `Torrent`、`SessionSettings`、`Peer`、`TrackerStat` 等，枚举已解析、默认值
  有文档，而不是裸 JSON。
- **链式请求构造器。** `TorrentGetRequest`、`TorrentSetRequest`、`TorrentAddRequest`、
  `SessionSetRequest`、`BandwidthGroupSetRequest` 只会把你实际设置过的字段发到线上。
- **类型化错误。** 统一的 `TransmissionError`，带粗粒度的 `kind` 与规范化的 `RpcErrorCode`，
  并移植了 Transmission 自身的「旧版错误消息 → 错误码」推断逻辑。
- **批量调用。** `client.batch()` 可将多个调用合并为一次 HTTP 往返。
- **可替换的传输与日志。** SDK 只通过 `HttpTransport` 接口访问网络 —— 这正是整个客户端可以脱离
  设备做单元测试的原因。
- **内核无平台依赖。** 只有 `platform/ArkHttpTransport` 与 `platform/HilogLogger` 引入了
  HarmonyOS kit。
- **生成式表格。** 字段名与旧协议键名映射由 Transmission 源码生成，不会与上游脱节。

### 接入到自己的应用

1. 将 `transmission_sdk/` 复制进你的工程（或发布到你的 ohpm 仓库）。
2. 声明依赖：

   ```json5
   // entry/oh-package.json5
   {
     "dependencies": {
       "transmission_sdk": "file:../transmission_sdk"
     }
   }
   ```

3. 在 `module.json5` 中申请网络权限：

   ```json5
   {
     "module": {
       "requestPermissions": [
         { "name": "ohos.permission.INTERNET" },
         { "name": "ohos.permission.GET_NETWORK_INFO" }
       ]
     }
   }
   ```

4. 从 `transmission_sdk` 导入。

### 快速上手

```ts
import {
  TransmissionClientBuilder,
  TorrentGetRequest,
  TorrentFields,
  TorrentIds,
  ApiStyleMode,
} from 'transmission_sdk';

const client = new TransmissionClientBuilder()
  .host('192.168.1.10')              // http://192.168.1.10:9091/transmission/rpc
  .credentials('admin', 'secret')
  .apiStyleMode(ApiStyleMode.AUTO)   // 默认值：自动协商
  .timeout(10_000)
  .build();

const settings = await client.connect();   // 自动协商协议版本
console.info(`服务端 ${settings.version}，rpc ${client.serverVersion?.toString()}`);

const torrents = await client.torrents.get(
  new TorrentGetRequest(TorrentFields.BASIC).ids(TorrentIds.RECENTLY_ACTIVE),
);

await client.torrents.addMagnet('magnet:?xt=urn:btih:…');
client.close();
```

**修改种子** —— 只有调用过的 setter 才会出现在报文中：

```ts
import { TorrentIds, TorrentSetRequest, IdleLimitMode } from 'transmission_sdk';

await client.torrents.stop(TorrentIds.ofHashes(['a1b2c3…']));
await client.torrents.verify(TorrentIds.single(42));

await client.torrents.set(
  new TorrentSetRequest(TorrentIds.single(42))
    .downloadLimit(2048)
    .downloadLimited(true)
    .seedIdleMode(IdleLimitMode.UNLIMITED)
    .labels(['linux', 'iso']),
);
```

**会话设置** —— `SessionSetRequest` 覆盖 RPC 规范中所有可写设置（49 个 setter）：

```ts
import { SessionSetRequest, EncryptionMode, TransportProtocol } from 'transmission_sdk';

await client.session.set(
  new SessionSetRequest()
    .downloadDir('/srv/media')
    .speedLimitDown(4096)
    .speedLimitDownEnabled(true)
    .encryption(EncryptionMode.REQUIRED)
    .preferredTransports([TransportProtocol.UTP, TransportProtocol.TCP]),
);
```

**批量调用** —— 一次往返刷新整个面板：

```ts
import { RpcMethod, BatchResults, SessionSettings, SessionStats, TorrentGetRequest } from 'transmission_sdk';

const batch = client
  .batch()
  .add(RpcMethod.SESSION_GET)
  .add(RpcMethod.SESSION_STATS)
  .add(RpcMethod.TORRENT_GET, new TorrentGetRequest(TorrentFields.BASIC).toJson());

const results = new BatchResults(await batch.execute());
const settings = SessionSettings.fromJson(results.at(0));
const stats = SessionStats.fromJson(results.at(1));
```

**错误处理** —— 一个类型、一个粗粒度 kind、一个规范化错误码：

```ts
import { TransmissionError, TransmissionErrorKind } from 'transmission_sdk';

try {
  await client.torrents.addFromUri('magnet:?xt=urn:btih:…');
} catch (error) {
  if (error instanceof TransmissionError && error.kind === TransmissionErrorKind.AUTHENTICATION) {
    // 账号或密码错误
  }
}
```

**后续启动跳过协商** —— 记住已解析的协议风格与 CSRF 会话 ID：

```ts
const client = new TransmissionClientBuilder()
  .host('192.168.1.10')
  .apiStyleMode(ApiStyleMode.AUTO)
  .onApiStyleResolved((style) => { /* 持久化保存 */ })
  .sessionId(await preferences.get('sessionId', ''))
  .build();
```

把已知的协议风格重新传给 `.apiStyleMode(...)` 并恢复会话 ID，之后的启动就能完全跳过协商与
CSRF 握手。

## 构建

用 DevEco Studio 打开工程后直接运行，或在终端构建：

```bash
npm run build          # debug HAP → entry/build/default/outputs/default/entry-default-signed.hap
npm run build:har      # SDK      → transmission_sdk/build/default/outputs/default/transmission_sdk.har
npm run build:app      # release APP
npm run clean
./hvigorw --print-env  # 只打印将使用的工具链，不执行构建
```

`hvigorw`（以及 `npm run build`）**不需要**预先导出 `DEVECO_HOME` 或 `JAVA_HOME`：
`scripts/run-hvigor.mjs` 会自行定位 DevEco Studio 安装目录，再把 `DEVECO_SDK_HOME`、内置 JDK
（`jbr/`）以及对应的 `PATH` 项传给 hvigor。少了最后这一步，`PackageHap` 会以
`spawn java ENOENT` 失败，而 hvigor 只会报一个毫无提示的 `00308018 Unknown Error`。已经存在的
环境变量优先级更高，因此同一条命令在 CI 中也能直接用 —— 只要把 `DEVECO_HOME` 指向华为命令行工具，
并为该布局提供 JDK。详见 [scripts/README.md](scripts/README.md)。

> **签名与包名绑定。** `build-profile.json5` 中的签名 profile 是为某一个 `bundleName` 签发的；
> 改动 `AppScope/app.json5` 里的 `bundleName` 会使其失效，`SignHap` 报 `00303074`。请在 DevEco
> Studio 中重新生成签名：*File → Project Structure → Signing Configs → 勾选 Automatically
> generate signature*。没有有效签名时仍会产出 `entry-default-unsigned.hap`，但这种未签名包需先用
> 签名工具签名，才能安装到设备上。

## 测试

SDK 的 hypium 单元测试与源码放在一起（`transmission_sdk/src/test/`），可在 DevEco Studio 中作为
本地单元测试运行。

为了 CI —— 也为了没有 DevEco Studio 的人 —— 仓库还提供一个宿主机测试框架：它把每个 `.ets` 复制为
`.ts`，用仓库自带的 TypeScript 编译，然后在 Node.js 上运行同一批测试文件，并用替身包替代
`@ohos/hypium`、`@kit.NetworkKit`、`@ohos.hilog` 与 `@kit.BasicServicesKit`：

```bash
npm install                    # 首次：为宿主机测试框架安装 TypeScript
npm test                       # ArkTS lint + 类型检查 + 运行全部单元测试
npm run typecheck              # 仅 lint + 类型检查
npm run lint                   # 仅 ArkTS 合规检查 + 清单 schema 检查
node scripts/run-tests.mjs --filter "LegacyCodec"
DSH_BUILD_DIR=.node-build-x node scripts/run-tests.mjs   # 使用独立构建目录
```

由于传输层是接口化的，测试不需要真实服务端：测试用例脚本化了 409 握手、两代协议的报文封装、错误
载荷与畸形响应，并断言最终得到的类型化模型。应用侧不依赖 ArkUI 的层（`model/`，以及 `viewmodel/`
中的列表过滤与排序）也由同一套框架编译并测试。

`npm run lint` 覆盖的是 `tsc` 和宿主机测试框架都看不见的部分 —— DevEco 强制的 ArkTS 限制、
`module.json5` / HAR 清单 schema、明暗配色之间与中英文字符串之间的资源对齐、无法解析的导入与不存在
的 SDK 导出，以及记录在 [docs/APP.md](docs/APP.md) 里的那些 ArkUI 陷阱。完整规则列表见
[scripts/README.md](scripts/README.md)。

ArkUI 的 `struct` 与装饰器不是 TypeScript，因此界面本身由 `npm run lint` 加一次 DevEco 构建来兜底。

## 协议差异速查

| 特性 | Transmission ≥ 4.1.0 | Transmission < 4.1.0 |
|:--|:--|:--|
| 报文封装 | `{jsonrpc, method, params, id}` | `{method, arguments, tag}` |
| 方法名 | `torrent_get` | `torrent-get` |
| 字段名 | `percent_done` | `percentDone` |
| `download_dir` | `download_dir` | 种子相关调用中为 `downloadDir`，其余为 `download-dir` |
| `wanted` 中的布尔值 | `true` / `false` | `1` / `0` |
| `encryption: allowed` | `allowed` | `tolerated` |
| `free_space.total_size` | `total_size` | `total_size`（是的，用下划线） |
| 错误上报 | `error.code` + `error.message` + `error.data` | `result` 中的字符串 |
| 版本探测 | 409 响应头 `X-Transmission-Rpc-Version`，以及 `rpc_version_semver` | `rpc_version`（整数） |

细节（含协商算法）见 [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md)。

## 重新生成的文件

有四个已提交的文件是生成出来的，以确保它们不会与来源脱节：

```bash
node scripts/generate-legacy-keys.mjs          # compat/LegacyKeys.ets       （来自 libtransmission/api-compat.cc）
node scripts/generate-rpc-fields.mjs           # constants/RpcFields.ets     （来自 docs/rpc-spec.md）
node scripts/generate-session-set-request.mjs  # model/SessionSetRequest.ets （来自 docs/rpc-spec.md）
node scripts/generate-app-resources.mjs        # entry 明暗配色 + 中英文字符串
```

每个脚本默认读取同级目录下的 `../transmission-ref` 检出，也可传入路径覆盖。

## 文档

- [docs/APP.md](docs/APP.md) —— 应用：界面、主题、持久化、刷新节奏
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) —— SDK 分层、请求生命周期、设计取舍
- [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md) —— 两代协议、协商、转换规则
- [docs/API.md](docs/API.md) —— 每个导出符号的参考
- [scripts/README.md](scripts/README.md) —— 宿主机测试框架与构建包装脚本

> 以上文档目前仍为英文版；按项目约定，**新写的**文档默认使用中文。

## 许可证

**GPL-2.0-only OR GPL-3.0-only** —— 与 Transmission 本身相同的双许可，因为其中有三个生成文件转录
自 Transmission 源码树。完整理由，以及你的应用无法采用 GPL 时的可选方案，见 [LICENSE](LICENSE)。
