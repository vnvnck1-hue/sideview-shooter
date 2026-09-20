param(
    [Parameter(Mandatory = $true)]
    [string] $Path,

    [int] $ExpectedWidth = 0,
    [int] $ExpectedHeight = 0,
    [int] $MaxOpaqueColors = 16,
    [switch] $RequireBinaryAlpha,
    [switch] $RequireTransparentBorder
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$resolvedPath = (Resolve-Path -LiteralPath $Path).Path
$bitmap = New-Object System.Drawing.Bitmap($resolvedPath)

try {
    $colors = New-Object 'System.Collections.Generic.HashSet[string]'
    $partialAlphaPixels = 0
    $opaquePixels = 0
    $borderPixels = 0

    for ($y = 0; $y -lt $bitmap.Height; $y++) {
        for ($x = 0; $x -lt $bitmap.Width; $x++) {
            $pixel = $bitmap.GetPixel($x, $y)
            if ($pixel.A -gt 0 -and $pixel.A -lt 255) {
                $partialAlphaPixels++
            }
            if ($pixel.A -eq 255) {
                $opaquePixels++
                [void] $colors.Add(('{0:X2}{1:X2}{2:X2}' -f $pixel.R, $pixel.G, $pixel.B))
            }
            if (($x -eq 0 -or $y -eq 0 -or $x -eq ($bitmap.Width - 1) -or $y -eq ($bitmap.Height - 1)) -and $pixel.A -ne 0) {
                $borderPixels++
            }
        }
    }

    $errors = New-Object System.Collections.Generic.List[string]
    if ($ExpectedWidth -gt 0 -and $bitmap.Width -ne $ExpectedWidth) {
        $errors.Add("Expected width $ExpectedWidth, got $($bitmap.Width).")
    }
    if ($ExpectedHeight -gt 0 -and $bitmap.Height -ne $ExpectedHeight) {
        $errors.Add("Expected height $ExpectedHeight, got $($bitmap.Height).")
    }
    if ($RequireBinaryAlpha -and $partialAlphaPixels -ne 0) {
        $errors.Add("Found $partialAlphaPixels pixels with partial alpha.")
    }
    if ($MaxOpaqueColors -gt 0 -and $colors.Count -gt $MaxOpaqueColors) {
        $errors.Add("Expected at most $MaxOpaqueColors opaque colors, got $($colors.Count).")
    }
    if ($RequireTransparentBorder -and $borderPixels -ne 0) {
        $errors.Add("Found $borderPixels non-transparent pixels on the canvas border.")
    }

    $result = [ordered]@{
        path = $resolvedPath
        width = $bitmap.Width
        height = $bitmap.Height
        opaquePixels = $opaquePixels
        opaqueColors = $colors.Count
        partialAlphaPixels = $partialAlphaPixels
        nonTransparentBorderPixels = $borderPixels
        passed = ($errors.Count -eq 0)
        errors = @($errors)
    }

    $result | ConvertTo-Json -Depth 4

    if ($errors.Count -gt 0) {
        throw "Native pixel-art validation failed for $resolvedPath"
    }
}
finally {
    $bitmap.Dispose()
}

