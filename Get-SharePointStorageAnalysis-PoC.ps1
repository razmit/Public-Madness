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
    [int]$TopSubsitesPercentage = 20,

    [Parameter(Mandatory=$false)]
    [string]$SharePointListUrl = "https://rsmnet.sharepoint.com/sites/YourTeamSite",

    [Parameter(Mandatory=$false)]
    [string]$ListName = "Storage Analysis"
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

        # Strip UTF-8 BOM (\uFEFF) and literal quote characters from column names.
        # SharePoint Admin Center exports prepend BOM and wrap some column names in quotes.
        $data = $data | ForEach-Object {
            $row    = $_
            $newRow = [ordered]@{}
            foreach ($prop in $row.PSObject.Properties) {
                $cleanName = $prop.Name.TrimStart([char]0xFEFF).Trim('"').Trim("'")
                $newRow[$cleanName] = $prop.Value
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

            # Get headers from first row, stripping BOM and quotes
            $headers = @{}
            for ($col = 1; $col -le $usedRange.Columns.Count; $col++) {
                $headerName = $worksheet.Cells.Item(1, $col).Text.TrimStart([char]0xFEFF).Trim('"').Trim("'")
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
# Loads all properties we need: AssociatedOwnerGroup, WebTemplate, Created
# (LastItemModifiedDate is already loaded by default)
function Get-AllSubsites {
    param(
        [string]$SiteUrl,
        [string]$ParentUrl = ""
    )

    $subsites = @()

    try {
        # Get all subsites recursively
        $webs = Get-PnPSubWeb -Recurse -IncludeRootWeb -ErrorAction Stop

        foreach ($web in $webs) {
            # Load additional properties we need beyond the defaults
            try {
                Get-PnPProperty -ClientObject $web -Property AssociatedOwnerGroup,WebTemplate,Created -ErrorAction SilentlyContinue | Out-Null
            }
            catch {
                # If loading fails, properties will be null - that's fine
            }
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
            FileCount = [int]$totalRows
            IsCapped  = $isCapped
        }
    }
    catch {
        Write-Warning "Could not calculate storage for $WebUrl : $($_.Exception.Message)"
        return [PSCustomObject]@{ StorageGB = $null; FileCount = 0; IsCapped = $false }
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

# Recursive helper: walk the children map upward and sum leaf file counts
function Get-RolledUpFileCount {
    param(
        [string]$Url,
        [hashtable]$FileCountMap,
        [hashtable]$ChildrenMap
    )

    $url = $Url.TrimEnd('/')

    if (-not $ChildrenMap.ContainsKey($url)) {
        # Leaf node: return the value we actually queried
        return $FileCountMap[$url]
    }

    $total = [int]0
    foreach ($childUrl in $ChildrenMap[$url]) {
        $childCount = Get-RolledUpFileCount -Url $childUrl -FileCountMap $FileCountMap -ChildrenMap $ChildrenMap
        if ($null -ne $childCount) { $total += $childCount }
    }
    return $total
}

# Function to write results to SharePoint List in batches
function Write-ToSharePointList {
    param(
        [array]$Items,
        [string]$ListUrl,
        [string]$ListName,
        [datetime]$RunDate
    )

    if ($Items.Count -eq 0) { return }

    Write-Host "  Writing $($Items.Count) items to SharePoint List..." -ForegroundColor Yellow

    try {
        # Connect to the list site if not already connected, or reconnect if needed
        $currentConnection = Get-PnPConnection -ErrorAction SilentlyContinue
        if (-not $currentConnection -or $currentConnection.Url -ne $ListUrl) {
            Connect-PnPOnline -Url $ListUrl -clientId f6666fe0-04e6-419a-b4bb-4025060af8f5 -Interactive -ErrorAction Stop
        }

        # Write items in batches of 100 to avoid overwhelming SharePoint
        $batchSize = 100
        $written = 0

        for ($i = 0; $i -lt $Items.Count; $i += $batchSize) {
            $batch = $Items[$i..[Math]::Min($i + $batchSize - 1, $Items.Count - 1)]

            foreach ($item in $batch) {
                $listItemValues = @{
                    Title                     = $item.SubsiteTitle
                    RunDate                   = $RunDate
                    SiteCollectionName        = $item.SiteCollectionName
                    SiteCollectionUrl         = $item.SiteCollectionUrl
                    SiteCollectionStorageGB   = $item.SiteCollectionStorageGB
                    SubsiteUrl                = $item.SubsiteUrl
                    SubsiteTitle              = $item.SubsiteTitle
                    SubsiteStorageGB          = $item.SubsiteStorageGB
                    FileCount                 = $item.FileCount
                    IsLeafNode                = $item.IsLeafNode
                    IsStorageCapped           = $item.IsStorageCapped
                    SubsiteDepth              = $item.SubsiteDepth
                    DirectChildCount          = $item.DirectChildCount
                    WebTemplate               = $item.WebTemplate
                    IsClassic                 = $item.IsClassic
                    SiteCreated               = $item.SiteCreated
                    LastActivity              = $item.LastActivity
                    Owners                    = $item.Owners  # Semicolon-separated emails - SharePoint will auto-resolve
                }

                try {
                    Add-PnPListItem -List $ListName -Values $listItemValues -ErrorAction Stop | Out-Null
                }
                catch {
                    # Ghost users (deleted/inactive AAD accounts) cause a "could not be found" error
                    # on Person fields. Retry without Owners so the row is still written.
                    if ($_.Exception.Message -match "could not be found") {
                        Write-Warning "  [GHOST USER] $($item.SubsiteUrl) - could not resolve one or more owners ($($item.Owners)). Writing row without Owners field."
                        $listItemValuesNoOwners = $listItemValues.Clone()
                        $listItemValuesNoOwners.Remove("Owners")
                        Add-PnPListItem -List $ListName -Values $listItemValuesNoOwners -ErrorAction Stop | Out-Null
                    }
                    else {
                        throw
                    }
                }
                $written++
            }

            Write-Progress -Activity "Writing to SharePoint List" -Status "$written / $($Items.Count)" -PercentComplete (($written / $Items.Count) * 100)
        }

        Write-Progress -Activity "Writing to SharePoint List" -Completed
        Write-Host "  Successfully wrote $written items to list" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to write to SharePoint List: $($_.Exception.Message)"
        throw
    }
}

# Main execution
try {
    Write-Host "`n======================================================" -ForegroundColor Cyan
    Write-Host "SharePoint Storage Analysis - Proof of Concept" -ForegroundColor Cyan
    Write-Host "======================================================`n" -ForegroundColor Cyan

    # Capture run timestamp for historical tracking
    $script:RunDate = Get-Date

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
            $storageMap   = @{}  # url (trimmed) -> StorageGB
            $fileCountMap = @{}  # url (trimmed) -> FileCount
            $cappedMap    = @{}  # url (trimmed) -> $true if search cap was hit for this node or any descendant
            $metadataMap  = @{}  # url (trimmed) -> owners, lastActivity, title, webTemplate, created

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

                    # Storage and file count query only on leaf nodes
                    if ($isLeaf) {
                        $result              = Get-WebStorageUsage -WebUrl $subsite.Url
                        $storageMap[$url]    = $result.StorageGB
                        $fileCountMap[$url]  = $result.FileCount
                        $cappedMap[$url]     = $result.IsCapped
                    } else {
                        $storageMap[$url]    = $null   # filled in during rollup
                        $fileCountMap[$url]  = 0       # filled in during rollup
                        $cappedMap[$url]     = $false  # updated during rollup
                    }

                    # Get owners from the AssociatedOwnerGroup property (already loaded)
                    # Use Email instead of Title for SharePoint Person field resolution
                    $owners = "No owner group"
                    if ($subsite.AssociatedOwnerGroup) {
                        try {
                            $members = Get-PnPGroupMember -Group $subsite.AssociatedOwnerGroup -ErrorAction Stop
                            $ownerEmails = ($members | Where-Object { $_.PrincipalType -eq "User" } | Select-Object -ExpandProperty Email) -join "; "
                            $owners = if ($ownerEmails) { $ownerEmails } else { "No individual owners (group-only)" }
                        }
                        catch {
                            $owners = "Unable to retrieve"
                        }
                    }

                    $metadataMap[$url] = @{
                        Title        = $subsite.Title
                        Owners       = $owners
                        LastActivity = $subsite.LastItemModifiedDate
                        WebTemplate  = $subsite.WebTemplate
                        SiteCreated  = $subsite.Created
                        IsLeaf       = $isLeaf
                    }

                    $script:TotalSubsitesProcessed++
                }
                catch {
                    Write-Warning "    Error processing subsite $($subsite.Url): $($_.Exception.Message)"
                    $storageMap[$url]    = $null
                    $fileCountMap[$url]  = 0
                    $cappedMap[$url]     = $false
                    $metadataMap[$url] = @{
                        Title        = $subsite.Title
                        Owners       = "Error"
                        LastActivity = $null
                        WebTemplate  = $subsite.WebTemplate
                        SiteCreated  = $subsite.Created
                        IsLeaf       = $isLeaf
                    }
                    $script:Errors += [PSCustomObject]@{ Site = $subsite.Url; Error = $_.Exception.Message }
                }
            }
            Write-Progress -Activity "Processing subsites for $siteName" -Completed

            # --- Second pass: roll leaf storage, file count, and cap flag up to all parent nodes ---
            # Process deepest nodes first so each parent can read already-computed children.
            $subsitesByDepth = $subsites | Sort-Object -Property { $_.Url.TrimEnd('/').Split('/').Count } -Descending
            foreach ($sub in $subsitesByDepth) {
                $url = $sub.Url.TrimEnd('/')
                if (-not $metadataMap[$url].IsLeaf) {
                    $storageMap[$url]   = Get-RolledUpStorage   -Url $url -StorageMap $storageMap     -ChildrenMap $childrenMap
                    $fileCountMap[$url] = Get-RolledUpFileCount -Url $url -FileCountMap $fileCountMap -ChildrenMap $childrenMap
                    # Parent is flagged as capped if any immediate child is capped
                    # (children are already processed since we go deepest-first)
                    $cappedMap[$url]    = ($childrenMap[$url] | Where-Object { $cappedMap[$_] -eq $true }).Count -gt 0
                }
            }

            # --- Build the flat result list ---
            $subsiteData = foreach ($sub in $subsites) {
                $url = $sub.Url.TrimEnd('/')

                # Derive IsClassic from WebTemplate
                # Classic templates: STS#0 (team site), BLOG#0, WIKI#0, etc.
                # Modern templates: GROUP#0 (Office 365 group site), SITEPAGEPUBLISHING#0, STS#3 (modern team w/o group)
                $webTemplate = $metadataMap[$url].WebTemplate
                $isClassic = if ($webTemplate) {
                    $webTemplate -notmatch '^(GROUP|SITEPAGEPUBLISHING)#' -and $webTemplate -ne 'STS#3'
                } else {
                    $null  # Unknown if WebTemplate is missing
                }

                # Derive SubsiteDepth from URL segment count
                # e.g., /sites/Teams = depth 0 (root), /sites/Teams/Alliance = depth 1, etc.
                $subsiteDepth = ($url -split '/').Count - ($siteUrl.TrimEnd('/') -split '/').Count

                # Derive DirectChildCount from childrenMap
                $directChildCount = if ($childrenMap.ContainsKey($url)) {
                    $childrenMap[$url].Count
                } else {
                    0
                }

                [PSCustomObject]@{
                    # SharePoint List Column Types:
                    RunDate                 = $script:RunDate            # DateTime (indexed for historical filtering)
                    SiteCollectionName      = $siteName                  # Single line of text
                    SiteCollectionUrl       = $siteUrl                   # Hyperlink or Single line of text
                    SiteCollectionStorageGB = $siteStorageGB             # Number (with decimals)
                    SubsiteUrl              = $url                       # Hyperlink or Single line of text
                    SubsiteTitle            = $metadataMap[$url].Title   # Single line of text
                    SubsiteStorageGB        = $storageMap[$url]          # Number (with decimals)
                    FileCount               = $fileCountMap[$url]        # Number (no decimals)
                    IsLeafNode              = $metadataMap[$url].IsLeaf  # Yes/No (boolean)
                    IsStorageCapped         = $cappedMap[$url]           # Yes/No (boolean)
                    SubsiteDepth            = $subsiteDepth              # Number (no decimals)
                    DirectChildCount        = $directChildCount          # Number (no decimals)
                    WebTemplate             = $webTemplate               # Single line of text
                    IsClassic               = $isClassic                 # Yes/No (boolean) - can be null
                    SiteCreated             = $metadataMap[$url].SiteCreated # DateTime
                    LastActivity            = $metadataMap[$url].LastActivity  # DateTime
                    Owners                  = $metadataMap[$url].Owners  # Person or Group (allow multiple selections) - semicolon-separated emails
                }
            }

            # Sort by storage and take top percentage
            $topPercentCount = [math]::Ceiling(@($subsiteData).Count * ($TopSubsitesPercentage / 100))
            $topSubsites = $subsiteData | Sort-Object -Property SubsiteStorageGB -Descending | Select-Object -First $topPercentCount

            Write-Host "  Including top $topPercentCount subsites (top $TopSubsitesPercentage%)" -ForegroundColor Green

            # Add to results
            $results += $topSubsites

            # Incrementally write to SharePoint List (crash-safe)
            Write-ToSharePointList -Items $topSubsites -ListUrl $SharePointListUrl -ListName $ListName -RunDate $script:RunDate

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

    # Export results to CSV (commented out - using SharePoint List instead)
    # Uncomment this section if you need CSV export in addition to SharePoint List
    <#
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
    #>

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
