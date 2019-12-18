# refer https://blogs.msdn.microsoft.com/cloud_solution_architect/2015/05/05/creating-azure-vms-with-arm-powershell-cmdlets/

# Powershell Script to create VMs for az-rg-fta-bck.
# -- 5 VMs: azvmftabckdc, azvmftabckdpm, azvmftabckabs, azvmftabckapp1, azvmftabckapp2
# -- 5 NICs: nic01-azvmftabckdc, nic01-azvmftabckdpm, nic01-azvmftabckdpm, nic01-azvmftabckapp1, nic01-azvmftabckapp2
# -- 1 vnet: az-vnet-fta-bck, 10.20.0.0/16, 
# -- 1 NLB: az-lb-fta-bck
# -- 1 PIP: az-pip-fta-back
# -- 1 SA: azsaftabck, used for host all the vm disks and diagnostic log. 
Import-Module C:\kangxh\PowerShell\allenk-Module-Azure.psm1
Add-AzureRMAccount-Allenk -myAzureEnv microsoft

# variables: 
$admin = Read-Host -Prompt Username
$adminPWD = Read-Host -AsSecureString -Prompt Password
$vmCred = New-Object System.Management.Automation.PSCredential ($admin, $adminPWD)

$location = "southeastasia"
$osImage = ((Get-AzureRmVMImage -Location 'Southeast Asia' -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus "2016-Datacenter" ) | Sort-Object –Descending Version)[0]

$rgConfig = @{name = "az-rg-fta-bck"; location = $location}
$vnetConfig = @{name = "az-vnet-fta-bck"; ip = "10.20.0.0/16"; location = $location; subnet = "backup"; subnetprefix = "10.20.0.0/24"}
$pipConfig = @{name = "az-pip-fta-bck"; ip = "dynamic" ; location = $location ; dns = "az-pip-fta-bck"}
$lbConfig = @{name = "az-lb-fta-bck"; location = $location}
$saConfig = @{name = "azsaftabck"; location = $location; sku="Standard_LRS"}
$avsetConfig = @{name = "az-avset-fta-bck"; location = $location; }
$vmConfig = @(
            @{name="azvmftabckdc";   location = $location; nicName = "nic01-azvmftabckdc";   image = $osImage; size = "Standard_A2_v2"; ip = "10.20.0.4"; RDPNATPort = 64384; cred = $vmCred}; 
            @{name="azvmftabckdpm";  location = $location; nicName = "nic01-azvmftabckdpm";  image = $osImage; size = "Standard_A2_v2"; ip = "10.20.0.5"; RDPNATPort = 64385; cred = $vmCred};
            @{name="azvmftabckabs";  location = $location; nicName = "nic01-azvmftabckabs";  image = $osImage; size = "Standard_A2_v2"; ip = "10.20.0.6"; RDPNATPort = 64386; cred = $vmCred};
            @{name="azvmftabckapp1"; location = $location; nicName = "nic01-azvmftabckapp1"; image = $osImage; size = "Standard_A2_v2"; ip = "10.20.0.7"; RDPNATPort = 64387; cred = $vmCred};
            @{name="azvmftabckapp2"; location = $location; nicName = "nic01-azvmftabckapp2"; image = $osImage; size = "Standard_A2_v2"; ip = "10.20.0.8"; RDPNATPort = 64388; cred = $vmCred};
            @{name="azvmftabckhv1"; location = $location; nicName = "nic01-azvmftabckhv1"; image = $osImage; size = "Standard_D2_v3"; ip = "10.20.0.9"; RDPNATPort = 64389; cred = $vmCred};
            @{name="azvmftabckhv2"; location = $location; nicName = "nic01-azvmftabckhv2"; image = $osImage; size = "Standard_D2_v3"; ip = "10.20.0.10"; RDPNATPort = 64390; cred = $vmCred}
        )

# create resource group.
New-AzureRmResourceGroup -Name $rgConfig.name -Location $rgConfig.location -Force

# create vnet
$vnet = Get-AzureRmVirtualNetwork -Name $vnetConfig.name -ResourceGroupName $rgConfig.name -ErrorAction Ignore
if($vnet){
    $subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $vnetConfig.subnet -VirtualNetwork $vnet -ErrorAction Ignore
}
else{
    $subnet = New-AzureRmVirtualNetworkSubnetConfig -Name $vnetConfig.subnet -AddressPrefix $vnetConfig.subnetprefix
    $vnet = New-AzureRmVirtualNetwork -Name $vnetConfig.name -ResourceGroupName $rgConfig.name -Location $vnetConfig.location -AddressPrefix $vnetConfig.ip -Subnet $subnet
}

# create avset
$avset = Get-AzureRmAvailabilitySet -ResourceGroupName $rgConfig.name  -Name $avsetconfig.name -ErrorAction Ignore
if ($avset){}
else{
    $avset = New-AzureRmAvailabilitySet -ResourceGroupName $rgConfig.name  -Name $avsetconfig.name -Location $avsetconfig.location -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 5
}

# create pip
$pip = Get-AzureRmPublicIpAddress -ResourceGroupName $rgConfig.name -Name $pipConfig.name -ErrorAction Ignore
if ($pip) {}
else{
    $pip = New-AzureRmPublicIpAddress -ResourceGroupName $rgConfig.name -Name $pipConfig.name -Location $pipConfig.location -AllocationMethod Dynamic -DomainNameLabel $pipConfig.dns
}

# create nlb, if nlb has been created but still need to check NAT rules. 
$lb = Get-AzureRmLoadBalancer -ResourceGroupName $rgConfig.name -Name $lbConfig.name -ErrorAction Ignore
if ($lb) {
    $feIpConfig = Get-AzureRmLoadBalancerFrontendIpConfig -Name "$($lbConfig.name)-frontIP" -LoadBalancer $lb

    for ($i=0; $i -lt $vmConfig.Count; $i++){
        $lb| add-AzureRmLoadBalancerInboundNatRuleConfig -Name "RDP-$($vmConfig[$i].name)" -FrontendIpConfiguration $feIpConfig -Protocol TCP -FrontendPort $vmConfig[$i].RDPNATPort -BackendPort 3389 -ErrorAction Ignore
    }

    $lb| Add-AzureRmLoadBalancerBackendAddressPoolConfig -Name "$($lbConfig.name)-backendpool" -ErrorAction Ignore
    $lb| Add-AzureRmLoadBalancerProbeConfig -Name "$($lbConfig.name)-healthprobe" -Protocol tcp -Port 3389 -IntervalInSeconds 15 -ProbeCount 2 -ErrorAction Ignore

    $lb | Set-AzureRmLoadBalancer
}
else{
    $feIpConfig = New-AzureRmLoadBalancerFrontendIpConfig -Name "$($lbConfig.name)-frontIP" -PublicIpAddress $pip

    $inboundNATRules=@()
    for ($i=0; $i -lt $vmConfig.Count; $i++){
        $value = New-AzureRmLoadBalancerInboundNatRuleConfig -Name "RDP-$($vmConfig[$i].name)" -FrontendIpConfiguration $feIpConfig -Protocol TCP -FrontendPort $vmConfig[$i].RDPNATPort -BackendPort 3389
        $inboundNATRules += $value
    }

    $beAddressPool = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name "$($lbConfig.name)-backendpool"
    $healthProbe = New-AzureRmLoadBalancerProbeConfig -Name "$($lbConfig.name)-healthprobe" -Protocol tcp -Port 3389 -IntervalInSeconds 15 -ProbeCount 2

    $lb = New-AzureRmLoadBalancer -ResourceGroupName $rgconfig.name -Location $lbConfig.location -Name $lbConfig.name `
        -FrontendIpConfiguration $feIpConfig -InboundNatRule $inboundNATRules -BackendAddressPool $beAddressPool -Probe $healthProbe
}

# create nic
$nics=@()
for ($i=0; $i -lt $vmConfig.Count; $i++){

    $nic = Get-AzureRmNetworkInterface -ResourceGroupName $rgConfig.name -Name $vmConfig[$i].nicname -ErrorAction Ignore
    if ($nic) {
        $nics += $nic 
    }
    else{
        $nic = New-AzureRmNetworkInterface -ResourceGroupName $rgConfig.name -Name $vmConfig[$i].nicname -Location $vmconfig[$i].location -Subnet $subnet `
            -LoadBalancerInboundNatRule $lb.InboundNatRules[$i] -LoadBalancerBackendAddressPool $lb.BackendAddressPools[0] -PrivateIpAddress $vmConfig[$i].ip 
        $nics += $nic 
    }
}

# create storage account: 
$sa = Get-AzureRmStorageAccount -ResourceGroupName $rgConfig.name -Name $saConfig.name -ErrorAction Ignore
if ($sa) {}
else{
    $sa = New-AzureRmStorageAccount -ResourceGroupName $rgConfig.name -Name $saConfig.name -Location $saConfig.location -Type $saConfig.sku
}

# create vm using windows image
for ($i=0; $i -lt $vmConfig.Count; $i++){

    $vm = Get-AzureRmVM -ResourceGroupName $rgConfig.name -Name $vmConfig[$i].name -ErrorAction Ignore
    if ($vm -eq $null){

        $vm = New-AzureRmVMConfig -VMName $vmConfig[$i].name -VMSize $vmConfig[$i].size -AvailabilitySetId $avset.id |
            Set-AzureRmVMOperatingSystem -Windows -ComputerName $vmConfig[$i].name -Credential $vmConfig[$i].cred -ProvisionVMAgent -EnableAutoUpdate  |
            Set-AzureRmVMSourceImage -PublisherName  $vmConfig[$i].image.PublisherName -Offer  $vmConfig[$i].image.offer -Skus  $vmConfig[$i].image.skus -Version  $vmConfig[$i].image.version | 
            Set-AzureRmVMOSDisk -Name "$($vmConfig[$i].name)-OSDisk" -VhdUri "https://$($saConfig.name).blob.core.windows.net/vhds/$($vmConfig[$i].name)-OSDisk.vhd" -Caching ReadOnly -CreateOption fromImage  | 
            Add-AzureRmVMNetworkInterface -Id $nics[$i].Id
    
        New-AzureRmVM -ResourceGroupName $rgConfig.name -Location $vmConfig[$i].Location -VM $vm -AsJob
    }
}

Get-Job | Wait-Job