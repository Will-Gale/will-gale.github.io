$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$src = "c:\Users\willg\source\repos\sonderdev-landing\logo-clean.png"
$dst = "c:\Users\willg\source\repos\sonderdev-landing\logo-transparent.png"

$bmp = [System.Drawing.Bitmap]::FromFile($src)
$w = $bmp.Width
$h = $bmp.Height

# Track background pixels connected to borders.
$visited = New-Object 'bool[,]' $w, $h
$queue = New-Object System.Collections.Generic.Queue[System.Drawing.Point]

function IsBgColor([System.Drawing.Color]$c) {
    $max = [Math]::Max($c.R, [Math]::Max($c.G, $c.B))
    $min = [Math]::Min($c.R, [Math]::Min($c.G, $c.B))
    $sat = if ($max -eq 0) { 0.0 } else { ($max - $min) / [double]$max }
    $val = $max / 255.0
    return (($val -lt 0.24) -or (($sat -lt 0.18) -and ($val -lt 0.44)))
}

function EnqueueIfBg([int]$x, [int]$y) {
    if ($x -lt 0 -or $y -lt 0 -or $x -ge $w -or $y -ge $h) { return }
    if ($visited[$x, $y]) { return }
    $c = $bmp.GetPixel($x, $y)
    if (IsBgColor $c) {
        $visited[$x, $y] = $true
        $queue.Enqueue([System.Drawing.Point]::new($x, $y))
    }
}

for ($x = 0; $x -lt $w; $x++) {
    EnqueueIfBg $x 0
    EnqueueIfBg $x ($h - 1)
}
for ($y = 0; $y -lt $h; $y++) {
    EnqueueIfBg 0 $y
    EnqueueIfBg ($w - 1) $y
}

while ($queue.Count -gt 0) {
    $p = $queue.Dequeue()
    $x = $p.X
    $y = $p.Y
    EnqueueIfBg ($x + 1) $y
    EnqueueIfBg ($x - 1) $y
    EnqueueIfBg $x ($y + 1)
    EnqueueIfBg $x ($y - 1)
}

$minX = $w
$minY = $h
$maxX = -1
$maxY = -1

for ($x = 0; $x -lt $w; $x++) {
    for ($y = 0; $y -lt $h; $y++) {
        $c = $bmp.GetPixel($x, $y)
        if ($visited[$x, $y]) {
            $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, $c.R, $c.G, $c.B))
        }
        elseif ($c.A -gt 8) {
            if ($x -lt $minX) { $minX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}

if ($maxX -gt $minX -and $maxY -gt $minY) {
    $pad = 8
    $cropW = $maxX - $minX + 1
    $cropH = $maxY - $minY + 1
    $out = New-Object System.Drawing.Bitmap ($cropW + 2 * $pad), ($cropH + 2 * $pad), ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.Clear([System.Drawing.Color]::Transparent)
    $srcRect = New-Object System.Drawing.Rectangle($minX, $minY, $cropW, $cropH)
    $dstRect = New-Object System.Drawing.Rectangle($pad, $pad, $cropW, $cropH)
    $g.DrawImage($bmp, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $out.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
    $out.Dispose()
}
else {
    $bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
}

$bmp.Dispose()
