# OoT benchmark helpers: one persistent connection to the emulator's local debug server
# (EDEN_NX2_DEBUG_SERVER=127.0.0.1:6545). Newline-delimited JSON requests, one at a time.

$script:Client = $null
$script:Reader = $null
$script:Writer = $null
$script:NextId = 1

function Connect-Oot {
    param([int]$TimeoutSeconds = 120)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ($true) {
        try {
            $c = [Net.Sockets.TcpClient]::new()
            $c.Connect('127.0.0.1', 6545)
            break
        } catch {
            if ((Get-Date) -gt $deadline) { throw 'Debug server did not come up on 127.0.0.1:6545' }
            Start-Sleep -Milliseconds 500
        }
    }
    $s = $c.GetStream()
    $s.ReadTimeout = 120000
    $enc = [Text.UTF8Encoding]::new($false)
    $script:Client = $c
    $script:Reader = [IO.StreamReader]::new($s, $enc)
    $script:Writer = [IO.StreamWriter]::new($s, $enc, 4096, $true)
    $script:Writer.AutoFlush = $true
}

function Disconnect-Oot {
    if ($script:Client) { $script:Client.Close(); $script:Client = $null }
}

function Invoke-Oot {
    param([string]$Method, [hashtable]$Params = @{})
    $id = $script:NextId++
    $req = @{ id = $id; method = $Method; params = $Params } | ConvertTo-Json -Compress -Depth 8
    $script:Writer.WriteLine($req)
    $line = $script:Reader.ReadLine()
    if ($null -eq $line) { throw "Debug server closed the connection during $Method" }
    $reply = $line | ConvertFrom-Json
    if ($reply.error) { throw "$Method failed: $($reply.error | ConvertTo-Json -Compress)" }
    return $reply.result
}

function Send-OotInput {
    param([string[]]$Buttons = @(), [double[]]$Left = @(0, 0), [double[]]$Right = @(0, 0), [int]$Frames = 6)
    $p = @{ frames = $Frames; left_stick = $Left; right_stick = $Right; timeout_s = 30 }
    if ($Buttons.Count) { $p.buttons = $Buttons }
    return Invoke-Oot -Method input -Params $p
}

function Save-OotScreenshot {
    param([string]$Destination)
    $r = Invoke-Oot -Method screenshot -Params @{ height = 540; save = $true; inline = $false }
    if ($Destination) { Copy-Item -LiteralPath $r.path -Destination $Destination -Force }
    return $r.path
}

Export-ModuleMember -Function Connect-Oot, Disconnect-Oot, Invoke-Oot, Send-OotInput, Save-OotScreenshot
