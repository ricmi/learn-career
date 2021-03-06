# windows 自动化部署脚本

[noc]

## 部署步骤

### 1. 创建实例

> 第一步创建实例不属于脚本的内容，脚本涵盖的是 第二~三步。

部署的第一步，创建一个分配好 ip 和 hostname 的实例 (痛点在于，能否将分配的步骤自动化)，按照实现的难度分为两个环境：

- Tencent
  腾讯云有一套完整的接口，可以很快的创建多台实例，而且创建时可以通过参数分配好 ip 以及 hostname。

- local
  本地环境有 华为云、融合云、hyper-V 等，接口未开放、开放程度低、未开发接口 等 是本地创建慢的原因；后期会尽量通过接口去操作创建实例。

### 2. 基础配置信息

> 最底层的系统信息以及管理软件的配置

- ipv4 Address
  用于环境的验证，无需任何更改。
- HOSTNAME
  目前环境不统一 需要验证，如果不通过，则需更改并重启。
- DNS
  有多个机房，每个机房有两个 DNS，同时也是域控。
  脚本自动识别并添加
- Domain
  需要确保加域的时候，上面的三个信息都是正确的，否则后续会有异常。
  操作同上。
- Port
  远程端口
- 执行策略
  脚本的执行、远程等策略。
- Winrm
  基础的通信服务设置，类似 Linux 的 SSH。

### 3. 容器模块

> 包括运行程序的模块，以及相关的容器类。

- 管理工具

  - Chocolatey
    统一的服务器软件管理工具，类似 Linux 的 yum 工具。
    每个业务线有对应的 choco 服务器，用于管理和下载软件包。
    安装由于官方网络上会有限制（同一个公网出口，大量的请求会被封禁），修改了脚本用于本地部署，脚本放至 noc.resource 库中。
  - BlueKing
    依赖于 python, 需放在 choco 安装完成 python 后。
    统一的平台管理工具。

- 基础的软件 及 相关的模块
  依赖于 choco 安装完成后，
  服务器运行所需的基础软件模块。

  - Nxlog
    日志和监控依赖软件。
  - WebDeploy
    用于 TFS 发布。
  - Python (必备)
    - Pip 切换阿里源
      安装软件快
    - Pip 安装需要的模块

- IIS 及其相关的模块 安装和配置

  - 最低的运行组件
    - 其中有老的项目及机器需要额外的配置
  - 日志字段相关设置
  - 其他相关的插件设置
    目前有 x-forword-for 插件

- Dotnet 相关设置
  - 确保 .Net-framework 是指定版本
    - 低于指定版本需要升级
  - 安装 dotnet core
  - 设置环境变量
    开发需要通过环境变量识别业务线、实现业务图映射等功能。
