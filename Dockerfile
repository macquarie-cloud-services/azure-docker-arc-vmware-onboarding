FROM mcr.microsoft.com/windows/servercore:ltsc2019
ENV POWERCLI_VERSION 12.3.0.17860403
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force ; \
  Install-Module -Name VMware.PowerCLI -RequiredVersion $env:POWERCLI_VERSION -Force ; \
  Import-Module VMware.PowerCli ; \
  Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCeip $false -Confirm:$false

ENTRYPOINT [ "powershell.exe" ]
