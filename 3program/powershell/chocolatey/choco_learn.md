# Chocolatey 安装与使用

## choco 安装

- powershell 安装

> 如果同一 IP 多次访问 Choco （出口 IP 都是一个），官方的策略会禁用访问，导致一段时间内，都无法访问。

```powershell
# Get-ExecutionPolicy 确保策略不受限，使用Bypass绕过策略来安装东西。
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# powershell v3+ 也可以使用下面的命令
Set-ExecutionPolicy Bypass -Scope Process -Force; iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex
```

- 从 powershell 通过 .nupkg 包安装

```powershell
1. 下载安装包
# 这里最好使用自建库中的包，因为官网下载会有策略和网络问题。
> Chocolatey package: https://chocolatey.org/api/v2/package/chocolatey/   # 这个是最新的包

2. 使用可解压 zip 格式的压缩软件解压下载好的 choco*.nupkg 文件（nupkg 实际上可以认为是 zip 文件）放置在任意目录，

3. 进入工作目录中的 tools 目录

4. 确保所有的可执行策略都可用，使用 Get-ExecutionPolicy 了解，然后 执行 `& .\chocolateyInstall.ps1`

5. 然后更换一下对应自定义源，我们总共有6个自定义源。（这一步是为了避免官方的源会有网络及策略问题）
    ```powershell
    -n="chocolatey" -s="https://chocolatey.org/api/v2/"
    -n="sh" -s="http://192.168.9.228/nuget/nuget"
    -n="ss" -s="ss-choco.1hai.cn/nuget"
    -n="sq" -s="sq-choco.1hai.cn/nuget"
    -n="qs" -s="qs-choco.1hai.cn/nuget"
    -n="qg" -s="qg-choco.1hai.cn/nuget"
    ```

6. 最后使用源重新安装一下 chocolatey
`choco upgrade chocolatey -y`

