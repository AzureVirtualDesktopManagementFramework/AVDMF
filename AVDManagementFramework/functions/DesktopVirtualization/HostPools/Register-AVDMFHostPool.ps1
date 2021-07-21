function Register-AVDMFHostPool {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true , ValueFromPipelineByPropertyName = $true )]
        [string] $AccessLevel,

        [Parameter(Mandatory = $true , ValueFromPipelineByPropertyName = $true )]
        [string] $PoolType,

        [Parameter(Mandatory = $true , ValueFromPipelineByPropertyName = $true )]
        [int] $MaxSessionLimit,

        [Parameter(Mandatory = $true , ValueFromPipelineByPropertyName = $true )]
        [int] $NumberOfSessionHosts,

        [Parameter(Mandatory = $true , ValueFromPipelineByPropertyName = $true )]
        [string] $FriendlyName,

        [Parameter(Mandatory = $true , ValueFromPipelineByPropertyName = $true )]
        [string] $WorkSpaceReference,

        [Parameter(Mandatory = $true , ValueFromPipelineByPropertyName = $true )]
        [string] $VirtualNetworkReference,

        [Parameter(Mandatory = $true , ValueFromPipelineByPropertyName = $true )]
        [string] $SubnetNSG,

        [Parameter(Mandatory = $false , ValueFromPipelineByPropertyName = $true )]
        [string] $SubnetRouteTable,

        [Parameter(Mandatory = $true , ValueFromPipelineByPropertyName = $true )]
        [string] $StorageAccountReference,

        [Parameter(Mandatory = $false , ValueFromPipelineByPropertyName = $true )]
        [string[]] $Users,

        [Parameter(Mandatory = $true , ValueFromPipelineByPropertyName = $true )]
        [string] $VMTemplate,

        [Parameter(Mandatory = $true , ValueFromPipelineByPropertyName = $true )]
        [string] $OrganizationalUnitDN,

        [PSCustomObject] $Tags = [PSCustomObject]@{}
    )
    process {
        $ResourceName = New-AVDMFResourceName -ResourceType 'HostPool' -AccessLevel $AccessLevel -HostPoolType $PoolType
        $resourceGroupName = New-AVDMFResourceName -ResourceType "ResourceGroup" -ResourceCategory 'HostPool' -AccessLevel $AccessLevel -HostPoolType $PoolType
        Register-AVDMFResourceGroup -Name $resourceGroupName -ResourceCategory 'HostPool'

        $resourceID = "/Subscriptions/$script:AzSubscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.DesktopVirtualization/hostpools/$ResourceName"

        #Register Subnet
        $subnetParams = @{
            Scope              = $AccessLevel + 'Access'  #TODO: Change the parameter name from scope to Access Level, also change it in subnet configurations
            NamePrefix         = $resourceName
            VirtualNetworkName = $script:VirtualNetworks[$VirtualNetworkReference].ResourceName
            VirtualNetworkID   = $script:VirtualNetworks[$VirtualNetworkReference].ResourceID
            NSGID              = $script:NetworkSecurityGroups[$SubnetNSG].ResourceID
            RouteTableID       = $script:RouteTables[$SubnetRouteTable].ResourceID
        }

        $subnetID = Register-AVDMFSubnet @subnetParams -PassThru

        # Pickup Storage Account
        #TODO: Change Storage Accounts into HashTables
        $StorageAccountRef = $StorageAccountReference #There is a bug in Script Analyzer that causes the parameter to report unused.
        $storageAccount = $script:StorageAccounts[$StorageAccountRef]
        Register-AVDMFFileShare -Name $resourceName.ToLower() -StorageAccountName $storageAccount.Name -ResourceGroupName $storageAccount.ResourceGroupName

        $script:HostPools[$ResourceName] = [PSCustomObject]@{
            PSTypeName           = 'AVDMF.DesktopVirtualization.HostPool'
            ResourceGroupName    = $resourceGroupName
            ResourceID           = $resourceID

            PoolType             = $PoolType
            MaxSessionLimit      = $MaxSessionLimit
            NumberOfSessionHosts = $NumberOfSessionHosts

            WorkSpaceReference   = $WorkSpaceReference

            SubnetID             = $subnetID

            VMTemplate           = $VMTemplate

            Tags                 = $Tags

        }

        #TODO: Change this into splatting and check if users are provided.
        Register-AVDMFApplicationGroup -HostPoolName $resourceName -ResourceGroupName $resourceGroupName -HostPoolResourceId $resourceID -Tags $Tags -Users $Users -FriendlyName $FriendlyName

        # Register Session Host
        $hostPoolInstance = $ResourceName.Substring($ResourceName.Length - 2, 2)

        $domainName = ($OrganizationalUnitDN -split "," | Where-Object { $_ -like "DC=*" } | ForEach-Object { $_.replace("DC=", "") }) -join "."

        for ($i = 1; $i -le $NumberOfSessionHosts; $i++) {
            #TODO: Change all parameters to use splatting
            $SessionHostParams = @{
                subnetID   = $subnetID
                DomainName = $domainName
                OUPath     = $OrganizationalUnitDN
            }
            Register-AVDMFSessionHost -ResourceGroupName $resourceGroupName -AccessLevel $AccessLevel -HostPoolType $PoolType -HostPoolInstance $hostPoolInstance -InstanceNumber $i -VMTemplate $script:VMTemplates[$VMTemplate] @SessionHostParams -Tags $Tags
        }
    }
}