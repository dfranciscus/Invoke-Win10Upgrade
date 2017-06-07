# Invoke-Win10Upgrade
Powershell module for remote in-place upgrades of Windows 7/8 to Windows 10.

# Overview
This module uses PowerShell and Microsoft Deployment Toolkit in order to remotely in-place upgrades domain-joined Windows machines to Windows 10. The main use case for this module is for organizations that do not use SCCM but want to the ability to remotely perform in-place upgrades. This module is a work around for the requirement of in-place upgrades with MDT that require interactive logons and to launch the litetouch.vbs script. To get around this requirement we use PowerShell and a Remote Desktop session to each computer, then launch litetouch.vbs with a scheduled task. This is admittedly a complete hack and I offer no guarantee to any user of this script. With that said, I plan on using this.

# Prerequisites
Computers must be joined to Active Directory<br>
Module should be used with at least Local Admin privledges on workstations and permission to the MDT share.<br>

Microsoft Deployment Toolkit setup:<br>
https://technet.microsoft.com/en-US/windows/dn475741<br>
Use this guide to setup the Task Sequence<br>
https://technet.microsoft.com/en-us/itpro/windows/deploy/upgrade-to-windows-10-with-the-microsoft-deployment-toolkit

# Bootstrap and Customsettings
Change values for deployroot, userdomain,userid,userpassword,eventservice,timezone,tasksequence,tasksequencebuild

#Bootstrap.ini:

[Settings]
Priority=Default

[Default]
DeployRoot=MDTShare
SkipBDDWelcome=YES
UserDomain=DOMAIN
UserID=User
UserPassword=Password

#CustomSettings.ini:

[Settings]
Priority=Default
Properties=MyCustomProperty

[Default]
OSInstall=Y
SkipCapture=NO
SkipAdminPassword=YES
SkipProductKey=YES
SkipComputerBackup=NO
SkipBitLocker=YES
EventService=MDT service
FinishAction=REBOOT
ApplyGPOPack=NO
SkipLocaleSelection=YES
SkipAppsOnUpgrade=YES
SkipDomainMembership=YES
SkipComputerName=YES
SkipTimeZone=YES
TimeZoneName=Eastern Standard Time
TimeZone=035
SkipSummary=YES
SkipFinalSummary=YES
SkipUserData=YES
SkipTaskSequence=YES
TaskSequenceID=WIN10-INPLACE
BuildID=WIN10-INPLACE



