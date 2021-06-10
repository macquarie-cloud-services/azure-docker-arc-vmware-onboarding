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

# Connect to VMware vCenter
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
Connect-VIServer -Server $vCenterAddress -User $vCenterUser -Password $vCenterPassword -Force
$VMs = Get-Folder -Name $VMFolder | Get-VM

ForEach ($VMName in $VMs) {
  $VM = Get-VM $VMName

  # Define scripts information
  $File1 = "install_arc_agent.ps1"
  $srcPath = "C:\arcOnboarding\"
  $DstPath = "C:\arctemp\"
  $Fullpath1 = $srcPath + $File1

  Copy-VMGuestFile -VM $VM -Source $Fullpath1 -Destination $DstPath -LocalToGuest -GuestUser $OSAdmin -GuestPassword $OSPassword -Force

  # Onboarding VM to Azure Arc
  $Command = $DstPath + $File1 + " -servicePrincipalClientId $servicePrincipalClientId -servicePrincipalSecret $servicePrincipalSecret -resourceGroup $resourceGroup -tenantId $tenantId -location $location -subscriptionId $subscriptionId"
  Write-Output "`nOnboarding $VMName Virtual Machine to Azure Arc..." -ForegroundColor Cyan 
  $Result = Invoke-VMScript -VM $VM -ScriptText $Command -GuestUser $OSAdmin -GuestPassword $OSPassword
  $ExitCode = $Result.ExitCode
  if ($ExitCode = "0") {
    Write-Output $VMName is now successfully onboarded to Azure Arc -ForegroundColor Green
  }
  Else {
    Write-Output $VMName returned exit code $ExitCode -ForegroundColor Red
  }
  $Delete = Invoke-VMScript -VM $VM -ScriptText "Remove-Item -Force -Recurse -Path $DstPath" -GuestUser $OSAdmin -GuestPassword $OSPassword
}
