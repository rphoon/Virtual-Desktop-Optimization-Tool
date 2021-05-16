Function Set-LocalPolicySettings
{
    [CmdletBinding()]
    Param
    (
        $LocalPolicyConfigFilePath
    )

    Begin
    {
        $result = $true
        $source = $PSCmdlet.MyInvocation.MyCommand.ToString() -replace ("Set-","")
        New-EventLog -Source $source -LogName 'Virtual Desktop Optimization' -ErrorAction SilentlyContinue
    }

    Process
    {

    }

    End
    {
        Write-Progress -ParentId 1 -Id 20 -Activity ("[VDI Optimize] LocalPolicySettings") -Completed
        # If (Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\VDIOptimize -Name $source)
        # {
        #     Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\VDIOptimize -Name $source -Value $result
        # }
        # Else
        # {
        #     New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\VDIOptimize -Name $source -Value $result
        # }
        #& gpupdate /force
        Return $result
    }
}