Function Set-Services
{
    [CmdletBinding()]
    Param
    (
        $ServicesConfigFilePath
    )

    Begin
    {
        $result = $true
        $source = $PSCmdlet.MyInvocation.MyCommand.ToString() -replace ("Set-", "")
        New-EventLog -Source $source -LogName 'Virtual Desktop Optimization' -ErrorAction SilentlyContinue
    }

    Process
    {
        If (Test-Path $ServicesConfigFilePath)
        {
            $Message = ("[VDI Optimize] Services")
            Write-EventLog -EventId 60 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information 
            Write-Progress -ParentId 1 -Id 60 -Activity "Services"
            Write-Verbose $Message
            $Services = (Get-Content $ServicesConfigFilePath | ConvertFrom-Json ).Where( { $_.VDIState -eq 'Disabled' })

            If ($Services.count -gt 0)
            {
                $i = 0
                Foreach ($Item in $Services)
                {
                    try
                    {
                        $Message = ("Stopping and disabling service: {0}" -f $Item.Name)
                        Write-Progress -ParentId 1 -Id 60 -Activity ("Services") -CurrentOperation $Message -Status ("Working on item {0} of {1}" -f $i, $Services.Count) -PercentComplete (($i / $Services.Count) * 100)
                        Write-EventLog -EventId 60 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information 
                        Write-Verbose "`t$Message"
                        Stop-Service $Item.Name -Force -ErrorAction SilentlyContinue
                        Set-Service $Item.Name -StartupType Disabled 
                    }
                    catch
                    {
                        $Message = ("Failed to stop or disable: {0} - {1}" -f $Item.Name, $_.Exception.Message)
                        Write-EventLog -EventId 160 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Error 
                        Write-Warning "`t$Message"
                        $result = $false
                    }
                    $i++
                }
            }  
            Else
            {
                Write-EventLog -EventId 65 -Message "No Services found to disable in $ServicesConfigFilePath" -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warnnig
                Write-Warning "`tNo Services found to disable in $ServicesConfigFilePath"
                $result = $false
            }
        }
        Else
        {
            Write-EventLog -EventId 160 -Message "File not found: $ServicesConfigFilePath" -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Error
            Write-Warning "`tFile not found: $ServicesConfigFilePath"
            $result = $false
        }

    }

    End
    {
        Write-Progress -ParentId 1 -Id 60 -Activity ("[VDI Optimize] Services") -Completed
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