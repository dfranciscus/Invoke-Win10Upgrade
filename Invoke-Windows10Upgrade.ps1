#requires -Version 4
#requires -RunAsAdministrator
function Invoke-Windows10Upgrade {
    [CmdletBinding()]
    param
	(
	[Parameter(Mandatory=$true)]
	[String[]]$ComputerName,
        [Parameter(Mandatory=$true)]
        [PSCredential]$Credential,
        [Parameter(Mandatory=$false)]
        [String]$MDTLiteTouchPath, 
        [Parameter(Mandatory=$false)]
        [String]$MDTComputerName, 
        [Parameter(Mandatory=$false)]
        [String]$MDTRoot,
        [Parameter(Mandatory=$False)]
        [Switch]$AllowRDP,
        [Parameter(Mandatory=$False)]
        [Switch]$DisableRDP,
        [Parameter(Mandatory=$False)]
        [Switch]$AllowRegUpgrade
	)
    process
    {
        #Test to ensure computers are online and return only those that can be pinged
        workflow Test-Ping 
        {
            param( 
                [Parameter(Mandatory=$true)] 
                [string[]]$Computers
            )
                foreach -parallel -throttlelimit 150 ($Computer in $Computers) 
                {
                    if (Test-Connection -Count 1 $Computer -Quiet -ErrorAction SilentlyContinue) 
                    {    
                        $Computer
                    }
                    else
                    {
                        Write-Warning -Message "$Computer not online"
                    }
                }
         }
        $ComputerName = Test-Ping -Computers $ComputerName 
        if (!$ComputerName)
        {
            Write-Warning -Message 'No computers are online. Exiting.'
            Break
        }

        #Restart all computers
        Restart-Computer -ComputerName $ComputerName -Force -Wait -For powershell -Timeout 600

        #Create Scheduled task on remote computers
        $STUserName = $Credential.UserName

        Invoke-Command -ComputerName $ComputerName -ArgumentList {$STUsername,$MDTLiteTouchPath} -ScriptBlock {
            schtasks.exe /ru $Using:STUserName /create /tn 'Upgrade to Windows 10' /tr "powershell -command Start-Process -FilePath cscript -ArgumentList $Using:MDTLiteTouchPath" /sc onlogon /RL HIGHEST /f /IT /DELAY 0000:30 
        } 
        
        #Allow RDP
        if ($AllowRDP)
        {
            Invoke-Command –Computername $ComputerName –ScriptBlock {
                Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" –Value 0
                Netsh advfirewall firewall set rule group=”remote desktop” new enable=yes }
        } 

        #Allow disableosupgrade in registry
        if ($AllowRegUpgrade)
        {
             Invoke-Command –Computername $ComputerName –ScriptBlock {
                gpupdate /force | Out-Null
                Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate" -Name "DisableOSUpgrade" –Value 0 }
        }
		
		#Remove old deployment logs
		Invoke-Command -ComputerName $ComputerName -ScriptBlock {
				Remove-Item 'C:\Windows\Temp\DeploymentLogs' -Recurse -Force -Confirm:$False -ErrorAction SilentlyContinue
        }
                  
        #RDP using workflow into all computers in $ComputerName
        workflow Connect-RDP
        {
            param(
            [Parameter(Mandatory=$true)]
            [string[]]$RDPComputers,
            [Parameter(Mandatory=$true)]
            [pscredential]$RDPCredential
            )
            $RDPUser = $RDPCredential.UserName
            $RDPPassword = $RDPCredential.GetNetworkCredential().Password
            
            foreach -parallel -Throttlelimit 150 ($RDPComputer in $RDPComputers)
            {
                cmdkey.exe /generic:TERMSRV/$RDPComputer /user:$RDPUser /pass:$RDPPassword
                Start-Process -FilePath mstsc.exe -ArgumentList "/v $RDPComputer" 
            }
        }
        #Put start time in variable for MDT monitoring
        $StartTime =  (Get-Date).ToUniversalTime()
        Connect-RDP -RDPComputers $ComputerName -RDPCredential $Credential 
        #Sleep to wait for litetouch to start
        Start-Sleep -seconds 300

        #Remove scheduled task
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        schtasks.exe /Delete /TN 'Upgrade to Windows 10' /F  
        }
        #Get end time for filtering MDT results
        $EndStartTime =  (Get-Date).ToUniversalTime()

        #Monitor MDT results
        try 
        {
            $Results = Invoke-Command -ComputerName $MDTComputerName -ArgumentList $MDTRoot,$StartTime,$EndStartTime -ErrorAction Stop -ScriptBlock {
                Add-PSSnapin Microsoft.BDD.PSSnapIn | Out-null
                New-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root $Using:MDTRoot | out-null
                Get-MDTMonitorData -Path DS001: | Where-Object {$_.PercentComplete -ne '100' -and $_.StartTime -gt $Using:StartTime -and $_.StartTime -lt $Using:EndStartTime -and $_.DeploymentStatus -eq '1'} | Select-Object name,percentcomplete,errors,starttime | Sort-Object -Property starttime -Descending | Format-Table -AutoSize }
            if (!$Results)
            {
                Write-Warning -Message 'No MDT Monitoring data found. Investigate and press enter to continue'
                Read-Host "Press enter to continue"
            }
        }
        catch 
        {
            Write-Error $_
            Read-Host "Press enter to continue" 
        }
        #Get end time for filtering MDT results
        $EndStartTime = (Get-Date).ToUniversalTime()
        While ($AllDone -ne '1')
        {
            $Results = $Null
            $Results = Invoke-Command -ComputerName $MDTComputerName -ArgumentList $MDTRoot,$StartTime,$EndStartTime -ErrorAction Stop -ScriptBlock {
                Add-PSSnapin Microsoft.BDD.PSSnapIn | Out-null
                New-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root $Using:MDTRoot | Out-null
                Get-MDTMonitorData -Path DS001: | Where-Object {$_.StartTime -gt $Using:StartTime -and $_.StartTime -lt $Using:EndStartTime -and $_.EndTime -eq $null} | Select-Object name,percentcomplete,errors,starttime | Sort-Object -Property starttime -Descending | Format-Table -AutoSize }
            if ($Results)
            {
                  Invoke-Command -ComputerName $MDTComputerName -ArgumentList $MDTRoot,$StartTime,$EndStartTime -ErrorAction Stop -ScriptBlock {
                      Add-PSSnapin Microsoft.BDD.PSSnapIn | Out-null
                      New-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root $Using:MDTRoot | Out-null 
                      Get-MDTMonitorData -Path DS001: | Where-Object {$_.StartTime -gt $Using:StartTime -and $_.StartTime -lt $Using:EndStartTime} | Select-Object name,percentcomplete,errors,starttime | Sort-Object -Property starttime -Descending | Format-Table -Property @{Expression={$_.StartTime.ToLocalTime()};Label="StartTime"},name,percentcomplete,errors -AutoSize }
            }
            else 
            {
                $AllDone = '1'
                Write-Warning -Message 'Deployment Complete'
            }
            Start-Sleep -Seconds 60
             $Results = Invoke-Command -ComputerName $MDTComputerName -ArgumentList $MDTRoot,$StartTime,$EndStartTime -ErrorAction Stop -ScriptBlock {
                Add-PSSnapin Microsoft.BDD.PSSnapIn | Out-null
                New-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root $Using:MDTRoot | out-null
                Get-MDTMonitorData -Path DS001: | Where-Object { $_.StartTime -gt $Using:StartTime -and $_.StartTime -lt $Using:EndStartTime} | Select-Object * | Sort-Object -Property starttime -Descending | Format-List }
        }
        
        #Disable RDP
        if ($DisableRDP)
        {
            Invoke-Command –Computername $ComputerName –ScriptBlock {
               Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 1
               Netsh advfirewall firewall set rule group=”remote desktop” new enable=no }
        }   

    }
}
