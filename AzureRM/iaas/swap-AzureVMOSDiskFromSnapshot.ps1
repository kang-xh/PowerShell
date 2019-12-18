cd C:\kangxh\Github\azure-powershell\iaas

Import-Module ..\module\allenk-Module-Azure.psm1
Remove-AzureRmAccount 

Add-AzureRMAccount-Allenk -myAzureEnv mooncake
$contextEnv = Get-AzureRmContext

$day = (date).DayOfYear

$ssConfig = @{name = "sgsvm-sql-$day-snap";     resourcegroup = "fta-rg-ce2-sgs"; location = "China East 2"; sku = "Premium_LRS"}
$vmconfig = @{name = "sgsvmsql"; resourcegroup = "fta-rg-ce2-sgs"; location = "China East 2"}
$mdConfig = @{name = "sgsvm-sql-$day-os"; resourcegroup = "fta-rg-ce2-sgs"; location = "China East 2"}


# preparation

$vm =  Get-AzureRmVM -ResourceGroupName $vmconfig.resourcegroup -Name $vmconfig.name

$osDisk = Get-AzureRmDisk -ResourceGroupName $vmconfig.resourcegroup -DiskName $vm.StorageProfile.OsDisk.Name

$ss = Get-AzureRmSnapshot -ResourceGroupName $ssConfig.resourcegroup -SnapshotName $ssConfig.name -ErrorAction Ignore
if ($null -eq $ss)
{
    $snapshotConfig = New-AzureRmSnapshotConfig -SkuName $ssConfig.sku -SourceResourceId $osDisk.Id -Location $ssConfig.location -CreateOption Copy
    $ss = New-AzureRmSnapshot -ResourceGroupName $ssConfig.resourcegroup -SnapshotName $ssConfig.name -Snapshot $snapshotConfig 
}

$diskConfig = New-AzureRmDiskConfig -Location $mdConfig.Location -SourceResourceId $ss.Id -CreateOption Copy
$disk = New-AzureRmDisk -Disk $diskConfig -ResourceGroupName $mdConfig.resourcegroup -DiskName $mdConfig.name

Set-AzureRmVMOSDisk -VM $vm -ManagedDiskId $disk.Id -Name $disk.Name 
Update-AzureRmVM -ResourceGroupName $vmconfig.resourcegroup -VM $vm

