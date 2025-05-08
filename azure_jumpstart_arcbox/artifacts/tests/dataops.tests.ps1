
BeforeDiscovery {

    $k3sArcDataClusterName = $env:k3sArcDataClusterName
    $aksArcClusterName = $env:aksArcClusterName
    $aksdrArcClusterName = $env:aksdrArcClusterName
    $namingPrefix = $env:namingPrefix

    $clusters = @($k3sArcDataClusterName, $aksArcClusterName, $aksdrArcClusterName)
    $customLocations = @("${k3sArcDataClusterName}-cl", "${aksArcClusterName}-cl", "${aksdrArcClusterName}-cl")
    $dataControllers = @("${k3sArcDataClusterName}-dc", "${aksArcClusterName}-dc", "${aksdrArcClusterName}-dc")
    $sqlMiInstances = @("k3s-sql", "aks-sql", "aks-dr-sql")
    $drPartners = @("k3s-sql", "aks-dr-sql")
    $VMs = @("$namingPrefix-sql")

    $null = Connect-AzAccount -Identity -Tenant $env:tenantId -Subscription $env:subscriptionId
    az config set extension.use_dynamic_install=yes_without_prompt
}

Describe "<cluster>" -ForEach $clusters {
    BeforeAll {
        $cluster = $_
    }
    It "Cluster exists" {
        $clusterObject = Get-AzConnectedKubernetes -ClusterName $cluster -ResourceGroupName $env:resourceGroup -SubscriptionId $env:subscriptionId
        $clusterObject | Should -Not -BeNullOrEmpty
    }
    It "Azure Arc Connected cluster is connected" {
        $connectedCluster = Get-AzConnectedKubernetes -Name $cluster -ResourceGroupName $env:resourceGroup -SubscriptionId $env:subscriptionId
        $connectedCluster.ConnectivityStatus | Should -Be "Connected"
    }
}

Describe "<customLocation>" -ForEach $customLocations {
    BeforeAll {
        $customLocation = $_
    }
    It "Custom Location exists" {
        $customLocationObject = Get-AzCustomLocation -Name $customLocation -ResourceGroupName $env:resourceGroup -SubscriptionId $env:subscriptionId
        $customLocationObject | Should -Not -BeNullOrEmpty
    }
    It "Custom Location is connected" {
        $customLocationObject = Get-AzCustomLocation -Name $customLocation -ResourceGroupName $env:resourceGroup -SubscriptionId $env:subscriptionId
        $customLocationObject.ProvisioningState | Should -Be "Succeeded"
    }
}

Describe "<dataController>" -ForEach $dataControllers {
    BeforeAll {
        $dataController = $_
    }
    It "Data Controller exists" {
        $dataControllerObject = $(az arcdata dc status show --resource-group $env:resourceGroup --name $dataController --query "{name:name,state:properties.k8SRaw.status.state}")
        ($dataControllerObject | ConvertFrom-Json).Name | Should -Not -BeNullOrEmpty
    }
    It "Data Controller is connected" {
        $dataControllerObject = $(az arcdata dc status show --resource-group $env:resourceGroup --name $dataController --query "{name:name,state:properties.k8SRaw.status.state}")
        ($dataControllerObject | ConvertFrom-Json).State | Should -Be "Ready"
    }
}

Describe "<sqlInstance>" -ForEach $sqlMiInstances {
    BeforeAll {
        $sqlInstance = $_
    }
    It "SQL Managed Instance exists" {
        $sqlMiInstanceObject = $(az sql mi-arc show --resource-group $env:resourceGroup --name $sqlInstance --query "{name:name,state:properties.k8SRaw.status.state}")
        ($sqlMiInstanceObject| ConvertFrom-Json).Name | Should -Not -BeNullOrEmpty
    }
    It "SQL Managed Instance is connected" {
        $sqlMiInstanceObject = $(az sql mi-arc show --resource-group $env:resourceGroup --name $sqlInstance --query "{name:name,state:properties.k8SRaw.status.state}")
        ($sqlMiInstanceObject| ConvertFrom-Json).State | Should -Be "Ready"
    }
}

Describe "<drPartner>" -ForEach $drPartners{
    BeforeAll {
        $drPartner = $_
    }
    It "DR configuration exists" {
        $drConfig = $(az sql instance-failover-group-arc list --resource-group $env:resourceGroup --mi $drPartner)
        $drConfig | Should -Not -Be "Found 0 failover group(s)."
    }
    It "DR configuration is healthy" {
        $drConfig = $(az sql mi-arc show --resource-group $env:resourceGroup --name $drPartner --query "{name:name,state:properties.k8SRaw.status.highAvailability.healthState}")
        ($drConfig| ConvertFrom-Json).state | Should -Be "Ok"
    }
}

Describe "<vm>" -ForEach $VMs {
    BeforeAll {
        $vm = $_
    }
    It "VM exists" {
        $vmobject = Get-VM -Name $vm
        $vmobject | Should -Not -BeNullOrEmpty
    }
    It "VM is running" {
        $vmobject = Get-VM -Name $vm
        $vmobject.State | Should -Be "Running"
    }
    It "Azure Arc Connected Machine exists" {
        $connectedMachine = Get-AzConnectedMachine -Name $vm -ResourceGroupName $env:resourceGroup -SubscriptionId $env:subscriptionId
        $connectedMachine | Should -Not -BeNullOrEmpty
    }
    It "Azure Arc Connected Machine is connected" {
        $connectedMachine = Get-AzConnectedMachine -Name $vm -ResourceGroupName $env:resourceGroup -SubscriptionId $env:subscriptionId
        $connectedMachine.Status | Should -Be "Connected"
    }
}