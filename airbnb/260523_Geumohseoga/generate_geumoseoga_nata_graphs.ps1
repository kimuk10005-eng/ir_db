$ErrorActionPreference = "Stop"

$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutDir = Join-Path $Base "금오서가_나타_그래프"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$Culture = [System.Globalization.CultureInfo]::InvariantCulture

Add-Type -AssemblyName System.Drawing

function Convert-ToDouble {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }
    $out = 0.0
    if ([double]::TryParse($Value, [System.Globalization.NumberStyles]::Float, $Culture, [ref]$out)) {
        return $out
    }
    return $null
}

function Get-SensorRows {
    param([string]$Path)

    $rows = New-Object System.Collections.Generic.List[object]
    $index = 0

    foreach ($row in (Import-Csv -LiteralPath $Path)) {
        $recordType = [string]$row.record_type

        if ($recordType -eq "data") {
            $x = Convert-ToDouble $row.time_s
            if ($null -eq $x) {
                $x = $index * 0.1
            }

            $y = Convert-ToDouble $row.avg_on
            if ($null -eq $y) {
                $y = Convert-ToDouble $row.raw_on
            }

            if ($null -ne $y) {
                $rows.Add([pscustomobject]@{ X = $x; Y = $y }) | Out-Null
                $index += 1
            }
            continue
        }

        $rawLine = [string]$row.raw_line
        if ($rawLine -match "Time=([0-9.]+)s.*CurrentRaw=([0-9.]+)") {
            $x = Convert-ToDouble $Matches[1]
            $y = Convert-ToDouble $Matches[2]
            if ($null -ne $x -and $null -ne $y) {
                $rows.Add([pscustomobject]@{ X = $x; Y = $y }) | Out-Null
            }
        }
    }

    return $rows
}

function Get-NiceStep {
    param(
        [double]$Range,
        [int]$TargetTicks = 7
    )

    if ($Range -le 0) {
        return 1.0
    }

    $rawStep = $Range / [Math]::Max(1, $TargetTicks)
    $power = [Math]::Pow(10, [Math]::Floor([Math]::Log10($rawStep)))
    $fraction = $rawStep / $power

    if ($fraction -le 1) { return 1 * $power }
    if ($fraction -le 2) { return 2 * $power }
    if ($fraction -le 5) { return 5 * $power }
    return 10 * $power
}

function Format-Tick {
    param([double]$Value)
    if ([Math]::Abs($Value - [Math]::Round($Value)) -lt 0.000001) {
        return ([int][Math]::Round($Value)).ToString($Culture)
    }
    return $Value.ToString("0.##", $Culture)
}

function Save-SensorGraph {
    param(
        [System.Collections.Generic.List[object]]$Rows,
        [string]$Title,
        [string]$OutPath
    )

    if ($Rows.Count -lt 2) {
        Write-Host "skip: $Title (not enough data)"
        return
    }

    $width = 1660
    $height = 610
    $left = 78
    $right = 34
    $top = 58
    $bottom = 58
    $plotWidth = $width - $left - $right
    $plotHeight = $height - $top - $bottom

    $xs = @($Rows | ForEach-Object { [double]$_.X })
    $ys = @($Rows | ForEach-Object { [double]$_.Y })

    $xMin = 0.0
    $xMax = ($xs | Measure-Object -Maximum).Maximum
    if ($xMax -le $xMin) {
        $xMax = $xMin + 1.0
    }

    $yMinData = ($ys | Measure-Object -Minimum).Minimum
    $yMaxData = ($ys | Measure-Object -Maximum).Maximum
    $yPad = [Math]::Max(1.0, ($yMaxData - $yMinData) * 0.12)
    $yMin = $yMinData - $yPad
    $yMax = $yMaxData + $yPad
    $yStep = Get-NiceStep -Range ($yMax - $yMin) -TargetTicks 7
    $yMin = [Math]::Floor($yMin / $yStep) * $yStep
    $yMax = [Math]::Ceiling($yMax / $yStep) * $yStep

    $xStep = Get-NiceStep -Range ($xMax - $xMin) -TargetTicks 6
    $xMaxTick = [Math]::Ceiling($xMax / $xStep) * $xStep
    $xMax = [Math]::Max($xMax, $xMaxTick)

    $bitmap = New-Object System.Drawing.Bitmap $width, $height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

    $white = [System.Drawing.Brushes]::White
    $gridPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(224, 224, 224)), 1
    $axisPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(32, 32, 32)), 1
    $linePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(80, 154, 216)), 1.8
    $textBrush = [System.Drawing.Brushes]::Black
    $legendBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(80, 154, 216))

    $titleFont = New-Object System.Drawing.Font "Malgun Gothic", 18, ([System.Drawing.FontStyle]::Bold)
    $labelFont = New-Object System.Drawing.Font "Malgun Gothic", 10
    $tickFont = New-Object System.Drawing.Font "Malgun Gothic", 10
    $legendFont = New-Object System.Drawing.Font "Malgun Gothic", 10

    $center = New-Object System.Drawing.StringFormat
    $center.Alignment = [System.Drawing.StringAlignment]::Center
    $center.LineAlignment = [System.Drawing.StringAlignment]::Center

    $rightAlign = New-Object System.Drawing.StringFormat
    $rightAlign.Alignment = [System.Drawing.StringAlignment]::Far
    $rightAlign.LineAlignment = [System.Drawing.StringAlignment]::Center

    $graphics.FillRectangle($white, 0, 0, $width, $height)

    $titleRect = New-Object System.Drawing.RectangleF 0, 7, $width, 38
    $graphics.DrawString($Title, $titleFont, $textBrush, $titleRect, $center)

    $graphics.DrawString("Raw sensor value (ADC)", $labelFont, $textBrush, 15, 30)
    $xLabelRect = New-Object System.Drawing.RectangleF $left, ($height - 31), $plotWidth, 24
    $graphics.DrawString("Time (s)", $labelFont, $textBrush, $xLabelRect, $center)

    function XToPixel([double]$x) {
        return $left + (($x - $xMin) / ($xMax - $xMin)) * $plotWidth
    }

    function YToPixel([double]$y) {
        return $top + (($yMax - $y) / ($yMax - $yMin)) * $plotHeight
    }

    for ($xTick = $xMin; $xTick -le $xMax + ($xStep * 0.001); $xTick += $xStep) {
        $px = [float](XToPixel $xTick)
        $graphics.DrawLine($gridPen, $px, $top, $px, $top + $plotHeight)
        $tickRect = New-Object System.Drawing.RectangleF ($px - 25), ($top + $plotHeight + 8), 50, 22
        $graphics.DrawString((Format-Tick $xTick), $tickFont, $textBrush, $tickRect, $center)
    }

    for ($yTick = $yMin; $yTick -le $yMax + ($yStep * 0.001); $yTick += $yStep) {
        $py = [float](YToPixel $yTick)
        $graphics.DrawLine($gridPen, $left, $py, $left + $plotWidth, $py)
        $tickRect = New-Object System.Drawing.RectangleF 5, ($py - 11), ($left - 15), 22
        $graphics.DrawString((Format-Tick $yTick), $tickFont, $textBrush, $tickRect, $rightAlign)
    }

    $graphics.DrawRectangle($axisPen, $left, $top, $plotWidth, $plotHeight)

    $points = New-Object "System.Drawing.PointF[]" $Rows.Count
    for ($i = 0; $i -lt $Rows.Count; $i++) {
        $points[$i] = New-Object System.Drawing.PointF ([float](XToPixel $Rows[$i].X)), ([float](YToPixel $Rows[$i].Y))
    }
    $graphics.DrawLines($linePen, $points)

    $legendX = $width - 200
    $legendY = $height - 86
    $graphics.FillRectangle($legendBrush, $legendX, $legendY + 8, 30, 8)
    $legendRect = New-Object System.Drawing.RectangleF ($legendX + 42), $legendY, 90, 24
    $graphics.DrawString("센서값", $legendFont, $textBrush, $legendRect)

    $bitmap.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $graphics.Dispose()
    $bitmap.Dispose()
    $gridPen.Dispose()
    $axisPen.Dispose()
    $linePen.Dispose()
    $legendBrush.Dispose()
    $titleFont.Dispose()
    $labelFont.Dispose()
    $tickFont.Dispose()
    $legendFont.Dispose()
    $center.Dispose()
    $rightAlign.Dispose()
}

$csvFiles = Get-ChildItem -LiteralPath $Base -Filter "*.csv" -File | Sort-Object Name
$renamedFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]

foreach ($file in $csvFiles) {
    $newName = $file.Name
    if ($newName -notlike "금오서가_나타*.csv") {
        if ($newName -like "나타 *") {
            $newName = "금오서가_" + $newName
        } else {
            $newName = "금오서가_나타 " + $newName
        }
    }

    if ($newName -ne $file.Name) {
        $targetPath = Join-Path $Base $newName
        if (Test-Path -LiteralPath $targetPath) {
            throw "Cannot rename '$($file.Name)' because '$newName' already exists."
        }
        Rename-Item -LiteralPath $file.FullName -NewName $newName
        $file = Get-Item -LiteralPath $targetPath
        Write-Host "renamed: $($file.Name)"
    }

    $renamedFiles.Add($file) | Out-Null
}

foreach ($file in $renamedFiles) {
    $rows = Get-SensorRows -Path $file.FullName
    $title = [System.IO.Path]::GetFileNameWithoutExtension($file.Name) + " (원본 센서값)"
    $outPath = Join-Path $OutDir ([System.IO.Path]::GetFileNameWithoutExtension($file.Name) + ".png")
    Save-SensorGraph -Rows $rows -Title $title -OutPath $outPath
    Write-Host "saved: $outPath"
}

Write-Host "done: $($renamedFiles.Count) csv files, output=$OutDir"


