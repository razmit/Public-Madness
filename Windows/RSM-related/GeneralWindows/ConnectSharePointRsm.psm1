function Connect-SharePointRsm {
    
    $orgName="RSM US LLP"
    
    Connect-SPOService -Url https://rsmnet-admin.sharepoint.com
    
    return $orgName 
}