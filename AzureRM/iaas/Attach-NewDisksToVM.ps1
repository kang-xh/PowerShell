# create new disks and attach to a VM.
# it is like DSC work mode. if a disk already attached to VM, it will be counted
# managed disk https://docs.microsoft.com/en-us/azure/virtual-machines/windows/attach-disk-ps
# unmanaged disk 
import-module C:\kangxh\PowerShell\allenk-Module-Azure.psm1
Add-AzureRMAccount-Allenk -myAzureEnv microsoft

$rgName = 'az-rg-fta-bck'; $vmName = 'azvmftabckdpm'; $location = 'southeastasia' 
$storageType = 'StandardLRS'; $dataDiskSize = 128; $dataDiskNum = 2

#check current VM storage status, if it is managed disk, add managed disks, otherwize, add blob disks.
$vm = Get-AzureRmVM -ResourceGroupName $rgName -Name $vmName
if ($vm.StorageProfile.OsDisk.ManagedDisk -eq $null){
    "unmanaged"
    for ($i = $vm.StorageProfile.DataDisks.count; $i -lt $dataDiskNum; $i++){
        $DataDiskVhdUri = $vm.StorageProfile.OsDisk.vhd.Uri.replace($vm.StorageProfile.OsDisk.Name, "$vmName-DataDisk-$i")
        Add-AzureRmVMDataDisk -VM $vm -Name "$vmName-DataDisk-$i" -Caching 'ReadOnly' -DiskSizeInGB $dataDiskSize -Lun $i -VhdUri $DataDiskVhdUri -CreateOption Empty
    }
    Update-AzureRmVM -VM $vm -ResourceGroupName $rgName
}
else {
    "managed"
    for ($i = $vm.StorageProfile.DataDisks.count; $i -lt $dataDiskNum; $i++){
        $diskConfig = New-AzureRmDiskConfig -SkuName  $storageType -Location $location -CreateOption Empty -DiskSizeGB $dataDiskSize
        $dataDisk1 = New-AzureRmDisk -DiskName "$vmName-DataDisk-$i" -Disk $diskConfig -ResourceGroupName $rgName
        
        $vm = Get-AzureRmVM -Name $vmName -ResourceGroupName $rgName 
        $vm = Add-AzureRmVMDataDisk -VM $vm -Name "$vmName-DataDisk-$i" -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun $i
    }
    Update-AzureRmVM -VM $vm -ResourceGroupName $rgName
}
