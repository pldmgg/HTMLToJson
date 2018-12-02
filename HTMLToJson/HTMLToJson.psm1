[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

# Get public and private function definition files.
[array]$Public  = Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue
[array]$Private = Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue
$ThisModule = $(Get-Item $PSCommandPath).BaseName

# Dot source the Private functions
foreach ($import in $Private) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error -Message "Failed to import function $($import.FullName): $_"
    }
}

[System.Collections.Arraylist]$ModulesToInstallAndImport = @()
if (Test-Path "$PSScriptRoot/module.requirements.psd1") {
    $ModuleManifestData = Import-PowerShellDataFile "$PSScriptRoot/module.requirements.psd1"
    #$ModuleManifestData.Keys | Where-Object {$_ -ne "PSDependOptions"} | foreach {$null = $ModulesToinstallAndImport.Add($_)}
    $($ModuleManifestData.GetEnumerator()) | foreach {
        if ($_.Key -ne "PSDependOptions") {
            $PSObj = [pscustomobject]@{
                Name    = $_.Key
                Version = $_.Value.Version
            }
            $null = $ModulesToinstallAndImport.Add($PSObj)
        }
    }
}

if ($PSVersionTable.Platform -eq "Unix" -or $PSVersionTable.OS -match "Darwin") {
    $env:SudoPwdPrompt = $True

    if ($ModulesToInstallAndImport.Count -gt 0) {
        foreach ($ModuleItem in $ModulesToInstallAndImport) {
            if ($ModuleItem.Name -match "ProgramManagement|WinSSH|NTFSSecurity|WindowsCompatibility") {
                continue
            }

            if (!$(Get-Module -ListAvailable $ModuleItem.Name -ErrorAction SilentlyContinue)) {
                try {
                    Install-Module $ModuleItem.Name -AllowClobber -ErrorAction Stop
                }
                catch {
                    try {
                        Install-Module $ModuleItem.Name -AllowClobber -AllowPrerelease -ErrorAction Stop
                    }
                    catch {
                        Write-Error $_
                        Write-Error "Unable to import all Module dependencies! Please unload $ThisModule via 'Remove-Module $ThisModule'! Halting!"
                        $global:FunctionResult = "1"
                        return
                    }
                }
            }
            
            # Make sure the Module Manifest file name and the Module Folder name are exactly the same case
            $env:PSModulePath -split ':' | foreach {
                Get-ChildItem -Path $_ -Directory | Where-Object {$_ -match $ModuleItem.Name}
            } | foreach {
                $ManifestFileName = $(Get-ChildItem -Path $_ -Recurse -File | Where-Object {$_.Name -match "$($ModuleItem.Name)\.psd1"}).BaseName
                if (![bool]$($_.Name -cmatch $ManifestFileName)) {
                    Rename-Item $_ $ManifestFileName
                }
            }

            if (!$(Get-Module $ModuleItem.Name -ErrorAction SilentlyContinue)) {
                try {
                    Import-Module $ModuleItem.Name -ErrorAction Stop -WarningAction SilentlyContinue
                }
                catch {
                    Write-Error $_
                    Write-Error "Unable to import all Module dependencies! Please unload $ThisModule via 'Remove-Module $ThisModule'! Halting!"
                    $global:FunctionResult = "1"
                    return
                }
            }
        }
    }
}

if (!$PSVersionTable.Platform -or $PSVersionTable.Platform -eq "Win32NT") {
    if ($ModulesToInstallAndImport.Count -gt 0) {
        # NOTE: If you're not sure if the Required Module is Locally Available or Externally Available,
        # add it the the -RequiredModules string array just to be certain
        $InvModDepSplatParams = @{
            RequiredModules                     = $ModulesToInstallAndImport
            InstallModulesNotAvailableLocally   = $True
            ErrorAction                         = "SilentlyContinue"
            WarningAction                       = "SilentlyContinue"
        }
        $ModuleDependenciesMap = InvokeModuleDependencies @InvModDepSplatParams
    }
}


# Public Functions


<#
    .SYNOPSIS
        Deploys ScrapingHub's Splash Docker container.

    .DESCRIPTION
        See .SYNOPSIS

    .NOTES

    .EXAMPLE
        # Launch PowerShell and ...

        PS C:\Users\zeroadmin> Deploy-SplashContainer
#>
function Deploy-SplashContainer {
    [CmdletBinding()]
    Param ()

    docker pull scrapinghub/splash
    docker run -p 8050:8050 -p 5023:5023 -d --name=splash-jump scrapinghub/splash    
}


<#
    .SYNOPSIS
        Get a list of Genres for different media.

    .DESCRIPTION
        See .SYNOPSIS

    .NOTES

    .PARAMETER Country
        This parameter is MANDATORY.

        This parameter takes a string that specifies which country you would like to gather streaming information about.

    .EXAMPLE
        # Launch PowerShell and ...

        PS C:\Users\zeroadmin> Get-JWGenres -Country "us"
#>
function Get-JWGenres {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True)]
        [ValidateSet("us","ca","mx","br","de","at","ch","uk","ie","ru","it","fr","es","nl","no",
        "se","dk","fi","lt","lv","ee","za","au","nz","in","jp","kr","th","my","ph","sg","id",
        "US","USA","Canada","Mexico","Brazil","Germany","Austria","Switzerland","United Kingdom",
        "Ireland","Russia","Italy","France","Spain","Netherlands","Norway","Sweden","Denmark",
        "Finland","Lithuania","Latvia","Estonia","South Africa","Australia","New Zealand",
        "India","Japan","South Korea","Thailand","Malaysia","Philippines","Singapore","Indonesia")]
        [string]$Country
    )

    $CountryConversion = @{
        US                  = "us"
        USA                 = "us"
        Canada              = "ca"
        Mexico              = "mx"
        Brazil              = "br"
        Germany             = "de"
        Austria             = "at"
        Switzerland         = "ch"
        'United Kingdom'    = "uk"
        Ireland             = "ie"
        Russia              = "ru"
        Italy               = "it"
        France              = "fr"
        Spain               = "es"
        Netherlands         = "nl"
        Norway              = "no"
        Sweden              = "se"
        Denmark             = "dk"
        Finland             = "fi"
        Lithuania           = "lt"
        Latvia              = "lv"
        Estonia             = "ee"
        'South Africa'      = "za"
        Australia           = "au"
        'New Zealand'       = "nz"
        India               = "in"
        Japan               = "jp"
        'South Korea'       = "kr"
        Thailand            = "th"
        Malaysia            = "my"
        Philippines         = "ph"
        Singapore           = "sg"
        Indonesia           = "id"
    }

    if ($CountryConversion.Keys -contains $Country) {
        $FinalCountry = $CountryConversion.$Country
    }
    else {
        $FinalCountry = $Country
    }

    #//*/span[@genres="filters.genres"]//li/a
    $JsonXPathConfigString = @"
{
    "title": "//*/img[@class=\"logo__img\"]/@alt",
    "Genres": {
        "_xpath": "//*/span[@genres=\"filters.genres\"]",
        "text": ".//li/a/text()"
    }
}
"@
    $BaseUrl = "https://www.justwatch.com/$FinalCountry/"
    $TextInfo = (Get-Culture).TextInfo
    
    $StreamingServicesInfoPrep = Get-SiteAsJson -Url $BaseUrl -XPathJsonConfigString $JsonXPathConfigString
    $($StreamingServicesInfoPrep | ConvertFrom-Json).Genres.text | foreach {$_.Trim()}
}


<#
    .SYNOPSIS
        Parses a website's html and returns json.

    .DESCRIPTION
        See .SYNOPSIS

    .NOTES

    .PARAMETER Country
        This parameter is MANDATORY.

        This parameter takes a string that specifies which country you would like to gather streaming information about.

    .PARAMETER StreamingServiceName
        This parameter is MANDATORY.

        This parameter takes a string that specifies which streaming service you would like to gather information about.

    .PARAMETER TVOrMovie
        This parameter is MANDATORY.

        This parameter takes a string that specifies whether you are looking for information about tv shows or movies.

    .PARAMETER ReleaseYear
        This parameter is MANDATORY.

        This parameter takes a string that represents a year from 1900 to the current year. Gathers info pertaining to that year.

    .EXAMPLE
        # Launch PowerShell and ...

        PS C:\Users\zeroadmin> Get-JWMedia -Country "us" -StreamingServiceName "Netflix" -TVOrMovie "movies" -ReleaseYear 2018
#>
function Get-JWMedia {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True)]
        [ValidateSet("us","ca","mx","br","de","at","ch","uk","ie","ru","it","fr","es","nl","no",
        "se","dk","fi","lt","lv","ee","za","au","nz","in","jp","kr","th","my","ph","sg","id",
        "US","USA","Canada","Mexico","Brazil","Germany","Austria","Switzerland","United Kingdom",
        "Ireland","Russia","Italy","France","Spain","Netherlands","Norway","Sweden","Denmark",
        "Finland","Lithuania","Latvia","Estonia","South Africa","Australia","New Zealand",
        "India","Japan","South Korea","Thailand","Malaysia","Philippines","Singapore","Indonesia")]
        [string]$Country,
    
        [Parameter(Mandatory=$True)]
        [ValidateSet('netflix','amazon-prime-video','amazon prime video','hulu',
        'yahoo-view','yahoo view','amazon-video','amazon video','hbo-now',
        'hbo now','youtube','youtube-premium','youtube premium','google-play-movies',
        'google play movies','apple-itunes','apple itunes','cbs','the-roku-channel',
        'the roku channel','hoopla','the-cw','the cw','cw-seed','cw seed','starz',
        'fandangonow','vudu','showtime','pbs','pantaflix','fxnow','tubi-tv','tubi tv',
        'dc-universe','dc universe','kanopy','playstation','microsoft-store','microsoft store',
        'max-go','max go','filmstruck','hbo-go','hbo go','abc','crackle','amc','fandor',
        'curiosity-stream','curiosity stream','nbc','epix','freeform','history','syfy','aande',
        'lifetime','shudder','screambox','acorn-tv','acorn tv','sundance-now','sundance now',
        'britbox','guidedoc','realeyz','mubi','netflix-kids','netflix kids')]
        [string]$StreamingServiceName,

        [Parameter(Mandatory=$True)]
        [ValidateSet("television","tv","tv-shows","movies","movie")]
        [string]$TVOrMovie,
        
        [Parameter(Mandatory=$True)]
        [ValidateScript({
            if ($(1900..$(Get-Date).Year) -notcontains $_) {$False} else {$True}
        })]
        [string]$ReleaseYear
    )

    if ($StreamingServiceName -match "[\s]") {
        $FinalServiceName = $StreamingServiceName -replace "[\s]","-"
    }
    else {
        $FinalServiceName = $StreamingServiceName
    }

    $CountryConversion = @{
        US                  = "us"
        USA                 = "us"
        Canada              = "ca"
        Mexico              = "mx"
        Brazil              = "br"
        Germany             = "de"
        Austria             = "at"
        Switzerland         = "ch"
        'United Kingdom'    = "uk"
        Ireland             = "ie"
        Russia              = "ru"
        Italy               = "it"
        France              = "fr"
        Spain               = "es"
        Netherlands         = "nl"
        Norway              = "no"
        Sweden              = "se"
        Denmark             = "dk"
        Finland             = "fi"
        Lithuania           = "lt"
        Latvia              = "lv"
        Estonia             = "ee"
        'South Africa'      = "za"
        Australia           = "au"
        'New Zealand'       = "nz"
        India               = "in"
        Japan               = "jp"
        'South Korea'       = "kr"
        Thailand            = "th"
        Malaysia            = "my"
        Philippines         = "ph"
        Singapore           = "sg"
        Indonesia           = "id"
    }

    if ($CountryConversion.Keys -contains $Country) {
        $FinalCountry = $CountryConversion.$Country
    }
    else {
        $FinalCountry = $Country
    }

    switch ($TVOrMovie) {
        {$_ -match "television|tv"} {$FinalTVOrMovie = "tv-shows"}
        {$_ -match "movie"} {$FinalTVOrMovie = "movies"}
    }
    

    $JsonXPathConfigString = @"
{
    "title": "//*/img[@class=\"logo__img\"]/@alt",
    "Media": {
        "_xpath": "//*/filter-bar",
        "hrefs": ".//ng-transclude//div[@class=\"main-content__poster__image__container\"]//a/@href"
    }
}
"@

    $FinalUrl = "https://www.justwatch.com/{0}/provider/{1}/{2}?release_year_from={3}" -f $FinalCountry,$FinalServiceName,$FinalTVOrMovie,$ReleaseYear
    Get-SiteAsJson -Url $FinalUrl -XPathJsonConfigString $JsonXPathConfigString -HandleInfiniteScrolling | ConvertFrom-Json
}


<#
    .SYNOPSIS
        Get a list of hrefs representing different streaming services.

    .DESCRIPTION
        See .SYNOPSIS

    .NOTES

    .PARAMETER Country
        This parameter is MANDATORY.

        This parameter takes a string that specifies which country you would like to gather streaming information about.

    .EXAMPLE
        # Launch PowerShell and ...

        PS C:\Users\zeroadmin> Get-JWStreamingServices -Country "us"
#>
function Get-JWStreamingServices {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True)]
        [ValidateSet("us","ca","mx","br","de","at","ch","uk","ie","ru","it","fr","es","nl","no",
        "se","dk","fi","lt","lv","ee","za","au","nz","in","jp","kr","th","my","ph","sg","id",
        "US","USA","Canada","Mexico","Brazil","Germany","Austria","Switzerland","United Kingdom",
        "Ireland","Russia","Italy","France","Spain","Netherlands","Norway","Sweden","Denmark",
        "Finland","Lithuania","Latvia","Estonia","South Africa","Australia","New Zealand",
        "India","Japan","South Korea","Thailand","Malaysia","Philippines","Singapore","Indonesia")]
        [string]$Country
    )

    $CountryConversion = @{
        US                  = "us"
        USA                 = "us"
        Canada              = "ca"
        Mexico              = "mx"
        Brazil              = "br"
        Germany             = "de"
        Austria             = "at"
        Switzerland         = "ch"
        'United Kingdom'    = "uk"
        Ireland             = "ie"
        Russia              = "ru"
        Italy               = "it"
        France              = "fr"
        Spain               = "es"
        Netherlands         = "nl"
        Norway              = "no"
        Sweden              = "se"
        Denmark             = "dk"
        Finland             = "fi"
        Lithuania           = "lt"
        Latvia              = "lv"
        Estonia             = "ee"
        'South Africa'      = "za"
        Australia           = "au"
        'New Zealand'       = "nz"
        India               = "in"
        Japan               = "jp"
        'South Korea'       = "kr"
        Thailand            = "th"
        Malaysia            = "my"
        Philippines         = "ph"
        Singapore           = "sg"
        Indonesia           = "id"
    }

    if ($CountryConversion.Keys -contains $Country) {
        $FinalCountry = $CountryConversion.$Country
    }
    else {
        $FinalCountry = $Country
    }

    $JsonXPathConfigString = @"
{
    "title": "//*/img[@class=\"logo__img\"]/@alt",
    "Services": {
        "_xpath": "//*/horizontal-scrollable",
        "hrefs": ".//ng-transclude//a/@href"
    }
}
"@
    $BaseUrl = "https://www.justwatch.com/$FinalCountry/"
    $TextInfo = (Get-Culture).TextInfo
    
    $StreamingServicesInfoPrep = Get-SiteAsJson -Url $BaseUrl -XPathJsonConfigString $JsonXPathConfigString
    $($StreamingServicesInfoPrep | ConvertFrom-Json).Services.hrefs | foreach {
        $ServiceNamehref = $($_ -split '/')[-1]
        [pscustomobject]@{
            FullUrl         = $BaseUrl + $_
            ServiceNamehref = $ServiceNamehref
            ServiceName     = $TextInfo.ToTitleCase($($ServiceNamehref -replace '-',' '))
        }
    }
}


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


<#
    .SYNOPSIS
        Installs dotnet-script (https://github.com/filipw/dotnet-script)

    .DESCRIPTION
        See .SYNOPSIS

    .NOTES

    .EXAMPLE
        # Launch PowerShell and ...

        PS C:\Users\zeroadmin> Install-DotNetSscript
#>
function Install-DotNetScript {
    [CmdletBinding()]
    Param ()

    if (!$(Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Error "Unable to find the 'dotnet' binary! Halting!"
        $global:FunctionResult = "1"
        return
    }

    dotnet tool install -g dotnet-script

    if (!$(Get-Command dotnet-script -ErrorAction SilentlyContinue)) {
        Write-Error "Something went wrong during installation of 'dotnet-script' via the dotnet cli. Please review the above output. Halting!"
        $global:FunctionResult = "1"
        return
    }
}


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



if ($PSVersionTable.Platform -eq "Win32NT" -and $PSVersionTable.PSEdition -eq "Core") {
    if (![bool]$(Get-Module -ListAvailable WindowsCompatibility)) {
        try {
            Install-Module WindowsCompatibility -ErrorAction Stop
        }
        catch {
            Write-Error $_
            $global:FunctionResult = "1"
            return
        }
    }
    if (![bool]$(Get-Module WindowsCompatibility)) {
        try {
            Import-Module WindowsCompatibility -ErrorAction Stop
        }
        catch {
            Write-Error $_
            Write-Warning "The $ThisModule Module was NOT loaded successfully! Please run:`n    Remove-Module $ThisModule"
            $global:FunctionResult = "1"
            return
        }
    }
}

[System.Collections.ArrayList]$script:FunctionsForSBUse = @(
    ${Function:AddMySudoPwd}.Ast.Extent.Text
    ${Function:AddWinRMTrustedHost}.Ast.Extent.Text
    ${Function:AddWinRMTrustLocalHost}.Ast.Extent.Text
    ${Function:DownloadNuGetPackage}.Ast.Extent.Text
    ${Function:GetElevation}.Ast.Extent.Text
    ${Function:GetLinuxOctalPermissions}.Ast.Extent.Text
    ${Function:GetModuleDependencies}.Ast.Extent.Text
    ${Function:GetMySudoStatus}.Ast.Extent.Text
    ${Function:InstallLinuxPackage}.Ast.Extent.Text
    ${Function:InvokeModuleDependencies}.Ast.Extent.Text
    ${Function:InvokePSCompatibility}.Ast.Extent.Text
    ${Function:ManualPSGalleryModuleInstall}.Ast.Extent.Text
    ${Function:NewCronToAddSudoPwd}.Ast.Extent.Text
    ${Function:NewUniqueString}.Ast.Extent.Text
    ${Function:RemoveMySudoPwd}.Ast.Extent.Text
    ${Function:ResolveHost}.Ast.Extent.Text
    ${Function:ScrubJsonUnicodeSymbols}.Ast.Extent.Text
    ${Function:SudoPwsh}.Ast.Extent.Text
    ${Function:TestIsValidIPAddress}.Ast.Extent.Text
    ${Function:VariableLibraryTemplate}.Ast.Extent.Text
    ${Function:Deploy-SplashContainer}.Ast.Extent.Text
    ${Function:Get-JWGenres}.Ast.Extent.Text
    ${Function:Get-JWMedia}.Ast.Extent.Text
    ${Function:Get-JWStreamingServices}.Ast.Extent.Text
    ${Function:Get-SiteAsJson}.Ast.Extent.Text
    ${Function:Install-Docker}.Ast.Extent.Text
    ${Function:Install-DotNetScript}.Ast.Extent.Text
    ${Function:Install-DotNetSDK}.Ast.Extent.Text
)

$script:UnicodeSymbolConversion = @{
    '\u2018' = "'"
    '\u2019' = "'"
    '\u201A' = ','
    '\u201B' = "'"
    '\u201C' = '"'
    '\u201D' = '"'
}

[System.Collections.ArrayList]$script:LuaScriptPSObjects = @(    
    [pscustomobject]@{
        LuaScriptName       = 'InfiniteScrolling'
        LuaScriptContent    = @'
function main(splash)
    local scroll_delay = 1
    local previous_height = -1
    local number_of_scrolls = 0
    local maximal_number_of_scrolls = 99

    local scroll_to = splash:jsfunc("window.scrollTo")
    local get_body_height = splash:jsfunc(
        "function() {return document.body.scrollHeight;}"
    )
    local get_inner_height = splash:jsfunc(
        "function() {return window.innerHeight;}"
    )
    local get_body_scroll_top = splash:jsfunc(
        "function() {return document.body.scrollTop;}"
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
'@
    }
)

# SIG # Begin signature block
# MIIMiAYJKoZIhvcNAQcCoIIMeTCCDHUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUiEGg9zDn+YAe9YfyixrBi0Os
# cQmgggn9MIIEJjCCAw6gAwIBAgITawAAAB/Nnq77QGja+wAAAAAAHzANBgkqhkiG
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFLEt+An/vTbc69iO
# x8a8NRvVoQbfMA0GCSqGSIb3DQEBAQUABIIBAMIvzb/ZxTkOaXw6Ku2Gkeh6YNxg
# wSPk4Spr52endthFuiCVwV/WJ6D0vBh3h9Fxr6BG/pjvv721XcYyIoRX29XoZHJo
# h18N4PIUKdMPpziiSYH+ykmZZcBP/0adR1SMwIg1jXFwUAgjQdvFavYyRTpWFFGU
# ccWeIT/xhoOOXOyKcazmGgdcCwWrPMzlYAi1mAgX7fwjSOpNXih8qf2T5YtAYizt
# AtqM7gtsGnjQHky+hrcod3tK7VYcdfIi7ZmCk6oe/TDopSLtetYaGfv7o3PeyLyr
# FsU9eLwOzzrzLaIgU91SATToKemWILIs3Tp07NZpzkD3dZABOPXiwJyLOqE=
# SIG # End signature block