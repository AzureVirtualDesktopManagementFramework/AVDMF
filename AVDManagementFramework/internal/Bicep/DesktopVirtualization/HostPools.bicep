targetScope = 'subscription'

param Location string
param HostPools array
param ApplicationGroups array
//param SessionHosts array // TODO: Delete This
param RemoteApps array
param ReplacementPlan object
param ResourceGroupName string

//TODO: There is only one session host per RG, do we really need the complexity of an array loop here?
module hostPoolModule 'modules/HostPool.bicep' = [for hostpoolitem in HostPools: {
  scope: resourceGroup(ResourceGroupName)
  name: hostpoolitem.name
  params: {
    HostPoolName: hostpoolitem.name
    Location: Location
    PoolType: hostpoolitem.PoolType
    maxSessionLimit: hostpoolitem.MaxSessionLimit
    SessionHostJoinType: hostpoolitem.SessionHostJoinType
    Tags: hostpoolitem.Tags
    CustomRdpProperty: hostpoolitem.CustomRdpProperty
  }
}]
module applicationGroupModule 'modules/ApplicationGroup.bicep' = [for applicationGroupItem in ApplicationGroups: {
  scope: resourceGroup(ResourceGroupName)
  name: applicationGroupItem.name
  params: {
    ApplicationGroupName: applicationGroupItem.name
    ApplicationGroupType: applicationGroupItem.ApplicationGroupType
    Location: Location
    HostPoolId: applicationGroupItem.HostPoolId
    FriendlyName: applicationGroupItem.FriendlyName
    Tags: applicationGroupItem.Tags
    PrincipalId: applicationGroupItem.PrincipalId
    SessionHostJoinType: applicationGroupItem.SessionHostJoinType
  }
  dependsOn: hostPoolModule
}]

module RemoteAppModule 'modules/RemoteApp.bicep' = [for (remoteAppItem, i) in RemoteApps: {
  scope: resourceGroup(ResourceGroupName)
  name: 'RemoteApp_${i + 1}_${replace(replace(remoteAppItem.RemoteAppName, '/', '_'), ' ', '')}'
  params: {
    ApplicationGroupName: remoteAppItem.ApplicationGroupName
    RemoteAppName: remoteAppItem.RemoteAppName
    RemoteAppProperties: remoteAppItem.RemoteAppProperties
  }
  dependsOn: [
    applicationGroupModule
    //SessionHostsModule // TODO: Check if all is well after removing this
  ]
}]

module ReplacementPlanModule 'modules/ReplacementPlan.bicep' = {
  scope: resourceGroup(ResourceGroupName)
  name: 'ReplacementPlan_${replace(replace(ReplacementPlan.Name, '/', '_'), ' ', '')}'
  params: {
    Location: Location
    //Storage Account
    StorageAccountName: 'safuncshr${uniqueString(ReplacementPlan.Name)}'

    // Log Analytics Workspace
    LogAnalyticsWorkspaceName: '${ReplacementPlan.Name}-LAW-01'

    //FunctionApp
    FunctionAppName: ReplacementPlan.Name

    SubscriptionId: subscription().subscriptionId


    AllowDownsizing: ReplacementPlan.AllowDownsizing
    AppPlanName: ReplacementPlan.AppPlanName
    AppPlanTier: ReplacementPlan.AppPlanTier
    DrainGracePeriodHours: ReplacementPlan.DrainGracePeriodHours
    FixSessionHostTags: ReplacementPlan.FixSessionHostTags
    FunctionAppZipUrl: ReplacementPlan.FunctionAppZipUrl
    MaxSimultaneousDeployments: ReplacementPlan.MaxSimultaneousDeployments
    ReplaceSessionHostOnNewImageVersion: ReplacementPlan.ReplaceSessionHostOnNewImageVersion
    ReplaceSessionHostOnNewImageVersionDelayDays: ReplacementPlan.ReplaceSessionHostOnNewImageVersionDelayDays
    SessionHostInstanceNumberPadding: ReplacementPlan.SessionHostInstanceNumberPadding
    SHRDeploymentPrefix: ReplacementPlan.SHRDeploymentPrefix
    TagDeployTimestamp: ReplacementPlan.TagDeployTimestamp
    TagIncludeInAutomation: ReplacementPlan.TagIncludeInAutomation
    TagPendingDrainTimestamp: ReplacementPlan.TagPendingDrainTimestamp
    TagScalingPlanExclusionTag: ReplacementPlan.TagScalingPlanExclusionTag
    TargetVMAgeDays: ReplacementPlan.TargetVMAgeDays
    HostPoolName: ReplacementPlan.HostPoolName
    SessionHostNamePrefix: ReplacementPlan.SessionHostNamePrefix
    SessionHostParameters: ReplacementPlan.SessionHostParameters
    SessionHostTemplateUri: ReplacementPlan.SessionHostTemplateUri
    SubnetId: ReplacementPlan.SubnetId
    TargetSessionHostCount: ReplacementPlan.TargetSessionHostCount
    ADOrganizationalUnitPath: ReplacementPlan.ADOrganizationalUnitPath
  }
  dependsOn: hostPoolModule
}

module RBACFunctionApphasDesktopVirtualizationVirtualMachineContributor 'modules/RBACRoleAssignment.bicep' = {
  name: 'RBACFunctionApphasDesktopVirtualizationVirtualMachineContributor'
  params: {
    PrinicpalId: ReplacementPlanModule.outputs.FunctionAppSP
    RoleDefinitionId: 'a959dbd1-f747-45e3-8ba6-dd80f235f97c' // Desktop Virtualization Virtual Machine Contributor
    Scope: subscription().id //We assign the permission at the subscription level to be able to attach the vnic to a subnet in a different resource group.
  }
  dependsOn: [ ReplacementPlanModule ]
}
