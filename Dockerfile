FROM mcr.microsoft.com/windows/servercore:ltsc2019

ENV POWERCLI_VERSION 12.3.0.17860403

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

MKDIR C:\arc-onboarding
CD C:\arc-onboarding

RUN `
  Function Test-Nano() { `
    $EditionId = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'EditionID').EditionId; `
    return (($EditionId -eq 'ServerStandardNano') -or ($EditionId -eq 'ServerDataCenterNano') -or ($EditionId -eq 'NanoServer')); `
  }`
  `
  Function Download-File([string] $source, [string] $target) { `
    if (Test-Nano) { `
      $handler = New-Object System.Net.Http.HttpClientHandler; `
      $client = New-Object System.Net.Http.HttpClient($handler); `
      $client.Timeout = New-Object System.TimeSpan(0, 30, 0); `
      $cancelTokenSource = [System.Threading.CancellationTokenSource]::new(); `
      $responseMsg = $client.GetAsync([System.Uri]::new($source), $cancelTokenSource.Token); `
      $responseMsg.Wait(); `
      if (!$responseMsg.IsCanceled) { `
        $response = $responseMsg.Result; `
        if ($response.IsSuccessStatusCode) { `
          $downloadedFileStream = [System.IO.FileStream]::new($target, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write); `
          $copyStreamOp = $response.Content.CopyToAsync($downloadedFileStream); `
          $copyStreamOp.Wait(); `
          $downloadedFileStream.Close(); `
          if ($copyStreamOp.Exception -ne $null) { throw $copyStreamOp.Exception } `
        } `
      } else { `
      Throw ("Failed to download " + $source) `
      }`
    } else { `
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; `
      $webClient = New-Object System.Net.WebClient; `
      $webClient.DownloadFile($source, $target); `
    } `
  } `
  `
  Write-Host INFO: Downloading scale_deploy.ps1...; `
  $location1='https://raw.githubusercontent.com/rphoon/azure-docker-arc-vmware-onboarding/main/scale_deploy.ps1; `
  Download-File $location1 C:\arc-onboarding\scale_deploy.ps1; `
  `
  Write-Host INFO: Downloading install_arc_agent.ps1...; `
  $location2='https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_servers_jumpstart/vmware/scaled_deployment/powercli/windows/install_arc_agent.ps1; `
  Download-File $location2 C:\arc-onboarding\install_arc_agent.ps1;

RUN `
  Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force ; \
  Install-Module -Name VMware.PowerCLI -RequiredVersion $env:POWERCLI_VERSION -Force ; \
  Import-Module VMware.PowerCli ; \
  Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCeip $false -Confirm:$false

ENTRYPOINT [ "powershell.exe" ]
