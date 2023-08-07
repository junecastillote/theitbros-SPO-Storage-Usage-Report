$credential = Get-Credential
Connect-PnPOnline -Url https://<tenant>.sharepoint.com -Credentials $credential

# Get All Sites (including OneDrive)
$spoSiteStorageUsage = .\Get-SPOSiteStorageUsage.ps1 -View AllSites

# Get SPO Sites Only
$spoSiteStorageUsage = .\Get-SPOSiteStorageUsage.ps1 -View 'SharePoint Sites'

# Get OneDrive Sites Only
$spoSiteStorageUsage = .\Get-SPOSiteStorageUsage.ps1 -View 'OneDrive Sites'

# Get Sites connected to Microsoft 365 Group
$spoSiteStorageUsage = .\Get-SPOSiteStorageUsage.ps1 -View 'Microsoft 365 Group Sites'

# Get Sites connected to Microsoft Teams
$spoSiteStorageUsage = .\Get-SPOSiteStorageUsage.ps1 -View 'Sites Connected to Teams'

# Get Sites connected to Microsoft Teams Channel (Private or Shared)
$spoSiteStorageUsage = .\Get-SPOSiteStorageUsage.ps1 -View 'Sites Connected to Teams Channel'

# Get Sites without a Microsoft 365 Group
$spoSiteStorageUsage = .\Get-SPOSiteStorageUsage.ps1 -View 'Sites Without a Group'

# Export to file
$spoSiteStorageUsage | Export-Csv -Path .\spoSiteStorageUsage.csv -NoTypeInformation
$spoSiteStorageUsage | Export-Clixml -Path .\spoSiteStorageUsage.xml
$spoSiteStorageUsage | ConvertTo-Json | Out-File -Path .\spoSiteStorageUsage.json
$spoSiteStorageUsage | ConvertTo-Yaml | Out-File -Path .\spoSiteStorageUsage.Yaml
$spoSiteStorageUsage | ConvertTo-Html | Out-File -Path .\spoSiteStorageUsage.html
$spoSiteStorageUsage |
ConvertTo-Html `
    -CssUri .\style1.css |
Out-File .\spoSiteStorageUsage.html