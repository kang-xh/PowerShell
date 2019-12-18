$remotePort=@{}
$remotePort["Windows"] = 3389
$remotePort["Linux"] = 22

$remoteProtocol=@{}
$remoteProtocol["Windows"] = "RDP"
$remoteProtocol["Linux"] = "SSH"


# https://4sysops.com/archives/convert-json-to-a-powershell-hash-table/
function ConvertTo-allenkCollectionToHashtable {
    [CmdletBinding()]
    [OutputType('hashtable')]
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process {
        ## Return null if the input is null. This can happen when calling the function
        ## recursively and a property is null
        if ($null -eq $InputObject) {
            return $null
        }

        ## Check if the input is an array or collection. If so, we also need to convert
        ## those types into hash tables as well. This function will convert all child
        ## objects into hash tables (if applicable)
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @(
                foreach ($object in $InputObject) {
                    ConvertTo-Hashtable -InputObject $object
                }
            )

            ## Return the array but don't enumerate it because the object may be pretty complex
            Write-Output -NoEnumerate $collection
        } elseif ($InputObject -is [psobject]) { ## If the object has properties that need enumeration
            ## Convert it to its own hash table and return it
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
            }
            $hash
        } else {
            ## If the object isn't an array, collection, or other object, it's already a hash table
            ## So just return it.
            $InputObject
        }
    }
}

# https://blogs.technet.microsoft.com/undocumentedfeatures/2016/09/20/powershell-random-password-generator/
# create a password with 12 char
function new-AllenkStrongPassword {
    [CmdletBinding()]
    [OutputType('string')]
    param ()
    process {
        $Password = ([char[]]([char]40..[char]46) + ([char[]]([char]65..[char]90)) + ([char[]]([char]97..[char]122)) + 0..9 | Sort-Object {Get-Random})[0..12]
        $Password = -join $Password  
        $Password
    }
}


# this function is used to add some NAT rules, we can use a 6xxxx port map to 3389 or 22
function global:New-AllenkCustomPortMapping {
    param
    (
    [Parameter( Mandatory=$true)] [string]$ipaddr,
    [Parameter( Mandatory=$true)] [int]$port
    )

    process{

        $IpCheck = ($ipaddr -As [IPAddress]) -as [Bool]

        if ($IpCheck){

            # only take the last two digits of the port and IP
            $port = $port % 100
            $ipValue = $ipaddr.Split('.')[3].ToInt16($null)
            $ipValue = ($ipValue % 100).ToString()

            return 60000 + $ipValue.ToInt16($null)*100 + $port

        }
        else{

            return -1

        }

    }
}

# Build a VM Group Array based 
function global:New-AllenkVMGroupArray {
    param
    (
    [Parameter( Mandatory=$true)] [int]$count,
    [Parameter( Mandatory=$true)] [string]$name,
    [Parameter( Mandatory=$true)] [string]$resourcegroup,
    [Parameter( Mandatory=$true)] [string]$location,
    [Parameter( Mandatory=$true)] [string]$os,
    [Parameter( Mandatory=$false)] [string]$size = "Standard_A2_V2",
    [Parameter( Mandatory=$true)] [string]$ip,
    [Parameter( Mandatory=$false)] [PSCredential]$cred
    )

    process{
        
        
        if ($count -eq 1) {
            $frontendPort = New-AllenkCustomPortMapping  -ipaddr $ip -port $remotePort[$os]
            $vm = @{name=$name; resourcegroup = $resourcegroup; location = $location; nicname = "nic01-$name"; os=$os; size = $size; ip = $ip; natrule = "$($remoteProtocol[$os])-$name"; frontendport = $frontendPort; backendport = $remotePort["$os"]; cred = $vmCred}
            return $vm
        }

        $vmArray = @()
        for ($i=1; $i -le $count; $i++){
            # create new vm name in the group
            $newName = $name + $i.ToString()

            # create new IP for this vm
            $ipValues = $ip.split('.')
            $ipValues[3] = ($ipValues[3].ToInt16($null) + $i -1).ToString()
            $newIP = $ipValues -join "."

            # create a port mapping for NLB NAT Rule
            $frontendPort = New-AllenkCustomPortMapping -ipaddr $newIP -port $remotePort[$os]
            
            $vm = @{name=$newName; resourcegroup = $resourcegroup; location = $location; nicname = "nic01-$newName"; os=$os; size = $size; ip = $newIP; natrule = "$($remoteProtocol[$os])-$newName"; frontendport = $frontendPort; backendport = $remotePort["$os"]; cred = $vmCred}
            $vmArray += $vm
        }
        return $vmArray;
    }
}