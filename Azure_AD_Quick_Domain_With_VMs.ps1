#Resoruce Group Info
$rgName = 'RG-MAGICMIKE' #resoruce group
$location = 'West Europe' #location of resource group

#Other Info
$deploymentName = 'magicmikead' #name of the deployment 
$numberOfVMsToCreate = 6 #number of additional VMs to create

#AD/Domain Info
$adadmin = 'adadmin' #username for AD
$domainPassword = Read-Host -assecurestring "Please enter your password for AD" #password for AD
$domainName = 'magicmike.com' #domain name
$adDNSPrefix = 'magicmikead' #DNS prefix of AD server
$dcSize = 'Standard_A1' #VM size

#VM Info
$vmUser = 'azureuser' #user for VM
$vmPassword = Read-Host -assecurestring "Please enter your password for VMs" #password for VM
$vmName = 'magicmike0' #VMs will be suffixed with a number
$vmSuffixStartNumber = 3
$vmSize = 'Basic_A1' #VM size for VM
$autoShutdownTime = '1830' #leave blank to turn off auto shutdown
if ($autoShutdownTime) {
	$autoShutdown = 'Enabled'
} else {
	$autoShutdown = 'Disabled'
}

if (!$AzureAccount) {
	$AzureAccount = Login-AzureRmAccount
}

$subs = Get-AzureRmSubscription
Select-AzureRmSubscription -TenantId $subs[0].TenantId -SubscriptionId $subs[0].SubscriptionId

# Create New Resource Group 
try {
	Get-AzureRmResourceGroup -Name $rgName -Location $location -ErrorAction Stop
	Write-Host 'RG already exists... skipping' -foregroundcolor yellow -backgroundcolor red
} catch {
	New-AzureRmResourceGroup -Name $rgName -Location $location
}

if (!(Get-AzureRmVM -Name $adDNSPrefix -ResourceGroupName $rgName -ErrorAction SilentlyContinue)) {
	$newDomainParams = @{
		'Name'			      = $deploymentName # Deployment name     
		'ResourceGroupName'   = $rgName
		'TemplateUri'		  = 'https://raw.githubusercontent.com/mikesanderson85/Azure-Quick-Deploy/master/azuredeploy_active_directory_new_domain.json'
		'adminUsername'	      = $adadmin
		'domainName'		  = $domainName # The FQDN of the AD Domain created       
		'dnsPrefix'		      = $adDNSPrefix # The DNS prefix for the public IP address used by the Load Balancer
		'adVMSize'		      = $dcsize
		'adminPassword'	      = $domainPassword
	}
	New-AzureRmResourceGroupDeployment @newDomainParams
	
	# Display the RDP connection string to the loadbalancer
	
	$rdpVM = Get-AzureRmPublicIpAddress -Name adPublicIP -ResourceGroupName $rgName
	$rdpString = $rdpVM.DnsSettings.Fqdn + ':3389'
	
	Write-Host 'Connect to the VM using the URL below:' -foregroundcolor yellow -backgroundcolor red
	Write-Host $rdpString
	
} else {
	Write-Host 'AD server name already exists. Skipping...' -foregroundcolor yellow -backgroundcolor red
}

if ($numberOfVMsToCreate -gt 0) {
	if (!$AzureAccount) {
		$AzureAccount = Login-AzureRmAccount
	}
	
	$subs = Get-AzureRmSubscription
	Select-AzureRmSubscription -TenantId $subs[0].TenantId -SubscriptionId $subs[0].SubscriptionId
	
	# Create New Resource Group
	# Checks to see if RG exists
	# -ErrorAction Stop added to Get-AzureRmResourceGroup cmdlet to treat errors as terminating
	
	try {
		Get-AzureRmResourceGroup -Name $rgName -Location $location -ErrorAction Stop
	} catch {
		Write-Host "Resource Group doesn't exist" -foregroundcolor yellow -backgroundcolor red
		exit
	}
	
	For ($i = $vmSuffixStartNumber; $i -le $numberOfVMsToCreate; $i++) {
		
		$vmNewName = "$vmName$i"
		
		# Check availability of DNS name
		
		If ((Test-AzureRmDnsAvailability -DomainQualifiedName $vmNewName -Location $location) -eq $false) {
			Write-Host "The DNS label prefix, $vmNewName for the VM is already in use" -foregroundcolor yellow -backgroundcolor red
			exit
		}
		
		$newVMParams = @{
			'ResourceGroupName'	    = $rgName
			'TemplateURI'		    = 'https://raw.githubusercontent.com/mikesanderson85/Azure-Quick-Deploy/master/azuredeploy_domain_joined_VM.json'
			'existingVNETName'	    = 'adVNET'
			'existingSubnetName'    = 'adSubnet'
			'dnsLabelPrefix'	    = $vmNewName
			'vmSize'			    = $vmsize
			'domainToJoin'		    = $domainName
			'domainUsername'	    = $adadmin
			'autoShutdownEnabled'   = $autoShutdown
			'autoShutdownTime'	    = $autoShutdownTime
			'domainPassword'	    = $domainPassword
			'ouPath'			    = ''
			'domainJoinOptions'	    = 3
			'vmAdminUsername'	    = $vmUser
			'vmAdminPassword'	    = $vmPassword
		}
		New-AzureRmResourceGroupDeployment @newVMParams
		
		# Display the RDP connection string
		
		$rdpVM = Get-AzureRmVM -ResourceGroupName $rgName -Name $vmNewName
		
		$rdpString = $vmNewName + '.' + $rdpVM.Location + '.cloudapp.azure.com'
		Write-Host 'Connect to the VM using the URL below:' -foregroundcolor yellow -backgroundcolor red
		Write-Host $rdpString
	}
} else {
	Write-Host "No VM's will be created"
}


