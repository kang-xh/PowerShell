
Add-AzureRMAccount-Allenk -myAzureEnv microsoft
$contextEnv = Get-AzureRmContext

# Naming Conversion
# ProjectName:   kangxh
# Resource Type: vnet; avset; nlb; pip; image; kv; sa
# region: sea
# usage: 
# tag: BillTo = fta; ManagedBy = allenk@microsoft.com; Environment = Demo


# Environment setup
    $subscriptionID = $contextEnv.Subscription.SubscriptionId
    $location = "southeastasia"
    $tags = @{"BillTo" = "kangxh"; "ManagedBy" = "allenk@microsoft.com"; "Environment" = "Kangxh"}


# Parameters

$snapshotSource    = @{name = "snap"; resourcegroup = "az-rg-kangxh-win"}
$managedDisk = @{name = "kangxhvmseavs-os"; resourcegroup = "az-rg-kangxh-win"; location = $location}


$snapshot = Get-AzureRmSnapshot -ResourceGroupName $snapshotSource.resourcegroup -SnapshotName $snapshotSource.name
 
$diskConfig = New-AzureRmDiskConfig -Location $managedDisk.Location -SourceResourceId $snapshot.Id -CreateOption Copy
$disk = New-AzureRmDisk -Disk $diskConfig -ResourceGroupName $managedDisk.resourcegroup -DiskName $managedDisk.name
