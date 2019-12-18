# global:   azureEnv, azureSub
# Function: 
#         Add-AzureRMAccount-Allenk
#         Calculate-BlobSpace
#         Get-BlobBytes
#

function global:Add-AzureRMAccount-Allenk {
    param (
        [Parameter()]
        [ValidateSet('mooncake','msdn','microsoft')]
        [string] $myAzureEnv = "mooncake"
    )

    process {
    
        switch ($myAzureEnv)
        {
            "mooncake" {
                $Thumbprint = "4F883F8F26299DDE014E9B86E7559FF8C6184D87"
                $ApplicationID = "f635feda-7749-4547-b795-1fc6cd7fa75b"
                $TenantID = "c43b8be0-0873-4392-9868-cb56e7bdbe24"
                $SubscriptionID = "54c76a13-59da-47a5-bfff-63b25c5036ea"

                Login-AzureRmAccount -ServicePrincipal -CertificateThumbprint $Thumbprint  -ApplicationId $ApplicationID -TenantId $TenantID -Environment AzureChinaCloud
                Set-AzureRmContext $SubscriptionID

                $global:azureSubscription = Get-AzurermSubscription 
                $global:azureEnv = Get-AzureRmEnvironment -Name AzureChinaCloud
            }

            "msdn"{
                $Thumbprint = "7405E548DAE2873732B86F4AD124E42024CB2399"
                $ApplicationID = "dd923aff-4a8c-478f-a062-ddae8c97e900"
                $TenantID = "1014a8be-f107-4d38-a6b9-d4e7b717fb0f"
                $SubscriptionID = "e7c1ea2d-b89c-43d2-9e87-8f025edb3abc"

                Login-AzureRmAccount -ServicePrincipal -CertificateThumbprint $Thumbprint  -ApplicationId $ApplicationID -TenantId $TenantID -Environment AzureCloud
                Set-AzureRmContext $SubscriptionID

                $global:azureSub = Get-AzurermSubscription 
                $global:azureEnv = Get-AzureRmEnvironment 
            }

            "microsoft"{
                $Thumbprint = "7405E548DAE2873732B86F4AD124E42024CB2399"
                $ApplicationID = "2025e9a0-c4ec-4a85-9aab-238ac0d81391"
                $TenantID = "72f988bf-86f1-41af-91ab-2d7cd011db47"
                $SubscriptionID = "9c6835cb-2079-4f99-96f4-74029267e0df"

                Login-AzureRmAccount -ServicePrincipal -CertificateThumbprint $Thumbprint  -ApplicationId $ApplicationID -TenantId $TenantID -Environment AzureCloud
                Set-AzureRmContext $SubscriptionID

                $global:azureSub = Get-AzurermSubscription 
                $global:azureEnv = Get-AzureRmEnvironment 
            }
        }
    }
}

 
function global:Get-BlobBytes
{
    param (
        [Parameter(Mandatory=$true)]
    #    [Microsoft.WindowsAzure.Management.Storage.Model.ResourceModel.AzureStorageBlob]$Blob)
        [Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageBlob]$Blob)
    # Base + blob name
    $blobSizeInBytes = 124 + $Blob.Name.Length * 2
 
    # Get size of metadata
    $metadataEnumerator = $Blob.ICloudBlob.Metadata.GetEnumerator()
    while ($metadataEnumerator.MoveNext())
    {
        $blobSizeInBytes += 3 + $metadataEnumerator.Current.Key.Length + $metadataEnumerator.Current.Value.Length
    }
 
    if ($Blob.BlobType -eq [Microsoft.WindowsAzure.Storage.Blob.BlobType]::BlockBlob)
    {
        $blobSizeInBytes += 8
        $Blob.ICloudBlob.DownloadBlockList() | 
            ForEach-Object { $blobSizeInBytes += $_.Length + $_.Name.Length }
    }
    else
    {
        $Blob.ICloudBlob.GetPageRanges() | 
            ForEach-Object { $blobSizeInBytes += 12 + $_.EndOffset - $_.StartOffset }
    }

    return $blobSizeInBytes
}

function global:Get-ContainerBytes
{
    param (
        [Parameter(Mandatory=$true)]
        [Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageContainer]$Container)
 
    # Base + name of container
    $containerSizeInBytes = 48 + $Container.Name.Length * 2
 
    # Get size of metadata
    $metadataEnumerator = $Container.CloudBlobContainer.Metadata.GetEnumerator()
    while ($metadataEnumerator.MoveNext())
    {
        $containerSizeInBytes += 3 + $metadataEnumerator.Current.Key.Length + 
                                     $metadataEnumerator.Current.Value.Length
    }

    # Get size for Shared Access Policies
    $containerSizeInBytes += $Container.Permission.SharedAccessPolicies.Count * 512
 
    # Calculate size of all blobs.
    $blobCount = 0
    Get-AzureStorageBlob -Context $storageContext -Container $Container.Name | 
        ForEach-Object { 
            $containerSizeInBytes += Get-BlobBytes $_ 
            $blobCount++
            }
 
    return @{ "containerSizeBytes" = $containerSizeInBytes; "blobCount" = $blobCount; “containerSizeGB” = ($containerSizeInBytes/1024/1024/1024).ToInt32($null)}
}

