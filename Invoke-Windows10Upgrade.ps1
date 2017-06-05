function Invoke-Windows10Upgrade {
    param
	(
		[Parameter(Mandatory=$true)]
		[String[]]$ComputerName,
        [Parameter(Mandatory=$true)]
        [PSCredential]$Credential,
        [Parameter(Mandatory=$true)]
        [String]$MDTLiteTouchPath
	)
    process
    {
        workflow Test-Ping 
        {
            param(  
                [string[]]$Computers
            )
                foreach -parallel -throttlelimit 150 ($Computer in $Computers) 
                {
                    if (Test-Connection -Count 1 $Computer -Quiet -ErrorAction SilentlyContinue) 
                    {    
                        $Computer
                    }
                }
         }
            $ComputerName = Test-Ping -Computers $ComputerName 

            #Restart all computers
            Restart-Computer -ComputerName $ComputerName -Force -Wait -For powershell -Timeout 300

            #Create Scheduled task on remote computers
            $STUserName = $Credential.UserName
            #$STPassword = $Credential.GetNetworkCredential().Password

                Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                     schtasks.exe /ru $Using:STUserName /create /tn 'Upgrade to Windows 10' /tr "cscript $Using:MDTLiteTouchPath" /sc onlogon /RL HIGHEST /f /IT /DELAY 0000:30 
                } -ArgumentList {$STUsername,$MDTLiteTouchPath}
            
            #RDP using workflow into all computers in $ComputerName
            workflow Connect-RDP
            {
                param(
                [string[]]$RDPComputers,
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
            Connect-RDP -RDPComputers $ComputerName -RDPCredential $Credential

            #Remove scheduled task
            Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                schtasks.exe /Delete /TN 'Upgrade to Windows 10' /F
              }
    }
}



