#Requires -RunAsAdministrator

### Judge the ipv4-address's ServerRoom.
# ShangHai-ZongBu   :   192.168.5.* | 192.168.9.* | 172.17.30.*
# ShangHai-ShuXun   :   172.20.*.*
# ShangHai-QuanHua  :   192.168.7.* | 172.21.*.*
# Qcloud-ShangHai   :   172.31.*.*
# Qcloud-GuangZhou  :   172.29.*.*
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
        [array]$Name,
        [switch]$AllSource
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


## verify chocolatey.
if (!(choco source)) { throw "Chocolatey is not install." }

# native ipv4 address.
$ipAddress = ((route print | findstr "0.0.0.0.*0.0.0.0") -replace "\s{2,}", " ").split()[4]
Remove-ChocoSource -AllSource
Add-ChocoSource -Name (Get-ServerRoom -Ip $ipAddress)

### NOTE:
# choco $name & $addSource must use "" include, otherwise the parameters cannot be identified.
# the script must to running as administrator.