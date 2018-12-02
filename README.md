[![Build status](https://ci.appveyor.com/api/projects/status/github/pldmgg/htmltojson?branch=master&svg=true)](https://ci.appveyor.com/project/pldmgg/htmltojson/branch/master)


# HTMLToJson
Use XPath to specify how to parse a particular website and return your desired Json output. Leverages [OpenScraping](https://github.com/Microsoft/openscraping-lib-csharp), [dotnet-script](https://github.com/filipw/dotnet-script), and ScrapingHub's [Splash Server](https://github.com/scrapinghub/splash)

## Getting Started

```powershell
# One time setup
    # Download the repository
    # Unblock the zip
    # Extract the HTMLToJson folder to a module path (e.g. $env:USERPROFILE\Documents\WindowsPowerShell\Modules\)
# Or, with PowerShell 5 or later or PowerShellGet:
    Install-Module HTMLToJson

# Import the module.
    Import-Module HTMLToJson    # Alternatively, Import-Module <PathToModuleFolder>

# Get commands in the module
    Get-Command -Module HTMLToJson

# Get help
    Get-Help <HTMLToJson Function> -Full
    Get-Help about_HTMLToJson
```

## Examples

### Scenario 1

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
