# VPN GW is the only connection way between China Azure and Global due to sepereate Subscription and AAD
#  Network Peering and vNet-vNet connection not work in such scenario.
# the script create VPN GW on both side and create connection.

Import-Module C:\kangxh\PowerShell\allenk-Module-Azure.psm1

$mcEnv=@{rg="mc-rg-fta-core"; location = "chinanorth";    vnet="mc-vnet-fta"; gateway="mc-vpn-fta"; pip="mc-pip-fta-vpngw"; localgateway = "mc-vpn-fta-localgw"; localgatewayconnection="mc-vpn-fta-localgw-connection"}
$azEnv=@{rg="az-rg-fta-core"; location = "southeastasia"; vnet="az-vnet-fta"; gateway="az-vpn-fta"; pip="az-pip-fta-vpngw"; localgateway = "az-vpn-fta-localgw"; localgatewayconnection="az-vpn-fta-localgw-connection"}
$SharedKey = 'AzureA1b2C3'
#login to mooncake to create gateway
Add-AzureRMAccount-Allenk -myAzureEnv mooncake

$mcGateway = Get-AzureRmVirtualNetworkGateway -Name $mcEnv.gateway -ResourceGroupName $mcEnv.rg -ErrorAction Ignore
if ($mcGateway -eq $null){
    $mcVNET = Get-AzureRmVirtualNetwork -Name $mcEnv.vnet -ResourceGroupName $mcEnv.rg

    # Create PIP if it does not exist:
    $mcPip = Get-AzureRmPublicIpAddress -Name $mcEnv.pip -ResourceGroupName $mcEnv.rg -ErrorAction Ignore
    if ($mcPip -eq $null)    {
        $mcPip  = New-AzureRmPublicIpAddress -Name $mcEnv.pip -ResourceGroupName $mcEnv.rg -Location $mcEnv.location -AllocationMethod Dynamic
    }

    # Create Gateway subnet if it has not been created.
    $mcGatewaySubnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $mcVNET -Name "GatewaySubnet" -ErrorAction Ignore
    if ($mcGatewaySubnet -eq $null){
        Add-AzureRmVirtualNetworkSubnetConfig -Name "GatewaySubnet" -AddressPrefix $MCGWSubnetPrefix -VirtualNetwork $mcVNet | Set-AzureRmVirtualNetwork
    }

    # Create Gateway using the vNet and PIP created before
    $mcGatewaySubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $mcVNET
    $mcGatewayIpConfig = New-AzureRmVirtualNetworkGatewayIpConfig -Name "GatewayIpConfig" -Subnet $mcGatewaySubnet -PublicIpAddress $mcPip
    $mcGateway = New-AzureRmVirtualNetworkGateway -Name $mcEnv.gateway -ResourceGroupName $mcEnv.rg -Location $mcenv.location -IpConfigurations $mcGatewayIpConfig -GatewayType Vpn -VpnType RouteBased -GatewaySku Basic -AsJob
}else{
    $mcVNET = Get-AzureRmVirtualNetwork -Name $mcEnv.vnet -ResourceGroupName $mcEnv.rg
    $mcPip = Get-AzureRmPublicIpAddress -Name $mcEnv.pip -ResourceGroupName $mcEnv.rg 
    $mcGatewaySubnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $mcVNET -Name "GatewaySubnet"
}

#login to global azure to create gateway
Add-AzureRMAccount-Allenk -myAzureEnv microsoft

$azGateway = Get-AzureRmVirtualNetworkGateway -Name $azEnv.gateway -ResourceGroupName $azEnv.rg -ErrorAction Ignore
if ($azGateway -eq $null){
    $azVNET = Get-AzureRmVirtualNetwork -Name $azEnv.vnet -ResourceGroupName $azEnv.rg

    # Create PIP if it does not exist:
    $azPip = Get-AzureRmPublicIpAddress -Name $azEnv.pip -ResourceGroupName $azEnv.rg -ErrorAction Ignore
    if ($azPip -eq $null)    {
        $azPip  = New-AzureRmPublicIpAddress -Name $azEnv.pip -ResourceGroupName $azEnv.rg -Location $azEnv.location -AllocationMethod Dynamic
    }

    # Create Gateway subnet if it has not been created.
    $azGatewaySubnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $azVNET -Name "GatewaySubnet" -ErrorAction Ignore
    if ($azGatewaySubnet -eq $null){
        Add-AzureRmVirtualNetworkSubnetConfig -Name "GatewaySubnet" -AddressPrefix $azGWSubnetPrefix -VirtualNetwork $azVNet | Set-AzureRmVirtualNetwork
    }

    # Create Gateway using the vNet and PIP created before
    $azGatewaySubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $azVNET
    $azGatewayIpConfig = New-AzureRmVirtualNetworkGatewayIpConfig -Name "GatewayIpConfig" -Subnet $azGatewaySubnet -PublicIpAddress $azPip
    $azGateway = New-AzureRmVirtualNetworkGateway -Name $azEnv.gateway -ResourceGroupName $azEnv.rg -Location $azenv.location -IpConfigurations $azGatewayIpConfig -GatewayType Vpn -VpnType RouteBased -GatewaySku Basic -AsJob
}else{
    $azVNET = Get-AzureRmVirtualNetwork -Name $azEnv.vnet -ResourceGroupName $azEnv.rg
    $azPip = Get-AzureRmPublicIpAddress -Name $azEnv.pip -ResourceGroupName $azEnv.rg 
    $azGatewaySubnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $azVNET -Name "GatewaySubnet"
}

# wait for above jobs to complete
Get-Job | Wait-Job

# Create local gateway and connection to bridge virtual networks
if (($mcGateway -ne $null) -and ($azGateway -ne $null)){
    Add-AzureRMAccount-Allenk -myAzureEnv mooncake
    $mcLocalGateway = New-AzureRmLocalNetworkGateway -Name $mcEnv.localgateway -ResourceGroupName $mcEnv.rg -Location $mcEnv.location -GatewayIpAddress $azPip.IpAddress  -AddressPrefix $azVNET.AddressSpace.AddressPrefixes
    New-AzureRmVirtualNetworkGatewayConnection -Name $mcEnv.localgatewayconnection -ResourceGroupName $mcEnv.rg -Location $mcEnv.location -VirtualNetworkGateway1 $mcGateway -LocalNetworkGateway2 $mcLocalGateway -ConnectionType IPsec -RoutingWeight 10 -SharedKey $SharedKey

    Add-AzureRMAccount-Allenk -myAzureEnv microsoft
    $azLocalGateway = New-AzureRmLocalNetworkGateway -Name $azEnv.localgateway -ResourceGroupName $azEnv.rg -Location $azEnv.location -GatewayIpAddress $mcPip.IpAddress  -AddressPrefix $mcVNET.AddressSpace.AddressPrefixes
    New-AzureRmVirtualNetworkGatewayConnection -Name $azEnv.localgatewayconnection -ResourceGroupName $azEnv.rg -Location $azEnv.location -VirtualNetworkGateway1 $azGateway -LocalNetworkGateway2 $azLocalGateway -ConnectionType IPsec -RoutingWeight 10 -SharedKey $SharedKey
}
