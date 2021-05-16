Function Set-AppxPackages
{
    [CmdletBinding()]
    Param
    (
        $AppxConfigFilePath
    )

    Begin
    {
        $result = $true
        $source = $PSCmdlet.MyInvocation.MyCommand.ToString() -replace ("Set-","")
        New-EventLog -Source $source -LogName 'Virtual Desktop Optimization' -ErrorAction SilentlyContinue
    }

    Process
    {
        If (Test-Path $AppxConfigFilePath)
        {
            $Message = ("[VDI Optimize] AppxPackages")
            Write-EventLog -EventId 20 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information 
            Write-Progress -ParentId 1 -Id 20 -Activity "AppxPackages"
            Write-Verbose $Message
            $AppxPackage = (Get-Content $AppxConfigFilePath | ConvertFrom-Json).Where( { $_.VDIState -eq 'Disabled' })
            If ($AppxPackage.Count -gt 0)
            {
                $i = 0
                Foreach ($Item in $AppxPackage)
                {
                    try
                    {
                        $Message = ("Removing Provisioned Package: {0}" -f $Item.AppxPackage)
                        Write-Progress -ParentId 1 -Id 20 -Activity ("AppxPackages") -CurrentOperation $Message -Status ("Working on item {0} of {1}" -f $i, $AppxPackage.Count) -PercentComplete (($i / $AppxPackage.Count) * 100)
                        Write-EventLog -EventId 20 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information 
                        Write-Verbose "`t$Message"
                        Get-AppxProvisionedPackage -Online -Verbose:$false | Where-Object { $_.PackageName -like ("*{0}*" -f $Item.AppxPackage) } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
                        
                        $Message = ("Removing 'AllUsers' Package: {0} - {1}" -f $Item.AppxPackage, $Item.Description)
                        Write-Progress -ParentId 1 -Id 20 -Activity ("AppxPackages") -CurrentOperation $Message -Status ("Working on item {0} of {1}" -f $i, $AppxPackage.Count) -PercentComplete (($i / $AppxPackage.Count) * 100)
                        Write-EventLog -EventId 20 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information 
                        Write-Verbose "`t$Message"
                        Get-AppxPackage -AllUsers -Name ("*{0}*" -f $Item.AppxPackage) -Verbose:$false | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                        
                        $Message = ("Removing Package: {0} - {1}" -f $Item.AppxPackage, $Item.Description)
                        Write-Progress -ParentId 1 -Id 20 -Activity ("AppxPackages") -CurrentOperation $Message -Status ("Working on item {0} of {1}" -f $i, $AppxPackage.Count) -PercentComplete (($i / $AppxPackage.Count) * 100)
                        Write-EventLog -EventId 20 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information 
                        Write-Verbose "`t$Message"
                        Get-AppxPackage -Name ("*{0}*" -f $Item.AppxPackage) -Verbose:$false | Remove-AppxPackage -ErrorAction SilentlyContinue | Out-Null
                    }
                    catch 
                    {
                        $Message = ("Failed to remove: {0} - {1}" -f $Item.AppxPackage, $_.Exception.Message)
                        Write-EventLog -EventId 120 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Error 
                        Write-Warning "`t$Message"
                        $result = $false
                    }
                    $i++
                }
            }
            Else 
            {
                Write-EventLog -EventId 20 -Message "No AppxPackages found to disable" -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning 
                Write-Warning "`tNo AppxPackages found to disable in $AppxConfigFilePath"
                $result = $false
            }
        }
        Else 
        {
            Write-EventLog -EventId 20 -Message "Configuration file not found - $AppxConfigFilePath" -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning 
            Write-Warning "`tConfiguration file not found -  $AppxConfigFilePath"
            $result = $false
        }
    }

    End
    {
        Write-Progress -ParentId 1 -Id 20 -Activity ("[VDI Optimize] AppxPackages") -Completed
        # If (Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\VDIOptimize -Name $source)
        # {
        #     Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\VDIOptimize -Name $source -Value $result
        # }
        # Else
        # {
        #     New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\VDIOptimize -Name $source -Value $result
        # }
        Return $result
    }
}