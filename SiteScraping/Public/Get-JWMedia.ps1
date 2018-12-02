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

    # &min_price=5&max_price=5 - Where 5 means that the price of the media is $5 (maximum $50)
    # &monetization_types=free
    # &monetization_types=ads
    # &monetization_types=flatrate
    # &monetization_types=rent
    # &monetization_types=buy
    # &presentation_types=sd
    # &presentation_types=hd
    # &presentation_types=4k
    # &rating_imdb=2 - Where 2 means that the IMDB rating is 2 or higher (up to 10)
    # &rating_tomato=15 - Where 15 means that its Rotten Tomatoes rating is 15% or higher (up to 100%)
    # &age_certifications=G
    # &age_certifications=PG
    # &age_certifications=PG-13
    # &age_certifications=R
    # &age_certifications=NC-17
    $FinalUrl = "https://www.justwatch.com/{0}/provider/{1}/{2}?genres={3}&release_year_from={4}&release_year_until={4}&min_price={5}&max_price={5}" -f $FinalCountry,$FinalServiceName,$FinalTVOrMovie,$Genre,$ReleaseYear,$PriceInDollars
    Get-SiteAsJson -Url $FinalUrl -XPathJsonConfigString $JsonXPathConfigString -HandleInfiniteScrolling | ConvertFrom-Json
}

# SIG # Begin signature block
# MIIMiAYJKoZIhvcNAQcCoIIMeTCCDHUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUHYuEyicRn8cpGRGtCb5RF2dG
# Hzqgggn9MIIEJjCCAw6gAwIBAgITawAAAB/Nnq77QGja+wAAAAAAHzANBgkqhkiG
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFBIWq0/vuiy4PlH0
# SG4GFYZIji1pMA0GCSqGSIb3DQEBAQUABIIBAFKbolpsk0QY7Oq3CsYgpNGJ399o
# vxgPER/D5qc66nbso9Kt7+M7mza/2AXPGkGJ+wE9XTCWQ4H4nsx1ZZHghUlVCiwP
# g/rRt5SHlCezzTfQE3fzymW88YyQEQ6tGfvg7ZXMX+dFQkp2YQd1Pzfkb8UXvqQp
# SOSHV1ChktXlG/2GVeYGTsBVk9hyjz2I0SApUsIdHNazP6s1dodV6hi0Kz/uOCAv
# eMiyesjjnYG+tU+7M6nor2ZW1qjKqagdAKYFk+M/HESiKbi28XF6v5xGwmiMsAxS
# yczKUDY08d+GyLw1dfTMY5fgg5ACqug1m4yxKuVXSmSXscUlNHoZ2nPIn1s=
# SIG # End signature block
