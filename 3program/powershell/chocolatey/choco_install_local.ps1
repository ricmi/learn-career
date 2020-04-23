#Requires -RunAsAdministrator
# The script must to  running as administrator

function Get-ServerRoom {
    param (
        [Parameter(Mandatory = $true,
            HelpMessage = "Please enter the IpV4 address.")]
        [string]$Ip
    )
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

function Remove-ChocoSource {
    param(
        [array]$Name, # input multiple source-name by array.
        [switch]$AllSource              # enter `Remove-ChocoSource -AllSource` to remove all source.
    )
    $sources = (choco source | Select-Object -Skip 1)
    if ($allSource) {
        $sources | % { $n = $_.split()[0] ; choco source remove -n="$n" }
    }
    else {
        $name | % { $n = $_.split()[0] ; choco source remove -n="$n" }
    }
}

function Add-ChocoSource {
    param (
        [validateset("chocolatey", "sh", "ss", "sq", "qs", "qg")]
        [array]$name,
        [switch]$allSource
    )
    ### all of the official & custom source.
    $sourceList = @{
        chocolatey = "https://chocolatey.org/api/v2/"
        sh         = "http://192.168.9.228/nuget/nuget"
        ss         = "http://ss-choco.1hai.cn/nuget"
        sq         = "http://sq-choco.1hai.cn/nuget"
        qs         = "http://qs-choco.1hai.cn/nuget"
        qg         = "http://qg-choco.1hai.cn/nuget"
    }
    if ($allSource) { $name = @("chocolatey", "sh", "ss", "sq", "qs", "qg") }
    $name | % { $s = $sourceList.$_ ; choco source add -n="$_" -s="$s" }
}

### Install choco by .nupkg.
function Add-Choco {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServerRoom
    )
    # Set file's url & dir.
    if ($ServerRoom -eq "SH") { $downloadUrl = "http://192.168.9.228/nuget/Packages/chocolatey/0.10.15/chocolatey.0.10.15.nupkg" }
    else { $downloadUrl = "http://" + $ServerRoom + "-choco.1hai.cn/Packages/chocolatey/0.10.15/chocolatey.0.10.15.nupkg" }
    #$officialUrl = "https://chocolatey.org/api/v2/package/chocolatey/"

    $chocoInstallDir = "C:\ProgramData\chocolatey\"
    $chocoTempDir = "C:\choco_temp\"
    ### restart powershell to delete temp-path "c:\choco_temp\".
    #Remove-Item -Path C:\choco_temp -Recurse

    $chocoInstallDir, $chocoTempDir | % { if (Test-Path $_) { mkdir $_ }
        else { Remove-Item -Path ($_ + "*") -Recurse -Force } }

    # Download & Expand file to temp_folder.
    # File must be saved in zip format, in fact, .nupkg is a fancy zip file.
    Invoke-WebRequest -Uri $downloadUrl -OutFile ($chocoTempDir + "choco.zip")
    Expand-Archive -Path ($chocoTempDir + "choco.zip") -DestinationPath $chocoTempDir -Force

    ### NOTE: Ensure PowerShell execution policy is set to at least bypass or remote signed.
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

    # start install
    & ($chocoTempDir + "tools\chocolateyInstall.ps1")
    if (choco source) { Write-Output "`n***** choco installed complete." }
    else { throw "`n***** Choco installed fails." }
}


# Verify that choco is installed
$ipAddress = ((route print | findstr "0.0.0.0.*0.0.0.0") -replace "\s{2,}", " ").split()[4]

if (Test-Path $env:ChocolateyInstall) {
    Write-Warning "`n##### choco has been installed."
}
else {
    $serverName = (Get-ServerRoom -ip $ipAddress)
    Add-Choco -ServerRoom $serverName

    Remove-ChocoSource -AllSource
    Add-ChocoSource -Name $serverName

    Write-Output "##### Start reinstall from new_source. #####"
    choco upgrade chocolatey -y

    if ((choco source | Select-Object -Skip 1).split()[0] -eq $serverName ) { Write-Host "##### Choco reinstall successful." -ForegroundColor Green }
    else { throw "Choco reinstall fails ." }
}
### NOTE: This will not set Chocolatey as an installed package,
# so it may be a good idea to also call `choco upgrade chocolatey -y` and let it reinstall version, but at least it will be available for upgrades.
## Need to add custom source before reinstall, Bekcause choco has network strategy.
