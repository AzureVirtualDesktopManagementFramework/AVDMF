function Register-AVDMFHostPool {
    <#
    .SYNOPSIS
        A short one-line action-based description, e.g. 'Tests if a function is valid'
    .DESCRIPTION
        A longer description of the function, its purpose, common use cases, etc.
    .NOTES
        Information or caveats about the function e.g. 'This function is not supported in Linux'
    .LINK
        Specify a URI to a help page, this will show when Get-Help -Online is used.
    .EXAMPLE
            Application Groups for RemoteApp Host Pools
                {
                    "Name": "Common Apps",
                    "RemoteAppReference":[
                        "SAPAnalyzer",
                        "SAPLogon"
                    ],
                    "Users":[
                        "BusinessAppGroup@oq.com"
                    ]
                }
    #>


    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true , ValueFromPipelineByPropertyName = $true )]
        [string] $AccessLevel,

        [Parameter(Mandatory = $true , ValueFromPipelineByPropertyName = $true )]
        [ValidateSet("Personal", "Pooled", "RemoteApp")]
        [string] $PoolType,

        [Parameter(Mandatory = $true , ValueFromPipelineByPropertyName = $true )]
        [string] $ReplacementPlan,

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

        [Parameter(Mandatory = $false , ValueFromPipelineByPropertyName = $true )]
        [string] $StorageAccountReference,

        [Parameter(Mandatory = $false , ValueFromPipelineByPropertyName = $true )]
        $RemoteAppGroups,

        [Parameter(Mandatory = $false , ValueFromPipelineByPropertyName = $true )]
        [string[]] $Users,

        [Parameter(Mandatory = $true , ValueFromPipelineByPropertyName = $true )]
        [string] $VMTemplate,

        [Parameter(Mandatory = $false , ValueFromPipelineByPropertyName = $true )]
        [ValidateSet("AAD", "ADDS")]
        [string] $SessionHostJoinType = $script:SessionHostJoinType,

        [Parameter(Mandatory = $false , ValueFromPipelineByPropertyName = $true )]
        [string] $ADOrganizationalUnitPath,

        [Parameter(Mandatory = $false , ValueFromPipelineByPropertyName = $true )]
        [bool] $UseAvailabilityZones = $false,

        [Parameter(Mandatory = $false , ValueFromPipelineByPropertyName = $true )]
        [string] $CustomRdpProperty = "drivestoredirect:s:;redirectwebauthn:i:0;redirectlocation:i:0;redirectclipboard:i:1;redirectprinters:i:0;devicestoredirect:s:;redirectcomports:i:0;redirectsmartcards:i:0;usbdevicestoredirect:s:;camerastoredirect:s:;autoreconnectionenabled:i:1;",

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
        if ($StorageAccountReference) {
            $storageAccount = $script:StorageAccounts[$StorageAccountReference]
            Register-AVDMFFileShare -Name $resourceName.ToLower() -StorageAccountName $storageAccount.Name -ResourceGroupName $storageAccount.ResourceGroupName
        }


        $script:HostPools[$ResourceName] = [PSCustomObject]@{
            PSTypeName           = 'AVDMF.DesktopVirtualization.HostPool'
            ResourceGroupName    = $resourceGroupName
            ResourceID           = $resourceID

            PoolType             = $PoolType
            MaxSessionLimit      = $MaxSessionLimit
            NumberOfSessionHosts = $NumberOfSessionHosts
            CustomRdpProperty    = $CustomRdpProperty

            WorkSpaceReference   = $WorkSpaceReference

            SubnetID             = $subnetID

            VMTemplate           = $VMTemplate

            SessionHostJoinType  = $script:SessionHostJoinType

            Tags                 = $Tags



        }

        #TODO: Check if users are provided.
        if ($PoolType -eq "RemoteApp") {
            # We assume only Remote App AGs are used for RemoteApp Host Pools
            foreach ($applicationGroup in $RemoteAppGroups) {
                # Register each application group
                $applicationGroupParams = @{
                    HostPoolName         = $resourceName
                    ResourceGroupName    = $resourceGroupName
                    HostPoolResourceId   = $resourceID
                    Users                = $applicationGroup.Users
                    Name                 = $applicationGroup.Name
                    FriendlyName         = $applicationGroup.Name
                    ApplicationGroupType = 'RemoteApp'
                    RemoteAppReference   = $applicationGroup.RemoteAppReference
                    SessionHostJoinType  = $script:SessionHostJoinType


                }
                #TODO: Add logic to check if all remote app references exist
                Register-AVDMFApplicationGroup @applicationGroupParams
            }
        }
        else {
            # This would apply for pooled and personal pools. Only creating one AG of type Desktop.
            $applicationGroupParams = @{
                HostPoolName             = $resourceName
                ResourceGroupName        = $resourceGroupName
                HostPoolResourceId       = $resourceID
                Users                    = $Users
                FriendlyName             = $FriendlyName
                ApplicationGroupType     = 'Desktop'
                SessionHostJoinType      = $SessionHostJoinType
                ADOrganizationalUnitPath = $ADOrganizationalUnitPath

            }
            Register-AVDMFApplicationGroup @applicationGroupParams
        }


        # Register Replacement Plan
        $hostPoolInstance = $ResourceName.Substring($ResourceName.Length - 2, 2)
        $sessionHostNamePrefix = New-AVDMFResourceName -ResourceType 'SessionHostPrefix' -AccessLevel $AccessLevel -HostPoolType $PoolType -HostPoolInstance $hostPoolInstance
        $replacementPlanParams = @{
            ResourceGroupName        = $resourceGroupName
            HostPoolName             = $resourceName
            NumberOfSessionHosts     = $NumberOfSessionHosts
            SessionHostNamePrefix    = $sessionHostNamePrefix
            SessionHostJoinType      = $script:SessionHostJoinType
            ADOrganizationalUnitPath = $ADOrganizationalUnitPath
            SubnetId                 = $subnetID
            ReplacementPlanTemplate  = $script:ReplacementPlanTemplates[$ReplacementPlan]
            SessionHostParameters    = $script:VMTemplates[$VMTemplate]
        }
        Register-AVDMFReplacementPlan @replacementPlanParams

        # Register Session Host
        $hostPoolInstance = $ResourceName.Substring($ResourceName.Length - 2, 2)

        switch ($SessionHostJoinType) {
            "AAD" {
                # TODO: Handle Intune managed session hosts
            }
            "ADDS" {
                $domainName = ($ADOrganizationalUnitPath -split "," | Where-Object { $_ -like "DC=*" } | ForEach-Object { $_.replace("DC=", "") }) -join "."
            }
        }

        $zone = 1
        for ($i = 1; $i -le $NumberOfSessionHosts; $i++) {
            #TODO: Change all parameters to use splatting
            $SessionHostParams = @{
                subnetID            = $subnetID
                SessionHostJoinType = $SessionHostJoinType
            }
            if ($SessionHostJoinType -eq "ADDS") {
                $SessionHostParams['DomainName'] = $domainName
                $SessionHostParams['OUPath'] = $ADOrganizationalUnitPath
            }
            if ($UseAvailabilityZones) {
                $SessionHostParams['AvailabilityZone'] = $zone
                $zone++
                if ($zone -eq 4) { $zone = 1 }
            }
            Register-AVDMFSessionHost -ResourceGroupName $resourceGroupName -AccessLevel $AccessLevel -HostPoolType $PoolType -HostPoolInstance $hostPoolInstance -InstanceNumber $i -VMTemplate $script:VMTemplates[$VMTemplate] @SessionHostParams -Tags $Tags
        }
    }
}