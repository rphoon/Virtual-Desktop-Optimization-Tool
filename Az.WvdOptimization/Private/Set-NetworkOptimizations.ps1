Function Set-NetworkOptimizations
{
    [CmdletBinding()]
    Param
    (
        $NetworkConfigFilePath
    )

    Begin
    {
        $result = $true
        $source = $PSCmdlet.MyInvocation.MyCommand.ToString() -replace ("Set-","")
        New-EventLog -Source $source -LogName 'Virtual Desktop Optimization' -ErrorAction SilentlyContinue
    }

    Process
    {
        If (Test-Path $NetworkConfigFilePath)
        {
            $Message = ("[VDI Optimize] NetworkOptimizations")
            Write-EventLog -EventId 70 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information 
            Write-Progress -ParentId 1 -Id 70 -Activity "NetworkOptimizations"
            Write-Verbose $Message
            $NetworkkSettings = (Get-Content $NetworkConfigFilePath | ConvertFrom-Json).Where( { $_.SetProperty -eq $true } )
            If ($NetworkkSettings.Count -gt 0)
            {
                $i = 0
                Foreach ($Item in $NetworkkSettings)
                {
                    If (Test-Path -Path $Item.HivePath)
                    {
                        $Message = ("Found Registry Path: {0}" -f $Item.HivePath)
                        Write-Progress -ParentId 1 -Id 70 -Activity ("NetworkOptimizations") -CurrentOperation $Message -Status ("Working on item {0} of {1}" -f $i, $NetworkkSettings.Count) -PercentComplete (($i / $NetworkkSettings.Count) * 100)
                        Write-EventLog -EventId 70 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information        
                        Write-Verbose "`t$Message"
                        
                        If (Get-ItemProperty -Path $Item.HivePath -Name $Item.KeyName -ErrorAction SilentlyContinue)
                        {
                            $Message = ("Setting Registry Entry: {0}{1} = {2}" -f $Item.HivePath, $Item.KeyName, $Item.PropertyValue)
                            Write-Progress -ParentId 1 -Id 70 -Activity ("NetworkOptimizations") -CurrentOperation $Message -Status ("Working on item {0} of {1}" -f $i, $NetworkkSettings.Count) -PercentComplete (($i / $NetworkkSettings.Count) * 100)
                            Write-EventLog -EventId 40 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information
                            Write-Verbose "`t$Message"
                            Set-ItemProperty -Path $Item.HivePath -Name $Item.KeyName -Value $Item.PropertyValue -Force
                        }
                        Else
                        {
                            $Message = ("Creating Registry Entry: {0}{1} = {2}" -f $Item.HivePath, $Item.KeyName, $Item.PropertyValue)
                            Write-Progress -ParentId 1 -Id 70 -Activity ("NetworkOptimizations") -CurrentOperation $Message -Status ("Working on item {0} of {1}" -f $i, $NetworkkSettings.Count) -PercentComplete (($i / $NetworkkSettings.Count) * 100)
                            Write-EventLog -EventId 70 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information
                            Write-Verbose "`t$Message"
                            New-ItemProperty -Path $Item.HivePath -Name $Item.KeyName -PropertyType $Key.PropertyType -Value $Item.PropertyValue -Force | Out-Null
                        } 
                    }
                    Else
                    {
                        $Message = ("Registry path not found: {0}{1}" -f $Item.HivePath, $Item.KeyName)
                        Write-EventLog -EventId 170 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Error
                        Write-Warning "`t$Message"
                        $result = $false
                    }
                    $i++
                }
            }
            Else
            {
                Write-EventLog -EventId 75 -Message "No Network Settings to set" -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning
                Write-Warning "`tNo Network Settings to set in $NetworkConfigFilePath"
                $result = $false
            }
        }
        Else
        {
            Write-EventLog -EventId 75 -Message "File not found - $NetworkConfigFilePath" -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning
            Write-Warning "`tFile not found - $NetworkConfigFilePath"
            $result = $false
        }

        # NIC Advanced Properties performance settings for network biased environments
        $Message = ("Set Network Buffer Size to 4MB")
        Write-Progress -ParentId 1 -Id 70 -Activity ("NetworkOptimizations") -CurrentOperation $Message
        Write-EventLog -EventId 70 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information
        Write-Verbose "`t$Message"
        Set-NetAdapterAdvancedProperty -DisplayName "Send Buffer Size" -DisplayValue 4MB
    }

    End
    {
        Write-Progress -ParentId 1 -Id 70 -Activity ("[VDI Optimize] NetworkOptimizations") -Completed
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