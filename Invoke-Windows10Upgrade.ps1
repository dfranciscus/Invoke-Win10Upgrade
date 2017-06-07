function Invoke-Win10Upgrade {
    [CmdletBinding()]
    param
	(
	[Parameter(Mandatory=$true)]
	[String[]]$ComputerName,
        [Parameter(Mandatory=$true)]
        [PSCredential]$Credential,
        [Parameter(Mandatory=$true)]
        [String]$MDTLiteTouchPath,
        [Parameter(Mandatory=$true)]
        [String]$MDTComputerName,
        [Parameter(Mandatory=$true)]
        [String]$MDTRoot,
        [Parameter(Mandatory=$False)]
        [Switch]$AllowRDP,
        [Parameter(Mandatory=$False)]
        [Switch]$DisableRDP 
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

        #Restart all computers
        Restart-Computer -ComputerName $ComputerName -Force -Wait -For powershell -Timeout 300

        #Create Scheduled task on remote computers
        $STUserName = $Credential.UserName

        Invoke-Command -ComputerName $ComputerName -ArgumentList {$STUsername,$MDTLiteTouchPath} -ScriptBlock {
            schtasks.exe /ru $Using:STUserName /create /tn 'Upgrade to Windows 10' /tr "cscript $Using:MDTLiteTouchPath" /sc onlogon /RL HIGHEST /f /IT /DELAY 0000:30 
        } 
        
	    Write-Output 'Allow RDP'
        #Allow RDP
      <#  if ($AllowRDP)
        {
            Invoke-Command –Computername $ComputerName –ScriptBlock {
                Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" –Value 0
                Netsh advfirewall firewall set rule group=”remote desktop” new enable=yes 
			}
        } #>
        
        Write-Output 'Connect RDP'
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
                #Connect-Mstsc -ComputerName $RDPComputer -Credential $RDPCredential -Admin -Erroraction stop
            }
        }
        #Put start time in variable for MDT monitoring
        $StartTime =  (Get-Date).ToUniversalTime()
        Connect-RDP -RDPComputers $ComputerName -RDPCredential $Credential 
        #Sleep to wait for litetouch to start
        Write-Output 'Sleep'
        Start-Sleep -seconds 120

        Write-Output 'Monitor MDT'
        #Monitor MDT results
        try 
        {
            $Results = Invoke-Command -ComputerName $MDTComputerName -ArgumentList $MDTRoot,$StartTime -ErrorAction Stop -ScriptBlock {
                Add-PSSnapin Microsoft.BDD.PSSnapIn | Out-null
                New-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root $Using:MDTRoot | out-null
                Get-MDTMonitorData -Path DS001: | Where-Object {$_.PercentComplete -ne '100' -and $_.StartTime -gt $Using:StartTime} | Select-Object name,percentcomplete,errors,starttime | Sort-Object -Property starttime -Descending | Format-Table -AutoSize }
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

        While ($AllDone -ne '1')
        {
            $Results = Invoke-Command -ComputerName $MDTComputerName -ArgumentList $MDTRoot,$StartTime -ErrorAction Stop -ScriptBlock {
                Add-PSSnapin Microsoft.BDD.PSSnapIn | Out-null
                New-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root $Using:MDTRoot | Out-null
                Get-MDTMonitorData -Path DS001: | Where-Object {$_.PercentComplete -ne '100' -and $_.StartTime -gt $Using:StartTime} | Select-Object name,percentcomplete,errors,starttime | Sort-Object -Property starttime -Descending | Format-Table -AutoSize }
            if ($Results)
            {
                  Invoke-Command -ComputerName $MDTComputerName -ArgumentList $MDTRoot,$StartTime -ErrorAction Stop -ScriptBlock {
                      Add-PSSnapin Microsoft.BDD.PSSnapIn | Out-null
                      New-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root $Using:MDTRoot | Out-null 
                      Get-MDTMonitorData -Path DS001: | Where-Object {$_.StartTime -gt $Using:StartTime} | Select-Object name,percentcomplete,errors,starttime | Sort-Object -Property starttime -Descending | Format-Table -AutoSize }
            }
            else 
            {
                $AllDone -eq '1'
                Write-Warning -Message 'Deployment Complete'
            }
            Start-Sleep -Seconds 60
        }

        #Remove scheduled task
        Write-Output 'Remove Scheduled Task'
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        schtasks.exe /Delete /TN 'Upgrade to Windows 10' /F  
        }
        #Disable RDP
      <#  if ($DisableRDP)
        {
            Invoke-Command –Computername $ComputerName –ScriptBlock {
               Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" –Value 1
               Netsh advfirewall firewall set rule group=”remote desktop” new enable=no  
               }
        } #>
        
    }
}



