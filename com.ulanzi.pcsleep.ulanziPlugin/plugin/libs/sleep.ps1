# Windows Sleep script
try {
    Add-Type -Assembly System.Windows.Forms
    [System.Windows.Forms.Application]::SetSuspendState([System.Windows.Forms.PowerState]::Suspend, $false, $false)
    Write-Output "SUCCESS: PC sleep command issued."
} catch {
    Write-Error "ERROR: Failed to put PC to sleep: $_"
    exit 1
}
