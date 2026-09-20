using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Collections.Generic;
public static class PreservePropReview {
 public static void Summary(string output,string[] sources,string[] candidates,string[] labels){
  int height=0,width=0;foreach(var path in sources)using(var b=new Bitmap(path)){height+=b.Height+56;width=Math.Max(width,b.Width);}
  int cell=width+32;
  using(var dst=new Bitmap(cell*2,height)){
   using(var g=Graphics.FromImage(dst))g.Clear(Color.FromArgb(32,34,42));int top=0;
   for(int i=0;i<sources.Length;i++)using(var src=new Bitmap(sources[i]))using(var b=new Bitmap(candidates[i])){
    using(var g=Graphics.FromImage(dst))using(var f=new Font("Consolas",10)){
     g.DrawString(labels[i]+" / SOURCE",f,Brushes.Wheat,12,top+8);
     g.DrawString("ASEPRITE PIXELS / x2",f,Brushes.Wheat,cell+12,top+8);
    }
    Draw(dst,src,(cell-src.Width)/2,top+36,1);Draw(dst,b,cell+(cell-src.Width)/2-2,top+34,2);
    top+=src.Height+56;
   }
   dst.Save(output,ImageFormat.Png);
  }
 }
 public static void Draw(Bitmap dst,Bitmap src,int x0,int y0,int scale){
  for(int y=0;y<src.Height;y++)for(int x=0;x<src.Width;x++){
   var c=src.GetPixel(x,y);if(c.A==0)continue;
   for(int dy=0;dy<scale;dy++)for(int dx=0;dx<scale;dx++){
    int xx=x0+x*scale+dx,yy=y0+y*scale+dy;if(xx<0||yy<0||xx>=dst.Width||yy>=dst.Height)continue;
    var bg=dst.GetPixel(xx,yy);int a=c.A;
    dst.SetPixel(xx,yy,Color.FromArgb((c.R*a+bg.R*(255-a))/255,(c.G*a+bg.G*(255-a))/255,(c.B*a+bg.B*(255-a))/255));
   }
  }
 }
 public static void Plate(string output,string original,string[] paths,int[] steps,string[] labels){
  using(var src=new Bitmap(original))using(var dst=new Bitmap((src.Width+28)*(paths.Length+1),src.Height+64)){
   using(var g=Graphics.FromImage(dst)){g.Clear(Color.FromArgb(32,34,42));using(var f=new Font("Consolas",10)){
    g.DrawString("APPROVED SOURCE",f,Brushes.Wheat,10,8);
    for(int i=0;i<paths.Length;i++)g.DrawString(labels[i],f,Brushes.Wheat,(src.Width+28)*(i+1)+10,8);
   }}
   Draw(dst,src,14,40,1);
   for(int i=0;i<paths.Length;i++)using(var b=new Bitmap(paths[i]))Draw(dst,b,(src.Width+28)*(i+1)+14-steps[i],40-steps[i],steps[i]);
   dst.Save(output,ImageFormat.Png);
  }
 }
 public static void Detail(string output,string source,string candidate,int step,int x,int y,int w,int h,int zoom){
  using(var src=new Bitmap(source))using(var b=new Bitmap(candidate))using(var dst=new Bitmap(w*zoom*2+48,h*zoom+48)){
   using(var g=Graphics.FromImage(dst)){g.Clear(Color.FromArgb(32,34,42));using(var f=new Font("Consolas",10)){g.DrawString("SOURCE",f,Brushes.Wheat,8,8);g.DrawString("PIXEL CONVERSION",f,Brushes.Wheat,w*zoom+32,8);}}
   using(var crop=src.Clone(new Rectangle(x,y,w,h),PixelFormat.Format32bppArgb))Draw(dst,crop,8,36,zoom);
   using(var reconstruct=new Bitmap(w,h)){
    for(int yy=0;yy<h;yy++)for(int xx=0;xx<w;xx++)reconstruct.SetPixel(xx,yy,b.GetPixel((x+xx)/step+1,(y+yy)/step+1));
    Draw(dst,reconstruct,w*zoom+32,36,zoom);
   }
   dst.Save(output,ImageFormat.Png);
  }
 }
 public static string Compare(string source,string candidate,int step){
  using(var src=new Bitmap(source))using(var b=new Bitmap(candidate)){
   int union=0,intersection=0,n=0;double error=0;var colors=new HashSet<int>();int partial=0,border=0;
   for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++){var c=b.GetPixel(x,y);if(c.A>0){colors.Add(c.ToArgb());if(x==0||y==0||x==b.Width-1||y==b.Height-1)border++;}if(c.A>0&&c.A<255)partial++;}
   for(int y=0;y<src.Height;y++)for(int x=0;x<src.Width;x++){
    var a=src.GetPixel(x,y);var c=b.GetPixel(x/step+1,y/step+1);bool aa=a.A>=128,cc=c.A>=128;
    if(aa||cc)union++;if(aa&&cc){intersection++;n++;error+=Math.Abs(a.R-c.R)+Math.Abs(a.G-c.G)+Math.Abs(a.B-c.B);}
   }
   return String.Format(System.Globalization.CultureInfo.InvariantCulture,"{{\"width\":{0},\"height\":{1},\"opaqueColors\":{2},\"partialAlpha\":{3},\"opaqueBorder\":{4},\"silhouetteIoU\":{5:F6},\"meanChannelErrorOnOverlap\":{6:F4}",b.Width,b.Height,colors.Count,partial,border,(double)intersection/union,error/(n*3))+"}";
  }
 }
 public static void Equal(string a,string b){using(var x=new Bitmap(a))using(var y=new Bitmap(b)){if(x.Size!=y.Size)throw new Exception("Size mismatch");for(int j=0;j<x.Height;j++)for(int i=0;i<x.Width;i++)if(x.GetPixel(i,j).ToArgb()!=y.GetPixel(i,j).ToArgb())throw new Exception("Pixel mismatch");}}
}
