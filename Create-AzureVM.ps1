param(
        [Parameter(Mandatory=$true,
            ParameterSetName='SpecificFile')]
        [string]$MachineFile,

        [Parameter(Mandatory=$true,
            ParameterSetName='TemplateFile')]
        [string]$TemplateFile,

        [Parameter (ParameterSetName='TemplateFile', Mandatory=$true)]
        [string]$OutPathName
     )

switch($PsCmdlet.ParameterSetName){
    'SpecificFile' {[xml]$xml = Get-Content $MachineFile
                    $name = $xml.VM.Name
                    $location = $xml.VM.Location
                    $resourceGroupName = $xml.VM.ResourceGroupName
                    $storageAccountName = $xml.VM.StorageAccountName
                    $virtualNetworkName = $xml.VM.VirtualNetworkName
                    $publicIPName = $xml.VM.PublicIPName
                    $nicName = $xml.VM.NICName
    }
    'TemplateFile' {[xml]$xml = Get-Content $TemplateFile
                    $name = $xml.VM.Name
                    if($name -eq 'ASK'){
                        $name = Read-Host 'Enter the NAME'
                    }
                    $location = $xml.VM.Location
                    if($location -eq 'ASK'){
                        $location = Read-Host 'Enter the LOCATION'
                    }
                    $resourceGroupName = $xml.VM.ResourceGroupName
                    if($resourceGroupName -eq 'ASK'){
                        $resourceGroupName = Read-Host 'Enter the RESOURCE GROUP NAME'
                    }
                    $storageAccountName = $xml.VM.StorageAccountName
                    if($storageAccountName -eq 'ASK'){
                        $storageAccountName = Read-Host 'Enter the STORAGe ACCOUNT NAME'
                    }
                    $virtualNetworkName = $xml.VM.VirtualNetworkName
                    if($virtualNetworkName -eq 'ASK'){
                        $virtualNetworkName = Read-Host 'Enter the VIRTUAL NETWORK NAME'
                    }
                    $publicIPName = $xml.VM.PublicIPName
                    if($publicIPName -eq 'ASK'){
                        $publicIPName = Read-Host 'Enter the PUBLIC IP NAME'
                    }elseif($publicIPName -eq 'AUTO'){
                        $publicIPName = '{0}_IP' -f $name
                    }
                    $nicName = $xml.VM.NICName
                    if($nicName -eq 'ASK'){
                        $nicName = Read-Host 'Enter the NIC NAME'
                    }elseif($nicIPName -eq 'AUTO'){
                        $nicIPName = '{0}_NIC' -f $name
                    }
    }
}
Write-Host ('Starting build') -f Cyan
Write-Host ('  Name = {0}' -f $name) -f Cyan
Write-Host ('  Location = {0}' -f $location) -f Cyan
Write-Host ('  Resource Group Name = {0}' -f $resourceGroupName) -f Cyan
Write-Host ('  Storage Account Name = {0}' -f $storageAccountName) -f Cyan
Write-Host ('  Virtual Network Name = {0}' -f $virtualNetworkName) -f Cyan
Write-Host ('  Public IP Name = {0}' -f $publicIPName) -f Cyan
Write-Host ('  NIC Name = {0}' -f $nicName) -f Cyan

while((Get-AzureRmStorageAccountNameAvailability -Name $storageAccountName).NameAvailable -eq $false){
       $storageAccountName = Read-Host 'The storage name is not unique. Please enter another.'
} 
Write-Host ('  Creating Storage Account with name {0}' -f $storageAccountName) -f cyan 
$storageAccount = New-AzureRmStorageAccount -ResourceGroupName  $resourceGroupName -Name $storageAccountName -SkuName "Standard_LRS" -Kind "Storage" -Location $location 
#$mySubnet = New-AzureRmVirtualNetworkSubnetConfig -Name "mySubnet" -AddressPrefix 10.0.0.0/24 
Write-Host '  Getting Virtual Network' -f cyan
$vnet = Get-AzureRmVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName
Write-Host '  Getting Public IP Address' -f cyan
$publicIp = New-AzureRmPublicIpAddress -Name $publicIPName -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Dynamic 
Write-Host '  Getting NIC' -f cyan
$nIC = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $resourceGroupName -Location $location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $publicIp.Id 
$cred = Get-Credential -Message 'Enter the name and password for the Admin account'
Write-Host '  New VM Config' -f Cyan
$vm = New-AzureRmVMConfig -VMName $name -VMSize "Standard_DS1_v2" 
Write-Host '  Setting VM OS' -f Cyan
$vm = Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $name -Credential $cred -ProvisionVMAgent -EnableAutoUpdate 
Write-Host '  Setting VM Source Image' -f Cyan
$vm = Set-AzureRmVMSourceImage -VM $vm -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus "2012-R2-Datacenter" -Version "latest" 
Write-Host '  Adding NIC to the VM' -f Cyan
$vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id 
$vhdPath = "vhds/myOsDisk1.vhd" 
$osDiskUri = $storageAccount.PrimaryEndpoints.Blob.ToString() + $vhdPath 
Write-Host ('  Setting the OS Disk Drive to {0}' -f $osDiskUri) -f Cyan
$vm = Set-AzureRmVMOSDisk -VM $vm -Name "OsDisk1" -VhdUri $osDiskUri -CreateOption fromImage 
Write-Host '  Creating the VM' -f Cyan
New-AzureRmVM -ResourceGroupName $resourceGroupName -Location $location -VM $vm 
if($PsCmdlet.ParameterSetName -eq 'TemplateFile'){
    Set-Content $outPathName '<?xml version="1.0"?>'
    Add-Content $outPathName ('<VM>')
    Add-Content $outPathName ('<Name>{0}</Name>' -f $name)
    Add-Content $outPathName ('<Location>{0}</Location>' -f $location)
    Add-Content $outPathName ('<ResourceGroupName>{0}</ResourceGroupName>' -f $resourceGroupName)
    Add-Content $outPathName ('<StorageAccountName>{0}</StorageAccountName>' -f $storageAccountName)
    Add-Content $outPathName ('<VirtualNetworkName>{0}</VirtualNetworkName>' -f $virtualNetworkName)
    Add-Content $outPathName ('<PublicIPName>{0}</PublicIPName>' -f $publicIPName)
    Add-Content $outPathName ('<NICName>{0}</NICName>' -f $nicName)
    Add-Content $outPathName ('</VM>')
    Write-Host 'Output file created' -f Cyan
}
