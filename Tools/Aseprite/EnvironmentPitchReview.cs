using System;
using System.Drawing;
using System.Drawing.Imaging;
public static class EnvironmentPitchReview {
 static Color Sample(Bitmap b,int x,int y,int step,int pad){return b.GetPixel(x/step+pad,y/step+pad);}
 public static void Preview(string output,string candidate,int width,int height,int step){
  using(var src=new Bitmap(candidate))using(var dst=new Bitmap(width,height)){
   for(int y=0;y<height;y++)for(int x=0;x<width;x++)dst.SetPixel(x,y,Sample(src,x,y,step,1));
   dst.Save(output,ImageFormat.Png);
  }
 }
 public static void Crop(string output,string source,string three,string four,int x,int y,int w,int h){
  string[] paths={source,three,four};int[] steps={1,3,4};string[] labels={"SOURCE","PIXEL 3.0x","PIXEL 4.0x"};
  CompareCrop(output,paths,steps,labels,x,y,w,h);
 }
 public static void CompareCrop(string output,string[] paths,int[] steps,string[] labels,int x,int y,int w,int h){
  if(paths.Length!=steps.Length||paths.Length!=labels.Length)throw new ArgumentException("Comparison length mismatch");
  const int zoom=2;int cell=w*zoom+16;
  using(var dst=new Bitmap(cell*paths.Length,h*zoom+40)){
   using(var g=Graphics.FromImage(dst))g.Clear(Color.FromArgb(32,34,42));
   for(int i=0;i<paths.Length;i++)using(var src=new Bitmap(paths[i])){
    using(var g=Graphics.FromImage(dst))using(var f=new Font("Consolas",11))g.DrawString(labels[i],f,Brushes.Wheat,cell*i+8,8);
    for(int yy=0;yy<h*zoom;yy++)for(int xx=0;xx<w*zoom;xx++){
     var c=Sample(src,x+xx/zoom,y+yy/zoom,steps[i],i==0?0:1);
     if(c.A>0)dst.SetPixel(cell*i+8+xx,32+yy,c);
    }
   }
   dst.Save(output,ImageFormat.Png);
  }
 }
}
