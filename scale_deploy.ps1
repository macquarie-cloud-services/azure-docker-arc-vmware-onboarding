param(
    [Parameter(Mandatory = $true)]
    [string] $subscriptionId,
    [Parameter(Mandatory = $true)]
    [string] $servicePrincipalClientId,
    [Parameter(Mandatory = $true)]
    [string] $servicePrincipalSecret,
    [Parameter(Mandatory = $true)]
    [string] $tenantId,
    [Parameter(Mandatory = $true)]
    [string] $resourceGroup,
    [Parameter(Mandatory = $true)]
    [string] $location,
    [Parameter(Mandatory = $true)]
    [string] $vCenterAddress,
    [Parameter(Mandatory = $true)]
    [string] $vCenterUser,
    [Parameter(Mandatory = $true)]
    [string] $vCenterPassword,
    [Parameter(Mandatory = $true)]
    [string] $VMFolder,
    [Parameter(Mandatory = $true)]
    [string] $OSAdmin,
    [Parameter(Mandatory = $true)]
    [string] $OSPassword
)

$srcPath = "C:\arcOnboarding\"
# Create vars.sh filefor Linux VMs
Set-Content -Path .\vars.sh -Value "#!/bin/sh"
Add-Content -Path .\vars.sh -Value "export subscription_id=$subscriptionId"
Add-Content -Path .\vars.sh -Value "export client_id=$servicePrincipalClientId"
Add-Content -Path .\vars.sh -Value "export client_secret=$servicePrincipalSecret"
Add-Content -Path .\vars.sh -Value "export tenant_id=$tenantId"
Add-Content -Path .\vars.sh -Value "export resourceGroup=$resourceGroup"
Add-Content -Path .\vars.sh -Value "export location=$location"

# Connect to VMware vCenter
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
Connect-VIServer -Server $vCenterAddress -User $vCenterUser -Password $vCenterPassword -Force
$VMs = Get-Folder -Name $VMFolder | Get-VM

ForEach ($VMName in $VMs) {
  $VM = Get-VM $VMName
  If ($VM.GuestId -match "windows") {
    Write-Output "`nWindows VM $VMName found..."
    # Define scripts information
    $File1 = "install_arc_agent.ps1"
    $DstPath = "C:\arctemp\"
    $Fullpath1 = $srcPath + $File1

    Copy-VMGuestFile -VM $VM -Source ".\install_arc_agent.ps1" -Destination $DstPath -LocalToGuest -GuestUser $OSAdmin -GuestPassword $OSPassword -Force

    # Onboarding VM to Azure Arc
    $Command = $DstPath + $File1 + " -servicePrincipalClientId $servicePrincipalClientId -servicePrincipalSecret $servicePrincipalSecret -resourceGroup $resourceGroup -tenantId $tenantId -location $location -subscriptionId $subscriptionId"
    Write-Output "`nOnboarding $VMName Virtual Machine to Azure Arc..." -ForegroundColor Cyan 
    $Result = Invoke-VMScript -VM $VM -ScriptText $Command -GuestUser $OSAdmin -GuestPassword $OSPassword
    $ExitCode = $Result.ExitCode
    if ($ExitCode = "0") {
        Write-Output "$VMName is now successfully onboarded to Azure Arc"
    }
    Else {
        Write-Output "$VMName returned exit code $ExitCode"
    }
    $Delete = Invoke-VMScript -VM $VM -ScriptText "Remove-Item -Force -Recurse -Path $DstPath" -GuestUser $OSAdmin -GuestPassword $OSPassword
  }
  Else {
    Write-Output "`nLinux VM $VMName found..."
    # Onboarding VM to Azure Arc
    Write-Output "`nOnboarding $VMName Virtual Machine to Azure Arc..."
    Copy-VMGuestFile -VM $VM -Source ".\vars.sh" -Destination "/tmp/arctemp/" -LocalToGuest -GuestUser $OSAdmin -GuestPassword $OSPassword -Force
    Copy-VMGuestFile -VM $VM -Source ".\install_arc_agent.sh" -Destination "/tmp/arctemp/" -LocalToGuest -GuestUser $OSAdmin -GuestPassword $OSPassword -Force
    $Result = Invoke-VMScript -VM $VM -ScriptText "sudo bash /tmp/arctemp/install_arc_agent.sh" -GuestUser $OSAdmin -GuestPassword $OSPassword
    $ExitCode = $Result.ExitCode
    if ($ExitCode = "0") {
        Write-Output "$VMName is now successfully onboarded to Azure Arc"
    }
    Else {
        Write-Output "$VMName returned exit code $ExitCode"
    }

    # Cleaning garbage
    #$Delete = Invoke-VMScript -VM $VM -ScriptText "rm -rf /tmp/arctemp/" -GuestUser $OSAdmin -GuestPassword $OSPassword
  }
}
