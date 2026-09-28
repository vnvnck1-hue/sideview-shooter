param([string]$Root = (Resolve-Path "$PSScriptRoot/../..").Path)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
public static class ObstacleAssets {
  static Bitmap Scale(Bitmap src, Rectangle area, int w, int h, bool hard) {
    Bitmap dst = new Bitmap(w*4,h*4,PixelFormat.Format32bppArgb);
    for(int y=0;y<h;y++) for(int x=0;x<w;x++) {
      int sx=area.X+Math.Min(area.Width-1,(int)((x+0.5)*area.Width/w));
      int sy=area.Y+Math.Min(area.Height-1,(int)((y+0.5)*area.Height/h));
      Color c=src.GetPixel(sx,sy);
      int a=hard?(c.A>=100?255:0):(c.A<24?0:c.A);
      c=Color.FromArgb(a,c.R,c.G,c.B);
      for(int dy=0;dy<4;dy++) for(int dx=0;dx<4;dx++) dst.SetPixel(x*4+dx,y*4+dy,c);
    }
    return dst;
  }
  static Rectangle Bounds(Bitmap src, Rectangle area) {
    int l=area.Right,t=area.Bottom,r=area.X,b=area.Y;
    for(int y=area.Y;y<area.Bottom;y++) for(int x=area.X;x<area.Right;x++) {
      if(src.GetPixel(x,y).A<160) continue;
      l=Math.Min(l,x);r=Math.Max(r,x);t=Math.Min(t,y);b=Math.Max(b,y);
    }
    return Rectangle.FromLTRB(l,t,r+1,b+1);
  }
  static float Height(Bitmap src,int x,int y) {
    if(x<0||y<0||x>=src.Width||y>=src.Height) return 0;
    Color c=src.GetPixel(x,y);
    return c.A<128?0:0.7f+(c.R+c.G+c.B)/255f/3f*0.3f;
  }
  static void Normal(Bitmap src,string path) {
    using(Bitmap n=new Bitmap(src.Width,src.Height)) {
      for(int y=0;y<src.Height;y++) for(int x=0;x<src.Width;x++) {
        double nx=(Height(src,x-4,y)-Height(src,x+4,y))*0.6;
        double ny=(Height(src,x,y+4)-Height(src,x,y-4))*0.6;
        double len=Math.Sqrt(nx*nx+ny*ny+1);
        n.SetPixel(x,y,Color.FromArgb(src.GetPixel(x,y).A,(int)(127.5+127.5*nx/len),(int)(127.5+127.5*ny/len),(int)(127.5+127.5/len)));
      }
      n.Save(path,ImageFormat.Png);
    }
  }
  public static void Build(string root) {
    string source=Path.Combine(root,"Assets/Generated/ObstacleProps");
    string output=Path.Combine(root,"GodotPrototype/assets/props/obstacles");
    string normals=Path.Combine(root,"GodotPrototype/assets/normals/props/obstacles");
    string fx=Path.Combine(root,"GodotPrototype/assets/effects/obstacles");
    Directory.CreateDirectory(output);Directory.CreateDirectory(normals);Directory.CreateDirectory(fx);
    string[] names={"barricade","cable_reel","supply_crate","rubble_block","gas_cylinder"};
    int[] cuts={0,390,740,1120,1450,1774};
    // Art px (x4 = world). Player stands ~66 art px (265 world): barricade knee-high, crate 128 cover (standing shots clear it, crouching hides),
    // gas cylinder chest-high, concrete just above the 200 px jump apex so it must be shot open.
    int[] widths={48,36,44,48,16};
    int[] heights={24,31,32,55,38};
    using(Bitmap atlas=new Bitmap(Path.Combine(source,"props_source.png"))) {
      for(int row=0;row<2;row++) for(int col=0;col<5;col++) {
        Rectangle bounds=Bounds(atlas,new Rectangle(cuts[col],row==0?0:520,cuts[col+1]-cuts[col],row==0?520:367));
        int w=widths[col],h=heights[col];
        if(row==1&&col>=2) { w=col==4?34:w;h=col==4?13:(col==2?14:18); }
        string name=names[col]+(row==0?"":"_broken")+".png";
        using(Bitmap sprite=Scale(atlas,bounds,w,h,true)) {
          sprite.Save(Path.Combine(output,name),ImageFormat.Png);
          Normal(sprite,Path.Combine(normals,name));
        }
        Console.WriteLine(name+" "+w*4+"x"+h*4+" alpha-trim="+bounds);
      }
    }
    using(Bitmap atlas=new Bitmap(Path.Combine(source,"explosion_source.png"))) {
      for(int i=0;i<6;i++) using(Bitmap frame=Scale(atlas,new Rectangle(i%3*512,i/3*512,512,512),96,96,false))
        frame.Save(Path.Combine(fx,"explosion_"+i.ToString("00")+".png"),ImageFormat.Png);
    }
  }
}
'@
[ObstacleAssets]::Build($Root)
