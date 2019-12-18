Import-Module C:\kangxh\PowerShell\allenk-Module-Azure.psm1

$mcEnv=@{rg="mc-rg-fta-core"; location = "chinanorth";    vnet="mc-vnet-fta"; gateway="mc-vpn-fta"; pip="mc-pip-fta-vpngw"; localgateway = "mc-vpn-fta-localgw"; localgatewayconnection="mc-vpn-fta-localgw-connection"}
$azEnv=@{rg="az-rg-fta-core"; location = "southeastasia"; vnet="az-vnet-fta"; gateway="az-vpn-fta"; pip="az-pip-fta-vpngw"; localgateway = "az-vpn-fta-localgw"; localgatewayconnection="az-vpn-fta-localgw-connection"}


#Part 1: On Mooncake, delete VPN GW, Local Gateway, VPN Connection, as PIP is the last resource to delete. if PIP is not there, no need to continue
Add-AzureRMAccount-Allenk -myAzureEnv mooncake

$mcPip = Get-AzureRmPublicIpAddress -Name $mcEnv.pip -ResourceGroupName $mcEnv.rg -ErrorAction Ignore
if ($mcPip -ne $null) {

    $mcLocalGatewayConnection = Get-AzureRmVirtualNetworkGatewayConnection -Name $mcEnv.localgatewayconnection -ResourceGroupName $mcEnv.rg -ErrorAction Ignore
    if ($mcLocalGatewayConnection -ne $null) {
        Remove-AzureRmVirtualNetworkGatewayConnection -Name $mcEnv.localgatewayconnection -ResourceGroupName $mcEnv.rg -Force
    }

    $mcLocalGateway = get-AzureRmLocalNetworkGateway -Name $mcEnv.localgateway -ResourceGroupName $mcEnv.rg -ErrorAction Ignore
    if ($mcLocalGateway -ne $null) {
        Remove-AzureRmLocalNetworkGateway -Name $mcEnv.localgateway -ResourceGroupName $mcEnv.rg -Force
    }

    $mcGateway = Get-AzureRmVirtualNetworkGateway -Name $mcEnv.gateway -ResourceGroupName $mcEnv.rg -ErrorAction Ignore
    if ($mcGateway -ne $null) {
        Remove-AzureRmVirtualNetworkGateway -Name $mcEnv.gateway -ResourceGroupName $mcEnv.rg -Force
    }

    Remove-AzureRmPublicIpAddress -Name $mcEnv.pip -ResourceGroupName $mcEnv.rg -Force 
}

#Part 2: On global azure, delete VPN GW, Local Gateway, VPN Connection
Add-AzureRMAccount-Allenk -myAzureEnv microsoft

$azPip = Get-AzureRmPublicIpAddress -Name $azEnv.pip -ResourceGroupName $azEnv.rg -ErrorAction Ignore
if ($azPip -ne $null) {

    $azLocalGatewayConnection = Get-AzureRmVirtualNetworkGatewayConnection -Name $azEnv.localgatewayconnection -ResourceGroupName $azEnv.rg -ErrorAction Ignore
    if ($azLocalGatewayConnection -ne $null) {
        Remove-AzureRmVirtualNetworkGatewayConnection -Name $azEnv.localgatewayconnection -ResourceGroupName $azEnv.rg -Force
    }

    $azLocalGateway = get-AzureRmLocalNetworkGateway -Name $azEnv.localgateway -ResourceGroupName $azEnv.rg -ErrorAction Ignore
    if ($azLocalGateway -ne $null) {
        Remove-AzureRmLocalNetworkGateway -Name $azEnv.localgateway -ResourceGroupName $azEnv.rg -Force
    }

    $azGateway = Get-AzureRmVirtualNetworkGateway -Name $azEnv.gateway -ResourceGroupName $azEnv.rg -ErrorAction Ignore
    if ($azGateway -ne $null) {
        Remove-AzureRmVirtualNetworkGateway -Name $azEnv.gateway -ResourceGroupName $azEnv.rg -Force
    }

    Remove-AzureRmPublicIpAddress -Name $azEnv.pip -ResourceGroupName $azEnv.rg -Force 
}