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

        # Strip UTF-8 BOM (\uFEFF) from column names - SharePoint Admin Center exports
        # prepend a BOM to the first column header, silently breaking property lookups.
        $data = $data | ForEach-Object {
            $row    = $_
            $newRow = [ordered]@{}
            foreach ($prop in $row.PSObject.Properties) {
                $newRow[$prop.Name.TrimStart([char]0xFEFF)] = $prop.Value
            }
            [PSCustomObject]$newRow
        }

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
                # TrimStart strips BOM from the first column header
                $headerName = $worksheet.Cells.Item(1, $col).Text.TrimStart([char]0xFEFF)
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
# Uses the SharePoint Search API to sum file sizes, which bypasses the List View
# Threshold entirely. The search index exposes a 'Size' managed property per file.
# Note: counts current file versions only (search index does not include version history),
# so numbers will be lower than Admin Center - fine for ranking purposes.
# Hard ceiling: Search API returns at most 10,000 rows total (500 per page x 20 pages).
# Sites with more indexed files will have their storage understated with a warning.
function Get-WebStorageUsage {
    param(
        [string]$WebUrl
    )

    try {
        $totalBytes = [long]0
        $startRow   = 0
        $batchSize  = 500
        $totalRows  = 1  # Seed value so the loop is entered at least once
        $isCapped   = $false

        while ($startRow -lt $totalRows -and $startRow -lt 10000) {
            # IsDocument:1 restricts to files only (excludes list items, pages, etc.)
            # path: scopes to this web and everything beneath it
            $queryText    = "path:`"$WebUrl`" IsDocument:1"
            $encodedQuery = [Uri]::EscapeDataString($queryText)
            $url = "/_api/search/query?querytext='$encodedQuery'&selectproperties='Size'&trimduplicates=false&rowlimit=$batchSize&startrow=$startRow"

            $response  = Invoke-PnPSPRestMethod -Url $url -Method Get -ErrorAction Stop
            $relevant  = $response.PrimaryQueryResult.RelevantResults
            $totalRows = $relevant.TotalRows

            if ($totalRows -eq 0) { break }

            # Warn and flag once when the 10k ceiling is confirmed
            if ($startRow -eq 0 -and $totalRows -gt 10000) {
                $isCapped = $true
                Write-Warning "  [SEARCH CAP] $WebUrl has $totalRows indexed files; only the first 10,000 are counted. Storage will be understated."
            }

            foreach ($row in $relevant.Table.Rows) {
                $sizeProp = $row.Cells | Where-Object { $_.Key -eq "Size" }
                if ($sizeProp -and $null -ne $sizeProp.Value) {
                    $totalBytes += [long]$sizeProp.Value
                }
            }

            $startRow += $batchSize
        }

        return [PSCustomObject]@{
            StorageGB = [math]::Round($totalBytes / 1GB, 4)
            IsCapped  = $isCapped
        }
    }
    catch {
        Write-Warning "Could not calculate storage for $WebUrl : $($_.Exception.Message)"
        return [PSCustomObject]@{ StorageGB = $null; IsCapped = $false }
    }
}

# Function to get site owners
# Accepts the full subsite URL and navigates to it via getwebbyurl() from whatever
# root connection is currently active - no per-subsite reconnection required.
function Get-SiteOwners {
    param(
        [string]$SiteUrl
    )

    try {
        # Direct getwebbyurl('...') avoids the @v OData alias which Invoke-PnPSPRestMethod
        # can URL-encode before sending, breaking the binding.
        $serverRelUrl = ([System.Uri]$SiteUrl).AbsolutePath.Replace("'", "''")
        $response = Invoke-PnPSPRestMethod `
            -Url "/_api/web/getwebbyurl('$serverRelUrl')/AssociatedOwnerGroup/Users?`$select=Title,PrincipalType" `
            -Method Get -ErrorAction Stop
        $owners = ($response.value |
            Where-Object { $_.PrincipalType -eq 1 } |
            Select-Object -ExpandProperty Title) -join "; "
        return $(if ($owners) { $owners } else { "No individual owners (group-only)" })
    }
    catch {
        return "Unable to retrieve"
    }
}

# Function to get last activity
# Same pattern: navigate to the target web via getwebbyurl() from the root connection.
function Get-SiteLastActivity {
    param(
        [string]$SiteUrl
    )

    try {
        $serverRelUrl = ([System.Uri]$SiteUrl).AbsolutePath.Replace("'", "''")
        $response = Invoke-PnPSPRestMethod `
            -Url "/_api/web/getwebbyurl('$serverRelUrl')?`$select=LastItemModifiedDate" `
            -Method Get -ErrorAction Stop
        return $response.LastItemModifiedDate
    }
    catch {
        return $null
    }
}

# Recursive helper: walk the children map upward and sum leaf storage values
function Get-RolledUpStorage {
    param(
        [string]$Url,
        [hashtable]$StorageMap,
        [hashtable]$ChildrenMap
    )

    $url = $Url.TrimEnd('/')

    if (-not $ChildrenMap.ContainsKey($url)) {
        # Leaf node: return the value we actually queried
        return $StorageMap[$url]
    }

    $total = [double]0
    foreach ($childUrl in $ChildrenMap[$url]) {
        $childStorage = Get-RolledUpStorage -Url $childUrl -StorageMap $StorageMap -ChildrenMap $ChildrenMap
        if ($null -ne $childStorage) { $total += $childStorage }
    }
    return [math]::Round($total, 4)
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
            Connect-PnPOnline -Url $siteUrl -clientId f6666fe0-04e6-419a-b4bb-4025060af8f5 -interactive -ErrorAction Stop
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

            # --- Build parent-child map from the subsite list ---
            $childrenMap = @{}
            foreach ($sub in $subsites) {
                $url = $sub.Url.TrimEnd('/')
                $parentUrl = $url.Substring(0, $url.LastIndexOf('/'))
                if (-not $childrenMap.ContainsKey($parentUrl)) {
                    $childrenMap[$parentUrl] = [System.Collections.Generic.List[string]]::new()
                }
                $childrenMap[$parentUrl].Add($url)
            }

            # --- First pass: connect to every subsite once ---
            # Collect owners + last activity for all, and run the Search query ONLY
            # for leaf nodes (subsites with no children). This keeps each search
            # scoped to the smallest possible file set, avoiding the 10k cap on
            # the large parent/root nodes whose storage we'll derive by summing.
            Write-Host "  Analyzing subsites (leaf-first storage, then rollup)..." -ForegroundColor Yellow
            $storageMap  = @{}  # url (trimmed) -> StorageGB
            $cappedMap   = @{}  # url (trimmed) -> $true if search cap was hit for this node or any descendant
            $metadataMap = @{}  # url (trimmed) -> owners, lastActivity, title

            $subsiteCount = 0
            foreach ($subsite in $subsites) {
                $subsiteCount++
                $url    = $subsite.Url.TrimEnd('/')
                $isLeaf = -not $childrenMap.ContainsKey($url)

                Write-Progress -Activity "Processing subsites for $siteName" `
                    -Status "[$subsiteCount/$($subsites.Count)] $($subsite.Title)$(if ($isLeaf) { ' [LEAF]' })" `
                    -PercentComplete (($subsiteCount / $subsites.Count) * 100)

                try {
                    # No reconnection needed - root site connection is reused for all
                    # REST calls via getwebbyurl(), and Search uses path: scoping.

                    # Storage query only on leaf nodes
                    if ($isLeaf) {
                        $result           = Get-WebStorageUsage -WebUrl $subsite.Url
                        $storageMap[$url] = $result.StorageGB
                        $cappedMap[$url]  = $result.IsCapped
                    } else {
                        $storageMap[$url] = $null   # filled in during rollup
                        $cappedMap[$url]  = $false  # updated during rollup
                    }

                    $metadataMap[$url] = @{
                        Title        = $subsite.Title
                        Owners       = Get-SiteOwners       -SiteUrl $subsite.Url
                        LastActivity = Get-SiteLastActivity  -SiteUrl $subsite.Url
                        IsLeaf       = $isLeaf
                    }

                    $script:TotalSubsitesProcessed++
                }
                catch {
                    Write-Warning "    Error processing subsite $($subsite.Url): $($_.Exception.Message)"
                    $storageMap[$url]  = $null
                    $metadataMap[$url] = @{
                        Title        = $subsite.Title
                        Owners       = "Error"
                        LastActivity = $null
                        IsLeaf       = $isLeaf
                    }
                    $script:Errors += [PSCustomObject]@{ Site = $subsite.Url; Error = $_.Exception.Message }
                }
            }
            Write-Progress -Activity "Processing subsites for $siteName" -Completed

            # --- Second pass: roll leaf storage and cap flag up to all parent nodes ---
            # Process deepest nodes first so each parent can read already-computed children.
            $subsitesByDepth = $subsites | Sort-Object -Property { $_.Url.TrimEnd('/').Split('/').Count } -Descending
            foreach ($sub in $subsitesByDepth) {
                $url = $sub.Url.TrimEnd('/')
                if (-not $metadataMap[$url].IsLeaf) {
                    $storageMap[$url] = Get-RolledUpStorage -Url $url -StorageMap $storageMap -ChildrenMap $childrenMap
                    # Parent is flagged as capped if any immediate child is capped
                    # (children are already processed since we go deepest-first)
                    $cappedMap[$url]  = ($childrenMap[$url] | Where-Object { $cappedMap[$_] -eq $true }).Count -gt 0
                }
            }

            # --- Build the flat result list ---
            $subsiteData = foreach ($sub in $subsites) {
                $url = $sub.Url.TrimEnd('/')
                [PSCustomObject]@{
                    SiteCollectionName      = $siteName
                    SiteCollectionUrl       = $siteUrl
                    SiteCollectionStorageGB = $siteStorageGB
                    SubsiteUrl              = $url
                    SubsiteTitle            = $metadataMap[$url].Title
                    SubsiteStorageGB        = $storageMap[$url]
                    IsLeafNode              = $metadataMap[$url].IsLeaf
                    IsStorageCapped         = $cappedMap[$url]
                    Owners                  = $metadataMap[$url].Owners
                    LastActivity            = $metadataMap[$url].LastActivity
                }
            }

            # Sort by storage and take top percentage
            $topPercentCount = [math]::Ceiling(@($subsiteData).Count * ($TopSubsitesPercentage / 100))
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
        foreach ($err in $script:Errors) {
            Write-Host "  - $($err.Site): $($err.Error)" -ForegroundColor Red
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
