<#
    
    .SYNOPSIS
        The DownloadNuGetPackage function download and unzips the specified NuGetPackage using the v3 NuGet API.
        It also indicated which assembly file (.dll) you should probably use for the PowerShell version (Windows or Core)
        you are using.
    
    .DESCRIPTION
        See .SYNOPSIS

    .PARAMETER AssemblyName
        This parameter is MANDATORY.

        TODO

    .PARAMETER NuGetPkgDownloadDirectory
        This parameter is OPTIONAL.

        TODO

    .PARAMETER AllowPreRelease
        This parameter is OPTIONAL.

        TODO

    .PARAMETER Silent
        This parameter is OPTIONAL.

        TODO

    .EXAMPLE
        # Open an elevated PowerShell Session, import the module, and -

        PS C:\Users\zeroadmin> DownloadNuGetPackage -AssemblyName Newtonsoft.Json -NuGetPkgDownloadDirectory "$HOME\Downloads" -Silent
    
#>
function DownloadNuGetPackage {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [string]$AssemblyName,

        [Parameter(Mandatory=$False)]
        [string]$NuGetPkgDownloadDirectory,

        [Parameter(Mandatory=$False)]
        [switch]$AllowPreRelease,

        [Parameter(Mandatory=$False)]
        [switch]$Silent
    )
    
    #region >> Prep

    if ($PSVersionTable.Platform -ne $null -and $PSVersionTable.Platform -ne "Win32NT" -and !$NuGetPkgDownloadDirectory) {
        Write-Error "On this OS Platform (i.e. $($PSVersionTable.Platform)), the -NuGetPkgDownloadDirectory parameter is required! Halting!"
        $global:FunctionResult = "1"
        return
    }
    
    if ($($PSVersionTable.Platform -ne $null -and $PSVersionTable.Platform -ne "Win32NT") -or $NuGetPkgDownloadDirectory) {
        #$NuGetPackageUri = "https://www.nuget.org/api/v2/package/$AssemblyName"
        #$NuGetPackageUri = "https://api.nuget.org/v3-flatcontainer/{id-lower}/{version-lower}/{id-lower}.{version-lower}.nupkg"
        if ($AllowPreRelease) {
            $SearchNuGetPackageUri = "https://api-v2v3search-0.nuget.org/query?q=$AssemblyName&prerelease=true"
        }
        else {
            $SearchNuGetPackageUri = "https://api-v2v3search-0.nuget.org/query?q=$AssemblyName&prerelease=false"
        }
        $VersionCheckPrep = $($(Invoke-RestMethod -Uri $SearchNuGetPackageUri).data | Where-Object {$_.id -eq $AssemblyName}).versions
        $LatestVersion = $VersionCheckPrep[-1].Version
        $LowercaseAssemblyName = $AssemblyName.ToLowerInvariant()
        $NuGetPackageUri = "https://api.nuget.org/v3-flatcontainer/$LowercaseAssemblyName/$LatestVersion/$LowercaseAssemblyName.$LatestVersion.nupkg"

        $OutFileBaseName = "$LowercaseAssemblyName.$LatestVersion.zip"
        $DllFileName = $OutFileBaseName -replace "zip","dll"

        if ($NuGetPkgDownloadDirectory) {
            $NuGetPkgDownloadPath = Join-Path $NuGetPkgDownloadDirectory $OutFileBaseName
            $NuGetPkgExtractionDirectory = Join-Path $NuGetPkgDownloadDirectory $AssemblyName
            if (!$(Test-Path $NuGetPkgDownloadDirectory)) {
                $null = New-Item -ItemType Directory -Path $NuGetPkgDownloadDirectory -Force
            }
            if (!$(Test-Path $NuGetPkgExtractionDirectory)) {
                $null = New-Item -ItemType Directory -Path $NuGetPkgExtractionDirectory -Force
            }
        }
    }
    if ($($PSVersionTable.PSEdition -eq "Desktop" -or $PSVersionTable.Platform -eq "Win32NT") -and !$NuGetPkgDownloadDirectory) {
        $NuGetConfigContent = Get-Content $(Get-NativePath @($env:AppData, "NuGet", "nuget.config"))
        $NuGetRepoPathCheck = $NuGetConfigContent | Select-String -Pattern '<add key="repositoryPath" value=' -ErrorAction SilentlyContinue
        if ($NuGetRepoPathCheck -ne $null) {
            $NuGetPackagesPath = $($($NuGetRepoPathCheck.Line.Trim() -split 'value=')[-1] -split ' ')[0] -replace '"',''
        }
        else {
            $NuGetPackagesPath = Get-NativePath @($HOME, ".nuget", "packages")
        }

        if (!$(Test-Path $NuGetPackagesPath)) {
            $null = New-Item -ItemType Directory -Path $NuGetPackagesPath -Force
        }

        $NuGetPkgExtractionDirectory = Get-NativePath @($NuGetPackagesPath, $AssemblyName)
    }

    if ($PSVersionTable.PSEdition -eq "Core") {
        $PossibleSubDirs = @(
            [pscustomobject]@{
                Preference      = 4
                SubDirectory    = $(Get-NativePath @("lib", "netstandard1.3"))
            }
            [pscustomobject]@{
                Preference      = 3
                SubDirectory    = $(Get-NativePath @("lib", "netstandard1.6"))
            }
            [pscustomobject]@{
                Preference      = 1
                SubDirectory    = $(Get-NativePath @("lib", "netstandard2.0"))
            }
            [pscustomobject]@{
                Preference      = 2
                SubDirectory    = $(Get-NativePath @("lib", "netcoreapp2.0"))
            }
        )
    }
    else {
        $PossibleSubDirs = @(
            [pscustomobject]@{
                Preference      = 8
                SubDirectory    = $(Get-NativePath @("lib", "net40"))
            }
            [pscustomobject]@{
                Preference      = 7
                SubDirectory    = $(Get-NativePath @("lib", "net45"))
            }
            [pscustomobject]@{
                Preference      = 6
                SubDirectory    = $(Get-NativePath @("lib", "net451"))
            }
            [pscustomobject]@{
                Preference      = 5
                SubDirectory    = $(Get-NativePath @("lib", "net46"))
            }
            [pscustomobject]@{
                Preference      = 4
                SubDirectory    = $(Get-NativePath @("lib", "net461"))
            }
            [pscustomobject]@{
                Preference      = 3
                SubDirectory    = $(Get-NativePath @("lib", "net462"))
            }
            [pscustomobject]@{
                Preference      = 2
                SubDirectory    = $(Get-NativePath @("lib", "net47"))
            }
            [pscustomobject]@{
                Preference      = 1
                SubDirectory    = $(Get-NativePath @("lib", "net471"))
            }
            [pscustomobject]@{
                Preference      = 15
                SubDirectory    = $(Get-NativePath @("lib", "netstandard1.0"))
            }
            [pscustomobject]@{
                Preference      = 14
                SubDirectory    = $(Get-NativePath @("lib", "netstandard1.1"))
            }
            [pscustomobject]@{
                Preference      = 13
                SubDirectory    = $(Get-NativePath @("lib", "netstandard1.2"))
            }
            [pscustomobject]@{
                Preference      = 12
                SubDirectory    = $(Get-NativePath @("lib", "netstandard1.3"))
            }
            [pscustomobject]@{
                Preference      = 11
                SubDirectory    = $(Get-NativePath @("lib", "netstandard1.4"))
            }
            [pscustomobject]@{
                Preference      = 10
                SubDirectory    = $(Get-NativePath @("lib", "netstandard1.5"))
            }
            [pscustomobject]@{
                Preference      = 9
                SubDirectory    = $(Get-NativePath @("lib", "netstandard1.6"))
            }
            [pscustomobject]@{
                Preference      = 16
                SubDirectory    = $(Get-NativePath @("lib", "netstandard2.0"))
            }
            [pscustomobject]@{
                Preference      = 17
                SubDirectory    = $(Get-NativePath @("lib", "netcoreapp2.0"))
            }
        )
    }

    #endregion >> Prep

    
    #region >> Main

    if ($($PSVersionTable.PSEdition -eq "Desktop" -or $PSVersionTable.Platform -eq "Win32NT") -and !$NuGetPkgDownloadDirectory) {
        if (!$(Get-Command nuget.exe -ErrorAction SilentlyContinue)) {
            $NugetPath = Join-Path $($NuGetPackagesPath | Split-Path -Parent) nuget.exe
            if(!$(Test-Path $NugetPath)) {
                Invoke-WebRequest -uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile $NugetPath
            }
            $NugetDir = $NugetPath | Split-Path -Parent

            # Update PowerShell $env:PATH
            [System.Collections.Arraylist][array]$CurrentEnvPathArray = $env:PATH -split ';' | Where-Object {![System.String]::IsNullOrWhiteSpace($_)} | Sort-Object | Get-Unique
            if ($CurrentEnvPathArray -notcontains $NugetDir) {
                $CurrentEnvPathArray.Insert(0,$NugetDir)
                $env:PATH = $CurrentEnvPathArray -join ';'
            }
            
            # Update SYSTEM Path
            $RegistrySystemPath = 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment'
            $CurrentSystemPath = $(Get-ItemProperty -Path $RegistrySystemPath -Name PATH).Path
            [System.Collections.Arraylist][array]$CurrentSystemPathArray = $CurrentSystemPath -split ';' | Where-Object {![System.String]::IsNullOrWhiteSpace($_)} | Sort-Object | Get-Unique
            if ($CurrentSystemPathArray -notcontains $NugetDir) {
                $CurrentSystemPathArray.Insert(0,$NugetDir)
                $UpdatedSystemPath = $CurrentSystemPathArray -join ';'
                Set-ItemProperty -Path $RegistrySystemPath -Name PATH -Value $UpdatedSystemPath
            }   
        }

        try {
            $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
            #$ProcessInfo.WorkingDirectory = $NuGetPackagesPath
            $ProcessInfo.FileName = $(Get-Command nuget).Source
            $ProcessInfo.RedirectStandardError = $true
            $ProcessInfo.RedirectStandardOutput = $true
            $ProcessInfo.UseShellExecute = $false
            if ($AllowPreRelease) {
                $ProcessInfo.Arguments = "install $AssemblyName -PreRelease"
            }
            else {
                $ProcessInfo.Arguments = "install $AssemblyName"
            }
            $Process = New-Object System.Diagnostics.Process
            $Process.StartInfo = $ProcessInfo
            $Process.Start() | Out-Null
            $stdout = $($Process.StandardOutput.ReadToEnd()).Trim()
            $stderr = $($Process.StandardError.ReadToEnd()).Trim()
            $AllOutput = $stdout + $stderr
            $AllOutput = $AllOutput -split "`n"

            if ($stderr -match "Unable to find package") {
                throw
            }

            $NuGetPkgExtractionDirectory = $(Get-ChildItem -Path $NuGetPackagesPath -Directory | Where-Object {$_.Name -eq $AssemblyName} | Sort-Object -Property CreationTime)[-1].FullName
        }
        catch {
            Write-Error $_
            Write-Error "NuGet.exe was unable to find a package called $AssemblyName! Halting!"
            $global:FunctionResult = "1"
            return
        }
    }
    if ($($PSVersionTable.Platform -ne $null -and $PSVersionTable.Platform -ne "Win32NT") -or $NuGetPkgDownloadDirectory) {
        try {
            # Download the NuGet Package
            if (!$Silent) {
                Write-Host "Downloading $AssemblyName NuGet Package to $NuGetPkgDownloadPath ..."
            }
            Invoke-WebRequest -Uri $NuGetPackageUri -OutFile $NuGetPkgDownloadPath
            if (!$Silent) {
                Write-Host "NuGet Package has been downloaded to $NuGetPkgDownloadPath"
            }
        }
        catch {
            Write-Error "Unable to find $AssemblyName via the NuGet API! Halting!"
            $global:FunctionResult = "1"
            return
        }

        # Step through possble Zip File SubDirs and get the most highest available compatible version of the Assembly
        try {
            if (!$Silent) {
                Write-Host "Attempting to extract NuGet zip file $NuGetPkgDownloadPath to $NuGetPkgExtractionDirectory ..."
            }
            if ($(Get-ChildItem $NuGetPkgExtractionDirectory).Count -gt 1) {
                foreach ($item in $(Get-ChildItem $NuGetPkgExtractionDirectory)) {
                    if ($item.Extension -ne ".zip") {
                        $item | Remove-Item -Recurse -Force
                    }
                }
            }
            Expand-Archive -Path $NuGetPkgDownloadPath -DestinationPath $NuGetPkgExtractionDirectory
            if (!$Silent) {
                Write-Host "NuGet Package is available here: $NuGetPkgExtractionDirectory"
            }
        }
        catch {
            Write-Warning "The Unzip-File function failed with the following error:"
            Write-Error $$_
            $global:FunctionResult = "1"
            return
        }
    }

    [System.Collections.ArrayList]$NuGetPackageActualSubDirs = @()
    $(Get-ChildItem -Recurse $NuGetPkgExtractionDirectory -File -Filter "*.dll").DirectoryName | foreach {
        $null = $NuGetPackageActualSubDirs.Add($_)
    }
    
    $s = [IO.Path]::DirectorySeparatorChar
    [System.Collections.ArrayList]$FoundSubDirsPSObjects = @()
    foreach ($pdir in $PossibleSubDirs) {
        foreach ($adir in $NuGetPackageActualSubDirs) {
            $IndexOfSlash = $pdir.SubDirectory.IndexOf($s)
            $pdirToRegexPattern = {
                $UpdatedString = $pdir.SubDirectory.Remove($IndexOfSlash, 1)
                $UpdatedString.Insert($IndexOfSlash, [regex]::Escape($s))
            }.Invoke()

            if ($adir -match $pdirToRegexPattern) {
                $FoundDirPSObj = [pscustomobject]@{
                    Preference   = $pdir.Preference
                    Directory    = $adir
                }
                $null = $FoundSubDirsPSObjects.Add($FoundDirPSObj)
            }
        }
    }

    $TargetDir = $($FoundSubDirsPSObjects | Sort-Object -Property Preference)[0].Directory
    $AssemblyPath = Get-NativePath @($TargetDir, $(Get-ChildItem $TargetDir -File -Filter "*.dll").Name)
    
    [pscustomobject]@{
        NuGetPackageDirectory   = $NuGetPkgExtractionDirectory
        AssemblyToLoad          = $AssemblyPath
    }
    
    #endregion >> Main

}

# SIG # Begin signature block
# MIIMiAYJKoZIhvcNAQcCoIIMeTCCDHUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU/dDSVRU9rMGKECxfni7UqlBL
# 6PKgggn9MIIEJjCCAw6gAwIBAgITawAAAB/Nnq77QGja+wAAAAAAHzANBgkqhkiG
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFJz4X72xOHInOeUL
# c/WQPxgoJjV1MA0GCSqGSIb3DQEBAQUABIIBAAnJj2tJVUbzx7AIiMVyBLCopE0W
# ZYQCMx2r8yuluXyFHqQ6fZ+KWz/QXIO+Ck4pYcSS8/7s4WoGr3HtI1MatoUoTWTz
# rzZNlWZtccfqVA42RLkey4K/rnfzkwD1ZyItk0Q7g8XbLA90Vwbh5waXJscH0dF8
# Ut7QeOIaitpQmDOigSuLuFEiQdcbwZ3JIRnxMhYhyika8Rlg9LVkml4M4Xvip8XP
# yoMRufssMcDovBqIFAK3e4TcfG4q2e1RdEJzt92ranwb8yGmEdUL6JmVR2VLdLXY
# +bq78BA03PqPdWn4jyYG5eFpmf10pFQ3rhu+a8zlQMu577OekLpkvI7jkJ8=
# SIG # End signature block
