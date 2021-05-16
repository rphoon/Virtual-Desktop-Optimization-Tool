Function Set-ScheduledTasks
{
    [CmdletBinding()]
    Param
    (
        $ScheduledTasksConfigFilePath
    )

    Begin
    {
        $result = $true
        $source = $PSCmdlet.MyInvocation.MyCommand.ToString() -replace ("Set-", "")
        New-EventLog -Source $source -LogName 'Virtual Desktop Optimization' -ErrorAction SilentlyContinue
    }

    Process
    {
        If (Test-Path $ScheduledTasksConfigFilePath)
        {
            $Message = ("[VDI Optimize] ScheduledTasks")
            Write-EventLog -EventId 30 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information 
            Write-Progress -ParentId 1 -Id 30 -Activity "ScheduledTasks"
            Write-Verbose $Message
            $ScheduledTasks = (Get-Content $ScheduledTasksConfigFilePath | ConvertFrom-Json).Where( { $_.VDIState -eq 'Disabled' })
            If ($ScheduledTasks.count -gt 0)
            {
                $i = 0
                Foreach ($Item in $ScheduledTasks)
                {
                    $TaskObject = Get-ScheduledTask $Item.ScheduledTask
                    $Message = ("Disabling Scheduled Task: {0}" -f $Item.ScheduledTask)
                    Write-Progress -ParentId 1 -Id 30 -Activity ("ScheduledTasks") -CurrentOperation $Message -Status ("Working on item {0} of {1}" -f $i, $ScheduledTasks.Count) -PercentComplete (($i / $ScheduledTasks.Count) * 100)
                    Write-EventLog -EventId 30 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information 
                    Write-Verbose "`t$Message"
                    If ($TaskObject -and $TaskObject.State -ne 'Disabled')
                    {
                        try
                        {
                            Disable-ScheduledTask -InputObject $TaskObject | Out-Null
                            $Message = ("Disabled Scheduled Task: {0}" -f $TaskObject.TaskName)
                            Write-EventLog -EventId 30 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information 
                            Write-Verbose "`t$Message" 
                        }
                        catch
                        {
                            $Message = ("Failed to disable Scheduled Task: {0}" -f $TaskObject.TaskName)
                            Write-EventLog -EventId 130 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Error 
                            Write-Warning "`t$Message" 
                            $result = $false
                        }
                    }
                    ElseIf ($TaskObject -and $TaskObject.State -eq 'Disabled') 
                    {
                        $Message = ("Scheduled Task: {0} already disabled" -f $TaskObject.TaskName)
                        Write-EventLog -EventId 35 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning 
                        Write-Verbose "`t$Message"
                    }
                    Else
                    {
                        $Message = ("Failed to find Scheduled Task: {0}" -f $Item.ScheduledTask)
                        Write-EventLog -EventId 130 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Error 
                        Write-Warning "`t$Message"
                        $result = $false
                    }
                    $i++
                }
            }
            Else
            {
                Write-EventLog -EventId 35 -Message "No Scheduled Tasks found to disable in $ScheduledTasksConfigFilePath" -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warnnig
                Write-Warning "`tNo Scheduled Tasks found to disable in $ScheduledTasksConfigFilePath"
                $result = $false
            }
        }
        Else 
        {
            Write-EventLog -EventId 130 -Message "File not found: $ScheduledTasksConfigFilePath" -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Error
            Write-Warning "`tFile not found: $ScheduledTasksConfigFilePath"
            $result = $false
        }
    }
    
    End
    {
        Write-Progress -ParentId 1 -Id 30 -Activity ("[VDI Optimize] ScheduledTasks") -Completed
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