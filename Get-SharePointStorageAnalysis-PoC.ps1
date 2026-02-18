<#
.SYNOPSIS
    Proof of Concept: Analyzes SharePoint storage usage for top sites and their subsites.

.DESCRIPTION
    This PoC script reads an Excel export from SharePoint Admin Center, processes the top N sites,
    and analyzes storage usage for all subsites within those sites. Results are exported to CSV.

.PARAMETER ExcelFilePath
    Path to the Excel file exported from SharePoint Admin Center

.PARAMETER OutputCsvPath
    Path where the output CSV will be saved (default: .\SharePoint_Storage_Analysis.csv)

.PARAMETER TopSitesCount
    Number of top sites to process (default: 3 for PoC testing)

.PARAMETER TopSubsitesPercentage
    Percentage of top subsites to include per site collection (default: 20)

.EXAMPLE
    .\Get-SharePointStorageAnalysis-PoC.ps1 -ExcelFilePath ".\SharePointSites.xlsx" -TopSitesCount 3
    Process the top 3 sites from the Excel file

.EXAMPLE
    .\Get-SharePointStorageAnalysis-PoC.ps1 -ExcelFilePath ".\SharePointSites.xlsx" -TopSitesCount 90 -TopSubsitesPercentage 20
    Process the top 90 sites and get the top 20% subsites from each

.NOTES
    Requires: PnP.PowerShell module
    Requires: ImportExcel module (or will use COM object as fallback)
    Author: Claude
    Date: 2026-02-12
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ExcelFilePath,

    [Parameter(Mandatory=$false)]
    [string]$OutputCsvPath = ".\SharePoint_Storage_Analysis.csv",

    [Parameter(Mandatory=$false)]
    [int]$TopSitesCount = 3,

    [Parameter(Mandatory=$false)]
    [int]$TopSubsitesPercentage = 20
)

# Check if PnP.PowerShell is available
if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
    Write-Error "PnP.PowerShell module is not installed. Install it with: Install-Module PnP.PowerShell -Scope CurrentUser"
    exit 1
}

Import-Module PnP.PowerShell -ErrorAction Stop

# Statistics tracking
$script:TotalSitesProcessed = 0
$script:TotalSubsitesFound = 0
$script:TotalSubsitesProcessed = 0
$script:Errors = @()

# Function to read Excel file
function Read-ExcelFile {
    param(
        [string]$FilePath,
        [int]$TopN
    )

    Write-Host "Reading Excel file: $FilePath" -ForegroundColor Yellow

    if (-not (Test-Path $FilePath)) {
        throw "Excel file not found: $FilePath"
    }

    # Try using ImportExcel module first (faster and cleaner)
    if (Get-Module -ListAvailable -Name ImportExcel) {
        Import-Module ImportExcel
        Write-Host "Using ImportExcel module..." -ForegroundColor Green

        $data = Import-Excel -Path $FilePath

        # Sort by storage and take top N
        $topSites = $data |
            Sort-Object -Property "Storage used (GB)" -Descending |
            Select-Object -First $TopN

        Write-Host "Loaded $($topSites.Count) sites from Excel`n" -ForegroundColor Green
        return $topSites
    }
    else {
        # Fallback to COM object
        Write-Host "ImportExcel module not found. Using COM object (slower)..." -ForegroundColor Yellow
        Write-Host "Tip: Install ImportExcel for better performance: Install-Module ImportExcel -Scope CurrentUser`n" -ForegroundColor Cyan

        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false

        try {
            $workbook = $excel.Workbooks.Open($FilePath)
            $worksheet = $workbook.Sheets.Item(1)
            $usedRange = $worksheet.UsedRange

            # Get headers from first row
            $headers = @{}
            for ($col = 1; $col -le $usedRange.Columns.Count; $col++) {
                $headerName = $worksheet.Cells.Item(1, $col).Text
                $headers[$col] = $headerName
            }

            # Read data rows
            $data = @()
            for ($row = 2; $row -le $usedRange.Rows.Count; $row++) {
                $rowData = @{}
                for ($col = 1; $col -le $usedRange.Columns.Count; $col++) {
                    $rowData[$headers[$col]] = $worksheet.Cells.Item($row, $col).Text
                }
                $data += [PSCustomObject]$rowData
            }

            # Sort by storage and take top N
            $topSites = $data |
                Sort-Object -Property @{Expression={[double]$_."Storage used (GB)"}; Descending=$true} |
                Select-Object -First $TopN

            Write-Host "Loaded $($topSites.Count) sites from Excel`n" -ForegroundColor Green
            return $topSites
        }
        finally {
            $workbook.Close($false)
            $excel.Quit()
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
        }
    }
}

# Function to get all subsites recursively
function Get-AllSubsites {
    param(
        [string]$SiteUrl,
        [string]$ParentUrl = ""
    )

    $subsites = @()

    try {
        # Get immediate subsites
        $webs = Get-PnPSubWeb -Recurse -IncludeRootWeb -ErrorAction Stop

        foreach ($web in $webs) {
            $subsites += $web
        }
    }
    catch {
        Write-Warning "Could not retrieve subsites from $SiteUrl : $($_.Exception.Message)"
        $script:Errors += [PSCustomObject]@{
            Site = $SiteUrl
            Error = $_.Exception.Message
        }
    }

    return $subsites
}

# Function to get storage usage for a web
# Uses REST API to sum file sizes across all document libraries (BaseTemplate 101).
# Note: this counts current file versions only, not version history - good enough for
# ranking purposes but will be lower than the Admin Center figure.
function Get-WebStorageUsage {
    param(
        [string]$WebUrl
    )

    try {
        $totalBytes = [long]0

        # Get all document libraries in this web (non-hidden, BaseTemplate 101)
        $listsResponse = Invoke-PnPSPRestMethod -Url "/_api/web/lists?`$filter=Hidden eq false and BaseTemplate eq 101&`$select=Id,Title,ItemCount" -Method Get -ErrorAction Stop

        foreach ($list in $listsResponse.value) {
            if ($list.ItemCount -eq 0) { continue }

            # Expand the File entity to get Length. Filter to files only (FSObjType eq 0)
            # so folder rows (which have no File) are skipped automatically.
            $nextLink = "/_api/web/lists(guid'$($list.Id)')/items?`$filter=FSObjType eq 0&`$select=File/Length&`$expand=File&`$top=5000"

            while ($nextLink) {
                $itemsResponse = Invoke-PnPSPRestMethod -Url $nextLink -Method Get -ErrorAction Stop

                foreach ($item in $itemsResponse.value) {
                    if ($null -ne $item.File -and $item.File.Length -gt 0) {
                        $totalBytes += [long]$item.File.Length
                    }
                }

                # Follow OData next page link if present
                if ($itemsResponse.'odata.nextLink') {
                    $nextLink = "/_api" + ($itemsResponse.'odata.nextLink' -split '/_api',2)[1]
                }
                else {
                    $nextLink = $null
                }
            }
        }

        return [math]::Round($totalBytes / 1GB, 4)
    }
    catch {
        Write-Warning "Could not calculate storage for $WebUrl : $($_.Exception.Message)"
        return $null
    }
}

# Function to get site owners
function Get-SiteOwners {
    param(
        [string]$SiteUrl
    )

    try {
        # Get the associated owner group directly - no -Includes needed
        $ownerGroup = Get-PnPGroup -AssociatedOwnerGroup -ErrorAction Stop

        if ($ownerGroup) {
            $members = Get-PnPGroupMember -Group $ownerGroup -ErrorAction Stop
            # Return display names, filtering out system/AD group entries if desired
            $ownerNames = ($members | Where-Object { $_.PrincipalType -eq "User" } | Select-Object -ExpandProperty Title) -join "; "
            return $(if ($ownerNames) { $ownerNames } else { "No individual owners (group-only)" })
        }
        else {
            return "No owner group"
        }
    }
    catch {
        return "Unable to retrieve"
    }
}

# Function to get last activity
function Get-SiteLastActivity {
    param(
        [string]$SiteUrl
    )

    try {
        # Use REST API - avoids -Includes ValidateSet issues entirely
        $response = Invoke-PnPSPRestMethod -Url "/_api/web?`$select=LastItemModifiedDate" -Method Get -ErrorAction Stop
        return $response.LastItemModifiedDate
    }
    catch {
        return $null
    }
}

# Main execution
try {
    Write-Host "`n======================================================" -ForegroundColor Cyan
    Write-Host "SharePoint Storage Analysis - Proof of Concept" -ForegroundColor Cyan
    Write-Host "======================================================`n" -ForegroundColor Cyan

    # Read Excel file
    $topSites = Read-ExcelFile -FilePath $ExcelFilePath -TopN $TopSitesCount

    if ($topSites.Count -eq 0) {
        Write-Error "No sites found in Excel file"
        exit 1
    }

    # Display sites to be processed
    Write-Host "Sites to be processed:" -ForegroundColor Yellow
    Write-Host "======================================================" -ForegroundColor Yellow
    foreach ($site in $topSites) {
        Write-Host "  - $($site.'Site name') | $($site.'Storage used (GB)') GB" -ForegroundColor White
        Write-Host "    $($site.URL)" -ForegroundColor DarkGray
    }
    Write-Host ""

    # Results array
    $results = @()

    # Process each site
    $siteCount = 0
    foreach ($site in $topSites) {
        $siteCount++
        $siteUrl = $site.URL
        $siteName = $site.'Site name'
        $siteStorageGB = $site.'Storage used (GB)'
        $siteLastActivity = $site.'Last activity'

        Write-Host "[$siteCount/$($topSites.Count)] Processing: $siteName" -ForegroundColor Cyan
        Write-Host "  URL: $siteUrl" -ForegroundColor Gray

        try {
            # Connect to the site
            Write-Host "  Connecting to site..." -ForegroundColor Yellow
            Connect-PnPOnline -Url $siteUrl -Interactive -ErrorAction Stop
            Write-Host "  Connected!" -ForegroundColor Green

            # Get all subsites
            Write-Host "  Retrieving subsites..." -ForegroundColor Yellow
            $subsites = Get-AllSubsites -SiteUrl $siteUrl
            $script:TotalSubsitesFound += $subsites.Count
            Write-Host "  Found $($subsites.Count) subsites" -ForegroundColor Green

            if ($subsites.Count -eq 0) {
                Write-Host "  No subsites found, skipping to next site`n" -ForegroundColor Yellow
                continue
            }

            # Process each subsite to get storage
            Write-Host "  Analyzing subsite storage..." -ForegroundColor Yellow
            $subsiteData = @()

            $subsiteCount = 0
            foreach ($subsite in $subsites) {
                $subsiteCount++
                Write-Progress -Activity "Processing subsites for $siteName" -Status "Subsite $subsiteCount of $($subsites.Count)" -PercentComplete (($subsiteCount / $subsites.Count) * 100)

                try {
                    # Connect to subsite
                    Connect-PnPOnline -Url $subsite.Url -Interactive -ErrorAction Stop

                    # Get storage
                    $storage = Get-WebStorageUsage -WebUrl $subsite.Url

                    # Get owners
                    $owners = Get-SiteOwners -SiteUrl $subsite.Url

                    # Get last activity
                    $lastActivity = Get-SiteLastActivity -SiteUrl $subsite.Url

                    $subsiteData += [PSCustomObject]@{
                        SiteCollectionName = $siteName
                        SiteCollectionUrl = $siteUrl
                        SiteCollectionStorageGB = $siteStorageGB
                        SubsiteUrl = $subsite.Url
                        SubsiteTitle = $subsite.Title
                        SubsiteStorageGB = $storage
                        Owners = $owners
                        LastActivity = $lastActivity
                    }

                    $script:TotalSubsitesProcessed++
                }
                catch {
                    Write-Warning "    Error processing subsite $($subsite.Url): $($_.Exception.Message)"
                    $script:Errors += [PSCustomObject]@{
                        Site = $subsite.Url
                        Error = $_.Exception.Message
                    }
                }
            }
            Write-Progress -Activity "Processing subsites for $siteName" -Completed

            # Sort subsites by storage and take top percentage
            $topPercentCount = [math]::Ceiling($subsiteData.Count * ($TopSubsitesPercentage / 100))
            $topSubsites = $subsiteData | Sort-Object -Property SubsiteStorageGB -Descending | Select-Object -First $topPercentCount

            Write-Host "  Including top $topPercentCount subsites (top $TopSubsitesPercentage%)" -ForegroundColor Green

            # Add to results
            $results += $topSubsites

            $script:TotalSitesProcessed++
            Write-Host "  Completed!`n" -ForegroundColor Green
        }
        catch {
            Write-Error "  Failed to process site: $($_.Exception.Message)`n"
            $script:Errors += [PSCustomObject]@{
                Site = $siteUrl
                Error = $_.Exception.Message
            }
        }
        finally {
            # Disconnect
            if (Get-PnPConnection -ErrorAction SilentlyContinue) {
                Disconnect-PnPOnline
            }
        }
    }

    # Export results to CSV
    Write-Host "`n======================================================" -ForegroundColor Cyan
    Write-Host "EXPORTING RESULTS" -ForegroundColor Cyan
    Write-Host "======================================================" -ForegroundColor Cyan

    if ($results.Count -gt 0) {
        $results | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8
        Write-Host "Results exported to: $OutputCsvPath" -ForegroundColor Green
        Write-Host "Total records: $($results.Count)`n" -ForegroundColor Green
    }
    else {
        Write-Host "No results to export`n" -ForegroundColor Yellow
    }

    # Summary
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host "SUMMARY" -ForegroundColor Cyan
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host "Sites processed: $script:TotalSitesProcessed / $($topSites.Count)" -ForegroundColor White
    Write-Host "Total subsites found: $script:TotalSubsitesFound" -ForegroundColor White
    Write-Host "Subsites successfully analyzed: $script:TotalSubsitesProcessed" -ForegroundColor White
    Write-Host "Errors encountered: $($script:Errors.Count)" -ForegroundColor $(if ($script:Errors.Count -gt 0) { "Red" } else { "Green" })

    if ($script:Errors.Count -gt 0) {
        Write-Host "`nErrors:" -ForegroundColor Red
        foreach ($error in $script:Errors) {
            Write-Host "  - $($error.Site): $($error.Error)" -ForegroundColor Red
        }
    }

    Write-Host "`nOperation complete!`n" -ForegroundColor Green
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    Write-Error $_.ScriptStackTrace
    if (Get-PnPConnection -ErrorAction SilentlyContinue) {
        Disconnect-PnPOnline
    }
    exit 1
}
