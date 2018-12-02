<#
    .SYNOPSIS
        Installs Docker on Linux.

    .DESCRIPTION
        See .SYNOPSIS

    .NOTES

    .EXAMPLE
        # Launch PowerShell and ...

        PS C:\Users\zeroadmin> Install-Docker
#>
function Install-Docker {
    [CmdletBinding(DefaultParameterSetName='Default')]
    Param()

    if (!$($PSVersionTable.Platform -eq "Unix" -or $PSVersionTable.OS -match "Darwin")) {
        Write-Error "The $($MyInvocation.MyCommand.Name) function from the SiteScraping Module should only be used on Linux! Halting!"
        $global:FunctionResult = "1"
        return
    }

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
    
    $HostNameCtlInfo = hostnamectl
    $OSVersionCheckPrep = $HostNameCtlInfo -match "Operating System:"
    $ArchitectureCheck = $HostNameCtlInfo -match "Architecture:"
    switch ($OSVersionCheckPrep) {
        {$_ -match "18\.04"} {
            $OSVerCheck = 'Ubuntu 18.04'
        }
        {$_ -match "16\.|16\.04"} {
            $OSVerCheck = 'Ubuntu 16.04'
        }
        {$_ -match "14\.|14\.04"} {
            $OSVerCheck = 'Ubuntu 14.04'
        }
        {$_ -match "stretch"} {
            $OSVerCheck = 'Debian 9'
        }
        {$_ -match "jessie"} {
            $OSVerCheck = 'Debian 8'
        }
        {$_ -match "CentOS.*7"} {
            $OSVerCheck = 'CentOS 7'
        }
        {$_ -match "RHEL.*7"} {
            $OSVerCheck = 'RHEL 7'
        }
        {$_ -match "openSUSE.*42"} {
            $OSVerCheck = 'openSUSE 42'
        }
    }

    if (!$OSVerCheck) {
        Write-Error "Unable to identify Linux OS Version! Halting!"
        $global:FunctionResult = "1"
        return
    }

    $CurrentUser = whoami
    
    if ($OSVerCheck -match "openSUSE" -and ![bool]$($ArchitectureCheck -match "arm")) {
        try {
            $SBAsString = @(
                'Write-Host "`nOutputStartsBelow`n"'
                'try {'
                "    zypper --non-interactive install docker docker-compose"
                '    systemctl start docker'
                '    systemctl enable docker'
                "    usermod -G docker -a $CurrentUser"
                "    Get-Command docker -ErrorAction Stop | ConvertTo-Json -Depth 3"
                '}'
                'catch {'
                '    @("ErrorMsg",$_.Exception.Message) | ConvertTo-Json -Depth 3'
                '}'
            )
            $SBAsString = $SBAsString -join "`n"
            $DockerInstallPrep = SudoPwsh -CmdString $SBAsString

            if ($DockerInstallPrep.Output -match "ErrorMsg") {
                throw $DockerInstallPrep.Output[-1]
            }
            if ($DockerInstallPrep.OutputType -eq "Error") {
                if ($DockerInstallPrep.Output -match "ErrorMsg") {
                    throw $DockerInstallPrep.Output[-1]
                }
                else {
                    throw $DockerInstallPrep.Output
                }
            }
            $DockerCommandInfo = $DockerInstallPrep.Output
            Write-Warning "You must reboot before using docker!"
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
                '    yum install net-tools -y'
                '    curl -fsSL https://get.docker.com/ | sh'
                '    systemctl start docker'
                '    systemctl enable docker'
                "    usermod -aG docker $CurrentUser"
                "    Get-Command docker -ErrorAction Stop | ConvertTo-Json -Depth 3"
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
                '    apt-get update'
                '    apt-get install -y apt-transport-https ca-certificates curl software-properties-common'
                '    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -'
                '    apt-key fingerprint 0EBFCD88'
                '    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"'
                '    apt-get update'
                '    apt-get install -y docker-ce'
                "    usermod -aG docker $CurrentUser"
                '    systemctl start docker'
                '    systemctl enable docker'
                "    Get-Command docker -ErrorAction Stop | ConvertTo-Json -Depth 3"
                '}'
                'catch {'
                '    @("ErrorMsg",$_.Exception.Message) | ConvertTo-Json -Depth 3'
                '}'
            )
            $SBAsString = $SBAsString -join "`n"
            $DockerInstallPrep = SudoPwsh -CmdString $SBAsString

            if ($DockerInstallPrep.Output -match "ErrorMsg") {
                throw $DockerInstallPrep.Output[-1]
            }
            if ($DockerInstallPrep.OutputType -eq "Error") {
                if ($DockerInstallPrep.Output -match "ErrorMsg") {
                    throw $DockerInstallPrep.Output[-1]
                }
                else {
                    throw $DockerInstallPrep.Output
                }
            }
            $DockerCommandInfo = $DockerInstallPrep.Output
        }
        catch {
            Write-Error $_
            $global:FunctionResult = "1"
            return
        }
    }

    if ($OSVerCheck -match "Debian" -and ![bool]$($ArchitectureCheck -match "arm")) {
        try {
            $SBAsString = @(
                'Write-Host "`nOutputStartsBelow`n"'
                'try {'
                '    apt-get update'
                '    apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common'
                '    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -'
                '    apt-key fingerprint 0EBFCD88'
                '    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"'
                '    apt-get update'
                '    apt-get install -y docker-ce'
                "    usermod -aG docker $CurrentUser"
                '    systemctl start docker'
                '    systemctl enable docker'
                "    Get-Command dotnet -ErrorAction Stop | ConvertTo-Json -Depth 3"
                '}'
                'catch {'
                '    @("ErrorMsg",$_.Exception.Message) | ConvertTo-Json -Depth 3'
                '}'
            )
            $SBAsString = $SBAsString -join "`n"
            $DockerInstallPrep = SudoPwsh -CmdString $SBAsString

            if ($DockerInstallPrep.Output -match "ErrorMsg") {
                throw $DockerInstallPrep.Output[-1]
            }
            if ($DockerInstallPrep.OutputType -eq "Error") {
                if ($DockerInstallPrep.Output -match "ErrorMsg") {
                    throw $DockerInstallPrep.Output[-1]
                }
                else {
                    throw $DockerInstallPrep.Output
                }
            }
            $DockerCommandInfo = $DockerInstallPrep.Output
        }
        catch {
            Write-Error $_
            $global:FunctionResult = "1"
            return
        }
    }
}

# SIG # Begin signature block
# MIIMiAYJKoZIhvcNAQcCoIIMeTCCDHUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUCJtlE5JSzOKP1K9QdZNu+SgL
# LD6gggn9MIIEJjCCAw6gAwIBAgITawAAAB/Nnq77QGja+wAAAAAAHzANBgkqhkiG
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFCnRtZGOWwVTmg3B
# 79ay0ET/5uXXMA0GCSqGSIb3DQEBAQUABIIBADgGScCZaaxr9DCngFf+/tvvsOPF
# 8N1rGY5SQszpunjAFn6EiiKPUqIYJW/j6lcnqeKsp1KEsMRG5p5fMfSq0BmrxlUq
# /tOhsxFq4L8zsPVWmv3Dih7GLfGifsrq7Mh2YhdcuUFrp6Cly5hOJ9QfJ6ww8q6/
# LWlaojgQfjctxwBjh+YE214s0sRXAsBOQZvjsTCEGh4Sqh09f2UamQh5ICvTaaLN
# 03iPm9zUOipVlNdnhR3hsFGSq/l29zmTwcSVN8fFjWMPDezLz/WonaBuF8bCyKhf
# qLzF5vT//RR67+zbNT7zslAMIUt9cdhkOGGbTq29tiUecg4kcyflg8O9z/s=
# SIG # End signature block
