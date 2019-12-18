# the script is to move a VM in one China Region to a new Region for VM using standard storage

Import-Module C:\kangxh\PowerShell\allenk-Module-Azure.psm1
Add-AzureRMAccount-Allenk -myAzureEnv mooncake

$sVM = "mcvmftamd1"

$sResourceGroupName = "mc-rg-fta-md"
$dResourceGroupName = "mc-rg-fta-md-CN2"

$dLocation = "China North 2"

$sStorageAccount = "mcsaftamd871"
$sStorageAccountDiag = ""
$dStorageAccount = "mcsavmnewregion"
$dStorageAccountDiag = "mcsavmnewregiondiag"

New-AzureRmResourceGroup -name $dResourceGroupName -Location $dLocation -Force

$sVMConfig = Get-AzureRmVM -ResourceGroupName $sResourceGroupName -Name $sVM


# Step 1: Recreate VM on the Target Location. For DEMO purpose, we skipped the process to create NSG and UDR. 

foreach ($nic in $sVMConfig.NetworkProfile.NetworkInterfaces){

    $sNicConfig = Get-AzureRmResource -ResourceId $nic.id
    if ($sNicConfig.Properties.ipConfigurations[0].properties.primary -eq $True){

        $sNic = $nic

        $sVNETName = $dVNETName = ($sNicConfig.Properties.ipConfigurations[0].properties.subnet.id.Split('/'))[8]
        $sVNETRGName = ($sNicConfig.Properties.ipConfigurations[0].properties.subnet.id.Split('/'))[4]
        $sSubnetName = $dSubnetName = ($sNicConfig.Properties.ipConfigurations[0].properties.subnet.id.Split('/'))[10]

        $sVNET = Get-AzureRmVirtualNetwork -ResourceGroupName $sVNETRGName -Name $sVNETName

        
        $dVNET = Get-AzureRmVirtualNetwork -ResourceGroupName $dResourceGroupName -Name $dVNETName -ErrorAction Ignore
        if ($dVNET -eq $null) {
            $dVNET = New-AzureRmVirtualNetwork -ResourceGroupName $dResourceGroupName -Name $dVNETName -Location $dLocation -AddressPrefix $sVNET.AddressSpace.AddressPrefixes -DnsServer $sVNET.DhcpOptions.DnsServers
            foreach ($subnet in $sVNET.Subnets){
                        Add-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $dVNET -Name $subnet.Name -AddressPrefix $subnet.AddressPrefix
            }
            Set-AzureRmVirtualNetwork -VirtualNetwork $dVNET 
        }
    }
}

# Step 2: Create AvailabilitySet
if ($sVMConfig.AvailabilitySetReference -ne $null){
    $sAvSetName = $sVMConfig.AvailabilitySetReference.Id.Split('/')[8]
    $sAvSetRGName = $sVMConfig.AvailabilitySetReference.Id.Split('/')[4]
    $sAvSet = Get-AzureRmAvailabilitySet -ResourceGroupName $sAvSetRGName -Name $sAvSetName

    $dAvSet = Get-AzureRmAvailabilitySet -ResourceGroupName $dResourceGroupName -Name $sAvSetName -ErrorAction Ignore
    if ($dAvSet -eq $null){
        if ($sAvSet.Managed){
            $dAvSet = New-AzureRmAvailabilitySet -ResourceGroupName $dResourceGroupName -Name $sAvSetName -Location $dLocation -Managed -Sku $sAvSet.Sku -PlatformFaultDomainCount $sAvSet.PlatformFaultDomainCount -PlatformUpdateDomainCount $sAvSet.PlatformUpdateDomainCount
        }else{
            $dAvSet = New-AzureRmAvailabilitySet -ResourceGroupName $dResourceGroupName -Name $sAvSetName -Location $dLocation          -Sku $sAvSet.Sku -PlatformFaultDomainCount $sAvSet.PlatformFaultDomainCount -PlatformUpdateDomainCount $sAvSet.PlatformUpdateDomainCount
        }
    }
}


# Step 3: Create NLB
$sNicConfig = Get-AzureRmResource -ResourceId $sNic.id
$sLBBackendAddressPoolsID = $sNicconfig.Properties.ipConfigurations[0].properties.loadBalancerBackendAddressPools[0].id

if ($sLBBackendAddressPoolsID -ne $null){

    $sLBRGName = $sLBBackendAddressPoolsID.Split('/')[4]
    $sLBName =$dLBName = $sLBBackendAddressPoolsID.Split('/')[8]
    $sLB = Get-AzureRmLoadBalancer -Name $sLBName -ResourceGroupName $sLBRGName

    $sPIPid = $sLB.FrontendIpConfigurations[0].PublicIpAddress.Id
    if ($sPIPid -ne $null){
        
        $sPipRGName = $sPipid.Split('/')[4]
        $sPipName = $dPipName = $sPipid.Split('/')[8]
        $sPip = Get-AzureRmPublicIpAddress -ResourceGroupName $sPipRGName -Name $sPipName
        
        $dPip = Get-AzureRmPublicIpAddress -ResourceGroupName $dResourceGroupName -Name $sPipName -ErrorAction Ignore
        if ($dPip) {
        }
        else{
            $dPip = New-AzureRmPublicIpAddress -ResourceGroupName $dResourceGroupName -Name $dPipName -Location $dLocation -AllocationMethod Dynamic -DomainNameLabel $sPIP.DnsSettings.DomainNameLabel
        }
    }

    $dNLB = Get-AzureRmLoadBalancer -Name $dLBName -ResourceGroupName $dResourceGroupName -ErrorAction Ignore
    if ($dNLB -eq $null){

        $feIpConfig = New-AzureRmLoadBalancerFrontendIpConfig -Name "$sLBName-frontIP" -PublicIpAddress $dPip
        $dNLB = New-AzureRmLoadBalancer -Name $dLBName -ResourceGroupName $dResourceGroupName -Location $dLocation -Sku $sLB.Sku.Name -FrontendIpConfiguration $feIpConfig
    }
}

# Step 4: Create Storage Account for VHD and Diagnostic
# $dStorage = New-AzureRmStorageAccount -ResourceGroupName $dResourceGroupName -Name $dStorageAccount -SkuName Standard_LRS -Location $dLocation 
# $dStorageDiag = New-AzureRmStorageAccount -ResourceGroupName $dResourceGroupName -Name $dStorageAccountDiag -SkuName Standard_LRS  -Location $dLocation

$dStorage = Get-AzureRmStorageAccount -ResourceGroupName $dResourceGroupName -Name $dStorageAccount 
$dStorageDiag = Get-AzureRmStorageAccount -ResourceGroupName $dResourceGroupName -Name $dStorageAccountDiag 

# the copy process can be done using powershell, like https://chinnychukwudozie.com/2016/10/27/copying-an-azure-cloud-blob-vhd-between-different-storage-accounts-and-resource-groups-with-arm-powershell/
# actually, prefer to do it manually using Storage Explorer or AzCopy.

# Step 5: Create VM.

$dSubnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $dVNET -Name $dSubnetName

$dNic = Get-AzureRmNetworkInterface -ResourceGroupName $dResourceGroupName -Name "NIC1-$sVM" -ErrorAction Ignore
if ($dNic -eq $null){
    $dNic = New-AzureRmNetworkInterface -ResourceGroupName $dResourceGroupName -Name "NIC1-$sVM" -Location $dLocation -SubnetID "$($dVNET.Id)/subnets/$($dSubnet.Name)"
}


$dOSDiskUri = $sVMConfig.StorageProfile.OsDisk.Vhd.uri.Replace($sStorageAccount, $dStorage.StorageAccountName)
$vm = New-AzureRmVMConfig -VMName $sVM -VMSize $sVMConfig.HardwareProfile.VmSize -AvailabilitySetId $dAvSet.id
Set-AzureRmVMOSDisk -vm $vm -Name "mcvmftamd1-OSDisk" -VhdUri $dOSDiskUri -Caching ReadOnly -CreateOption attach -Windows 
Add-AzureRmVMNetworkInterface -vm $vm -Id $dNic.Id

Foreach($dataDiskConfig in $sVMConfig.StorageProfile.DataDisks){

    $dOSDiskUri = $dataDiskConfig.Vhd.Uri.Replace($sStorageAccount, $dStorage.StorageAccountName)
    Add-AzureRmVMDataDisk -VM $vm -Name $dataDiskConfig.Name -Lun $dataDiskConfig.lun -CreateOption Attach -VhdUri $dOSDiskUri

}

New-AzureRmVM -ResourceGroupName $dResourceGroupName -Location $dLocation -VM $vm -AsJob


Get-Job | Wait-Job
