Function Set-DiskCleanup
{
    [CmdletBinding()]
    Param
    (
        $DiskConfigFilePath
    )

    Begin
    {
        $result = $true
        $source = $PSCmdlet.MyInvocation.MyCommand.ToString() -replace ("Set-", "")
        New-EventLog -Source $source -LogName 'Virtual Desktop Optimization' -ErrorAction SilentlyContinue
    }

    Process
    {
        If (Test-Path -Path $DiskConfigFilePath)
        {
            $Message = ("[VDI Optimize] DiskCleanup")
            Write-EventLog -EventId 90 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information 
            Write-Progress -ParentId 1 -Id 90 -Activity "DiskCleanup (Long operation > 7 min)"
            Write-Verbose $Message
            $DiskCleanup = (Get-Content $DiskConfigFilePath | ConvertFrom-Json).Where( { $_.Enabled -eq $true } )
            If ($DiskCleanup.Count -gt 0)
            {
                $i = 0
                Foreach ($Item in $DiskCleanup)
                {
                    $Message = ("{0}" -f $Item.Description)
                    Write-Progress -ParentId 1 -Id 90 -Activity ("DiskCleanup (Long operation > 7 min)") -CurrentOperation $Message -Status ("Working on item {0} of {1}" -f $i, $DiskCleanup.Count) -PercentComplete (($i / $DiskCleanup.Count) * 100)
                    Write-EventLog -EventId 90 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information 
                    Write-Verbose ("`t{0}" -f $Item.Description)
                    Switch ($Item.Name)
                    {
                        "Logging"
                        {
                            Get-ChildItem -Path $Item.Path -Include *.tmp, *.dmp, *.etl, *.evtx, thumbcache*.db, *.log -File -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
                        }
                        "RetailDemo"
                        {
                            # Delete "RetailDemo" content (if it exits)
                            Get-ChildItem -Path $Item.Path -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
                        }
                        "SystemTemp"
                        {
                            # Delete not in-use anything in the C:\Windows\Temp folder
                            Get-ChildItem -Path $Item.Path -File -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
                        }
                        "WindowsErrorReporting"
                        {
                            # Clear out Windows Error Reporting (WER) report archive folders
                            Get-ChildItem -Path (Join-Path -Path $Item.Path -ChildPath "\Temp") -File -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
                            Get-ChildItem -Path (Join-Path -Path $Item.Path -ChildPath "\ReportArchive") -File -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
                            Get-ChildItem -Path (Join-Path -Path $Item.Path -ChildPath "\ReportQueue") -File -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
                        }
                        "UserTemp"
                        {
                            # Delete not in-use anything in your %temp% folder
                            Get-ChildItem -Path $env:TEMP -File -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
                        }
                        "RecycleBin"
                        {
                            # Clear out ALL visible Recycle Bins
                            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
                        }
                        "BranchCache"
                        {
                            # Clear out BranchCache cache
                            Clear-BCCache -Force -ErrorAction SilentlyContinue
                        }
                    }
                    $i++
                }
            }
            Else 
            {
                Write-EventLog -EventId 90 -Message "No Disk tasks found to cleanup" -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning 
                Write-Warning "`tNo Disk tasks found to cleanup in $DiskConfigFilePath"
                $result = $false
            }
        }
        Else 
        {
            Write-EventLog -EventId 20 -Message "Configuration file not found - $DiskConfigFilePath" -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning 
            Write-Warning "`tConfiguration file not found -  $DiskConfigFilePath"
            $result = $false
        }
    }    
    End
    {
        Write-Progress -ParentId 1 -Id 20 -Activity ("[VDI Optimize] DiskCleanup") -Completed
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