using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Collections.Generic;
using System.Globalization;
public static class CrispPropReview {
 static double L(Color c){return .2126*c.R+.7152*c.G+.0722*c.B;}
 static int RGB(Color c){return c.R*65536+c.G*256+c.B;}
 public static string Audit(string source,string previous,string result){
  using(var s=new Bitmap(source))using(var old=new Bitmap(previous))using(var b=new Bitmap(result)){
   if(b.Width!=s.Width+2||b.Height!=s.Height+2)throw new Exception("Native resolution lost");
   var colors=new HashSet<int>();for(int y=0;y<s.Height;y++)for(int x=0;x<s.Width;x++){var c=s.GetPixel(x,y);if(c.A>=128)colors.Add(RGB(c));}
   double before=0,after=0;int edges=0,unknown=0,maskErrors=0,edited=0;
   for(int y=0;y<s.Height;y++)for(int x=0;x<s.Width;x++){
    var c=s.GetPixel(x,y);var n=b.GetPixel(x+1,y+1);
    if((c.A>=128)!=(n.A==255))maskErrors++;
    if(n.A==255&&!colors.Contains(RGB(n)))unknown++;
    if(c.A>=128&&RGB(c)!=RGB(n))edited++;
    for(int axis=0;axis<2;axis++){
     int xx=x+(axis==0?1:0),yy=y+(axis==1?1:0);if(xx>=s.Width||yy>=s.Height)continue;
     var d=s.GetPixel(xx,yy);if(c.A<128||d.A<128)continue;
     double delta=L(d)-L(c);if(Math.Abs(delta)<24)continue;
     var p=old.GetPixel(x/2+1,y/2+1);var q=old.GetPixel(xx/2+1,yy/2+1);
     var m=b.GetPixel(xx+1,yy+1);
     // Capped signed contrast at the SAME original edge, not a quality score.
     before+=p.A>=128&&q.A>=128?Math.Max(0,Math.Min(1,(L(q)-L(p))/delta)):0;
     after+=Math.Max(0,Math.Min(1,(L(m)-L(n))/delta));edges++;
    }
   }
   if(maskErrors!=0||unknown!=0||edited==0)throw new Exception("Preservation invariant failed");
   if(edges==0)throw new Exception("No source edges to measure");
   if(after<=before)throw new Exception("No measured edge retention improvement");
   return String.Format(CultureInfo.InvariantCulture,"{{\"sourceStrongEdgePairs\":{0},\"previousSamePositionContrastRetention\":{1:F5},\"newSamePositionContrastRetention\":{2:F5},\"outputColoursAbsentFromSource\":{3},\"maskErrors\":{4},\"changedOpaqueRGBPixels\":{5}}}",edges,before/edges,after/edges,unknown,maskErrors,edited);
  }
 }
 public static void Summary(string output,string[] sources,string[] results){
  int width=0,height=0;foreach(var p in sources)using(var b=new Bitmap(p)){width=Math.Max(width,b.Width);height+=b.Height+48;}
  int cell=width+24;
  using(var d=new Bitmap(cell*2,height)){
   using(var g=Graphics.FromImage(d))g.Clear(Color.FromArgb(32,34,42));int top=0;
   for(int i=0;i<sources.Length;i++)using(var s=new Bitmap(sources[i]))using(var b=new Bitmap(results[i])){
    using(var g=Graphics.FromImage(d))using(var f=new Font("Consolas",10)){
     g.DrawString("APPROVED SOURCE",f,Brushes.Wheat,12,top+8);g.DrawString("NEW / NATIVE 1px",f,Brushes.Wheat,cell+12,top+8);
    }
    PreservePropReview.Draw(d,s,(cell-s.Width)/2,top+32,1);
    PreservePropReview.Draw(d,b,cell+(cell-s.Width)/2-1,top+31,1);
    top+=s.Height+48;
   }
   d.Save(output,ImageFormat.Png);
  }
 }
 public static void Crop(string output,string source,string previous,string result,int x,int y,int w,int h){
  int zoom=3,cell=w*zoom+20;
  using(var s=new Bitmap(source))using(var p=new Bitmap(previous))using(var b=new Bitmap(result))using(var dst=new Bitmap(cell*3,h*zoom+44)){
   using(var g=Graphics.FromImage(dst))using(var f=new Font("Consolas",10)){
    g.Clear(Color.FromArgb(32,34,42));string[] labels={"SOURCE","PREVIOUS","NEW"};for(int i=0;i<3;i++)g.DrawString(labels[i],f,Brushes.Wheat,cell*i+8,8);
   }
   for(int i=0;i<3;i++)using(var crop=new Bitmap(w,h)){
    for(int yy=0;yy<h;yy++)for(int xx=0;xx<w;xx++)crop.SetPixel(xx,yy,i==0?s.GetPixel(x+xx,y+yy):i==1?p.GetPixel((x+xx)/2+1,(y+yy)/2+1):b.GetPixel(x+xx+1,y+yy+1));
    PreservePropReview.Draw(dst,crop,cell*i+8,32,zoom);
   }
   dst.Save(output,ImageFormat.Png);
  }
 }
}
