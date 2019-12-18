Remove-AzureRmAccount 

install-module azuread
install-module msonline

# get credential using onmicrosoft.com tenant, like kangxh.onmicrosoft.com
$AzureAdCred = Get-Credential
Connect-AzureAD -Credential $AzureAdCred

connect-msolService -Credential $AzureAdCred

# Disable AAD connect 
Set-MsolDirSyncEnabled –EnableDirSync $false

# remove legacy user account for AAD sync.
Remove-AzureADUser -ObjectId a55fa6fa-2380-4425-970b-522e580aa75b