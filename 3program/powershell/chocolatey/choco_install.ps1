# =====================================================================
# Copyright 2017 - 2020 Chocolatey Software, Inc, and the
# original authors/contributors from ChocolateyGallery
# Copyright 2011 - 2017 RealDimensions Software, LLC, and the
# original authors/contributors from ChocolateyGallery
# at https://github.com/chocolatey/chocolatey.org
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# =====================================================================

# For organizational deployments of Chocolatey, please see https://chocolatey.org/docs/how-to-setup-offline-installation

# Environment Variables, specified as $env:NAME in PowerShell.exe and %NAME% in cmd.exe.
# For explicit proxy, please set $env:chocolateyProxyLocation and optionally $env:chocolateyProxyUser and $env:chocolateyProxyPassword
# For an explicit version of Chocolatey, please set $env:chocolateyVersion = 'versionnumber'
# To target a different url for chocolatey.nupkg, please set $env:chocolateyDownloadUrl = 'full url to nupkg file'
# NOTE: $env:chocolateyDownloadUrl does not work with $env:chocolateyVersion.
# To use built-in compression instead of 7zip (requires additional download), please set $env:chocolateyUseWindowsCompression = 'true'
# To bypass the use of any proxy, please set $env:chocolateyIgnoreProxy = 'true'

# input ipv4address to get serverRoom(SH, SS, SQ, QS, QG)
function Get-ServerRoom {
    param (
        [Parameter(Mandatory = $true,
            HelpMessage = "Please enter the IpV4 address.")]
        [string]$ip
    )
    # ip corresponding to the server-room
    $server = @{
        SH = "192.168.5", "192.168.9", "172.17.30"
        SS = "172.20"
        SQ = "192.168.7", "172.21"
        QS = "172.31"
        QG = "172.29"
    }
    foreach ($name in $server.Keys) {
        if ($server.$name -is [array]) {
            $server.$name | ForEach-Object {
                if ($ip -match $_) { return $name }
            }
        }
        else {
            if ($ip -match $server.$name) { return $name }
        }
    }
}

# local choco-server's source-url
$chocoSourceList = @{
    chocolatey = "https://chocolatey.org/api/v2/"
    sh         = "http://192.168.9.228/nuget/nuget/"
    ss         = "http://ss-choco.1hai.cn/nuget/"
    sq         = "http://sq-choco.1hai.cn/nuget/"
    qs         = "http://qs-choco.1hai.cn/nuget/"
    qg         = "http://qg-choco.1hai.cn/nuget/"
}

# local ipv4-Address
$ipv4Address = (cmd /c "FOR /F "tokens=4 " %i in ('route print^|findstr "0.0.0.0.*0.0.0.0"') do @echo %i" | Select-Object -Index 0)

# get the download address of the choco-server corresponding to the ipv4
$serverRoomName = Get-ServerRoom -ip $ipv4Address
$serverRoomChocoSource = ($chocoSourceList.$serverRoomName)
$url = $serverRoomChocoSource.substring(0, $serverRoomChocoSource.length - 6) + "Packages/chocolatey/0.10.15/chocolatey.0.10.15.nupkg"


$chocolateyVersion = $env:chocolateyVersion
if (![string]::IsNullOrEmpty($chocolateyVersion)) {
    Write-Output "Downloading specific version of Chocolatey: $chocolateyVersion"
    $url = "https://chocolatey.org/api/v2/package/chocolatey/$chocolateyVersion"
}

$chocolateyDownloadUrl = $env:chocolateyDownloadUrl
if (![string]::IsNullOrEmpty($chocolateyDownloadUrl)) {
    Write-Output "Downloading Chocolatey from : $chocolateyDownloadUrl"
    $url = "$chocolateyDownloadUrl"
}

# temp path
if ($env:TEMP -eq $null) {
    $env:TEMP = Join-Path $env:SystemDrive 'temp'
}
$chocTempDir = Join-Path $env:TEMP "chocolatey"
$tempDir = Join-Path $chocTempDir "chocInstall"
if (![System.IO.Directory]::Exists($tempDir)) { [void][System.IO.Directory]::CreateDirectory($tempDir) }
$file = Join-Path $tempDir "chocolatey.zip"

# PowerShell v2/3 caches the output stream. Then it throws errors due
# to the FileStream not being what is expected. Fixes "The OS handle's
# position is not what FileStream expected. Do not use a handle
# simultaneously in one FileStream and in Win32 code or another
# FileStream."
function Fix-PowerShellOutputRedirectionBug {
    $poshMajorVerion = $PSVersionTable.PSVersion.Major

    if ($poshMajorVerion -lt 4) {
        try {
            # http://www.leeholmes.com/blog/2008/07/30/workaround-the-os-handles-position-is-not-what-filestream-expected/ plus comments
            $bindingFlags = [Reflection.BindingFlags] "Instance,NonPublic,GetField"
            $objectRef = $host.GetType().GetField("externalHostRef", $bindingFlags).GetValue($host)
            $bindingFlags = [Reflection.BindingFlags] "Instance,NonPublic,GetProperty"
            $consoleHost = $objectRef.GetType().GetProperty("Value", $bindingFlags).GetValue($objectRef, @())
            [void] $consoleHost.GetType().GetProperty("IsStandardOutputRedirected", $bindingFlags).GetValue($consoleHost, @())
            $bindingFlags = [Reflection.BindingFlags] "Instance,NonPublic,GetField"
            $field = $consoleHost.GetType().GetField("standardOutputWriter", $bindingFlags)
            $field.SetValue($consoleHost, [Console]::Out)
            [void] $consoleHost.GetType().GetProperty("IsStandardErrorRedirected", $bindingFlags).GetValue($consoleHost, @())
            $field2 = $consoleHost.GetType().GetField("standardErrorWriter", $bindingFlags)
            $field2.SetValue($consoleHost, [Console]::Error)
        }
        catch {
            Write-Output "Unable to apply redirection fix."
        }
    }
}

Fix-PowerShellOutputRedirectionBug

# Attempt to set highest encryption available for SecurityProtocol.
# PowerShell will not set this by default (until maybe .NET 4.6.x). This
# will typically produce a message for PowerShell v2 (just an info
# message though)
try {
    # Set TLS 1.2 (3072) as that is the minimum required by Chocolatey.org.
    # Use integers because the enumeration value for TLS 1.2 won't exist
    # in .NET 4.0, even though they are addressable if .NET 4.5+ is
    # installed (.NET 4.5 is an in-place upgrade).
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
}
catch {
    Write-Output 'Unable to set PowerShell to use TLS 1.2. This is required for contacting Chocolatey as of 03 FEB 2020. https://chocolatey.org/blog/remove-support-for-old-tls-versions. If you see underlying connection closed or trust errors, you may need to do one or more of the following: (1) upgrade to .NET Framework 4.5+ and PowerShell v3+, (2) Call [System.Net.ServicePointManager]::SecurityProtocol = 3072; in PowerShell prior to attempting installation, (3) specify internal Chocolatey package location (set $env:chocolateyDownloadUrl prior to install or host the package internally), (4) use the Download + PowerShell method of install. See https://chocolatey.org/docs/installation for all install options.'
}

function Get-Downloader {
    param (
        [string]$url
    )

    $downloader = new-object System.Net.WebClient

    $defaultCreds = [System.Net.CredentialCache]::DefaultCredentials
    if ($defaultCreds -ne $null) {
        $downloader.Credentials = $defaultCreds
    }

    $ignoreProxy = $env:chocolateyIgnoreProxy
    if ($ignoreProxy -ne $null -and $ignoreProxy -eq 'true') {
        Write-Debug "Explicitly bypassing proxy due to user environment variable"
        $downloader.Proxy = [System.Net.GlobalProxySelection]::GetEmptyWebProxy()
    }
    else {
        # check if a proxy is required
        $explicitProxy = $env:chocolateyProxyLocation
        $explicitProxyUser = $env:chocolateyProxyUser
        $explicitProxyPassword = $env:chocolateyProxyPassword
        if ($explicitProxy -ne $null -and $explicitProxy -ne '') {
            # explicit proxy
            $proxy = New-Object System.Net.WebProxy($explicitProxy, $true)
            if ($explicitProxyPassword -ne $null -and $explicitProxyPassword -ne '') {
                $passwd = ConvertTo-SecureString $explicitProxyPassword -AsPlainText -Force
                $proxy.Credentials = New-Object System.Management.Automation.PSCredential ($explicitProxyUser, $passwd)
            }

            Write-Debug "Using explicit proxy server '$explicitProxy'."
            $downloader.Proxy = $proxy

        }
        elseif (!$downloader.Proxy.IsBypassed($url)) {
            # system proxy (pass through)
            $creds = $defaultCreds
            if ($creds -eq $null) {
                Write-Debug "Default credentials were null. Attempting backup method"
                $cred = get-credential
                $creds = $cred.GetNetworkCredential();
            }

            $proxyaddress = $downloader.Proxy.GetProxy($url).Authority
            Write-Debug "Using system proxy server '$proxyaddress'."
            $proxy = New-Object System.Net.WebProxy($proxyaddress)
            $proxy.Credentials = $creds
            $downloader.Proxy = $proxy
        }
    }

    return $downloader
}

function Download-String {
    param (
        [string]$url
    )
    $downloader = Get-Downloader $url

    return $downloader.DownloadString($url)
}

function Download-File {
    param (
        [string]$url,
        [string]$file
    )
    #Write-Output "Downloading $url to $file"
    $downloader = Get-Downloader $url

    $downloader.DownloadFile($url, $file)
}

if ($url -eq $null -or $url -eq '') {
    Write-Output "Getting latest version of the Chocolatey package for download."
    $url = 'https://chocolatey.org/api/v2/Packages()?$filter=((Id%20eq%20%27chocolatey%27)%20and%20(not%20IsPrerelease))%20and%20IsLatestVersion'
    [xml]$result = Download-String $url
    $url = $result.feed.entry.content.src
}

# Download the Chocolatey package
Write-Output "Getting Chocolatey from $url."
Download-File $url $file

# Determine unzipping method
# 7zip is the most compatible so use it by default
$7zaExe = Join-Path $tempDir '7za.exe'
$unzipMethod = '7zip'
$useWindowsCompression = $env:chocolateyUseWindowsCompression
if ($useWindowsCompression -ne $null -and $useWindowsCompression -eq 'true') {
    Write-Output 'Using built-in compression to unzip'
    $unzipMethod = 'builtin'
}
elseif (-Not (Test-Path ($7zaExe))) {
    Write-Output "Downloading 7-Zip commandline tool prior to extraction."
    # download 7zip
    Download-File 'http://ss-choco.1hai.cn/tools/7za.exe' "$7zaExe"
}

# $unzipMethod = 'builtin'
# unzip the package
Write-Output "Extracting $file to $tempDir..."
if ($unzipMethod -eq '7zip') {
    $params = "x -o`"$tempDir`" -bd -y `"$file`""
    # use more robust Process as compared to Start-Process -Wait (which doesn't
    # wait for the process to finish in PowerShell v3)
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = New-Object System.Diagnostics.ProcessStartInfo($7zaExe, $params)
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $process.Start() | Out-Null
    $process.BeginOutputReadLine()
    $process.WaitForExit()
    $exitCode = $process.ExitCode
    $process.Dispose()

    $errorMessage = "Unable to unzip package using 7zip. Perhaps try setting `$env:chocolateyUseWindowsCompression = 'true' and call install again. Error:"
    switch ($exitCode) {
        0 { break }
        1 { throw "$errorMessage Some files could not be extracted" }
        2 { throw "$errorMessage 7-Zip encountered a fatal error while extracting the files" }
        7 { throw "$errorMessage 7-Zip command line error" }
        8 { throw "$errorMessage 7-Zip out of memory" }
        255 { throw "$errorMessage Extraction cancelled by the user" }
        default { throw "$errorMessage 7-Zip signalled an unknown error (code $exitCode)" }
    }
}
else {
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        try {
            $shellApplication = new-object -com shell.application
            $zipPackage = $shellApplication.NameSpace($file)
            $destinationFolder = $shellApplication.NameSpace($tempDir)
            $destinationFolder.CopyHere($zipPackage.Items(), 0x10)
        }
        catch {
            throw "Unable to unzip package using built-in compression. Set `$env:chocolateyUseWindowsCompression = 'false' and call install again to use 7zip to unzip. Error: `n $_"
        }
    }
    else {
        Expand-Archive -Path "$file" -DestinationPath "$tempDir" -Force
    }
}

# Call chocolatey install
Write-Output "Installing chocolatey on this machine"
$toolsFolder = Join-Path $tempDir "tools"
$chocInstallPS1 = Join-Path $toolsFolder "chocolateyInstall.ps1"

& $chocInstallPS1

Write-Output 'Ensuring chocolatey commands are on the path'
$chocInstallVariableName = "ChocolateyInstall"
$chocoPath = [Environment]::GetEnvironmentVariable($chocInstallVariableName)
if ($chocoPath -eq $null -or $chocoPath -eq '') {
    $chocoPath = "$env:ALLUSERSPROFILE\Chocolatey"
}

if (!(Test-Path ($chocoPath))) {
    $chocoPath = "$env:SYSTEMDRIVE\ProgramData\Chocolatey"
}

$chocoExePath = Join-Path $chocoPath 'bin'

if ($($env:Path).ToLower().Contains($($chocoExePath).ToLower()) -eq $false) {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine);
}

Write-Output 'Ensuring chocolatey.nupkg is in the lib folder'
$chocoPkgDir = Join-Path $chocoPath 'lib\chocolatey'
$nupkg = Join-Path $chocoPkgDir 'chocolatey.nupkg'
if (![System.IO.Directory]::Exists($chocoPkgDir)) { [System.IO.Directory]::CreateDirectory($chocoPkgDir); }
Copy-Item "$file" "$nupkg" -Force -ErrorAction SilentlyContinue

# choco : remove offical-source, add local-source
$localSources = (choco source | Select-Object -Skip 1)
# remove offical-chocolatey-source: [chocolatey = https://chocolatey.org/api/v2/"]
$null = $localSources | % { $n = $_.split()[0] ; choco source remove -n="$n" }
# add choco-server-source corresponding to the ipv4
choco source add -n="$serverRoomName" -s="$serverRoomChocoSource"
