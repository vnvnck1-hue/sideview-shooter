using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Collections.Generic;
using System.Globalization;
public static class PixelPitchReview {
 static double[] Steps={1,1.25,1.5,2};
 static string[] Labels={"CURRENT / 1.00x","A / 1.25x","B / 1.50x","C / 2.00x"};
 public static void SetSteps(double[] steps){
  if(steps.Length!=4||steps[0]!=1)throw new ArgumentException("Expected baseline and three grid pitches");
  for(int i=0;i<4;i++)if(Double.IsNaN(steps[i])||steps[i]<1||steps[i]>4)throw new ArgumentException("Invalid grid pitch");
  Steps=(double[])steps.Clone();Labels=new string[4];
  for(int i=0;i<4;i++)Labels[i]=(i==0?"CURRENT":((char)('A'+i-1)).ToString())+" / "+steps[i].ToString("F2",CultureInfo.InvariantCulture)+"x";
 }
 static Color Sample(Bitmap b,double x,double y,double step){return b.GetPixel(Math.Min(b.Width-2,1+(int)Math.Floor(x/step)),Math.Min(b.Height-2,1+(int)Math.Floor(y/step)));}
 static void Draw(Bitmap dst,Bitmap src,int left,int top,int sx,int sy,int w,int h,int zoom,double step){
  for(int y=0;y<h*zoom;y++)for(int x=0;x<w*zoom;x++){
   var c=Sample(src,sx+(x+.5)/zoom,sy+(y+.5)/zoom,step);
   if(c.A>0)dst.SetPixel(left+x,top+y,c);
  }
 }
 public static void Plate(string output,string[] files,int width,int height){
  int cell=width+24,row=height+48;
  using(var dst=new Bitmap(cell*2,row*2)){
   using(var g=Graphics.FromImage(dst))g.Clear(Color.FromArgb(32,34,42));
   for(int i=0;i<4;i++)using(var b=new Bitmap(files[i])){
    int left=(i%2)*cell,top=(i/2)*row;
    using(var g=Graphics.FromImage(dst))using(var f=new Font("Consolas",11))g.DrawString(Labels[i],f,Brushes.Wheat,left+12,top+10);
    Draw(dst,b,left+12,top+36,0,0,width,height,1,Steps[i]);
   }
   dst.Save(output,ImageFormat.Png);
  }
 }
 public static void Detail(string output,string[] files,int x,int y,int w,int h){
  const int zoom=4;int cell=w*zoom+16;
  using(var dst=new Bitmap(cell*4,h*zoom+48)){
   using(var g=Graphics.FromImage(dst))g.Clear(Color.FromArgb(32,34,42));
   for(int i=0;i<4;i++)using(var b=new Bitmap(files[i])){
    using(var g=Graphics.FromImage(dst))using(var f=new Font("Consolas",10))g.DrawString(Labels[i],f,Brushes.Wheat,cell*i+8,8);
    Draw(dst,b,cell*i+8,36,x,y,w,h,zoom,Steps[i]);
   }
   dst.Save(output,ImageFormat.Png);
  }
 }
 public static string Validate(string source,string approved,string candidate,double step){
  using(var src=new Bitmap(source))using(var a=new Bitmap(approved))using(var b=new Bitmap(candidate)){
   if(b.Width!=(int)Math.Ceiling(src.Width/step)+2||b.Height!=(int)Math.Ceiling(src.Height/step)+2)throw new Exception("Incorrect grid dimensions");
   var allowed=new HashSet<int>();var used=new HashSet<int>();int partial=0,border=0,foreign=0;
   for(int y=0;y<a.Height;y++)for(int x=0;x<a.Width;x++){var c=a.GetPixel(x,y);if(c.A==255)allowed.Add(c.ToArgb());}
   for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++){var c=b.GetPixel(x,y);
    if(c.A>0&&c.A<255)partial++;
    if(c.A>0){used.Add(c.ToArgb());if(!allowed.Contains(c.ToArgb()))foreign++;if(x==0||y==0||x==b.Width-1||y==b.Height-1)border++;}
   }
   if(partial>0||border>0||foreign>0)throw new Exception("Alpha/border/palette invariant failed");
   int intersection=0,union=0;double error=0;
   for(int y=0;y<src.Height;y++)for(int x=0;x<src.Width;x++){
    var c=src.GetPixel(x,y);var d=Sample(b,x+.5,y+.5,step);bool p=c.A>=128,q=d.A==255;
    if(p||q)union++;if(p&&q){intersection++;error+=Math.Abs(c.R-d.R)+Math.Abs(c.G-d.G)+Math.Abs(c.B-d.B);}
   }
   return String.Format(CultureInfo.InvariantCulture,"{{\"width\":{0},\"height\":{1},\"colours\":{2},\"partialAlpha\":{3},\"foreignColours\":{4},\"maskIoUAtSourceSize\":{5:F6},\"meanRGBErrorOnOverlap\":{6:F4}",b.Width,b.Height,used.Count,partial,foreign,(double)intersection/union,error/(intersection*3))+"}";
  }
 }
}
