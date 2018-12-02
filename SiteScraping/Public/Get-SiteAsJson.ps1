<#
    .SYNOPSIS
        Parses a website's html and returns json.

    .DESCRIPTION
        See .SYNOPSIS

    .NOTES

    .PARAMETER Url
        This parameter is MANDATORY.

        This parameter takes a string that represents the url for the site that you would like to parse.

    .PARAMETER NewProjectDirectory
        This parameter is OPTIONAL.

        This parameter takes a string that represents a path to a new dotnet console app project. If this parameter is not used, the project
        directory will be created in the current location.
    
    .PARAMETER XPathJsonConfigString
        This parameter is OPTIONAL.

        This parameter takes a string that represents a Json XPath Configuration. For example, for the site 'http://dotnetapis.com/', one possible
        way of parsing the html would be -

        $JsonXPathConfigString = @"
        {
            "title": "//*[@id='app']/div/div/div[2]/div[3]/div/div/div/div/h1",
            "VisibleAPIs": {
                "_xpath": "//a[(@class='list-group-item')]",
                "APIName": ".//h3",
                "APIVersion": ".//p//code//span[normalize-space()][2]",
                "APIDescription": ".//p[(@class='list-group-item-text')]"
            }
        }
        "@
        Get-SiteAsJson -Url 'http://dotnetapis.com/' -XPathJsonConfigString $JsonXPathConfigString

    .PARAMETER XPathJsonConfigFile
        This parameter is OPTIONAL.

        This parameter takes a string that represents a path to a a .json file that contains XPath parsing instructions for -Url.

    .PARAMETER HandleInfiniteScrolling
        This parameter is OPTIONAL.

        This parameter is a switch. If the -Url you are trying to parse uses infinite scrolling (i.e. scrolling down on the page
        perpetually loads more and more info), then use this switch.

    .PARAMETER RemoveFileOutputs
        This parameter is OPTIONAL.

        This parameter is a switch. If used, files in the $WorkingDir will be removed after JSON output is generated.

    .EXAMPLE
        # Launch PowerShell and ...

        PS C:\Users\zeroadmin> Get-SiteAsJson -Url 'http://dotnetapis.com/'
#>
function Get-SiteAsJson {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True)]
        [uri]$Url,

        [Parameter(Mandatory=$False)]
        [string]$XPathJsonConfigString,

        [Parameter(Mandatory=$False)]
        [string]$XPathJsonConfigFile,

        [Parameter(Mandatory=$False)]
        [switch]$HandleInfiniteScrolling,

        [Parameter(Mandatory=$False)]
        [string]$NewProjectDirectory,

        [Parameter(Mandatory=$False)]
        [switch]$RemoveFileOutputs
    )

    if (!$XPathJsonConfigFile -and !$XPathJsonConfigString) {
        Write-Error "The $($MyInvocation.MyCommand.Name) function requires either the -XPathJsonConfigString or the -XPathJsonConfigFile parameter! Halting!"
        $global:FunctionResult = "1"
        return
    }

    $DirSep = [IO.Path]::DirectorySeparatorChar

    $UrlString = $Url.OriginalString
    if ($UrlString[-1] -ne '/') {
        $UrlString = $UrlString + '/'
    }
    
    $SiteNamePrep = @($($Url.OriginalString -split '/' | Where-Object {$_ -notmatch 'http' -and ![System.String]::IsNullOrWhiteSpace($_)}))[0]
    $SiteName = @($($SiteNamePrep -split '\.' | Where-Object {$_ -notmatch 'www' -and ![System.String]::IsNullOrWhiteSpace($_)}))[0]

    if (!$SiteName) {
        Write-Error "Unable to parse site domain name from the value provided to the -Url parameter! Halting!"
        $global:FunctionResult = "1"
        return
    }

    if ($XPathJsonConfigFile) {
        try {
            $XPathJsonConfigFile = $(Resolve-Path $XPathJsonConfigFile -ErrorAction Stop).Path
        }
        catch {
            Write-Error $_
            $global:FunctionResult = "1"
            return
        }

        # Make sure the file is valid Json
        try {
            $JsonContent = Get-Content $XPathJsonConfigFile
            $JsonAsPSObject = $JsonContent | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Error $_
            $global:FunctionResult = "1"
            return
        }
    }
    if ($XPathJsonConfigString) {
        # Make sure the string is valid Json
        try {
            $JsonAsPSObject = $XPathJsonConfigString | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Error $_
            $global:FunctionResult = "1"
            return
        }
    }

    # Check to see if a Project folder of the same name as $SiteName exists in either the current directory or the Parent Directory of $NewProjectDirectory
    if (!$NewProjectDirectory) {
        $PotentialProjectDirectories = @($(Get-ChildItem -Directory))
        if ($PotentialProjectDirectories.Name -contains $SiteName) {
            $DirItem = $PotentialProjectDirectories | Where-Object {$_.Name -eq $SiteName}
            
            # Make sure the existing project directory actually has a .csproj file in it to confirm it's a real project
            $DirItemContents = Get-ChildItem -Path $DirItem.FullName -File -Filter "*.csproj"
            if ($DirItemContents) {
                $ProjectDirectoryItem = $DirItem
            }
        }
    }
    else {
        $PotentialProjectDirParentDir = $NewProjectDirectory | Split-Path -Parent
        $PotentialProjectDirName = $NewProjectDirectory | Split-Path -Leaf

        $PotentialProjectDirectories = @($(Get-ChildItem -Path $PotentialProjectDirParentDir -Directory).Name)
        if ($PotentialProjectDirectories -contains $PotentialProjectDirName) {
            $DirItem = $PotentialProjectDirectories | Where-Object {$_.Name -eq $PotentialProjectDirName}

            # Make sure the existing project directory actually has a .csproj file in it to confirm it's a real project
            $DirItemContents = Get-ChildItem -Path $DirItem.FullName -File -Filter "*.csproj"
            if ($DirItemContents) {
                $ProjectName = $PotentialProjectDirName
            }

            $ProjectDirectoryItem = $DirItem
        }
    }

    # If an appropriate Project Folder doesn't already exist, create one
    if (!$ProjectDirectoryItem) {
        if (!$NewProjectDirectory) {
            $CurrentProjectDirectories = @($(Get-ChildItem -Directory).Name)
            if ($CurrentProjectDirectories.Count -gt 0) {
                $DirectoryName = NewUniqueString -ArrayOfStrings $CurrentProjectDirectories -PossibleNewUniqueString $SiteName
            }
            else {
                $DirectoryName = $SiteName
            }
            $NewProjectDirectory = $pwd.Path + $DirSep + $DirectoryName
        }
        else {
            $NewProjectParentDir = $NewProjectDirectory | Split-Path -Parent
            if (!$(Test-Path $NewProjectParentDir)) {
                Write-Error "Unable to find the path $NewProjectParentDir! Halting!"
                $global:FunctionResult = "1"
                return
            }

            $CurrentProjectDirectories = @($(Get-ChildItem -Path $NewProjectParentDir -Directory).Name)
            if ($CurrentProjectDirectories.Count -gt 0) {
                $DirectoryName = NewUniqueString -ArrayOfStrings $CurrentProjectDirectories -PossibleNewUniqueString $SiteName
            }
            else {
                $DirectoryName = $SiteName
            }
            $NewProjectDirectory = $NewProjectParentDir + $DirSep + $DirectoryName
        }

        if (!$(Test-Path $NewProjectDirectory)) {
            try {
                $ProjectDirectoryItem = New-Item -ItemType Directory -Path $NewProjectDirectory -ErrorAction Stop
            }
            catch {
                Write-Error $_
                $global:FunctionResult = "1"
                return
            }
        }
        else {
            Write-Error "A directory with the name $NewProjectDirectory already exists! Halting!"
            $global:FunctionResult = "1"
            return
        }

        Push-Location $ProjectDirectoryItem.FullName

        $null = dotnet new console
        $null = dotnet restore
        $null = dotnet build
        $TestRun = dotnet run
        if ($TestRun -ne "Hello World!") {
            Write-Error "There was an issue creating a new dotnet console app in '$($pwd.Path)'! Halting!"
            $global:FunctionResult = "1"
            return
        }
    }
    else {
        Push-Location $ProjectDirectoryItem.FullName
    }

    # Install any NuGetPackage dependencies
    # These packages will be found under $HOME/.nuget/packages/ after install, so they're not project specific
    # However, first make sure the project doesn't already include these packages
    $CSProjFileItem = Get-ChildItem -File -Filter "*.csproj"
    [xml]$CSProjParsedXml = Get-Content $CSProjFileItem
    $CurrentPackages = $CSProjParsedXml.Project.ItemGroup.PackageReference.Include

    $PackagesToInstall = @("Newtonsoft.Json","OpenScraping")
    foreach ($PackageName in $PackagesToInstall) {
        if ($CurrentPackages -notcontains $PackageName) {
            $null = dotnet add package $PackageName
        }
    }

    # Create Directory that will contain our .csx script and html parsing json config file (for example, dotnetapis.com.json)
    $WorkingDir = $ProjectDirectoryItem.FullName + $DirSep + "ScriptsConfigsAndOutput"
    if (!$(Test-Path $WorkingDir)) {
        try {
            $null = New-Item -ItemType Directory -Path $WorkingDir -ErrorAction Stop
        }
        catch {
            Write-Error $_
            $global:FunctionResult = "1"
            return
        }
    }

    Push-Location $WorkingDir

    # NOTE: OpenScraping 1.3.0 also installs System.Net.Http 4.3.2, System.Xml.XPath.XmlDocument 4.3.0, and HtmlAgilityPack 1.8.10

    $CSharpScriptPath = $WorkingDir + $DirSep + "$SiteName.csx"
    $HtmlParsingJsonConfigPath = $WorkingDir + $DirSep + "$SiteName.json"

    if ($HandleInfiniteScrolling) {
        # Get the InfiniteScrolling Lua Script and double-up on the double quotes
        $LuaScriptPSObjs = $(Get-Module SiteScraping).Invoke({$LuaScriptPSObjects})
        $LuaScriptPrep = $($LuaScriptPSObjs | Where-Object {$_.LuaScriptName -eq 'InfiniteScrolling'}).LuaScriptContent
        $LuaScript = $LuaScriptPrep -replace '"','""'

        <#
        $LuaScript = @"
function main(splash)
    local scroll_delay = 1
    local previous_height = -1
    local number_of_scrolls = 0
    local maximal_number_of_scrolls = 99

    local scroll_to = splash:jsfunc(""window.scrollTo"")
    local get_body_height = splash:jsfunc(
        ""function() {return document.body.scrollHeight;}""
    )
    local get_inner_height = splash:jsfunc(
        ""function() {return window.innerHeight;}""
    )
    local get_body_scroll_top = splash:jsfunc(
        ""function() {return document.body.scrollTop;}""
    )
    assert(splash:go(splash.args.url))
    splash:wait(splash.args.wait)

    while true do
        local body_height = get_body_height()
        local current = get_inner_height() - get_body_scroll_top()
        scroll_to(0, body_height)
        number_of_scrolls = number_of_scrolls + 1
        if number_of_scrolls == maximal_number_of_scrolls then
            break
        end
        splash:wait(scroll_delay)
        local new_body_height = get_body_height()
        if new_body_height - body_height <= 0 then
            break
        end
    end        
    return splash:html()
end
"@
    #>
    }

    if ($LuaScript) {
        $SplashEndPointString = 'string splashEndpoint = @"execute";'
        $PostDataString = 'var postData = JsonConvert.SerializeObject(new { url = url, timeout = 30, wait = 3, lua_source = luaScript });'
        $FinalLuaScript = $LuaScript -join "`n"
    }
    else {
        $SplashEndPointString = 'string splashEndpoint = @"render.html";'
        $PostDataString = 'var postData = JsonConvert.SerializeObject(new { url = url, timeout = 10, wait = 3 });'
        $FinalLuaScript = 'null'
    }

    # Write the CSharp Script
    $CSharpScript = @"
#r "nuget:Newtonsoft.Json,12.0.1"
#r "nuget:OpenScraping,1.3.0"

using System;
using System.Net;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using OpenScraping;
using OpenScraping.Config;

// XPath Cheat Sheet: http://ricostacruz.com/cheatsheets/xpath.html

string currDir = Directory.GetCurrentDirectory();
//string currDir = @"C:\Users\pddomain\Documents\LINQPad Queries";
string dirSeparator = System.IO.Path.DirectorySeparatorChar.ToString();

bool scrapeJavaScript = true;
if (scrapeJavaScript)
{
    string url = @"$UrlString";
    // Get Splash here: https://splash.readthedocs.io/en/stable/install.html
    string splashServer = @"http://localhost:8050/";
    $SplashEndPointString
    string splashFinalUrl = splashServer + splashEndpoint;
    var request = (HttpWebRequest)WebRequest.Create(splashFinalUrl);
    request.Method = "POST";

    // For available Splash EndPoint Args (such as "timeout" and "wait" below), see: 
    // https://splash.readthedocs.io/en/stable/api.html
    string luaScript = @"
$FinalLuaScript";

    $PostDataString

    //Console.WriteLine(postData);
    var data = Encoding.ASCII.GetBytes(postData);
    // List of available content types here: https://en.wikipedia.org/wiki/Media_type
    request.ContentType = "application/json; charset=utf-8";
    //request.ContentType = "application/x-www-form-urlencoded; charset=utf-8";
    request.ContentLength = data.Length;

    using (var stream = request.GetRequestStream())
    {
        stream.Write(data, 0, data.Length);
    }
    var response = (HttpWebResponse)request.GetResponse();

    using (StreamReader sr = new StreamReader(response.GetResponseStream()))
    {
        var responseString = sr.ReadToEnd();
        using (StreamWriter sw = new StreamWriter(currDir + dirSeparator + "$SiteName.html"))
        {
            sw.Write(responseString);
        }
        //Console.WriteLine(responseString);
    }
}

// $SiteName.json contains the JSON configuration file pasted above
var jsonConfig = File.ReadAllText(currDir + dirSeparator + "$SiteName.json");
var config = StructuredDataConfig.ParseJsonString(jsonConfig);

var html = File.ReadAllText(currDir + dirSeparator + "$SiteName.html", Encoding.UTF8);

var openScraping = new StructuredDataExtractor(config);
var scrapingResults = openScraping.Extract(html);

Console.WriteLine(JsonConvert.SerializeObject(scrapingResults, Newtonsoft.Json.Formatting.Indented));
"@

    #Write-Host $CSharpScript

    Set-Content -Path $CSharpScriptPath -Value $CSharpScript

    if ($XPathJsonConfigFile) {
        $HtmlParsingJsonConfig = Get-Content $XPathJsonConfigFile
    }
    if ($XPathJsonConfigString) {
        $HtmlParsingJsonConfig = $XPathJsonConfigString
    }

    Set-Content -Path $HtmlParsingJsonConfigPath -Value $HtmlParsingJsonConfig

    # Json Output
    dotnet-script $CSharpScriptPath

    # Cleanup
    if ($RemoveFileOutputs) {
        $HtmlFile = $WorkingDir + $DirSep + "$SiteName.html"
        $FilesToRemove = @($HtmlFile,$CSharpScriptPath,$HtmlParsingJsonConfigPath)
        foreach ($FilePath in $FilesToRemove) {
            $null = Remove-Item -Path $FilePath -Force
        }
    }

    Pop-Location
    Pop-Location

}

# SIG # Begin signature block
# MIIMiAYJKoZIhvcNAQcCoIIMeTCCDHUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUQpJJo2ff25kqTd5nyxx3s1eV
# mJigggn9MIIEJjCCAw6gAwIBAgITawAAAB/Nnq77QGja+wAAAAAAHzANBgkqhkiG
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFGS7YIBsu+SkKmOr
# 8ipEYmRI9Yu7MA0GCSqGSIb3DQEBAQUABIIBAJdVh1DB5Yk6HXgWpzmUicxsTvPk
# ex99cWZAnAVt38yVOR3QgXJ/pkx0Cw9sfBKJ20rkkqJXbCPhx+Xx02dPlXGssJ4+
# haKb4sTMwffdH+Ey2tctxYB5MUIZKitH8Qxul/vKTrQm1n76GJgwO36XPRBErwDt
# nRjNMcq15nYOX8H0X5jEh66ffKjodC9g+Wu1X/7AxkfrCONusjkcjzK7i5KwkIN5
# nSV1OLhIwYJ5nbRbic3+oDxtd1KAg8KX/GjOpfNMCWRk1ZqNvHz0mXiyw/42/UKg
# WNv0fg2szU6cQlzlduWIR6p02qietEHYPQUwXgPr7TOqCsqM/dh7hlnKMlY=
# SIG # End signature block
