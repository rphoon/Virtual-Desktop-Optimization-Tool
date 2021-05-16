Function Set-WindowsMediaPlayer
{
    [CmdletBinding()]
    Param
    (

    )

    Begin
    {
        $result = $true
        $source = $PSCmdlet.MyInvocation.MyCommand.ToString() -replace ("Set-","")
        New-EventLog -Source $source -LogName 'Virtual Desktop Optimization' -ErrorAction SilentlyContinue
    }

    Process
    {
        try
        {
            $Message = "[VDI Optimize] WindowsMediaPlayer"
            Write-Progress -ParentId 1 -Id 10 -Activity ("[VDI Optimize] WindowsMediaPlayer") -CurrentOperation $Message
            Write-EventLog -EventId 10 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information 
            Write-Verbose $Message
            Disable-WindowsOptionalFeature -Online -FeatureName WindowsMediaPlayer -NoRestart -Verbose:$false | Out-Null
            Get-WindowsPackage -Online -PackageName "*Windows-mediaplayer*" -Verbose:$false | ForEach-Object { 
                $Message = ("Removing: {0}" -f $_.PackageName)
                Write-Progress -ParentId 1 -Id 10 -Activity ("[VDI Optimize] WindowsMediaPlayer") -CurrentOperation $Message
                Write-EventLog -EventId 10 -Message $Message -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Information
                Write-Verbose "`t$Message"
                Remove-WindowsPackage -PackageName $_.PackageName -Online -ErrorAction SilentlyContinue -NoRestart | Out-Null
            }
        }
        catch 
        {
            $err = $_ | Select-Object * | Out-String
            Write-EventLog -EventId 110 -Message ("[VDI Optimize] WindowsMediaPlayer encountered an error:`n`r{0}" -f $err) -LogName 'Virtual Desktop Optimization' -Source $source -EntryType Error
            $result = $false
        }

    }

    End
    {
        Write-Progress -ParentId 1 -Id 10 -Activity ("[VDI Optimize] WindowsMediaPlayer") -Completed
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