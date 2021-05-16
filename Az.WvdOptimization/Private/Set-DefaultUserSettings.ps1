Function Set-DefaultUserSettings
{
    [CmdletBinding()]
    Param
    (
        $DefaultUserSettingsFilePath
    )

    Begin
    {
        $result = $true
        $source = $PSCmdlet.MyInvocation.MyCommand.ToString() -replace ("Set-","")
        New-EventLog -Source $source -LogName 'Virtual Desktop Optimization' -ErrorAction SilentlyContinue
    }

    Process
    {
        If (Test-Path $DefaultUserSettingsFilePath)
        {
            $Message = ("[VDI Optimize] DefaultUserSettings")
            Write-EventLog -EventId 40 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information
            Write-Progress -ParentId 1 -Id 40 -Activity "DefaultUserSettings"
            Write-Verbose $Message
            $UserSettings = (Get-Content $DefaultUserSettingsFilePath | ConvertFrom-Json).Where( { $_.SetProperty -eq $true })
            If ($UserSettings.Count -gt 0)
            {
                & REG LOAD HKLM\VDOT_TEMP C:\Users\Default\NTUSER.DAT | Out-Null

                $i = 0
                Foreach ($Item in $UserSettings)
                {
                    If ($Item.PropertyType -eq "BINARY")
                    {
                        $Value = [byte[]]($Item.PropertyValue.Split(","))
                    }
                    Else
                    {
                        $Value = $Item.PropertyValue
                    }

                    If (Test-Path -Path ("{0}" -f $Item.HivePath))
                    {
                        $Message = ("Found Registry Path and Key: {0}{1}" -f $Item.HivePath, $Item.KeyName)
                        Write-Progress -ParentId 1 -Id 40 -Activity ("DefaultUserSettings") -CurrentOperation $Message -Status ("Working on item {0} of {1}" -f $i, $UserSettings.Count) -PercentComplete (($i / $UserSettings.Count) * 100)
                        Write-EventLog -EventId 40 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information        
                        Write-Verbose "`t$Message"
                        If (Get-ItemProperty -Path ("{0}" -f $Item.HivePath) -ErrorAction SilentlyContinue)
                        {
                            $Message = ("Setting Registry Entry: {0}{1} = {2}" -f $Item.HivePath, $Item.KeyName, $Value)
                            Write-Progress -ParentId 1 -Id 40 -Activity ("DefaultUserSettings") -CurrentOperation $Message -Status ("Working on item {0} of {1}" -f $i, $UserSettings.Count) -PercentComplete (($i / $UserSettings.Count) * 100)
                            Write-EventLog -EventId 40 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information
                            Write-Verbose "`t$Message"
                            Set-ItemProperty -Path ("{0}" -f $Item.HivePath) -Name $Item.KeyName -Value $Value -Force 
                        }
                        Else
                        {
                            $Message = ("Creating Registry Entry: {0}{1} = {2}" -f $Item.HivePath, $Item.KeyName, $Value)
                            Write-Progress -ParentId 1 -Id 40 -Activity ("DefaultUserSettings") -CurrentOperation $Message -Status ("Working on item {0} of {1}" -f $i, $UserSettings.Count) -PercentComplete (($i / $UserSettings.Count) * 100)
                            Write-EventLog -EventId 40 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information
                            Write-Verbose "`t$Message"
                            New-ItemProperty -Path ("{0}" -f $Item.HivePath) -Name $Item.KeyName -PropertyType $Item.PropertyType -Value $Value -Force | Out-Null
                        }
                    }
                    Else
                    {
                        $Message = ("Registry path not found, creating key and value: {0}{1} = {2} ({3})" -f $Item.HivePath, $Item.KeyName, $Value, $Item.PropertyType)
                        Write-Progress -ParentId 1 -Id 40 -Activity ("DefaultUserSettings") -CurrentOperation $Message -Status ("Working on item {0} of {1}" -f $i, $UserSettings.Count) -PercentComplete (($i / $UserSettings.Count) * 100)
                        Write-EventLog -EventId 40 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information
                        Write-Verbose "`t$Message"
                        $newKey = New-Item -Path ("{0}" -f $Item.HivePath) -Force
                        If (Test-Path -Path $newKey.PSPath)
                        {
                            New-ItemProperty -Path ("{0}" -f $Item.HivePath) -Name $Item.KeyName -PropertyType $Item.PropertyType -Value $Value -Force | Out-Null
                        }
                        Else
                        {
                            $Message = ("Failed to create new Registry Entry: {0}{1} = {2} ({3})" -f $Item.HivePath, $Item.KeyName, $Value, $Item.PropertyType)
                            Write-EventLog -EventId 140 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Error
                            Write-Warning "`t$Message"
                            $result = $false
                        } 
                    }
                    $i++
                }
                & REG UNLOAD HKLM\VDOT_TEMP > nul
            }
            Else
            {
                Write-EventLog -EventId 45 -Message "No Default User Settings to set" -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning
                Write-Warning ("`tNo Default User Settings to set in $DefaultUserSettingsFilePath")
                $result = $false
            }
        }
        Else
        {
            Write-EventLog -EventId 45 -Message "File not found: $DefaultUserSettingsFilePath" -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning
            Write-Warning ("`tFile not found: $DefaultUserSettingsFilePath")
            $result = $false
        }
    }

    End
    {
        Write-Progress -ParentId 1 -Id 40 -Activity ("[VDI Optimize] DefaultUserSettings") -Completed
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