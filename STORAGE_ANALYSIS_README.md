# SharePoint Storage Analysis - PoC Guide

## Overview
This script analyzes SharePoint storage usage by processing top sites from a SharePoint Admin Center export and identifying the largest subsites within each.

## Prerequisites

1. **Required PowerShell Modules:**
   ```powershell
   Install-Module PnP.PowerShell -Scope CurrentUser
   Install-Module ImportExcel -Scope CurrentUser  # Optional but recommended for faster Excel reading
   ```

2. **Permissions:**
   - SharePoint Admin or Site Collection Admin access to the sites you want to analyze

3. **Input File:**
   - Excel export (.xlsx) from SharePoint Admin Center with columns:
     - Site name
     - URL
     - Storage used (GB)
     - Last activity

## Usage

### Phase 1: Proof of Concept (Test with 2-3 sites)

```powershell
.\Get-SharePointStorageAnalysis-PoC.ps1 -ExcelFilePath "C:\path\to\SharePointSites.xlsx" -TopSitesCount 3
```

This will:
- Process the top 3 sites from your Excel
- Analyze all subsites in each
- Export top 20% of subsites by storage to CSV
- Output: `SharePoint_Storage_Analysis.csv`

### Phase 2: Production Run (Top 90 sites)

Once you've validated the PoC works correctly:

```powershell
.\Get-SharePointStorageAnalysis-PoC.ps1 -ExcelFilePath "C:\path\to\SharePointSites.xlsx" -TopSitesCount 90 -TopSubsitesPercentage 20 -OutputCsvPath "C:\Reports\Storage_Analysis_Full.csv"
```

## Output Format

The CSV will contain:

| Column | Description |
|--------|-------------|
| SiteCollectionName | Parent site collection name |
| SiteCollectionUrl | Parent site collection URL |
| SiteCollectionStorageGB | Total storage of parent site collection |
| SubsiteUrl | URL of the subsite |
| SubsiteTitle | Title of the subsite |
| SubsiteStorageGB | Storage used by this subsite |
| Owners | Site owners (semicolon-separated) |
| LastActivity | Last modified date |

## Important Notes

### Performance Expectations

- **PoC (3 sites):** ~5-15 minutes depending on subsite count
- **Full run (90 sites):** Could take several hours
  - If each site has 100 subsites, that's 9,000 subsites to analyze
  - Recommend running overnight or during off-hours

### Storage Calculation

The script calculates subsite storage by summing the `DiskUsage` property of all lists and libraries within the subsite. This is an approximation and may not match exactly with SharePoint Admin Center's site collection totals due to:
- System files and hidden lists
- Version history
- Recycle bin items

### Authentication

The script uses `-Interactive` authentication, which will:
- Open a browser window for you to sign in
- Prompt once per site collection
- May prompt multiple times during the run

For unattended runs, you could modify to use certificate-based auth or app credentials.

### Error Handling

- Errors are logged but won't stop the script
- A summary of errors is displayed at the end
- Common errors:
  - Access denied: You lack permissions to a site/subsite
  - Timeout: Site is very large or slow to respond
  - Connection issues: Network problems

## Next Steps

After validating the PoC:

1. **Import to SharePoint List** (for Power BI auto-refresh)
2. **Add Power BI Dashboard** connected to the SharePoint List
3. **Schedule regular runs** (monthly/quarterly) to track storage trends

## Troubleshooting

**ImportExcel module not installed:**
- Script will fall back to COM objects (slower but works)
- Install module for better performance: `Install-Module ImportExcel -Scope CurrentUser`

**Script takes too long:**
- Reduce `TopSitesCount` to process fewer sites
- Increase `TopSubsitesPercentage` to capture fewer subsites per site
- Consider adding parallel processing (future enhancement)

**Authentication keeps prompting:**
- This is normal for multi-site processing
- For production, consider app-only authentication with certificates

## Support

For issues or questions, contact your SharePoint administrator.
