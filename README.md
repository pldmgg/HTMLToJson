[![Build status](https://ci.appveyor.com/api/projects/status/github/pldmgg/htmltojson?branch=master&svg=true)](https://ci.appveyor.com/project/pldmgg/htmltojson/branch/master)


# HTMLToJson
Use XPath to specify how to parse a particular website and return your desired Json output. Leverages [OpenScraping](https://github.com/Microsoft/openscraping-lib-csharp), [dotnet-script](https://github.com/filipw/dotnet-script), and ScrapingHub's [Splash Server](https://github.com/scrapinghub/splash) in order to fully and faithfully render javascript.

# Compatibility
All functions in the HTMLToJson Module except `Install-Docker` and `Deploy-SplashServer` are compatible with Windows PowerShell 5.1 and PowerShell Core 6.X (Windows and Linux). The `Install-Docker` and `Deploy-SplashServer` functions work on PowerShell Core 6.X on Linux (specifically Ubuntu 18.04/16.04/14.04, Debian 9/8, CentOS/RHEL 7, OpenSUSE 42).

# Initial Prep
In order to fully and faithfully render sites, the HTMLToJson Module relies on ScrapingHub's Splash Server. If you do not already have Splash deployed to your environment, ssh to a VM running your preferred compatible Linux distro, launch PowerShell Core (using `sudo`), and install the HTMLToJson Module -

```
sudo pwsh
Install-Module HTMLToJson
exit
```

Next, launch pwsh (without `sudo`), import the HTMLToJson Module, and install Docker (you will receive a sudo prompt unless you have password-less sudo configured on your system).

```powershell
pwsh

Import-Module HTMLToJson
Install-Docker
```

Finally, deploy ScrapingHub's Splash Server Docker Container -

```powershell
Deploy-SplashContainer
```

At this point, you can continue on the same Linux VM running your Splash Docker container, or you can hop back into your local workstation (Windows or Linux...and make sure you install/import the module there). Either way, the following steps will be the same.

Next, we need to install the .Net Core SDK as well as dotnet-script. These provide the `dotnet` and `dotnet-script` binaries -

```powershell
Install-DotNetSDK
Install-DotNetScript
```

# Parsing A Website Using XPath

```powershell
PS C:\Users\zeroadmin> $JsonXPathConfigString = @"
{
    "title": "//*/h1",
    "VisibleAPIs": {
        "_xpath": "//a[(@class=\"list-group-item\")]",
        "APIName": ".//h3",
        "APIVersion": ".//p//code//span[normalize-space()][2]",
        "APIDescription": ".//p[(@class=\"list-group-item-text\")]"
    }
}
"@
PS C:\Users\zeroadmin> Get-SiteAsJson -Url 'http://dotnetapis.com/' -XPathJsonConfigString $JsonXPathConfigString -SplashServerUri 'http://192.168.2.50:8050'
{
    "title": "DotNetApis (BETA)",
    "VisibleAPIs": [
        {
            "APIName": "NUnit",
            "APIVersion": "3.11.0",
            "APIDescription": "NUnit is a unit-testing framework for all .NET languages with a strong TDD focus."
        },
        {
            "APIName": "Json.NET",
            "APIVersion": "12.0.1",
            "APIDescription": "Json.NET is a popular high-performance JSON framework for .NET"
        },
        {
            "APIName": "EntityFramework",
            "APIVersion": "6.2.0",
            "APIDescription": "Entity Framework is Microsoft's recommended data access technology for new applications."
        },
        {
            "APIName": "MySql.Data",
            "APIVersion": "8.0.13",
            "APIDescription": "MySql.Data.MySqlClient .Net Core Class Library"
        },
        {
            "APIName": "NuGet.Core",
            "APIVersion": "2.14.0",
            "APIDescription": "NuGet.Core is the core framework assembly for NuGet that the rest of NuGet builds upon."
        }
    ]
}
```

## Notes

* PSGallery: https://www.powershellgallery.com/packages/HTMLToJson
