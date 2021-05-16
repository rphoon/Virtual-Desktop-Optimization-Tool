<#
- TITLE:          Microsoft Windows 10 Virtual Desktop Optimization Script
- AUTHORED BY:    Robert M. Smith, Tim Muessig, Jason Parker
- AUTHORED DATE:  4/17/2021
- CONTRIBUTORS:   
- LAST UPDATED:   
- PURPOSE:        To automatically apply settings referenced in the following white papers:
                  https://docs.microsoft.com/en-us/windows-server/remote/remote-desktop-services/rds_vdi-recommendations-1909
                  
- Important:      Every setting in this script and input files are possible recommendations only,
                  and NOT requirements in any way. Please evaluate every setting for applicability
                  to your specific environment. These scripts have been tested on plain Hyper-V
                  VMs. Please test thoroughly in your environment before implementation

- DEPENDENCIES    1. On the target machine, run PowerShell elevated (as administrator)
                  2. Within PowerShell, set exectuion policy to enable the running of scripts.
                     Ex. Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
                  3. LGPO.EXE (available at https://www.microsoft.com/en-us/download/details.aspx?id=55319)
                  4. LGPO database files available in the respective folders (ex. \1909, or \2004)
                  5. This PowerShell script
                  6. The text input files containing all the apps, services, traces, etc. that you...
                     may be interested in disabling. Please review these input files to customize...
                     to your environment/requirements

- REFERENCES:
https://social.technet.microsoft.com/wiki/contents/articles/7703.powershell-running-executables.aspx
https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/remove-item?view=powershell-6
https://blogs.technet.microsoft.com/secguide/2016/01/21/lgpo-exe-local-group-policy-object-utility-v1-0/
https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/set-service?view=powershell-6
https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/remove-item?view=powershell-6
https://msdn.microsoft.com/en-us/library/cc422938.aspx
#>

<#
All VDOT main function Event ID's           [1-9]   - Normal Operations (Informational, Warning)
All WindowsMediaPlayer function Event ID's  [10-19] - Normal Operations (Informational, Warning)
All AppxPackages function Event ID's        [20-29] - Normal Operations (Informational, Warning)
All ScheduledTasks function Event ID's      [30-39] - Normal Operations (Informational, Warning)
All DefaultUserSettings function Event ID's [40-49] - Normal Operations (Informational, Warning)
All AutoLoggers function Event ID's         [50-59] - Normal Operations (Informational, Warning)
All Services function Event ID's            [60-69] - Normal Operations (Informational, Warning)
All Network function Event ID's             [70-79] - Normal Operations (Informational, Warning)
All LocalPolicy function Event ID's         [80-89] - Normal Operations (Informational, Warning)
All DiskCleanup function Event ID's         [90-99] - Normal Operations (Informational, Warning)


All VDOT main function Event ID's           [100-109] - Errors Only
All WindowsMediaPlayer function Event ID's  [110-119] - Errors Only
All AppxPackages function Event ID's        [120-129] - Errors Only
All ScheduledTasks function Event ID's      [130-139] - Errors Only
All DefaultUserSettings function Event ID's [140-149] - Errors Only
All AutoLoggers function Event ID's         [150-159] - Errors Only
All Services function Event ID's            [160-169] - Errors Only
All Network function Event ID's             [170-179] - Errors Only
All LocalPolicy function Event ID's         [180-189] - Errors Only
All DiskCleanup function Event ID's         [190-199] - Errors Only

#>

<# Categories of cleanup items:
This script is dependent on three elements:
LGPO Settings folder, applied with the LGPO.exe Microsoft app

The UWP app input file contains the list of almost all the UWP application packages that can be removed with PowerShell interactively.  
The Store and a few others, such as Wallet, were left off intentionally.  Though it is possible to remove the Store app, 
it is nearly impossible to get it back.  Please review the lists below and comment out or remove references to packages that you do not want to remove.
#>
Function Start-VDIOptimize
{
    [Cmdletbinding(DefaultParameterSetName = "Default")]
    Param (
        [System.String]$WindowsVersion = (Get-ItemProperty "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\").ReleaseId,

        [ValidateSet('All', 'WindowsMediaPlayer', 'AppxPackages', 'ScheduledTasks', 'DefaultUserSettings', 'Autologgers', 'Services', 'NetworkOptimizations', 'LocalPolicySettings', 'DiskCleanup')] 
        [String[]]$Optimizations = "All",

        [Switch]$Restart,

        [Switch]
        $AcceptEULA,

        [Switch]
        $Quiet
    )
    BEGIN
    {
        #Requires -RunAsAdministrator
        #Requires -PSEdition Desktop -Version 5.1

        If ($Quiet)
        {
            $VerbosePreference = "SilentlyContinue"
            $ErrorActionPreference = "SilentlyContinue"
            $WarningPreference = "SilentlyContinue"
            $ProgressPreference = "SilentlyContinue"
            $AcceptEULA = $true
        }

        [System.Console]::WindowWidth = 140
        [System.Console]::BufferHeight = 9999

        trap [System.Management.Automation.ItemNotFoundException]
        {
            Write-Warning ("One or more paths were not found")
        }
        $source = $PSCmdlet.MyInvocation.MyCommand.ToString() -replace ("Start-","")
        $RegPath = "HKLM:\SOFTWARE\Microsoft\VDIOptimize"
        $StartTime = Get-Date
        
        If (-not([System.Diagnostics.EventLog]::SourceExists("Virtual Desktop Optimization")))
        {
            New-EventLog -Source $source -LogName 'Virtual Desktop Optimization'
            $Message = ("[VDI Optimize] Created Windows Event Log")
            Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information -EventId 1 -Message $Message
            Write-Verbose $Message
        }

        $psModPath = $env:PSModulePath.Split(";") | Get-ChildItem -Filter "Az.WvdOptimization"
        If ($psModPath.Count -ge 1)
        {
            $psModPath = $psModPath | Sort-Object -Property CreationTime -Descending | Select-Object -First 1
        }
        Else
        {
            $Message = ("[VDI Optimize] Unable to find Az.WvdOptimization module path")
            Write-EventLog -EventId 100 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Error
            $Exception = [System.IO.DirectoryNotFoundException]::new($Message)
            $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                $Exception,
                "ModulePathNotFound",
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                "Az.WvdOptimization"
            )
            $PSCmdlet.ThrowTerminatingError($ErrorRecord) 
        }
        
        $Message = ("[VDI Optimize] Started: {0}" -f $PSCmdlet.MyInvocation.Line)
        Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information -EventId 1 -Message $Message
        Write-Verbose $Message
        $WorkingLocation = Join-Path -Path $psModPath.FullName -ChildPath ("Versions\{0}" -f $WindowsVersion)
    }
    PROCESS
    {
        If (Test-Path -Path $WorkingLocation)
        {
            $StartingLocation = Get-Location
            Push-Location $WorkingLocation
            $Message = ("[VDI Optimize] Found and loaded working location:`n`r{0}" -f $WorkingLocation)
            Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information -EventId 1 -Message $Message
            Write-Verbose $Message
        }
        Else
        {
            $Message = ("[VDI Optimize] Unable to validate working location:`n`r{0}" -f $WorkingLocation)
            Write-EventLog -EventId 100 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Error
            $Exception = [Exception]::new($Message)
            $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                $Exception,
                "WorkingLocationNotFound",
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $WorkingLocation
            )
            $PSCmdlet.ThrowTerminatingError($ErrorRecord) 
        }

        If (-NOT $Quiet)
        {
            _ShowMenu -Title "Virtual Desktop Optimization Tool v2021.05.xx" -Style Full -Color Cyan -DisplayOnly
        }
        
        $EULA = Get-Content -Path ("{0}\EULA.txt" -f $psModPath.FullName)
        
        If (-NOT $AcceptEULA)
        {
            $EULA | Out-Host
            Switch (_GetChoicePrompt -OptionList "&Yes", "&No" -Title "End User License Agreement" -Message "Do you accept the EULA?" -Default 0)
            {
                0
                {
                    Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information -EventId 1 -Message "EULA Accepted"
                    Write-Verbose "EULA Accepted"
                }
                1
                {
                    Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning -EventId 5 -Message "EULA Declined, exiting!"
                    Write-Verbose "EULA Declined, exiting!"
                    Return
                }
                Default
                {
                    Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information -EventId 1 -Message "EULA Accepted"
                    Write-Verbose "EULA Accepted"
                }
            }
        }
        Else 
        {
            Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information -EventId 1 -Message "EULA Accepted by Parameter"
            Write-Verbose "EULA Accepted by Parameter"
        }

        If ($Optimizations -eq "All")
        {
            $Optimizers = 9
        }
        Else {
            $Optimizers = ($Optimizations | Measure-Object).Count
        }

        $i = 0
        Write-Progress -Id 1 -Activity ("VDI Optimization") -Status ("Optimizating {0} Configuration(s)" -f $Optimizers) -PercentComplete (($i/$Optimizers)*100)
        If (($Optimizations -contains "WindowsMediaPlayer" -or $Optimizations -contains "All"))
        {
            # All WindowsMediaPlayer function Event ID's [10-19]
            Write-Progress -Id 1 -Activity ("VDI Optimization") -Status ("Optimizating {0} Configuration(s)" -f $Optimizers) -PercentComplete (($i/$Optimizers)*100)
            $WindowsMediaPlayer = Set-WindowsMediaPlayer
            If ($WindowsMediaPlayer)
            {
                Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information -EventId 10 -Message "[VDI Optimize] Windows Media Player optimization was successful"
            }
            Else
            {
                Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning -EventId 15 -Message "[VDI Optimize] Windows Media Player optimization threw 1 or more errors."
                Write-Warning ("[VDI Optimize] WindowsMediaPlayer | 1 or more errors thrown, check the event log for details.")
            }
            $i++
            Write-Progress -Id 1 -Activity ("VDI Optimization") -CurrentOperation ("Applied Configurations: {0}" -f $i) -Status ("Optimizating {0} Configuration(s)" -f $Optimizers) -PercentComplete (($i/$Optimizers)*100)
        }
        If (($Optimizations -contains "AppxPackages" -or $Optimizations -contains "All"))
        {
            # All AppxPackages function Event ID's [20-29]
            Write-Progress -Id 1 -Activity ("VDI Optimization") -Status ("Optimizating {0} Configuration(s)" -f $Optimizers) -PercentComplete (($i/$Optimizers)*100)
            $AppxPackages = Set-AppxPackages -AppxConfigFilePath ".\ConfigurationFiles\AppxPackages.json"
            If ($AppxPackages)
            {
                Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information -EventId 20 -Message "[VDI Optimize] AppxPackage optimization was successful"
            }
            Else
            {
                Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning -EventId 25 -Message "[VDI Optimize] AppxPackage optimization threw 1 or more errors."
                Write-Warning ("[VDI Optimize] AppxPackage | 1 or more errors thrown, check the event log for details.")
            }
            $i++
            Write-Progress -Id 1 -Activity ("VDI Optimization") -CurrentOperation ("Applied Configurations: {0}" -f $i) -Status ("Optimizating {0} Configuration(s)" -f $Optimizers) -PercentComplete (($i/$Optimizers)*100)
        }
    
        # All ScheduledTasks function Event ID's [30-39]
        If (($Optimizations -contains "ScheduledTasks" -or $Optimizations -contains "All"))
        {
            Write-Progress -Id 1 -Activity ("VDI Optimization") -Status ("Optimizating {0} Configuration(s)" -f $Optimizers) -PercentComplete (($i/$Optimizers)*100)
            $ScheduledTasks = Set-ScheduledTasks -ScheduledTasksConfigFilePath ".\ConfigurationFiles\ScheduledTasks.json"
            If ($ScheduledTasks)
            {
                Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information -EventId 30 -Message "[VDI Optimize] ScheduledTasks optimization was successful"
            }
            Else
            {
                Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning -EventId 35 -Message "[VDI Optimize] ScheduledTasks optimization threw 1 or more errors."
                Write-Warning ("[VDI Optimize] ScheduledTasks | 1 or more errors thrown, check the event log for details.")
            }
            $i++
            Write-Progress -Id 1 -Activity ("VDI Optimization") -CurrentOperation ("Applied Configurations: {0}" -f $i) -Status ("Optimizating {0} Configuration(s)" -f $Optimizers) -PercentComplete (($i/$Optimizers)*100)
        }

        # All DefaultUserSettings function Event ID's [40-49]
        If (($Optimizations -contains "DefaultUserSettings" -or $Optimizations -contains "All"))
        {
            Write-Progress -Id 1 -Activity ("VDI Optimization") -Status ("Optimizating {0} Configuration(s)" -f $Optimizers) -PercentComplete (($i/$Optimizers)*100)
            $DefaultUserSettings = Set-DefaultUserSettings -DefaultUserSettingsFilePath ".\ConfigurationFiles\DefaultUserSettings.json"
            If ($DefaultUserSettings)
            {
                Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information -EventId 40 -Message "[VDI Optimize] DefaultUserSettings optimization was successful"
            }
            Else
            {
                Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning -EventId 45 -Message "[VDI Optimize] DefaultUserSettings optimization threw 1 or more errors."
                Write-Warning ("[VDI Optimize] DefaultUserSettings | 1 or more errors thrown, check the event log for details.")
            }
            $i++
            Write-Progress -Id 1 -Activity ("VDI Optimization") -CurrentOperation ("Applied Configurations: {0}" -f $i) -Status ("Optimizating {0} Configuration(s)" -f $Optimizers) -PercentComplete (($i/$Optimizers)*100)
        }
    
        # All AutoLoggers function Event ID's [50-59]
        If (($Optimizations -contains "Autologgers" -or $Optimizations -contains "All"))
        {
            Write-Progress -Id 1 -Activity ("VDI Optimization") -Status ("Optimizating {0} Configuration(s)" -f $Optimizers) -PercentComplete (($i/$Optimizers)*100)
            $Autologgers = Set-AutoLoggers -AutoLoggersFilePath ".\ConfigurationFiles\Autologgers.json"
            If ($Autologgers)
            {
                Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information -EventId 50 -Message "[VDI Optimize] Autologgers optimization was successful"
            }
            Else
            {
                Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning -EventId 55 -Message "[VDI Optimize] Autologgers optimization threw 1 or more errors."
                Write-Warning ("[VDI Optimize] Autologgers | 1 or more errors thrown, check the event log for details.")
            }
            $i++
            Write-Progress -Id 1 -Activity ("VDI Optimization") -CurrentOperation ("Applied Configurations: {0}" -f $i) -Status ("Optimizating {0} Configuration(s)" -f $Optimizers) -PercentComplete (($i/$Optimizers)*100)
        }

        # All Services function Event ID's [60-69]
        If (($Optimizations -contains "Services" -or $Optimizations -contains "All"))
        {
            Write-Progress -Id 1 -Activity ("VDI Optimization") -Status ("Optimizating {0} Configuration(s)" -f $Optimizers) -PercentComplete (($i/$Optimizers)*100)
            $Services = Set-Services -ServicesConfigFilePath ".\ConfigurationFiles\Services.json"
            If ($Services)
            {
                Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information -EventId 60 -Message "[VDI Optimize] Services optimization was successful"
            }
            Else
            {
                Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning -EventId 65 -Message "[VDI Optimize] Services optimization threw 1 or more errors."
                Write-Warning ("[VDI Optimize] Services | 1 or more errors thrown, check the event log for details.")
            }
            $i++
            Write-Progress -Id 1 -Activity ("VDI Optimization") -CurrentOperation ("Applied Configurations: {0}" -f $i) -Status ("Optimizating {0} Configuration(s)" -f $Optimizers) -PercentComplete (($i/$Optimizers)*100)
        }

        # All Network function Event ID's [70-79]
        If (($Optimizations -contains "NetworkOptimizations" -or $Optimizations -contains "All"))
        {
            Write-Progress -Id 1 -Activity ("VDI Optimization") -Status ("Optimizating {0} Configuration(s)" -f $Optimizers) -PercentComplete (($i/$Optimizers)*100)
            $NetworkOptimizations = Set-NetworkOptimizations -NetworkConfigFilePath ".\ConfigurationFiles\NetworkOptimizations.json"
            If ($NetworkOptimizations)
            {
                Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information -EventId 70 -Message "[VDI Optimize] NetworkOptimizations optimization was successful"
            }
            Else
            {
                Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning -EventId 75 -Message "[VDI Optimize] NetworkOptimizations optimization threw 1 or more errors."
                Write-Warning ("[VDI Optimize] NetworkOptimizations | 1 or more errors thrown, check the event log for details.")
            }
            $i++
            Write-Progress -Id 1 -Activity ("VDI Optimization") -CurrentOperation ("Applied Configurations: {0}" -f $i) -Status ("Optimizating {0} Configuration(s)" -f $Optimizers) -PercentComplete (($i/$Optimizers)*100)
        }

        # All LocalPolicy function Event ID's [80-89]
        If (($Optimizations -contains "LocalPolicySettings" -or $Optimizations -contains "All"))
        {
            Write-Progress -Id 1 -Activity ("VDI Optimization") -Status ("Optimizating {0} Configuration(s)" -f $Optimizers) -PercentComplete (($i/$Optimizers)*100)
            $LocalPolicySettings = Set-LocalPolicySettings -LocalPolicyConfigFilePath ""
            If ($LocalPolicySettings)
            {
                Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information -EventId 80 -Message "[VDI Optimize] LocalPolicySettings optimization was successful"
            }
            Else
            {
                Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning -EventId 85 -Message "[VDI Optimize] LocalPolicySettings optimization threw 1 or more errors."
                Write-Warning ("[VDI Optimize] LocalPolicySettings | 1 or more errors thrown, check the event log for details.")
            }
            $i++
            Write-Progress -Id 1 -Activity ("VDI Optimization") -CurrentOperation ("Applied Configurations: {0}" -f $i) -Status ("Optimizating {0} Configuration(s)" -f $Optimizers) -PercentComplete (($i/$Optimizers)*100)
        }

        # All DiskCleanup function Event ID's [90-99]
        If (($Optimizations -contains "DiskCleanup" -or $Optimizations -contains "All"))
        {
            Write-Progress -Id 1 -Activity ("VDI Optimization") -Status ("Optimizating {0} Configuration(s)" -f $Optimizers) -PercentComplete (($i/$Optimizers)*100)
            $DiskCleanup = Set-DiskCleanup -DiskConfigFilePath ".\ConfigurationFiles\DiskCleanup.json"
            If ($DiskCleanup)
            {
                Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information -EventId 90 -Message "[VDI Optimize] DiskCleanup optimization was successful"
            }
            Else
            {
                Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Warning -EventId 95 -Message "[VDI Optimize] DiskCleanup optimization threw 1 or more errors."
                Write-Warning ("[VDI Optimize] DiskCleanup | 1 or more errors thrown, check the event log for details.")
            }
            $i++
            Write-Progress -Id 1 -Activity ("VDI Optimization") -CurrentOperation ("Applied Configurations: {0}" -f $i) -Status ("Optimizating {0} Configuration(s)" -f $Optimizers) -PercentComplete (($i/$Optimizers)*100)
        }
    }
    END
    {
        $EndTime = Get-Date
        $ScriptRunTime = New-TimeSpan -Start $StartTime -End $EndTime
        $Message = ("[VDI Optimize] Total Run Time: {0}:{1}:{2}.{3}" -f $ScriptRunTime.Hours, $ScriptRunTime.Minutes, $ScriptRunTime.Seconds, $ScriptRunTime.Milliseconds)
        Write-EventLog -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information -EventId 1 -Message $Message
        Write-Verbose $Message
        Set-Location $StartingLocation
        If (-NOT $Quiet)
        {
            _ShowMenu -Title ("Thank you from the Virtual Desktop Optimization Team`n {0}" -f $Message) -Style Mini -DisplayOnly -Color Cyan
        }
    }
}
