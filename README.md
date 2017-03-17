# PSInPlaceWindows10Upgrade
Powershell module for remote in-place upgrades of Windows 7/8 to Windows 10.

# Overview
This module will use a combination of tools including Powershell, PSExec, and Microsoft Deployment Toolkit in order to remotely in-place upgrades domain-joined Windows machines to Windows 10. The main use case for this module is a work around for the requirement of in-place upgrades with MDT that require interactive logons and to launch the litetouch.vbs script. To get around this requirement we use PowerShell workflow and Connect-Mstsc to launch a Remote Desktop session to each computer, then launch litetouch.vbs with PSExec. This is admittedly a complete hack and I offer no guarantee to any user of this module. With that said, I plan on using this.

# Prerequisites
Powershell modules:<br>
PSTerminalServices - https://psterminalservices.codeplex.com/<br>
Connect-Mstsc - https://gallery.technet.microsoft.com/scriptcenter/Connect-Mstsc-Open-RDP-2064b10b<br>
Microsoft.BDD.PSSnapIn (Snap-in) - Get from your MDT Server, C:\Program Files\Microsoft Deployment Toolkit\Bin

Microsoft Deployment Toolkit setup:<br>
https://technet.microsoft.com/en-US/windows/dn475741<br>
Use this guide to setup the Task Sequence<br>
https://technet.microsoft.com/en-us/itpro/windows/deploy/upgrade-to-windows-10-with-the-microsoft-deployment-toolkit



