param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$NativeRoot = Join-Path $ProjectRoot 'Assets\GameReady\Native4'
$ReadyRoot = Join-Path $ProjectRoot 'Assets\GameReady'
$RuntimeRoot = Join-Path $ProjectRoot 'GodotPrototype\assets'
$ValidationRoot = Join-Path $ReadyRoot 'Validation'

$Themes = [ordered]@{
    research_analysis = [ordered]@{
        wall='#879da6'; panel='#99adb4'; light='#d6ded9'; shade='#667e89'; line='#526d79'; deep='#253b4b';
        floor='#b7c4c2'; accent='#54d8bd'; glass='#83bbb9'; screen='#287a7c'; warm='#c8c9bd';
        props=@('specimen_chamber','analysis_bench','microscope_station','cold_storage','sample_cart')
    }
    research_isolation = [ordered]@{
        wall='#94a5ad'; panel='#aab9bd'; light='#e0e4df'; shade='#748992'; line='#5e747e'; deep='#293f4c';
        floor='#c4d0cc'; accent='#55d8ed'; glass='#91cbd2'; screen='#338aa0'; warm='#d0d3ca';
        props=@('decon_arch','isolation_pod','wash_station','medical_cabinet','uv_sterilizer')
    }
    research_diagnostics = [ordered]@{
        wall='#81939f'; panel='#96a8b2'; light='#d1d9d8'; shade='#617886'; line='#4c6573'; deep='#1f3447';
        floor='#acbdc2'; accent='#5ab9ff'; glass='#79aabd'; screen='#245f84'; warm='#c8cac2';
        props=@('diagnostic_console','server_rack','wall_display','signal_scope','drone_dock')
    }
}

$Sizes = @{
    specimen_chamber=@(52,84); analysis_bench=@(96,53); microscope_station=@(55,59); cold_storage=@(56,75); sample_cart=@(63,48)
    decon_arch=@(79,102); isolation_pod=@(102,62); wash_station=@(65,59); medical_cabinet=@(54,79); uv_sterilizer=@(54,68)
    diagnostic_console=@(94,62); server_rack=@(61,88); wall_display=@(100,53); signal_scope=@(58,65); drone_dock=@(80,55)
}

function Color([string]$Hex) { return [System.Drawing.ColorTranslator]::FromHtml($Hex) }
function New-Bitmap([int]$Width,[int]$Height,[string]$Fill=$null) {
    $bitmap = [System.Drawing.Bitmap]::new($Width,$Height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    if ($Fill) { $g=[System.Drawing.Graphics]::FromImage($bitmap); $g.Clear((Color $Fill)); $g.Dispose() }
    return $bitmap
}
function Fill-Rect($Bitmap,[int]$X0,[int]$Y0,[int]$X1,[int]$Y1,[string]$Hex) {
    $c=Color $Hex
    for($y=$Y0;$y -le $Y1;$y++){ for($x=$X0;$x -le $X1;$x++){ if($x -ge 0 -and $y -ge 0 -and $x -lt $Bitmap.Width -and $y -lt $Bitmap.Height){$Bitmap.SetPixel($x,$y,$c)} } }
}
function Blit($Destination,$Source,[int]$X,[int]$Y) {
    $g=[System.Drawing.Graphics]::FromImage($Destination)
    $g.CompositingMode=[System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $g.DrawImageUnscaled($Source,$X,$Y)
    $g.Dispose()
}
function Upscale4($Bitmap) {
    $large=New-Bitmap ($Bitmap.Width*4) ($Bitmap.Height*4)
    $g=[System.Drawing.Graphics]::FromImage($large)
    $g.CompositingMode=[System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $g.DrawImage($Bitmap,[System.Drawing.Rectangle]::new(0,0,$large.Width,$large.Height),0,0,$Bitmap.Width,$Bitmap.Height,[System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose(); return $large
}
function Save-Png($Bitmap,[string]$Path) {
    $dir=Split-Path -Parent $Path
    if(-not (Test-Path -LiteralPath $dir)){New-Item -ItemType Directory -Path $dir -Force | Out-Null}
    $Bitmap.Save($Path,[System.Drawing.Imaging.ImageFormat]::Png)
}
function Make-Normal($Bitmap,[double]$Strength=2.6) {
    $normal=New-Bitmap $Bitmap.Width $Bitmap.Height '#8080ff'
    for($y=0;$y -lt $Bitmap.Height;$y++){for($x=0;$x -lt $Bitmap.Width;$x++){
        $c=$Bitmap.GetPixel($x,$y)
        if($c.A -eq 0){continue}
        $xl=[Math]::Max(0,$x-1);$xr=[Math]::Min($Bitmap.Width-1,$x+1);$yu=[Math]::Max(0,$y-1);$yd=[Math]::Min($Bitmap.Height-1,$y+1)
        $l=$Bitmap.GetPixel($xl,$y);$r=$Bitmap.GetPixel($xr,$y);$u=$Bitmap.GetPixel($x,$yu);$d=$Bitmap.GetPixel($x,$yd)
        $lh=($l.R+$l.G+$l.B)/765.0;$rh=($r.R+$r.G+$r.B)/765.0;$uh=($u.R+$u.G+$u.B)/765.0;$dh=($d.R+$d.G+$d.B)/765.0
        $nx=-($rh-$lh)*$Strength;$ny=-($dh-$uh)*$Strength;$nz=1.0;$len=[Math]::Sqrt($nx*$nx+$ny*$ny+$nz*$nz)
        $rr=[int][Math]::Round(($nx/$len*0.5+0.5)*255);$gg=[int][Math]::Round(($ny/$len*0.5+0.5)*255);$bb=[int][Math]::Round(($nz/$len*0.5+0.5)*255)
        $normal.SetPixel($x,$y,[System.Drawing.Color]::FromArgb(255,$rr,$gg,$bb))
    }}
    return $normal
}
function Save-Asset($Bitmap,[string]$Relative,[string]$ReadyRelative) {
    Save-Png $Bitmap (Join-Path $NativeRoot $Relative)
    $large=Upscale4 $Bitmap
    Save-Png $large (Join-Path $RuntimeRoot $Relative)
    if($ReadyRelative){Save-Png $large (Join-Path $ReadyRoot $ReadyRelative)}
    $nativeNormal=Make-Normal $Bitmap
    $normal=Upscale4 $nativeNormal
    Save-Png $normal (Join-Path (Join-Path $RuntimeRoot 'normals') $Relative)
    $nativeNormal.Dispose(); $normal.Dispose(); $large.Dispose()
}
function Publish-NativeAsset($Bitmap,[string]$Relative,[string]$ReadyRelative) {
    $large=Upscale4 $Bitmap
    Save-Png $large (Join-Path $RuntimeRoot $Relative)
    if($ReadyRelative){Save-Png $large (Join-Path $ReadyRoot $ReadyRelative)}
    $nativeNormal=Make-Normal $Bitmap
    $normal=Upscale4 $nativeNormal
    Save-Png $normal (Join-Path (Join-Path $RuntimeRoot 'normals') $Relative)
    $nativeNormal.Dispose(); $normal.Dispose(); $large.Dispose()
}
function Make-BackgroundMacro($P) {
    $b=New-Bitmap 96 64 $P.panel
    Fill-Rect $b 0 0 1 63 $P.deep;Fill-Rect $b 2 0 2 63 $P.light;Fill-Rect $b 3 0 5 63 $P.shade
    Fill-Rect $b 91 0 93 63 $P.shade;Fill-Rect $b 94 0 94 63 $P.light;Fill-Rect $b 95 0 95 63 $P.line
    foreach($pt in @(@(8,10),@(87,10),@(8,54),@(87,54))){Fill-Rect $b $pt[0] $pt[1] ($pt[0]+1) ($pt[1]+1) $P.line;Fill-Rect $b $pt[0] $pt[1] $pt[0] $pt[1] $P.light}
    return $b
}
function Make-Background($P,[int]$Variant) {
    $macro=Make-BackgroundMacro $P;$b=New-Bitmap 32 32
    $sx=($Variant%3)*32;$sy=[int]([Math]::Floor($Variant/3))*32
    $g=[System.Drawing.Graphics]::FromImage($b);$g.CompositingMode=[System.Drawing.Drawing2D.CompositingMode]::SourceCopy;$g.DrawImage($macro,[System.Drawing.Rectangle]::new(0,0,32,32),$sx,$sy,32,32,[System.Drawing.GraphicsUnit]::Pixel);$g.Dispose();$macro.Dispose();return $b
}
function Make-Frame($P,[string]$Kind) {
    $b=New-Bitmap 32 32
    $top=$Kind -in @('top','top_left','top_right');$bottom=$Kind -in @('bottom','bottom_left','bottom_right');$left=$Kind -in @('left','top_left','bottom_left');$right=$Kind -in @('right','top_right','bottom_right')
    if($top){Fill-Rect $b 0 0 31 11 $P.deep;Fill-Rect $b 0 2 31 3 $P.line;Fill-Rect $b 0 4 31 5 $P.light;Fill-Rect $b 0 6 31 9 $P.shade;Fill-Rect $b 0 10 31 11 $P.line}
    if($bottom){Fill-Rect $b 0 20 31 31 $P.deep;Fill-Rect $b 0 20 31 21 $P.line;Fill-Rect $b 0 22 31 25 $P.floor;Fill-Rect $b 0 26 31 26 $P.light;Fill-Rect $b 0 27 31 31 $P.shade}
    if($left){Fill-Rect $b 0 0 13 31 $P.deep;Fill-Rect $b 2 0 3 31 $P.line;Fill-Rect $b 4 0 5 31 $P.light;Fill-Rect $b 6 0 11 31 $P.shade;Fill-Rect $b 12 0 13 31 $P.line}
    if($right){Fill-Rect $b 18 0 31 31 $P.deep;Fill-Rect $b 18 0 19 31 $P.line;Fill-Rect $b 20 0 21 31 $P.light;Fill-Rect $b 22 0 27 31 $P.shade;Fill-Rect $b 28 0 29 31 $P.line}
    if(($top -or $bottom) -and ($left -or $right)){$xx=if($left){10}else{20};$yy=if($top){8}else{22};Fill-Rect $b $xx $yy ($xx+1) ($yy+1) $P.accent}
    return $b
}
function Make-Bend($P,[string]$Name) {
    $kind=if($Name -eq 'top_left'){'top_left'}elseif($Name -eq 'top_right'){'top_right'}elseif($Name -eq 'bottom_left'){'bottom_left'}else{'bottom_right'}
    $src=Make-Frame $P $kind; $out=New-Bitmap 32 32
    $sx=if($Name -like '*left'){0}else{18};$sy=if($Name -like 'top*'){0}else{20};$w=14;$h=12
    $g=[System.Drawing.Graphics]::FromImage($out);$g.CompositingMode=[System.Drawing.Drawing2D.CompositingMode]::SourceCopy;$g.DrawImage($src,[System.Drawing.Rectangle]::new($sx,$sy,$w,$h),$sx,$sy,$w,$h,[System.Drawing.GraphicsUnit]::Pixel);$g.Dispose();$src.Dispose();return $out
}
function Make-Sheet($Images,[int]$Columns) {
    $rows=[int][Math]::Ceiling($Images.Count/$Columns);$out=New-Bitmap ($Columns*32) ($rows*32)
    for($i=0;$i -lt $Images.Count;$i++){Blit $out $Images[$i] (($i%$Columns)*32) ([int]([Math]::Floor($i/$Columns))*32)}
    return $out
}

$playerPath = Join-Path $ReadyRoot 'Characters\HoodedMechanic\Frames\idle\idle_01.png'
$player = [System.Drawing.Bitmap]::FromFile($playerPath)

foreach($theme in $Themes.Keys){
    $p=$Themes[$theme];$props=@{}
    for($i=0;$i -lt $p.props.Count;$i++){
        $name=$p.props[$i];$size=$Sizes[$name];$relative="props\$theme\${theme}_${name}.png";$nativePath=Join-Path $NativeRoot $relative
        if(-not (Test-Path -LiteralPath $nativePath -PathType Leaf)){throw "Missing Aseprite-native prop: $nativePath"}
        $img=[System.Drawing.Bitmap]::FromFile($nativePath)
        if($img.Width -ne $size[0] -or $img.Height -ne $size[1]){throw "Unexpected native size for ${theme}_${name}: $($img.Width)x$($img.Height)"}
        $props[$name]=$img;Publish-NativeAsset $img $relative "Props\$theme\${theme}_${name}.png"
    }
    $bgs=@();for($i=0;$i -lt 6;$i++){$img=Make-Background $p $i;$bgs+=$img;$letter=[char](97+$i);Save-Asset $img "tiles\${theme}_modular\Background\${theme}_bg_fill_${letter}.png" "Tiles\${theme}_Modular\Background\${theme}_bg_fill_${letter}.png"}
    $names=@('top_left','top','top_right','left','right','bottom_left','bottom','bottom_right');$frames=[ordered]@{};foreach($n in $names){$img=Make-Frame $p $n;$frames[$n]=$img;Save-Asset $img "tiles\${theme}_modular\Frame\${theme}_frame_${n}.png" "Tiles\${theme}_Modular\Frame\${theme}_frame_${n}.png"}
    $bendNames=@('top_left','top_right','bottom_left','bottom_right');$bends=@();foreach($n in $bendNames){$img=Make-Bend $p $n;$bends+=$img;Save-Asset $img "tiles\${theme}_modular\Frame\InnerCorners\${theme}_frame_inner_${n}.png" "Tiles\${theme}_Modular\Frame\InnerCorners\${theme}_frame_inner_${n}.png"}
    $bgSheet=Make-Sheet $bgs 3;$frameSheet=Make-Sheet @($frames.Values) 4;$terrain=Make-Sheet (@($frames.Values)+(New-Bitmap 32 32)) 3;$bendSheet=Make-Sheet $bends 4
    foreach($pair in @(@('background_sheet_3x2',$bgSheet),@('frame_sheet_4x2',$frameSheet),@('frame_terrain_3x3',$terrain),@('frame_bend_sheet_4x1',$bendSheet))){Save-Asset $pair[1] "tiles\${theme}_modular\${theme}_modular_$($pair[0]).png" "Tiles\${theme}_Modular\${theme}_modular_$($pair[0]).png"}
    $preview=New-Bitmap 448 192 $p.deep
    for($yy=0;$yy -lt 6;$yy++){for($xx=0;$xx -lt 14;$xx++){$bgIndex=($xx%3)+($yy%2)*3;Blit $preview $bgs[$bgIndex] ($xx*32) ($yy*32);$edge=if($yy -eq 0 -and $xx -eq 0){'top_left'}elseif($yy -eq 0 -and $xx -eq 13){'top_right'}elseif($yy -eq 5 -and $xx -eq 0){'bottom_left'}elseif($yy -eq 5 -and $xx -eq 13){'bottom_right'}elseif($yy -eq 0){'top'}elseif($yy -eq 5){'bottom'}elseif($xx -eq 0){'left'}elseif($xx -eq 13){'right'}else{$null};if($edge){Blit $preview $frames[$edge] ($xx*32) ($yy*32)}}}
    $xs=if($theme -eq 'research_analysis'){@(40,105,195,275,365)}elseif($theme -eq 'research_isolation'){@(45,138,258,330,395)}else{@(145,55,255,340)}
    $ids=if($theme -eq 'research_diagnostics'){@(0,1,3,4)}else{@(0,1,2,3,4)};$ground=180
    for($j=0;$j -lt $ids.Count;$j++){$img=$props[$p.props[$ids[$j]]];Blit $preview $img $xs[$j] ($ground-$img.Height+1)}
    if($theme -eq 'research_diagnostics'){$img=$props['wall_display'];Blit $preview $img 258 45}
    $largePreview=Upscale4 $preview;Save-Png $largePreview (Join-Path $ValidationRoot "${theme}_room_preview.png")
    $playerReview=New-Bitmap $largePreview.Width $largePreview.Height;Blit $playerReview $largePreview 0 0
    $playerX=if($theme -eq 'research_analysis'){860}elseif($theme -eq 'research_isolation'){1010}else{740}
    Blit $playerReview $player $playerX 400
    Save-Png $playerReview (Join-Path $ValidationRoot "${theme}_player_scale_review.png")
    $playerReview.Dispose();$largePreview.Dispose();$preview.Dispose()
    foreach($img in $props.Values){$img.Dispose()};foreach($img in $bgs){$img.Dispose()};foreach($img in $frames.Values){$img.Dispose()};foreach($img in $bends){$img.Dispose()};$bgSheet.Dispose();$frameSheet.Dispose();$terrain.Dispose();$bendSheet.Dispose()
}

$player.Dispose()
Write-Host 'Built research facility V3: Aseprite-native props, dense native tiles, runtime assets, native-grid normal maps, and validation previews.'
