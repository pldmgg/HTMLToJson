[CmdletBinding()]
param(
    [Parameter(Mandatory=$False)]
    [System.Collections.Hashtable]$TestResources
)

# NOTE: `Set-BuildEnvironment -Force -Path $PSScriptRoot` from build.ps1 makes the following $env: available:
<#
    $env:BHBuildSystem = "Unknown"
    $env:BHProjectPath = "U:\powershell\ProjectRepos\Sudo"
    $env:BHBranchName = "master"
    $env:BHCommitMessage = "!deploy"
    $env:BHBuildNumber = 0
    $env:BHProjectName = "Sudo"
    $env:BHPSModuleManifest = "U:\powershell\ProjectRepos\Sudo\Sudo\Sudo.psd1"
    $env:BHModulePath = "U:\powershell\ProjectRepos\Sudo\Sudo"
    $env:BHBuildOutput = "U:\powershell\ProjectRepos\Sudo\BuildOutput"
#>

# Verbose output for non-master builds on appveyor
# Handy for troubleshooting.
# Splat @Verbose against commands as needed (here or in pester tests)
$Verbose = @{}
if($env:BHBranchName -notlike "master" -or $env:BHCommitMessage -match "!verbose") {
    $Verbose.add("Verbose",$True)
}

# Make sure the Module is not already loaded
if ([bool]$(Get-Module -Name $env:BHProjectName -ErrorAction SilentlyContinue)) {
    Remove-Module $env:BHProjectName -Force
}

Describe -Name "General Project Validation: $env:BHProjectName" -Tag 'Validation' -Fixture {
    $Scripts = Get-ChildItem $env:BHProjectPath -Include *.ps1,*.psm1,*.psd1 -Recurse

    # TestCases are splatted to the script so we need hashtables
    $TestCasesHashTable = $Scripts | foreach {@{file=$_}}         
    It "Script <file> should be valid powershell" -TestCases $TestCasesHashTable {
        param($file)

        $file.fullname | Should Exist

        $contents = Get-Content -Path $file.fullname -ErrorAction Stop
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize($contents, [ref]$errors)
        $errors.Count | Should Be 0
    }

    It "Module '$env:BHProjectName' Should Load" -Test {
        {Import-Module $env:BHPSModuleManifest -Force} | Should Not Throw
    }

    It "Module '$env:BHProjectName' Public and Not Private Functions Are Available" {
        $Module = Get-Module $env:BHProjectName
        $Module.Name -eq $env:BHProjectName | Should Be $True
        $Commands = $Module.ExportedCommands.Keys
        $Commands -contains 'AddMySudoPwd' | Should Be $False
        $Commands -contains 'AddWinRMTrustedHost' | Should Be $False
        $Commands -contains 'AddWinRMTrustLocalHost' | Should Be $False
        $Commands -contains 'DownloadNuGetPackage' | Should Be $False
        $Commands -contains 'GetElevation' | Should Be $False
        $Commands -contains 'GetLinuxOctalPermissions' | Should Be $False
        $Commands -contains 'GetModuleDependencies' | Should Be $False
        $Commands -contains 'GetMySudoStatus' | Should Be $False
        $Commands -contains 'InstallLinuxPackage' | Should Be $False
        $Commands -contains 'InvokeModuleDependencies' | Should Be $False
        $Commands -contains 'InvokePSCompatibility' | Should Be $False
        $Commands -contains 'ManualPSGalleryModuleInstall' | Should Be $False
        $Commands -contains 'NewCronToAddSudoPwd' | Should Be $False
        $Commands -contains 'NewUniqueString' | Should Be $False
        $Commands -contains 'RemoveMySudoPwd' | Should Be $False
        $Commands -contains 'ResolveHost' | Should Be $False
        $Commands -contains 'ScrubJsonUnicodeSymbols' | Should Be $False
        $Commands -contains 'SudoPwsh' | Should Be $False
        $Commands -contains 'TestIsValidIPAddress' | Should Be $False
        
        $Commands -contains 'Deploy-SplashContainer' | Should Be $True
        $Commands -contains 'Get-SiteAsJson' | Should Be $True
        $Commands -contains 'Install-Docker' | Should Be $True
        $Commands -contains 'Install-DotNetSDK' | Should Be $True
        $Commands -contains 'Install-DotNetScript' | Should Be $True
    }

    It "Module '$env:BHProjectName' Private Functions Are Available in Internal Scope" {
        $Module = Get-Module $env:BHProjectName
        [bool]$Module.Invoke({Get-Item function:AddMySudoPwd}) | Should Be $True
        [bool]$Module.Invoke({Get-Item function:AddWinRMTrustedHost}) | Should Be $True
        [bool]$Module.Invoke({Get-Item function:AddWinRMTrustLocalHost}) | Should Be $True
        [bool]$Module.Invoke({Get-Item function:DownloadNuGetPackage}) | Should Be $True
        [bool]$Module.Invoke({Get-Item function:GetElevation}) | Should Be $True
        [bool]$Module.Invoke({Get-Item function:GetLinuxOctalPermissions}) | Should Be $True
        [bool]$Module.Invoke({Get-Item function:GetModuleDependencies}) | Should Be $True
        [bool]$Module.Invoke({Get-Item function:GetMySudoStatus}) | Should Be $True
        [bool]$Module.Invoke({Get-Item function:InstallLinuxPackage}) | Should Be $True
        [bool]$Module.Invoke({Get-Item function:InvokeModuleDependencies}) | Should Be $True
        [bool]$Module.Invoke({Get-Item function:InvokePSCompatibility}) | Should Be $True
        [bool]$Module.Invoke({Get-Item function:ManualPSGalleryModuleInstall}) | Should Be $True
        [bool]$Module.Invoke({Get-Item function:NewCronToAddSudoPwd}) | Should Be $True
        [bool]$Module.Invoke({Get-Item function:NewUniqueString}) | Should Be $True
        [bool]$Module.Invoke({Get-Item function:RemoveMySudoPwd}) | Should Be $True
        [bool]$Module.Invoke({Get-Item function:ResolveHost}) | Should Be $True
        [bool]$Module.Invoke({Get-Item function:ScrubJsonUnicodeSymbols}) | Should Be $True
        [bool]$Module.Invoke({Get-Item function:SudoPwsh}) | Should Be $True
        [bool]$Module.Invoke({Get-Item function:TestIsValidIPAddress}) | Should Be $True
    }
}

# SIG # Begin signature block
# MIIMiAYJKoZIhvcNAQcCoIIMeTCCDHUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUYGwe432rQuaTPJL9tVo6Ucwo
# alGgggn9MIIEJjCCAw6gAwIBAgITawAAAB/Nnq77QGja+wAAAAAAHzANBgkqhkiG
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFOmisGZ6d1uCvfR+
# y0mCwNzay9VeMA0GCSqGSIb3DQEBAQUABIIBABNIbrEyRX284KYdX6Azu/yhyaPx
# HrQNRowHj7D+2I0IK72FcCJ7F3oy0gZBwj5cGmN0oE17PPIbjSYT7pYElI8TIbKh
# jp/xMZpwvOxPfqBWtKloiu+RoOggZ6NFoWCY5TtvcUSEPe9I2BJeRVOoIUdSSEYa
# 4+htkWx3LBe3pBJp9eFNTohdKAF39OR80tTKsJgdiYECcBZz0tjkK0IKmq/n5ZBp
# /Po1j40XXpIbeJrB/rqj4FXYbX/vJguhPG8/L8bevuMWBsoeRGCMAEk1yOQ8fu2O
# lST+G3a9B9d8k9MjvyMOyxQ4XzPzLePY30o9+cCHSlNPtedn8W0t9LXdzNc=
# SIG # End signature block
