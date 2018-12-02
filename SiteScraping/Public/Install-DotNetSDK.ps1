<#
    .SYNOPSIS
        Installs the .Net SDK on Windows or Linux. Compatible with Windows PowerShell 5.1 and PowerShell Core.

    .DESCRIPTION
        See .SYNOPSIS

    .NOTES

    .EXAMPLE
        # Launch PowerShell and ...

        PS C:\Users\zeroadmin> Install-DotNetSDK
#>
function Install-DotNetSDK {
    [CmdletBinding()]
    Param ()

    if ($PSVersionTable.Platform -eq "Unix" -or $PSVersionTable.OS -match "Darwin" -and $env:SudoPwdPrompt) {
        if (GetElevation) {
            Write-Error "You should not be running the $($MyInvocation.MyCommand.Name) function as root! Halting!"
            $global:FunctionResult = "1"
            return
        }
        RemoveMySudoPwd
        NewCronToAddSudoPwd
        $env:SudoPwdPrompt = $False
    }
    if (!$PSVersionTable.Platform -or $PSVersionTable.Platform -eq "Win32NT") {
        if (!$(GetElevation)) {
            Write-Error "The $($MyInvocation.MyCommand.Name) function must be run from an elevated PowerShell session! Halting!"
            $global:FunctionResult = "1"
            return
        }
    }

    if (!$PSVersionTable.Platform -or $PSVersionTable.Platform -eq "Win32NT") {
        try {
            $null = Install-Program -ProgramName dotnetcore-sdk -CommandName dotnet.exe -ErrorAction Stop
        }
        catch {
            Write-Error $_
            $global:FunctionResult = "1"
            return
        }

        # Make sure $env:Path is updated
        $DotNetExeDir = "C:\Program Files\dotnet"
        [System.Collections.Arraylist][array]$CurrentEnvPathArray = $env:Path -split ';' | Where-Object {![System.String]::IsNullOrWhiteSpace($_)} | Sort-Object | Get-Unique
        if ($CurrentEnvPathArray -notcontains $DotNetExeDir) {
            $CurrentEnvPathArray.Insert(0,$DotNetExeDir)
            $env:Path = $CurrentEnvPathArray -join ';'
        }

        $DotNetCommandInfo = Get-Command dotnet
    }
    if ($PSVersionTable.Platform -eq "Unix" -or $PSVersionTable.OS -match "Darwin") {
        $HostNameCtlInfo = hostnamectl
        $OSVersionCheckPrep = $HostNameCtlInfo -match "Operating System:"
        $ArchitectureCheck = $HostNameCtlInfo -match "Architecture:"
        switch ($OSVersionCheckPrep) {
            {$_ -match "18\.04"} {
                $OSVerCheck = 'Ubuntu 18.04'
                $MicrosoftUrl = "https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb"
            }
            {$_ -match "16\.|16\.04"} {
                $OSVerCheck = 'Ubuntu 16.04'
                $MicrosoftUrl = "https://packages.microsoft.com/config/ubuntu/16.04/packages-microsoft-prod.deb"
            }
            {$_ -match "14\.|14\.04"} {
                $OSVerCheck = 'Ubuntu 14.04'
                $MicrosoftUrl = "https://packages.microsoft.com/config/ubuntu/14.04/packages-microsoft-prod.deb"
            }
            {$_ -match "stretch"} {
                $OSVerCheck = 'Debian 9'
                $MicrosoftUrl = "https://packages.microsoft.com/config/debian/9/prod.list"
            }
            {$_ -match "jessie"} {
                $OSVerCheck = 'Debian 8'
                $MicrosoftUrl = "https://packages.microsoft.com/config/debian/8/prod.list"
            }
            {$_ -match "CentOS.*7"} {
                $OSVerCheck = 'CentOS 7'
                $MicrosoftUrl = "https://packages.microsoft.com/config/rhel/7/packages-microsoft-prod.rpm"
            }
            {$_ -match "openSUSE.*42"} {
                $OSVerCheck = 'openSUSE 42'
                $MicrosoftUrl = "https://packages.microsoft.com/config/opensuse/42.2/prod.repo"
            }
        }

        if (!$MicrosoftUrl) {
            Write-Error "Unable to identify Linux OS Version! Halting!"
            $global:FunctionResult = "1"
            return
        }
        
        if ($OSVerCheck -match "openSUSE" -and ![bool]$($ArchitectureCheck -match "arm")) {
            try {
                $SBAsString = @(
                    'Write-Host "`nOutputStartsBelow`n"'
                    'try {'
                    '    rpm --import https://packages.microsoft.com/keys/microsoft.asc'
                    '    zypper --non-interactive ar --gpgcheck-allow-unsigned-repo https://packages.microsoft.com/rhel/7/prod/ microsoft'
                    '    zypper --non-interactive update'
                    '    rpm -ivh --nodeps https://packages.microsoft.com/rhel/7/prod/dotnet-sdk-2.1.500-x64.rpm'
                    "    Get-Command dotnet -ErrorAction Stop | ConvertTo-Json -Depth 3"
                    '}'
                    'catch {'
                    '    @("ErrorMsg",$_.Exception.Message) | ConvertTo-Json -Depth 3'
                    '}'
                )
                $SBAsString = $SBAsString -join "`n"
                $DotNetInstallPrep = SudoPwsh -CmdString $SBAsString

                if ($DotNetInstallPrep.Output -match "ErrorMsg") {
                    throw $DotNetInstallPrep.Output[-1]
                }
                if ($DotNetInstallPrep.OutputType -eq "Error") {
                    if ($DotNetInstallPrep.Output -match "ErrorMsg") {
                        throw $DotNetInstallPrep.Output[-1]
                    }
                    else {
                        throw $DotNetInstallPrep.Output
                    }
                }
                $DotNetCommandInfo = $DotNetInstallPrep.Output
            }
            catch {
                Write-Error $_
                $global:FunctionResult = "1"
                return
            }
        }
        
        if ($OSVerCheck -match "CentOS" -and ![bool]$($ArchitectureCheck -match "arm")) {
            try {
                $SBAsString = @(
                    'Write-Host "`nOutputStartsBelow`n"'
                    'try {'
                    "    curl https://packages.microsoft.com/config/rhel/7/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo"
                    '    yum update -y'
                    '    yum install dotnet-sdk-2.1 -y'
                    "    Get-Command dotnet -ErrorAction Stop | ConvertTo-Json -Depth 3"
                    '}'
                    'catch {'
                    '    @("ErrorMsg",$_.Exception.Message) | ConvertTo-Json -Depth 3'
                    '}'
                )
                $SBAsString = $SBAsString -join "`n"
                $DotNetInstallPrep = SudoPwsh -CmdString $SBAsString

                if ($DotNetInstallPrep.Output -match "ErrorMsg") {
                    throw $DotNetInstallPrep.Output[-1]
                }
                if ($DotNetInstallPrep.OutputType -eq "Error") {
                    if ($DotNetInstallPrep.Output -match "ErrorMsg") {
                        throw $DotNetInstallPrep.Output[-1]
                    }
                    else {
                        throw $DotNetInstallPrep.Output
                    }
                }
                $DotNetCommandInfo = $DotNetInstallPrep.Output
            }
            catch {
                Write-Error $_
                $global:FunctionResult = "1"
                return
            }
        }

        if ($OSVerCheck -match "Ubuntu" -and ![bool]$($ArchitectureCheck -match "arm")) {
            try {
                $SBAsString = @(
                    'Write-Host "`nOutputStartsBelow`n"'
                    'try {'
                    '    apt-get install -y apt-transport-https'
                    "    wget -q $MicrosoftUrl"
                    '    dpkg -i packages-microsoft-prod.deb'
                    '    apt-get update'
                    '    apt-get install -y dotnet-sdk-2.1'
                    "    Get-Command dotnet -ErrorAction Stop | ConvertTo-Json -Depth 3"
                    '}'
                    'catch {'
                    '    @("ErrorMsg",$_.Exception.Message) | ConvertTo-Json -Depth 3'
                    '}'
                )
                $SBAsString = $SBAsString -join "`n"
                $DotNetInstallPrep = SudoPwsh -CmdString $SBAsString

                if ($DotNetInstallPrep.Output -match "ErrorMsg") {
                    throw $DotNetInstallPrep.Output[-1]
                }
                if ($DotNetInstallPrep.OutputType -eq "Error") {
                    if ($DotNetInstallPrep.Output -match "ErrorMsg") {
                        throw $DotNetInstallPrep.Output[-1]
                    }
                    else {
                        throw $DotNetInstallPrep.Output
                    }
                }
                $DotNetCommandInfo = $DotNetInstallPrep.Output
            }
            catch {
                Write-Error $_
                $global:FunctionResult = "1"
                return
            }
        }

        if ($OSVerCheck -match "Ubuntu" -and $ArchitectureCheck -match "arm") {
            try {
                $SBAsString = @(
                    'Write-Host "`nOutputStartsBelow`n"'
                    'try {'
                    '    apt-get -y update'
                    '    sudo apt-get -y install libunwind8 gettext'
                    '    wget https://download.microsoft.com/download/8/8/5/88544F33-836A-49A5-8B67-451C24709A8F/dotnet-sdk-2.1.300-linux-arm.tar.gz'
                    #'    wget https://dotnetcli.blob.core.windows.net/dotnet/aspnetcore/Runtime/2.1.0/aspnetcore-runtime-2.1.0-linux-arm.tar.gz'
                    '    mkdir /opt/dotnet'
                    '    tar -xvf dotnet-sdk-2.1.300-linux-arm.tar.gz -C /opt/dotnet/'
                    #'    tar -xvf aspnetcore-runtime-2.1.0-linux-arm.tar.gz -C /opt/dotnet/'
                    '    ln -s /opt/dotnet/dotnet /usr/local/bin'
                    "    Get-Command dotnet -ErrorAction Stop | ConvertTo-Json -Depth 3"
                    '}'
                    'catch {'
                    '    @("ErrorMsg",$_.Exception.Message) | ConvertTo-Json -Depth 3'
                    '}'
                )
                $SBAsString = $SBAsString -join "`n"
                $DotNetInstallPrep = SudoPwsh -CmdString $SBAsString

                if ($DotNetInstallPrep.Output -match "ErrorMsg") {
                    throw $DotNetInstallPrep.Output[-1]
                }
                if ($DotNetInstallPrep.OutputType -eq "Error") {
                    if ($DotNetInstallPrep.Output -match "ErrorMsg") {
                        throw $DotNetInstallPrep.Output[-1]
                    }
                    else {
                        throw $DotNetInstallPrep.Output
                    }
                }
                $DotNetCommandInfo = $DotNetInstallPrep.Output
            }
            catch {
                Write-Error $_
                $global:FunctionResult = "1"
                return
            }
        }

        if ($OSVerCheck -match "Debian" -and ![bool]$($ArchitectureCheck -match "arm")) {
            if ($OSVerCheck -eq "Debian 9") {
                $AddAptSource = "    sh -c 'echo `"deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-debian-stretch-prod stretch main`" > /etc/apt/sources.list.d/microsoft.list'"
            }
            elseif ($OSVerCheck -eq "Debian 8") {
                $AddAptSource = "    sh -c 'echo `"deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-debian-jessie-prod jessie main`" > /etc/apt/sources.list.d/microsoft.list'"
            }

            try {
                $SBAsString = @(
                    'Write-Host "`nOutputStartsBelow`n"'
                    'try {'
                    '    apt-get install -y curl gnupg apt-transport-https ca-certificates'
                    '    curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -'
                    $AddAptSource
                    '    apt-get update'
                    '    sudo apt-get install -y dotnet-sdk-2.1'
                    "    Get-Command dotnet -ErrorAction Stop | ConvertTo-Json -Depth 3"
                    '}'
                    'catch {'
                    '    @("ErrorMsg",$_.Exception.Message) | ConvertTo-Json -Depth 3'
                    '}'
                )
                $SBAsString = $SBAsString -join "`n"
                $DotNetInstallPrep = SudoPwsh -CmdString $SBAsString

                if ($DotNetInstallPrep.Output -match "ErrorMsg") {
                    throw $DotNetInstallPrep.Output[-1]
                }
                if ($DotNetInstallPrep.OutputType -eq "Error") {
                    if ($DotNetInstallPrep.Output -match "ErrorMsg") {
                        throw $DotNetInstallPrep.Output[-1]
                    }
                    else {
                        throw $DotNetInstallPrep.Output
                    }
                }
                $DotNetCommandInfo = $DotNetInstallPrep.Output
            }
            catch {
                Write-Error $_
                $global:FunctionResult = "1"
                return
            }
        }
    }

    $DotNetCommandInfo
}

# SIG # Begin signature block
# MIIMiAYJKoZIhvcNAQcCoIIMeTCCDHUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUbgZNjppT4e3qAse02puA4Rgo
# 8Umgggn9MIIEJjCCAw6gAwIBAgITawAAAB/Nnq77QGja+wAAAAAAHzANBgkqhkiG
# 9w0BAQsFADAwMQwwCgYDVQQGEwNMQUIxDTALBgNVBAoTBFpFUk8xETAPBgNVBAMT
# CFplcm9EQzAxMB4XDTE3MDkyMDIxMDM1OFoXDTE5MDkyMDIxMTM1OFowPTETMBEG
# CgmSJomT8ixkARkWA0xBQjEUMBIGCgmSJomT8ixkARkWBFpFUk8xEDAOBgNVBAMT
# B1plcm9TQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDCwqv+ROc1
# bpJmKx+8rPUUfT3kPSUYeDxY8GXU2RrWcL5TSZ6AVJsvNpj+7d94OEmPZate7h4d
# gJnhCSyh2/3v0BHBdgPzLcveLpxPiSWpTnqSWlLUW2NMFRRojZRscdA+e+9QotOB
# aZmnLDrlePQe5W7S1CxbVu+W0H5/ukte5h6gsKa0ktNJ6X9nOPiGBMn1LcZV/Ksl
# lUyuTc7KKYydYjbSSv2rQ4qmZCQHqxyNWVub1IiEP7ClqCYqeCdsTtfw4Y3WKxDI
# JaPmWzlHNs0nkEjvnAJhsRdLFbvY5C2KJIenxR0gA79U8Xd6+cZanrBUNbUC8GCN
# wYkYp4A4Jx+9AgMBAAGjggEqMIIBJjASBgkrBgEEAYI3FQEEBQIDAQABMCMGCSsG
# AQQBgjcVAgQWBBQ/0jsn2LS8aZiDw0omqt9+KWpj3DAdBgNVHQ4EFgQUicLX4r2C
# Kn0Zf5NYut8n7bkyhf4wGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwDgYDVR0P
# AQH/BAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAUdpW6phL2RQNF
# 7AZBgQV4tgr7OE0wMQYDVR0fBCowKDAmoCSgIoYgaHR0cDovL3BraS9jZXJ0ZGF0
# YS9aZXJvREMwMS5jcmwwPAYIKwYBBQUHAQEEMDAuMCwGCCsGAQUFBzAChiBodHRw
# Oi8vcGtpL2NlcnRkYXRhL1plcm9EQzAxLmNydDANBgkqhkiG9w0BAQsFAAOCAQEA
# tyX7aHk8vUM2WTQKINtrHKJJi29HaxhPaHrNZ0c32H70YZoFFaryM0GMowEaDbj0
# a3ShBuQWfW7bD7Z4DmNc5Q6cp7JeDKSZHwe5JWFGrl7DlSFSab/+a0GQgtG05dXW
# YVQsrwgfTDRXkmpLQxvSxAbxKiGrnuS+kaYmzRVDYWSZHwHFNgxeZ/La9/8FdCir
# MXdJEAGzG+9TwO9JvJSyoGTzu7n93IQp6QteRlaYVemd5/fYqBhtskk1zDiv9edk
# mHHpRWf9Xo94ZPEy7BqmDuixm4LdmmzIcFWqGGMo51hvzz0EaE8K5HuNvNaUB/hq
# MTOIB5145K8bFOoKHO4LkTCCBc8wggS3oAMCAQICE1gAAAH5oOvjAv3166MAAQAA
# AfkwDQYJKoZIhvcNAQELBQAwPTETMBEGCgmSJomT8ixkARkWA0xBQjEUMBIGCgmS
# JomT8ixkARkWBFpFUk8xEDAOBgNVBAMTB1plcm9TQ0EwHhcNMTcwOTIwMjE0MTIy
# WhcNMTkwOTIwMjExMzU4WjBpMQswCQYDVQQGEwJVUzELMAkGA1UECBMCUEExFTAT
# BgNVBAcTDFBoaWxhZGVscGhpYTEVMBMGA1UEChMMRGlNYWdnaW8gSW5jMQswCQYD
# VQQLEwJJVDESMBAGA1UEAxMJWmVyb0NvZGUyMIIBIjANBgkqhkiG9w0BAQEFAAOC
# AQ8AMIIBCgKCAQEAxX0+4yas6xfiaNVVVZJB2aRK+gS3iEMLx8wMF3kLJYLJyR+l
# rcGF/x3gMxcvkKJQouLuChjh2+i7Ra1aO37ch3X3KDMZIoWrSzbbvqdBlwax7Gsm
# BdLH9HZimSMCVgux0IfkClvnOlrc7Wpv1jqgvseRku5YKnNm1JD+91JDp/hBWRxR
# 3Qg2OR667FJd1Q/5FWwAdrzoQbFUuvAyeVl7TNW0n1XUHRgq9+ZYawb+fxl1ruTj
# 3MoktaLVzFKWqeHPKvgUTTnXvEbLh9RzX1eApZfTJmnUjBcl1tCQbSzLYkfJlJO6
# eRUHZwojUK+TkidfklU2SpgvyJm2DhCtssFWiQIDAQABo4ICmjCCApYwDgYDVR0P
# AQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBS5d2bhatXq
# eUDFo9KltQWHthbPKzAfBgNVHSMEGDAWgBSJwtfivYIqfRl/k1i63yftuTKF/jCB
# 6QYDVR0fBIHhMIHeMIHboIHYoIHVhoGubGRhcDovLy9DTj1aZXJvU0NBKDEpLENO
# PVplcm9TQ0EsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNl
# cnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9emVybyxEQz1sYWI/Y2VydGlmaWNh
# dGVSZXZvY2F0aW9uTGlzdD9iYXNlP29iamVjdENsYXNzPWNSTERpc3RyaWJ1dGlv
# blBvaW50hiJodHRwOi8vcGtpL2NlcnRkYXRhL1plcm9TQ0EoMSkuY3JsMIHmBggr
# BgEFBQcBAQSB2TCB1jCBowYIKwYBBQUHMAKGgZZsZGFwOi8vL0NOPVplcm9TQ0Es
# Q049QUlBLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENO
# PUNvbmZpZ3VyYXRpb24sREM9emVybyxEQz1sYWI/Y0FDZXJ0aWZpY2F0ZT9iYXNl
# P29iamVjdENsYXNzPWNlcnRpZmljYXRpb25BdXRob3JpdHkwLgYIKwYBBQUHMAKG
# Imh0dHA6Ly9wa2kvY2VydGRhdGEvWmVyb1NDQSgxKS5jcnQwPQYJKwYBBAGCNxUH
# BDAwLgYmKwYBBAGCNxUIg7j0P4Sb8nmD8Y84g7C3MobRzXiBJ6HzzB+P2VUCAWQC
# AQUwGwYJKwYBBAGCNxUKBA4wDDAKBggrBgEFBQcDAzANBgkqhkiG9w0BAQsFAAOC
# AQEAszRRF+YTPhd9UbkJZy/pZQIqTjpXLpbhxWzs1ECTwtIbJPiI4dhAVAjrzkGj
# DyXYWmpnNsyk19qE82AX75G9FLESfHbtesUXnrhbnsov4/D/qmXk/1KD9CE0lQHF
# Lu2DvOsdf2mp2pjdeBgKMRuy4cZ0VCc/myO7uy7dq0CvVdXRsQC6Fqtr7yob9NbE
# OdUYDBAGrt5ZAkw5YeL8H9E3JLGXtE7ir3ksT6Ki1mont2epJfHkO5JkmOI6XVtg
# anuOGbo62885BOiXLu5+H2Fg+8ueTP40zFhfLh3e3Kj6Lm/NdovqqTBAsk04tFW9
# Hp4gWfVc0gTDwok3rHOrfIY35TGCAfUwggHxAgEBMFQwPTETMBEGCgmSJomT8ixk
# ARkWA0xBQjEUMBIGCgmSJomT8ixkARkWBFpFUk8xEDAOBgNVBAMTB1plcm9TQ0EC
# E1gAAAH5oOvjAv3166MAAQAAAfkwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwx
# CjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGC
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFJFquNr0v1QyuHbp
# hv2KLJ8x+TVmMA0GCSqGSIb3DQEBAQUABIIBAL6ioT5Wts8km95p/9kNvYNhSQLW
# TUbbQeyweOQzmG+NE9xKosfS4EIPs7lmfkFwY+O14KjK22bwHMtlPSGpISezoNNl
# Zvp7quwyfWNEqifCbR2KD+GV5iXdkabLsZBh7NS+15ZqwryuZzRBK4bq9jzI0NKY
# WHG380cUFDSxizl9mdbVHXg+3tzTM2wfPVWrGtisbYDGOVe4K7x55RRL7phkr20b
# JwJnBjnpIaHuupZ4UDA5t30OdpvO28PIHnMh+eeNs8TjbBkbmUAiAsPYsN8Ch144
# oQ3Y9p4Z7JCPixP3z5JbotPCbNz1vvMTEed0+bM3kRy9MlqzUvvy2WWYLV4=
# SIG # End signature block
