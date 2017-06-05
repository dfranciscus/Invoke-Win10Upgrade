# Invoke-Win10Upgrade
Powershell module for remote in-place upgrades of Windows 7/8 to Windows 10.

# Overview
This module uses PowerShell and Microsoft Deployment Toolkit in order to remotely in-place upgrades domain-joined Windows machines to Windows 10. The main use case for this module is for organizations that do not use SCCM but want to the ability to remotely perform in-place upgrades. This module is a work around for the requirement of in-place upgrades with MDT that require interactive logons and to launch the litetouch.vbs script. To get around this requirement we use PowerShell and a Remote Desktop session to each computer, then launch litetouch.vbs with a scheduled task. This is admittedly a complete hack and I offer no guarantee to any user of this script. With that said, I plan on using this.

# Prerequisites
Computers must be joined to Active Directory<br>
Module should be used with at least Local Admin privledges on workstations and permission to the MDT share.<br>

Powershell modules:<br>
Microsoft.BDD.PSSnapIn (Snap-in) - Get from your MDT Server, C:\Program Files\Microsoft Deployment Toolkit\Bin

Microsoft Deployment Toolkit setup:<br>
https://technet.microsoft.com/en-US/windows/dn475741<br>
Use this guide to setup the Task Sequence<br>
https://technet.microsoft.com/en-us/itpro/windows/deploy/upgrade-to-windows-10-with-the-microsoft-deployment-toolkit



