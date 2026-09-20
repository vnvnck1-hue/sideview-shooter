using System;
using System.Drawing;
using System.Drawing.Imaging;
public static class PropContrastReview {
 public static void Validate(string baseline,string variant){
  using(var a=new Bitmap(baseline))using(var b=new Bitmap(variant)){
   if(a.Size!=b.Size)throw new Exception("Canvas changed");int changed=0;
   for(int y=0;y<a.Height;y++)for(int x=0;x<a.Width;x++){
    var c=a.GetPixel(x,y);var d=b.GetPixel(x,y);if(c.A!=d.A)throw new Exception("Silhouette changed");
    if(d.A!=0&&d.A!=255)throw new Exception("Partial alpha");if(c.ToArgb()!=d.ToArgb())changed++;
   }
   if(changed==0)throw new Exception("No contrast difference");
  }
 }
 public static void Grid(string output,string[] sources,string[][] variants,string[] names){
  int maxW=0,height=0;foreach(var s in sources)using(var b=new Bitmap(s)){maxW=Math.Max(maxW,b.Width);height+=b.Height+52;}
  int cw=maxW+24;string[] labels={"SOURCE","BASELINE","A / MEDIUM","B / STRONG"};
  using(var dst=new Bitmap(cw*4,height)){
   using(var g=Graphics.FromImage(dst))g.Clear(Color.FromArgb(32,34,42));int top=0;
   for(int i=0;i<sources.Length;i++)using(var src=new Bitmap(sources[i])){
    using(var g=Graphics.FromImage(dst))using(var f=new Font("Consolas",10))for(int j=0;j<4;j++)g.DrawString(names[i]+" / "+labels[j],f,Brushes.Wheat,j*cw+8,top+8);
    PreservePropReview.Draw(dst,src,(cw-src.Width)/2,top+36,1);
    for(int j=0;j<3;j++)using(var b=new Bitmap(variants[i][j]))PreservePropReview.Draw(dst,b,(j+1)*cw+(cw-src.Width)/2-2,top+34,2);
    top+=src.Height+52;
   }
   dst.Save(output,ImageFormat.Png);
  }
 }
 public static void Crop(string output,string source,string[] variants,int x,int y,int w,int h,int zoom){
  int cw=w*zoom+20;string[] labels={"SOURCE","BASELINE","A / MEDIUM","B / STRONG"};
  using(var dst=new Bitmap(cw*4,h*zoom+48))using(var src=new Bitmap(source)){
   using(var g=Graphics.FromImage(dst)){g.Clear(Color.FromArgb(32,34,42));using(var f=new Font("Consolas",10))for(int j=0;j<4;j++)g.DrawString(labels[j],f,Brushes.Wheat,j*cw+8,8);}
   using(var c=src.Clone(new Rectangle(x,y,w,h),PixelFormat.Format32bppArgb))PreservePropReview.Draw(dst,c,8,36,zoom);
   for(int j=0;j<3;j++)using(var b=new Bitmap(variants[j]))using(var c=new Bitmap(w,h)){
    for(int yy=0;yy<h;yy++)for(int xx=0;xx<w;xx++)c.SetPixel(xx,yy,b.GetPixel((x+xx)/2+1,(y+yy)/2+1));
    PreservePropReview.Draw(dst,c,(j+1)*cw+8,36,zoom);
   }
   dst.Save(output,ImageFormat.Png);
  }
 }
}
