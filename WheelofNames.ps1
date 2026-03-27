function Start-WheelOfNames {
    <#
    .SYNOPSIS
        A retro DOS-style Wheel of Fortune TUI using the Wheel of Names API.
    .DESCRIPTION
        Spins a wheel with entries from a Wheel of Names shared link.
        Features ASCII art wheel animation, retro colors, and sound effects.
    .PARAMETER WheelId
        The Wheel of Names shared wheel ID (from the URL after /shared/).
        If omitted, you can enter names manually.
    .PARAMETER Names
        An array of names to use instead of fetching from the API.
    .PARAMETER NoSound
        Disable console beep sounds.
    .EXAMPLE
        Start-WheelOfNames -Names @("Alice","Bob","Charlie","Diana","Eve")
    .EXAMPLE
        Start-WheelOfNames -WheelId "abc-123"
    #>
    [CmdletBinding()]
    param(
        [string]$WheelId,
        [string[]]$Names,
        [switch]$NoSound
    )

    # ── CONFIGURATION ──────────────────────────────────────────────────
    $script:SliceColors = @(
        'Red','Yellow','Green','Cyan','Magenta','White',
        'DarkYellow','DarkCyan','DarkGreen','DarkRed'
    )
    $script:SoundEnabled = -not $NoSound

    # ── SAFE DRAWING HELPERS ───────────────────────────────────────────

    function Get-ScreenSize {
        $sz = $Host.UI.RawUI.WindowSize
        return @{ W = $sz.Width; H = $sz.Height }
    }

    function Safe-WriteAt {
        param([int]$X, [int]$Y, [string]$Text, [string]$Color = "White")
        $scr = Get-ScreenSize
        if ($Y -lt 0 -or $Y -ge $scr.H -or $X -ge $scr.W -or $X -lt 0) { return }
        $maxLen = $scr.W - $X
        if ($maxLen -le 0) { return }
        if ($Text.Length -gt $maxLen) { $Text = $Text.Substring(0, $maxLen) }
        try {
            $pos = $Host.UI.RawUI.CursorPosition
            $pos.X = $X; $pos.Y = $Y
            $Host.UI.RawUI.CursorPosition = $pos
            Write-Host $Text -NoNewline -ForegroundColor $Color
        } catch { }
    }

    function Safe-ClearRegion {
        param([int]$X, [int]$Y, [int]$W, [int]$H)
        $scr = Get-ScreenSize
        if ($W -le 0 -or $H -le 0) { return }
        $blank = " " * [Math]::Min($W, $scr.W)
        for ($row = $Y; $row -lt ($Y + $H); $row++) {
            Safe-WriteAt $X $row $blank "Black"
        }
    }

    function Write-CenteredAt {
        param([int]$Y, [string]$Text, [string]$Color = "White")
        $scr = Get-ScreenSize
        $x = [Math]::Max(0, [Math]::Floor(($scr.W - $Text.Length) / 2))
        Safe-WriteAt $x $Y $Text $Color
    }

    function Beep-Safe {
        param([int]$Freq = 800, [int]$Dur = 50)
        if ($script:SoundEnabled) {
            try { [Console]::Beep($Freq, $Dur) } catch { }
        }
    }

    # ── BOX DRAWING ────────────────────────────────────────────────────

    function Draw-Box {
        param([int]$X, [int]$Y, [int]$W, [int]$H, [string]$Color = "DarkCyan", [string]$Title = "")
        $hz = [string][char]0x2550
        $vt = [string][char]0x2551
        $tl = [string][char]0x2554; $tr = [string][char]0x2557
        $bl = [string][char]0x255A; $br = [string][char]0x255D

        Safe-WriteAt $X $Y ($tl + ($hz * [Math]::Max(0, $W - 2)) + $tr) $Color
        if ($Title) {
            $ts = "$hz $Title $hz"
            $tx = $X + [Math]::Max(0, [Math]::Floor(($W - $ts.Length) / 2))
            Safe-WriteAt $tx $Y $ts "Cyan"
        }
        for ($i = 1; $i -lt ($H - 1); $i++) {
            Safe-WriteAt $X ($Y + $i) $vt $Color
            Safe-WriteAt ($X + $W - 1) ($Y + $i) $vt $Color
        }
        Safe-WriteAt $X ($Y + $H - 1) ($bl + ($hz * [Math]::Max(0, $W - 2)) + $br) $Color
    }

    # ── WHEEL RENDERING ────────────────────────────────────────────────

    function Draw-Wheel {
        param(
            [string[]]$Entries,
            [int]$HighlightIndex,
            [int]$CX, [int]$CY,
            [int]$Radius = 9,
            [bool]$Spinning = $false,
            [double]$RotationDeg = 0
        )
        $count = $Entries.Count
        $angleStep = (2 * [Math]::PI) / $count
        $rotRad = $RotationDeg * [Math]::PI / 180

        # Outer ring
        for ($a = 0; $a -lt 360; $a += 3) {
            $rad = ($a * [Math]::PI / 180) + $rotRad
            $px = [Math]::Round($CX + ($Radius * 2.1) * [Math]::Cos($rad))
            $py = [Math]::Round($CY + $Radius * [Math]::Sin($rad))
            $sliceIdx = [Math]::Floor(($a / 360.0) * $count) % $count
            $col = $script:SliceColors[$sliceIdx % $script:SliceColors.Count]
            $ch = if ($Spinning) {
                @(([string][char]0x2588), ([string][char]0x2593), ([string][char]0x2592), ([string][char]0x2591))[$a % 4]
            } else {
                [string][char]0x2588
            }
            Safe-WriteAt $px $py $ch $col
        }

        # Spokes and labels
        for ($i = 0; $i -lt $count; $i++) {
            $angle = ($i * $angleStep) - ([Math]::PI / 2) + $rotRad
            $col = $script:SliceColors[$i % $script:SliceColors.Count]
            $isHi = ($i -eq $HighlightIndex)

            for ($r = 2; $r -lt ($Radius - 1); $r++) {
                $sx = [Math]::Round($CX + ($r * 2.1) * [Math]::Cos($angle))
                $sy = [Math]::Round($CY + $r * [Math]::Sin($angle))
                $sc = if ($isHi) { [string][char]0x2588 } else { [string][char]0x2591 }
                Safe-WriteAt $sx $sy $sc $col
            }

            $lr = $Radius * 0.55
            $lx = [Math]::Round($CX + ($lr * 2.1) * [Math]::Cos($angle))
            $ly = [Math]::Round($CY + $lr * [Math]::Sin($angle))
            $name = $Entries[$i]
            if ($name.Length -gt 10) { $name = $name.Substring(0, 9) + "~" }
            $startX = $lx - [Math]::Floor($name.Length / 2)
            $labelCol = if ($isHi) { "White" } else { $col }
            Safe-WriteAt $startX $ly $name $labelCol
        }

        # Center hub
        Safe-WriteAt ($CX - 1) $CY "[*]" "Yellow"

        # Pointer at top (fixed, doesn't rotate)
        Safe-WriteAt $CX ($CY - $Radius - 1) "V" "White"
        Safe-WriteAt ($CX - 1) ($CY - $Radius - 2) "|||" "Yellow"
    }

    # ── SPIN ANIMATION ─────────────────────────────────────────────────

    function Invoke-Spin {
        param(
            [string[]]$Entries,
            [int]$CX, [int]$CY,
            [int]$Radius
        )
        $count = $Entries.Count

        # Pick winner, compute total clicks
        $winnerIdx = Get-Random -Minimum 0 -Maximum $count
        $fullRotations = Get-Random -Minimum 3 -Maximum 6
        $totalSteps = ($count * $fullRotations) + $winnerIdx
        if ($totalSteps -lt 10) { $totalSteps += $count }

        # Clear region bounds
        $clearX = [Math]::Max(0, $CX - ($Radius * 2) - 6)
        $clearW = ($Radius * 4) + 12
        $clearY = [Math]::Max(0, $CY - $Radius - 3)
        $clearH = ($Radius * 2) + 6

        for ($step = 0; $step -lt $totalSteps; $step++) {
            $current = $step % $count
            $progress = $step / $totalSteps

            # Each step rotates the wheel by one slice worth of degrees
            $degreesPerSlice = 360.0 / $count
            $rotDeg = $step * $degreesPerSlice

            $delay = [int](30 + 470 * [Math]::Pow($progress, 2.5))

            Safe-ClearRegion $clearX $clearY $clearW $clearH
            $spinning = ($step -lt ($totalSteps - 3))
            Draw-Wheel -Entries $Entries -HighlightIndex $current -CX $CX -CY $CY -Radius $Radius -Spinning $spinning -RotationDeg $rotDeg

            if ($progress -gt 0.3) {
                Beep-Safe -Freq ([int](600 + 400 * (1 - $progress))) -Dur 15
            }

            Start-Sleep -Milliseconds $delay
        }

        return $winnerIdx
    }

    # ── BANNER ─────────────────────────────────────────────────────────

    function Draw-Banner {
        param([int]$StartY = 0)
        $banner = @(
            '         _  _  _ _            _          __'
            '        | || || | |          | |        / _|'
            '        | || || | |__   _____| |   ___ | |_'
            '        | || || |  _ \ / _  /  _) / _ \|  _|'
            '        |_______| | | |  __/|  __| (_) | |'
            '         \_____/|_| |_|\___| \___|\___/|_|'
            ''
            '          _   _                            '
            '         | \ | | __ _ _ __ ___   ___  ___  '
            '         |  \| |/ _` |  _   _ \ / _ \/ __| '
            '         | |\  | (_| | | | | | |  __/\__ \ '
            '         |_| \_|\__,_|_| |_| |_|\___||___/ '
        )
        $colorCycle = @('Red','Yellow','Green','Cyan','Magenta','White')
        for ($i = 0; $i -lt $banner.Count; $i++) {
            $col = $colorCycle[$i % $colorCycle.Count]
            Write-CenteredAt ($StartY + $i) $banner[$i] $col
        }
        return ($StartY + $banner.Count)
    }

    # ── FETCH NAMES FROM API ───────────────────────────────────────────

    function Get-WheelEntries {
        param([string]$Id)
        if (-not $Id) { return $null }
        try {
            $uri = "https://wheelofnames.com/api/v1/wheels/$Id"
            $r = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 10
            $list = if ($r.entries) { $r.entries | ForEach-Object { $_.text } }
                    elseif ($r.wheel.entries) { $r.wheel.entries | ForEach-Object { $_.text } }
                    else { $null }
            return ($list | Where-Object { $_ })
        } catch {
            return $null
        }
    }

    # ── SIDEBARS ───────────────────────────────────────────────────────

    function Draw-Scoreboard {
        param([hashtable]$Scores, [int]$X, [int]$Y, [int]$H)
        $w = 26
        Draw-Box $X $Y $w $H "DarkCyan" "SCORES"
        $sorted = $Scores.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First ($H - 3)
        $row = 2
        foreach ($e in $sorted) {
            $n = $e.Key; if ($n.Length -gt 15) { $n = $n.Substring(0,14) + "." }
            $line = " {0,-16} {1,3}" -f $n, $e.Value
            $col = if ($row -eq 2) { "Yellow" } elseif ($row -eq 3) { "White" } else { "Gray" }
            Safe-WriteAt ($X + 1) ($Y + $row) $line $col
            $row++
        }
    }

    function Draw-History {
        param([System.Collections.ArrayList]$Log, [int]$X, [int]$Y, [int]$H)
        $w = 26
        Draw-Box $X $Y $w $H "DarkCyan" "HISTORY"
        $start = [Math]::Max(0, $Log.Count - ($H - 3))
        $row = 2
        for ($i = $start; $i -lt $Log.Count -and $row -lt ($H - 1); $i++) {
            $line = " {0,2}. {1}" -f ($i + 1), $Log[$i]
            if ($line.Length -gt ($w - 2)) { $line = $line.Substring(0, $w - 3) + "." }
            $col = $script:SliceColors[$i % $script:SliceColors.Count]
            Safe-WriteAt ($X + 1) ($Y + $row) $line $col
            $row++
        }
    }

    # ══════════════════════════════════════════════════════════════════
    #                         MAIN ENTRY
    # ══════════════════════════════════════════════════════════════════

    $entries = $null
    if ($Names -and $Names.Count -gt 0) { $entries = $Names }

    if (-not $entries -and $WheelId) {
        Clear-Host
        Draw-Banner | Out-Null
        Write-Host "`n  Fetching wheel..." -ForegroundColor DarkCyan
        $entries = Get-WheelEntries -Id $WheelId
        if (-not $entries) {
            Write-Host "  Could not fetch. Falling back to manual entry." -ForegroundColor Red
        }
    }

    if (-not $entries) {
        Clear-Host
        Draw-Banner | Out-Null
        Write-Host "`n  Enter names (one per line, blank to finish):" -ForegroundColor Cyan
        $entries = [System.Collections.ArrayList]::new()
        while ($true) {
            Write-Host "  > " -NoNewline -ForegroundColor DarkYellow
            $line = Read-Host
            if ([string]::IsNullOrWhiteSpace($line)) { break }
            [void]$entries.Add($line.Trim())
        }
        if ($entries.Count -lt 2) {
            Write-Host "  Need at least 2 entries!" -ForegroundColor Red
            return
        }
        $entries = [string[]]$entries
    }

    $scores = @{}; foreach ($e in $entries) { $scores[$e] = 0 }
    $history = [System.Collections.ArrayList]::new()
    $round = 0

    # ── GAME LOOP ─────────────────────────────────────────────────────
    while ($true) {
        $round++
        Clear-Host
        $scr = Get-ScreenSize

        $wheelRadius = [Math]::Min(9, [Math]::Floor(($scr.H - 12) / 2))
        if ($wheelRadius -lt 3) { $wheelRadius = 3 }
        $centerX = [Math]::Floor($scr.W / 2)
        $centerY = $wheelRadius + 4

        # Title bar
        $titleHz = ([string][char]0x2550) * $scr.W
        Safe-WriteAt 0 0 $titleHz "DarkCyan"
        $starCh = [string][char]0x2605
        Write-CenteredAt 1 " WHEEL OF NAMES $starCh Round $round " "Cyan"
        Safe-WriteAt 0 2 $titleHz "DarkCyan"

        # Wheel
        Draw-Wheel -Entries $entries -HighlightIndex -1 -CX $centerX -CY $centerY -Radius $wheelRadius

        # Sidebars
        if ($scr.W -gt 90) {
            $sideH = [Math]::Min(($entries.Count + 4), ($scr.H - 8))
            Draw-Scoreboard $scores 1 3 $sideH
            Draw-History $history ($scr.W - 28) 3 ([Math]::Min(14, ($scr.H - 8)))
        }

        # Controls
        $statusY = [Math]::Min($centerY + $wheelRadius + 3, $scr.H - 4)
        $statusHz = ([string][char]0x2500) * $scr.W
        Safe-WriteAt 0 $statusY $statusHz "DarkGray"
        Safe-WriteAt 2 ($statusY + 1) "[SPACE] Spin  [R] Remove winner  [Q] Quit" "DarkYellow"
        Safe-WriteAt 2 ($statusY + 2) "Press a key..." "Gray"

        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        # QUIT
        if ($key.Character -eq 'q' -or $key.Character -eq 'Q') {
            Clear-Host
            $y = Draw-Banner
            $y++
            Write-CenteredAt $y "Thanks for playing!" "Yellow"
            $y += 2
            if ($history.Count -gt 0) {
                Write-CenteredAt $y "=== Final Results ===" "Cyan"; $y++
                $sorted = $scores.GetEnumerator() | Sort-Object Value -Descending
                foreach ($s in $sorted) {
                    if ($s.Value -gt 0) {
                        Write-CenteredAt $y ("{0}: {1} win(s)" -f $s.Key, $s.Value) "White"; $y++
                    }
                }
                $y++
                Write-CenteredAt $y "=== Spin History ===" "DarkCyan"; $y++
                for ($i = 0; $i -lt $history.Count; $i++) {
                    Write-CenteredAt $y ("{0,3}. {1}" -f ($i+1), $history[$i]) "Gray"; $y++
                }
            }
            try {
                $pos = $Host.UI.RawUI.CursorPosition
                $pos.X = 0; $pos.Y = [Math]::Min($y + 1, $scr.H - 1)
                $Host.UI.RawUI.CursorPosition = $pos
            } catch { }
            Write-Host ""
            return
        }

        # REMOVE LAST WINNER
        if ($key.Character -eq 'r' -or $key.Character -eq 'R') {
            if ($history.Count -gt 0) {
                $lastWinner = $history[$history.Count - 1]
                $entries = @($entries | Where-Object { $_ -ne $lastWinner })
                if ($entries.Count -lt 2) {
                    Safe-WriteAt 2 ($statusY + 2) "Not enough entries left!" "Red"
                    Start-Sleep -Seconds 2
                    if ($entries.Count -lt 2) { return }
                }
            }
            continue
        }

        # ── SPIN ──
        @("3","2","1","SPIN!") | ForEach-Object {
            Safe-WriteAt ($centerX - 3) $centerY "       " "Black"
            $cc = if ($_ -eq "SPIN!") { "Yellow" } else { "White" }
            Safe-WriteAt ($centerX - [Math]::Floor($_.Length / 2)) $centerY $_ $cc
            Beep-Safe 600 80
            Start-Sleep -Milliseconds 350
        }

        $winnerIdx = Invoke-Spin -Entries $entries -CX $centerX -CY $centerY -Radius $wheelRadius

        $winner = $entries[$winnerIdx]
        [void]$history.Add($winner)
        if ($scores.ContainsKey($winner)) { $scores[$winner]++ } else { $scores[$winner] = 1 }

        # ── WINNER DISPLAY ──
        $winY = [Math]::Min($statusY, $scr.H - 6)
        Safe-ClearRegion 0 $winY $scr.W ([Math]::Max(1, $scr.H - $winY))

        $row1 = $winY + 0
        $row2 = $winY + 1
        $row3 = $winY + 2
        $row4 = $winY + 3

        Safe-WriteAt 0 $row1 (([string][char]0x2500) * $scr.W) "Yellow"
        Write-CenteredAt $row2 ".  *  .  *  WINNER!  *  .  *  ." "Yellow"
        Write-CenteredAt $row3 (">>>  " + $winner + "  <<<") "White"
        Write-CenteredAt $row4 ".  *  .  *  .  *  .  *  .  *  ." "Yellow"

        # Victory jingle
        Beep-Safe 523 100; Beep-Safe 659 100; Beep-Safe 784 100; Beep-Safe 1047 150

        # Flash
        for ($f = 0; $f -lt 6; $f++) {
            $fc = @("Yellow","Red","Cyan","Magenta","Green","White")[$f]
            Write-CenteredAt $row3 (">>>  " + $winner + "  <<<") $fc
            Start-Sleep -Milliseconds 180
        }
        Write-CenteredAt $row3 (">>>  " + $winner + "  <<<") "White"

        $promptRow = [Math]::Min($row4 + 2, $scr.H - 1)
        Safe-WriteAt 2 $promptRow "Press any key for next spin..." "DarkGray"
        [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# ── ALIASES ────────────────────────────────────────────────────────────
Set-Alias -Name wheel -Value Start-WheelOfNames
Set-Alias -Name spin  -Value Start-WheelOfNames

Write-Host ""
Write-Host "  Wheel of Names loaded!" -ForegroundColor Cyan
Write-Host "  Usage:" -ForegroundColor Gray
Write-Host '    Start-WheelOfNames -Names @("Alice","Bob","Charlie","Diana","Eve","Frank")' -ForegroundColor Yellow
Write-Host '    Start-WheelOfNames -WheelId "your-shared-wheel-id"' -ForegroundColor Yellow
Write-Host '    Start-WheelOfNames                  # manual entry mode' -ForegroundColor Yellow
Write-Host '    Start-WheelOfNames -NoSound         # disable beeps' -ForegroundColor Yellow
Write-Host ""
Write-Host "  Aliases: wheel, spin" -ForegroundColor DarkGray
Write-Host ""