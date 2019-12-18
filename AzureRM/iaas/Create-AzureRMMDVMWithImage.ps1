cd C:\kangxh\github\azure-powershell

Import-Module .\module\allenk-Module-Azure.psm1
Import-Module .\module\allenk-Module-Common.psm1

Add-AzureRMAccount-Allenk -myAzureEnv microsoft

# Parameters

    $location = "southeastasia"
    
    # use name conversion rules to build resource name
    $nameConversion = @{project = "kangxh"; region = "sea"; svc="local"}
    $tags = @{"BillTo" = "kangxh"; "ManagedBy" = "allenk@microsoft.com"; "Environment" = "Prod"}

    # formated resource name:
    $newRGName = "az-rg-kangxh-oss"
    $newVMName = "kangxhvmseaoss"
    $newVMIP = " 192.168.5.10"
    $vmCount = 1
    $newAvsetName = "kangxhavsetseaoss"
    $newNLBName = "kangxhnlbseaoss"
    $newSAName = "kangxhsaseaossdiag"
    $newPipName = "kangxhpipseaoss"
    
    # Shared Resource. Create in core resource group if not created already
    $sharedRGName = "az-rg-kangxh-core"
    $sharedVNetName = "kangxhvnetsea"
    $sharedVNetIP = "192.168.0.0/16"
    $sharedVNetSubnet = "oss"
    $sharedVNetSubnetIP = "192.168.5.0/24"
    $sharedKvName = "kangxhkvsea"
    $sharedSecretName = "password-vm"

    $sharedImageName = "kangxhimageseacentos" # change this value to Windows if we will use the Windows image

    $adminUsername = "allenk" # Read-Host -Prompt Username


# Environment setup
    
    # shared resources
    $vnetCfg  = @{name = $sharedVNetName;  resourcegroup = $sharedRGName;  location = $location; ip = $sharedVNetIP; subnet = $sharedVNetSubnet; subnetprefix = $sharedVNetSubnetIP}
    
    if ($sharedImageName -eq "Windows"){
        $imageCfg = @{customed=$false; location = $location; publisher = "MicrosoftWindowsServer"; offer = "WindowsServer"; sku = "2016-Datacenter"; os = "Windows" }
        $image = (Get-AzureRmVMImage -Location $imageCfg.location -PublisherName $imageCfg.publisher -Offer $imageCfg.offer -Skus $imageCfg.sku | Sort-Object -Descending -Property Version)[0]
    }
    else{
        $imageCfg = @{customed=$true; name = $sharedImageName; resourcegroup = $sharedRGName;  location = $location; os = "Linux"}
        $image = Get-AzureRmImage -ResourceGroupName $imageCfg.resourcegroup -ImageName $imageCfg.name
    }
  
    $kvCfg =    @{name = $sharedKvName;    resourcegroup = $sharedRGName;  location = $location; secret = $sharedSecretName}
    $Password = Get-AzureKeyVaultSecret -VaultName $kvCfg.name -Name $kvcfg.secret
    $cred = New-Object PSCredential $adminUsername, $Password.SecretValue

# customize parameters to structured data

    # new resources
    $rgCfg =    @{name = $newRGName; location = $location}

    $saCfg =    @{name = $newSAName; resourcegroup = $rgCfg.name; location = $location; sku="Standard_LRS"}
    $avsetCfg = @{name = $newAvsetName;    resourcegroup = $rgCfg.name; location = $location}
    $nlbCfg =   @{name = $newNLBName;      resourcegroup = $rgCfg.name; location = $location}
    $pipCfg   = @{name = $newPipName;      resourcegroup = $rgCfg.name; location = $location; dns = $newPipName; allocation= "dynamic"}

    $vmCfg= @(New-AllenkVMGroupArray -count $vmCount -name $newVMName -resourcegroup $rgCfg.name -location $location -os $imageCfg.os -ip $newVMIP -cred $cred )

# Provisioning

# create resource group.
    $rg = Get-AzureRmResourceGroup -Name $rgCfg.name -Location $rgCfg.location -ErrorAction Ignore
    if($null -eq $rg){
        $rg = New-AzureRmResourceGroup -Name $rgCfg.name -Location $rgCfg.location -Tag $tags
    }

    # create storage account: 
    $sa = Get-AzureRmStorageAccount -ResourceGroupName $saCfg.resourcegroup -Name $saCfg.name -ErrorAction Ignore
    if ($null -eq $sa){
        $sa = New-AzureRmStorageAccount -ResourceGroupName $saCfg.resourcegroup -Name $saCfg.name -Location $saCfg.location -Type $saCfg.sku
    }

# create vnet
    $vnet = Get-AzureRmVirtualNetwork -Name $vnetCfg.name -ResourceGroupName $vnetCfg.resourcegroup -ErrorAction Ignore
    if ($null -eq $vnet){
        $vnet = New-AzureRmVirtualNetwork -Name $vnetCfg.name -ResourceGroupName $vnetCfg.resourcegroup -Location $vnetCfg.location -AddressPrefix $vnetCfg.ip -Subnet $subnet
    }

    $subnet = Get-AzureRmVirtualNetworkSubnetConfig  -Name $vnetCfg.subnet -VirtualNetwork $vnet -ErrorAction Ignore
    if ($null -eq $subnet){
        Add-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $vnetCfg.subnet -AddressPrefix $vnetCfg.subnetprefix
        $vnet = Set-AzureRmVirtualNetwork -VirtualNetwork $vnet
        $subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $vnetCfg.subnet -VirtualNetwork $vnet
    }

# create avset
    $avset = Get-AzureRmAvailabilitySet -ResourceGroupName $avsetCfg.resourcegroup  -Name $avsetCfg.name -ErrorAction Ignore
    if ($null -eq $avset){
        $avset = New-AzureRmAvailabilitySet -ResourceGroupName $avsetCfg.resourcegroup  -Name $avsetCfg.name -Location $avsetCfg.location -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 5 -Sku Aligned
    }

# create pip
    $pip = Get-AzureRmPublicIpAddress -ResourceGroupName $pipCfg.resourcegroup -Name $pipCfg.name -ErrorAction Ignore
    if ($null -eq $pip) {
        $pip = New-AzureRmPublicIpAddress -ResourceGroupName $pipCfg.resourcegroup -Name $pipCfg.name -Location $pipCfg.location -AllocationMethod $pipCfg.allocation -DomainNameLabel $pipCfg.dns
    }

# create nlb and inboundnat rules. if nlb is there already, add inbound rules when creating nic
    $nlb = Get-AzureRmLoadBalancer -ResourceGroupName $nlbCfg.resourcegroup -Name $nlbCfg.name -ErrorAction Ignore
    if ($null -eq $nlb) {
        $feIpConfig = New-AzureRmLoadBalancerFrontendIpConfig -Name "frontendIP-$($pipCfg.name)" -PublicIpAddress $pip

        $inboundNATRules=@()
        for ($i=0; $i -lt $vmCfg.Count; $i++){
           $natrule = New-AzureRmLoadBalancerInboundNatRuleConfig -Name $vmCfg[$i].natrule -FrontendIpConfiguration $feIpConfig -Protocol TCP -FrontendPort $vmCfg[$i].frontendport -BackendPort $vmCfg[$i].backendport
           $inboundNATRules += $natrule
        }

        $beAddressPool = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name "backendPool-$($avsetCfg.name)"
    
        if ($vmCfg[0].os -eq "Linux"){
            $healthProbe = New-AzureRmLoadBalancerProbeConfig -Name "healthProbe-$($avsetCfg.name)" -Protocol tcp -Port 22 -IntervalInSeconds 15 -ProbeCount 2
        }
        else{
            $healthProbe = New-AzureRmLoadBalancerProbeConfig -Name "healthProbe-$($avsetCfg.name)" -Protocol tcp -Port 3389 -IntervalInSeconds 15 -ProbeCount 2
        }

        $nlb = New-AzureRmLoadBalancer -ResourceGroupName $nlbCfg.resourcegroup -Location $nlbCfg.location -Name $nlbCfg.name `
            -FrontendIpConfiguration $feIpConfig -InboundNatRule $inboundNATRules -BackendAddressPool $beAddressPool -Probe $healthProbe
    }

# create nic and inbound nat rules.
    $nics=@()
    for ($i=0; $i -lt $vmCfg.Count; $i++){

        $nic = Get-AzureRmNetworkInterface -ResourceGroupName $vmCfg[$i].resourcegroup -Name $vmCfg[$i].nicname -ErrorAction Ignore
        if ($nic) {
            $nics += $nic 
        }
        else{
            $newInboundNatRule = add-AzureRmLoadBalancerInboundNatRuleConfig -LoadBalancer $nlb -Name $vmCfg[$i].natrule -FrontendIpConfiguration $nlb.FrontendIpConfigurations[0] -Protocol TCP -FrontendPort $vmCfg[$i].frontendport -BackendPort $vmCfg[$i].backendport
            Set-AzureRmLoadBalancer -LoadBalancer $nlb

            $nic = New-AzureRmNetworkInterface -ResourceGroupName $vmCfg[$i].resourcegroup -Name $vmCfg[$i].nicname -Location $vmCfg[$i].location -Subnet $subnet `
                -LoadBalancerInboundNatRule $nlb.InboundNatRules[-1] -LoadBalancerBackendAddressPool $nlb.BackendAddressPools[0] -PrivateIpAddress $vmCfg[$i].ip 
            $nics += $nic 
        }
    }

# create vm using windows image
if ($imageCfg.customed -eq $true) {
    for ($i=0; $i -lt $vmCfg.Count; $i++){
        $vm  = New-AzureRMVMConfig -VMName $vmCfg[$i].name -VMSize $vmCfg[$i].size -AvailabilitySetID $avset.Id
        if ($vmCfg[$i].os -eq "Linux"){
            $vm = Set-AzureRmVMOperatingSystem -VM $vm -Credential $cred -ComputerName $vmCfg[$i].name -Linux
        }
        else{
            $vm = Set-AzureRmVMOperatingSystem -VM $vm -Credential $cred -ComputerName $vmCfg[$i].name -Windows
        }
        $vm  = Add-AzureRMVMNetworkInterface -VM $vm -Id $nics[$i].Id
        $vm = Set-AzureRmVMSourceImage -VM $vm -Id $Image.id
        $vm = Set-AzureRmVMBootDiagnostics -VM $vm -Enable -ResourceGroupName $vmCfg[$i].resourcegroup -StorageAccountName $sa.StorageAccountName

        New-AzureRMVM -ResourceGroupName $vmCfg[$i].resourcegroup -Location $vmCfg[$i].location -VM $vm -AsJob -ErrorAction Ignore
    }
}
else {
    for ($i=0; $i -lt $vmCfg.Count; $i++){
        $vm  = New-AzureRMVMConfig -VMName $vmCfg[$i].name -VMSize $vmCfg[$i].size -AvailabilitySetID $avset.Id
        if ($vmCfg[$i].os -eq "Linux"){
            $vm = Set-AzureRmVMOperatingSystem -VM $vm -Credential $cred -ComputerName $vmCfg[$i].name -Linux
        }
        else{
            $vm = Set-AzureRmVMOperatingSystem -VM $vm -Credential $cred -ComputerName $vmCfg[$i].name -Windows -ProvisionVMAgent -EnableAutoUpdate
        }
        $vm = Add-AzureRMVMNetworkInterface -VM $vm -Id $nics[$i].Id
        $vm = Set-AzureRmVMSourceImage -VM $vm -PublisherName $imageCfg.publisher -Offer $imageCfg.offer -Skus $imageCfg.sku -Version latest
        $vm = Set-AzureRmVMBootDiagnostics -VM $vm -Enable -ResourceGroupName $vmCfg[$i].resourcegroup -StorageAccountName $sa.StorageAccountName

        New-AzureRMVM -ResourceGroupName $vmCfg[$i].resourcegroup -Location $vmCfg[$i].location -VM $vm -AsJob -ErrorAction Ignore
    }
}
