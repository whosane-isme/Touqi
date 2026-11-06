# Clicks a Tools > TAS menu entry in the running emulator through Windows UI Automation and
# prints the status-bar "TAS state". -Item: Record (start/stop recording), Start/Stop, Reset.
param([string]$Item = 'Record')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$A = [Windows.Automation.AutomationElement]
$p = Get-Process lichii | Select-Object -First 1
$desk = $A::RootElement
$cond = New-Object Windows.Automation.PropertyCondition($A::ControlTypeProperty, [Windows.Automation.ControlType]::MenuItem)
function Get-Item([string]$Pattern) {
    for ($i = 0; $i -lt 20; $i++) {
        $e = $desk.FindAll([Windows.Automation.TreeScope]::Descendants, $cond) |
            Where-Object { $_.Current.ProcessId -eq $p.Id -and $_.Current.Name -like $Pattern } |
            Select-Object -First 1
        if ($e) { return $e }
        Start-Sleep -Milliseconds 250
    }
    throw "Menu item '$Pattern' not found"
}
(Get-Item 'Tools').GetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern).Expand()
(Get-Item 'TAS').GetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern).Expand()
(Get-Item "*$Item*").GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke()
Start-Sleep -Milliseconds 800
$root = $A::FromHandle($p.MainWindowHandle)
$text = New-Object Windows.Automation.PropertyCondition($A::ControlTypeProperty, [Windows.Automation.ControlType]::Text)
$root.FindAll([Windows.Automation.TreeScope]::Descendants, $text) |
    Where-Object { $_.Current.Name -like 'TAS state*' } | ForEach-Object { $_.Current.Name }
