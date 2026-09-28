$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class CreatureExportCheck {
 static byte[] Read(Bitmap b){var d=b.LockBits(new Rectangle(0,0,b.Width,b.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);var a=new byte[b.Width*b.Height*4];Marshal.Copy(d.Scan0,a,0,a.Length);b.UnlockBits(d);return a;}
 public static void Frame(string native,string runtime,string normal,string runtimeNormal){
  using(var a=new Bitmap(native))using(var b=new Bitmap(runtime))using(var n=new Bitmap(normal))using(var nr=new Bitmap(runtimeNormal)){
   int w=a.Width,h=a.Height;if(b.Width!=w*4||b.Height!=h*4||n.Width!=w||n.Height!=h||nr.Width!=w*4||nr.Height!=h*4)throw new Exception("Dimension mismatch "+native);
   var aa=Read(a);var bb=Read(b);var nn=Read(n);var n4=Read(nr);
   for(int y=0;y<h*4;y++)for(int x=0;x<w*4;x++){int i=(y*w*4+x)*4,j=((y/4)*w+x/4)*4;for(int ch=0;ch<4;ch++){if(aa[j+ch]!=bb[i+ch])throw new Exception("Native4 colour mismatch "+native);if(nn[j+ch]!=n4[i+ch])throw new Exception("Native4 normal mismatch "+native);}}
   for(int i=0;i<w*h;i++){if(nn[i*4+3]!=255)throw new Exception("Normal alpha mismatch");double x=nn[i*4+2]/127.5-1,y=nn[i*4+1]/127.5-1,z=nn[i*4]/127.5-1;double len=Math.Sqrt(x*x+y*y+z*z);if(len<.985||len>1.015||z<.2)throw new Exception("Invalid normal vector");if(aa[i*4+3]==0&&(nn[i*4]!=255||nn[i*4+1]!=128||nn[i*4+2]!=128))throw new Exception("Transparent area not flat normal");}
  }
 }
 public static int GifFrames(string file){using(var im=Image.FromFile(file)){return im.GetFrameCount(new FrameDimension(im.FrameDimensionsList[0]));}}
}
'@
$repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$baseDir=Join-Path $repoRoot 'Assets\Generated\CreatureProductionV1'
$reports=@()
foreach($id in @('CeilingBell','RingSpine','SeamAmbusher')) {
 $dir=Join-Path $baseDir "processed\$id"
 $m=Get-Content -LiteralPath (Join-Path $dir 'animation.json') -Raw | ConvertFrom-Json
 foreach($fr in $m.frames){
  $rel="$($fr.clip)\$($fr.key).png"
  [CreatureExportCheck]::Frame((Join-Path $dir "frames\$rel"),(Join-Path $dir "runtime4x\frames\$rel"),(Join-Path $dir "normals\$rel"),(Join-Path $dir "runtime4x\normals\$rel"))
 }
 foreach($clip in $m.clips){
  $count=[CreatureExportCheck]::GifFrames((Join-Path $dir "preview\$($clip.name).gif"))
  if($count -ne ($clip.to-$clip.from+1)){throw "GIF frame count mismatch: $id / $($clip.name): $count"}
 }
 $reports+=@{id=$id;status='passed';frames=$m.frames.Count;checks=@('every native frame equals all 16 pixels in corresponding 4x block','native/4x normal dimensions match color frames','normal vectors normalized within 1.5 percent','transparent diffuse regions have flat normals','all 8 GIF frame counts match clip metadata')}
 Write-Output "VERIFIED Native4 and normals: $id / $($m.frames.Count) frames"
}
$reports | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $baseDir 'export_verification.json') -Encoding UTF8
