Function Set-AutoLoggers
{
    [CmdletBinding()]
    Param
    (
        $AutoLoggersFilePath
    )

    Begin
    {
        $result = $true
        $source = $PSCmdlet.MyInvocation.MyCommand.ToString() -replace ("Set-","")
        New-EventLog -Source $source -LogName 'Virtual Desktop Optimization' -ErrorAction SilentlyContinue
    }

    Process
    {
        If (Test-Path $AutoLoggersFilePath)
        {
            $Message = ("[VDI Optimize] AutoLoggers")
            Write-EventLog -EventId 50 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information
            Write-Progress -ParentId 1 -Id 50 -Activity "AutoLoggers"
            Write-Verbose $Message
            $DisableAutologgers = (Get-Content $AutoLoggersFilePath | ConvertFrom-Json).Where( { $_.Disabled -eq 'True' })
            If ($DisableAutologgers.count -gt 0)
            {
                $i = 0
                #Write-EventLog -EventId 50 -Message "Disable AutoLoggers" -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information
                #Write-Verbose "Processing Autologger Configuration File"
                Foreach ($Item in $DisableAutologgers)
                {
                    $Message = ("Updating Registry Key for: {0}" -f $Item.KeyName)
                    Write-Progress -ParentId 1 -Id 50 -Activity ("AutoLoggers") -CurrentOperation $Message -Status ("Working on item: {0} of {1}" -f $i, $DisableAutologgers.Count) -PercentComplete (($i / $DisableAutologgers.Count) * 100)
                    Write-EventLog -EventId 50 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information
                    Write-Verbose "`t$Message"
                    New-ItemProperty -Path ("{0}" -f $Item.KeyName) -Name "Start" -PropertyType "DWORD" -Value 0 -Force | Out-Null
                    Start-Sleep -Milliseconds 499
                    $i++
                }
            }
            Else 
            {
                Write-EventLog -EventId 55 -Message "No Autologgers found to disable" -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning
                Write-Warning "`tNo Autologgers found to disable in $AutoLoggersFilePath"
                $result = $false
            }
        }
        Else
        {
            Write-EventLog -EventId 150 -Message "File not found: $AutoLoggersFilePath" -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Error
            Write-Warning "File Not Found: $AutoLoggersFilePath"
            $result = $false
        }
    }
    End
    {
        Write-Progress -ParentId 1 -Id 50 -Activity ("[VDI Optimize] AutoLoggers") -Completed
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