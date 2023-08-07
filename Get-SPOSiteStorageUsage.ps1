[CmdletBinding(DefaultParameterSetName = 'PSetAll')]
param (
    [Parameter(Mandatory, ParameterSetName = 'PSetSpecified')]
    [String[]]
    $URL,

    [Parameter(Mandatory, ParameterSetName = 'PSetAll')]
    [ValidateSet(
        'All Sites',
        'SharePoint Sites',
        'Microsoft 365 Group Sites',
        'Sites Connected to Teams',
        'Sites Connected to Teams Channel',
        'Sites Without a Group',
        'OneDrive Sites'
    )]
    [string]
    $View,

    [Parameter(ParameterSetName = 'PSetAll')]
    [string[]]
    $Exclude
)

try {
    $pnpTenantInstance = Get-PnPTenantInstance -ErrorAction Stop
    $excludedUrls = [System.Collections.ArrayList]@(
        "$($pnpTenantInstance.RootSiteUrl)"
        "$($pnpTenantInstance.RootSiteUrl)sites/appcatalog"
        "$($pnpTenantInstance.RootSiteUrl)portals/hub",
        "$($pnpTenantInstance.RootSiteUrl)search",
        "$($pnpTenantInstance.MySiteHostUrl)",
        "$($pnpTenantInstance.TenantAdminUrl)"
    )

    if ($Exclude) {
        $excludedUrls.AddRange($Exclude)
    }
}
catch {
    $_.Exception.Message
    return $null
}

# If URL is specified
if ($PSCmdlet.ParameterSetName -eq 'PSetSpecified') {
    $siteCollection = [System.Collections.ArrayList]@()
    $URL | ForEach-Object {
        try {
            $null = $siteCollection.Add($(Get-PnPTenantSite -Url $_ -Detailed -ErrorAction Stop))
        }
        catch {
            $_.Exception.Message | Out-Default
        }
    }
}

# If View is specified
if ($PSCmdlet.ParameterSetName -eq 'PSetAll') {
    #Region Build site template lookup table
    ## Get all available site templates
    $ClientContext = Get-PnPContext
    $Web = Get-PnPWeb

    ## Get All Web Templates
    $WebTemplateCollection = $Web.GetAvailableWebTemplates(1033, 0)
    $ClientContext.Load($WebTemplateCollection)
    $ClientContext.ExecuteQuery()

    ## Create a lookup dictionary
    $webTemplateTable = [ordered]@{}
    $WebTemplateCollection | Sort-Object Name | ForEach-Object {
        $webTemplateTable.Add($_.Name, $_.Title)
    }
    #EndRegion

    switch ($View) {
        'All Sites' { $siteCollection = Get-PnPTenantSite -IncludeOneDriveSites | Where-Object { $_.Url -notin $excludedUrls } }
        'SharePoint Sites' { $siteCollection = Get-PnPTenantSite | Where-Object { $_.Url -notin $excludedUrls } }
        'OneDrive Sites' { $siteCollection = Get-PnPTenantSite -IncludeOneDriveSites -Filter "Url -like '-my.sharepoint.com/personal/'" | Where-Object { $_.Url -notin $excludedUrls } }
        'Microsoft 365 Group Sites' { $siteCollection = Get-PnPTenantSite -GroupIdDefined:$true | Where-Object { $_.GroupId -ne '00000000-0000-0000-0000-000000000000' -and $_.Url -notin $excludedUrls } }
        'Sites Without a Group' { $siteCollection = Get-PnPTenantSite -GroupIdDefined:$false | Where-Object { $_.Url -notin $excludedUrls } }
        'Sites Connected to Teams' { $siteCollection = Get-PnPTenantSite -GroupIdDefined:$true | Where-Object { $_.IsTeamsConnected -eq $true -and $_.Url -notin $excludedUrls } }
        'Sites Connected to Teams Channel' { $siteCollection = Get-PnPTenantSite | Where-Object { $_.IsTeamsChannelConnected -and $_.Url -notin $excludedUrls } }
        Default {}
    }
}

"Found $($siteCollection.Count) site(s) ..." | Out-Default

if ($siteCollection.Count -lt 1) {
    return $null
}

$spoSiteStorageUsageResult = [System.Collections.ArrayList]@()

foreach ($spoSite in ($siteCollection | Sort-Object Url)) {
    "Processing $($spoSite.Url) ..." | Out-Default
    $siteAttributes = [System.Collections.ArrayList]@()
    if ($spoSite.GroupId -ne '00000000-0000-0000-0000-000000000000') {
        $null = $siteAttributes.Add('Microsoft 365 Group')
    }
    if ($spoSite.IsTeamsConnected) {
        $null = $siteAttributes.Add('Microsoft Teams')
    }
    if ($spoSite.TeamsChannelType -eq 'PrivateChannel') {
        $null = $siteAttributes.Add('Private Channel')
    }
    if ($spoSite.TeamsChannelType -eq 'SharedChannel') {
        $null = $siteAttributes.Add('Shared Channel')
    }

    $null = $spoSiteStorageUsageResult.Add(
        $([PSCustomObject]@{
                'SiteName'         = $spoSite.Title
                'Url'              = $spoSite.Url
                'StorageQuota(GB)' = $(($spoSite.StorageQuota * 1MB) / 1GB)
                'StorageUsage(GB)' = $([System.Math]::Round((($spoSite.StorageUsageCurrent * 1MB) / 1GB), 2))
                'StorageUsage(%)'  = $(
                    if ($spoSite.StorageUsageCurrent -gt 0) {
                        $([System.Math]::Round((($spoSite.StorageUsageCurrent / $spoSite.StorageQuota) * 100), 2))
                    }
                    else {
                        0
                    }
                )
                'Owner'            = $(
                    if ($spoSite.Template -like "GROUP*") {
                        $group = Get-PnPMicrosoft365Group -Identity $spoSite.GroupId
                        if ($group.Mail) {
                            "$($group.DisplayName) <$($group.Mail)>"
                        }
                        else {
                            "$($group.DisplayName) <No Email>"
                        }
                    }
                    else {
                        if ($spoSite.Owner) {
                            if ($user = Get-PnPAzureADUser -Identity $spoSite.Owner) {
                                if ($user.Mail) {
                                    "$($user.DisplayName) <$($user.Mail)>"
                                }
                                else {
                                    "$($user.DisplayName) <No Email>"
                                }
                            }
                        }
                    }
                )
                'Template'         = $(
                    if ($spoSite.Url -like "*-my.sharepoint.com/personal/*") {
                        'OneDrive'
                    }
                    else {
                        $webTemplateTable[$($spoSite.Template)]
                    }
                )
                SiteAttributes     = $(
                    if ($siteAttributes.Count -gt 0) {
                        $siteAttributes -join ","
                    }
                )
            }
        )
    )
}
return $spoSiteStorageUsageResult