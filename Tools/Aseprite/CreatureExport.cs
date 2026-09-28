using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class CreatureExport {
 static byte[] Read(Bitmap b){var d=b.LockBits(new Rectangle(0,0,b.Width,b.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);var a=new byte[b.Width*b.Height*4];Marshal.Copy(d.Scan0,a,0,a.Length);b.UnlockBits(d);return a;}
 static void Save(byte[] a,int w,int h,string file){Directory.CreateDirectory(Path.GetDirectoryName(file));using(var b=new Bitmap(w,h,PixelFormat.Format32bppArgb)){var d=b.LockBits(new Rectangle(0,0,w,h),ImageLockMode.WriteOnly,PixelFormat.Format32bppArgb);Marshal.Copy(a,0,d.Scan0,a.Length);b.UnlockBits(d);b.Save(file,ImageFormat.Png);}}
 static byte[] Scale(byte[] a,int w,int h,int scale){var b=new byte[w*h*scale*scale*4];for(int y=0;y<h*scale;y++)for(int x=0;x<w*scale;x++)Array.Copy(a,((y/scale)*w+x/scale)*4,b,(y*w*scale+x)*4,4);return b;}
 public static void Export(string source,string runtime,string normal,string runtimeNormal){
  using(var b=new Bitmap(source)){int w=b.Width,h=b.Height;var a=Read(b);Save(Scale(a,w,h,4),w*4,h*4,runtime);
   var height=new double[w*h];var mask=new bool[w*h];var eroded=new bool[w*h];var bevel=new double[w*h];
   for(int i=0;i<w*h;i++){mask[i]=a[i*4+3]>=128;height[i]=(.299*a[i*4+2]+.587*a[i*4+1]+.114*a[i*4])/255.0;}
   Array.Copy(mask,eroded,mask.Length);
   for(int pass=0;pass<2;pass++){var next=new bool[w*h];for(int y=1;y<h-1;y++)for(int x=1;x<w-1;x++){int i=y*w+x;next[i]=eroded[i]&&eroded[i-1]&&eroded[i+1]&&eroded[i-w]&&eroded[i+w];if(next[i])bevel[i]+=.5;}eroded=next;}
   for(int i=0;i<w*h;i++)height[i]=mask[i]?height[i]*.55+Math.Sqrt(bevel[i])*.45:0;
   var n=new byte[a.Length];
   for(int y=0;y<h;y++)for(int x=0;x<w;x++){int i=y*w+x;double dx=0,dy=0;
    if(mask[i]&&x>0&&y>0&&x<w-1&&y<h-1){dx=(height[i-w+1]+2*height[i+1]+height[i+w+1]-height[i-w-1]-2*height[i-1]-height[i+w-1])*2.6/8;dy=(height[i+w-1]+2*height[i+w]+height[i+w+1]-height[i-w-1]-2*height[i-w]-height[i-w+1])*2.6/8;}
    double length=Math.Sqrt(dx*dx+dy*dy+1);n[i*4]=(byte)Math.Round((1/length*.5+.5)*255);n[i*4+1]=(byte)Math.Round((dy/length*.5+.5)*255);n[i*4+2]=(byte)Math.Round((-dx/length*.5+.5)*255);n[i*4+3]=255;
   }
   Save(n,w,h,normal);Save(Scale(n,w,h,4),w*4,h*4,runtimeNormal);
  }
 }
 public static void Contact(string[] sheets,string[] labels,string target,int cellWidth,int cellHeight){
  int cols=4,zoom=2,top=40,row=cellHeight*zoom+40;
  using(var b=new Bitmap(cols*cellWidth*zoom+32,top+row*sheets.Length))using(var g=Graphics.FromImage(b))using(var font=new Font("Consolas",13)){
   g.Clear(Color.FromArgb(26,31,40));g.InterpolationMode=InterpolationMode.NearestNeighbor;g.PixelOffsetMode=PixelOffsetMode.Half;
   for(int r=0;r<sheets.Length;r++)using(var sheet=new Bitmap(sheets[r])){
    int count=sheet.Width/cellWidth;g.DrawString(labels[r]+"  / "+count+" frames",font,Brushes.White,16,top+r*row-27);
    for(int c=0;c<4;c++){int ix=(int)Math.Round(c*(count-1)/3.0);g.DrawImage(sheet,new Rectangle(16+c*cellWidth*zoom,top+r*row,cellWidth*zoom,cellHeight*zoom),new Rectangle(ix*cellWidth,0,cellWidth,cellHeight),GraphicsUnit.Pixel);}
   }b.Save(target,ImageFormat.Png);
  }
 }
 public static void Compare(string source,string frame,string target){
  using(var a=new Bitmap(source))using(var b=new Bitmap(frame))using(var outImage=new Bitmap(900,520))using(var g=Graphics.FromImage(outImage))using(var font=new Font("Consolas",16)){
   g.Clear(Color.FromArgb(29,34,42));g.InterpolationMode=InterpolationMode.NearestNeighbor;g.PixelOffsetMode=PixelOffsetMode.Half;
   g.DrawString("GENERATED POSE / SOURCE",font,Brushes.White,24,20);g.DrawString("NATIVE / SHARED 16 COLORS",font,Brushes.White,465,20);
   var ab=Bounds(a);var bb=Bounds(b);double scale=Math.Min(350.0/ab.Width,420.0/ab.Height);
   int w=(int)Math.Round(ab.Width*scale),h=(int)Math.Round(ab.Height*scale);
   g.DrawImage(a,new Rectangle(30+(370-w)/2,75+(420-h)/2,w,h),ab,GraphicsUnit.Pixel);
   g.DrawImage(b,new Rectangle(475+(370-w)/2,75+(420-h)/2,w,h),bb,GraphicsUnit.Pixel);
   outImage.Save(target,ImageFormat.Png);
  }
 }
 static Rectangle Bounds(Bitmap b){var a=Read(b);int x0=b.Width,y0=b.Height,x1=0,y1=0;for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++)if(a[(y*b.Width+x)*4+3]>=128){x0=Math.Min(x0,x);y0=Math.Min(y0,y);x1=Math.Max(x1,x);y1=Math.Max(y1,y);}return new Rectangle(x0,y0,x1-x0+1,y1-y0+1);}
}
