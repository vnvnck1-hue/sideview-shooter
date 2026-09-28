using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class CreatureSourcePrep {
 public class Component { public List<int> Pixels=new List<int>();public int X0=int.MaxValue,Y0=int.MaxValue,X1=-1,Y1=-1;public double CX {get{return (X0+X1)*.5;}}public double CY {get{return (Y0+Y1)*.5;}} }
 public class Pose {public string key,file;public int[] rect;public int[] sourceBounds;public int sourceOpaquePixels,removedSpeckPixels;}
 static byte[] Read(Bitmap b){var data=b.LockBits(new Rectangle(0,0,b.Width,b.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);var bytes=new byte[b.Width*b.Height*4];Marshal.Copy(data.Scan0,bytes,0,bytes.Length);b.UnlockBits(data);return bytes;}
 public static Pose[] Run(string input,string output,string[] names){
  Directory.CreateDirectory(output);
  using(var src=new Bitmap(input)){
   int w=src.Width,h=src.Height;var bytes=Read(src);var seen=new bool[w*h];var cs=new List<Component>();
   for(int p=0;p<w*h;p++) {if(seen[p]||bytes[p*4+3]<128)continue;var c=new Component();var queue=new Queue<int>();queue.Enqueue(p);seen[p]=true;
    while(queue.Count>0){int q=queue.Dequeue(),x=q%w,y=q/w;c.Pixels.Add(q);c.X0=Math.Min(c.X0,x);c.X1=Math.Max(c.X1,x);c.Y0=Math.Min(c.Y0,y);c.Y1=Math.Max(c.Y1,y);
     for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++){int nx=x+dx,ny=y+dy;if(nx<0||ny<0||nx>=w||ny>=h)continue;int n=ny*w+nx;if(!seen[n]&&bytes[n*4+3]>=128){seen[n]=true;queue.Enqueue(n);}}
    }cs.Add(c);
   }
   var main=new List<Component>();
   for(int row=0;row<4;row++){var r=cs.Where(c=>(int)(c.CY*4/h)==row).OrderByDescending(c=>c.Pixels.Count).Take(4).OrderBy(c=>c.CX).ToArray();if(r.Length!=4)throw new Exception("Expected four bodies in row "+row+" of "+input);main.AddRange(r);}
   var groups=main.Select(c=>new List<Component>{c}).ToArray();int removed=0;
   foreach(var c in cs){if(main.Contains(c))continue;if(c.Pixels.Count<9){removed+=c.Pixels.Count;continue;}
    int row=Math.Max(0,Math.Min(3,(int)(c.CY*4/h)));int nearest=-1;double distance=double.MaxValue;
    for(int col=0;col<4;col++){int i=row*4+col;var m=main[i];double dx=Math.Max(0,Math.Max(m.X0-c.CX,c.CX-m.X1)),dy=Math.Max(0,Math.Max(m.Y0-c.CY,c.CY-m.Y1));double d=dx*dx+dy*dy;if(d<distance){distance=d;nearest=i;}}
    if(nearest>=0 && distance<Math.Pow(h/4*.9,2))groups[nearest].Add(c);else removed+=c.Pixels.Count;
   }
   var result=new List<Pose>();
   for(int i=0;i<16;i++){
    var g=groups[i];int x0=g.Min(c=>c.X0),y0=g.Min(c=>c.Y0),x1=g.Max(c=>c.X1)+1,y1=g.Max(c=>c.Y1)+1;
    int ow=x1-x0+4,oh=y1-y0+4;var target=new byte[ow*oh*4];
    foreach(var c in g)foreach(int q in c.Pixels){int x=q%w-x0+2,y=q/w-y0+2;Array.Copy(bytes,q*4,target,(y*ow+x)*4,4);}
    string key=names[i/4]+"_"+(i%4+1).ToString("D2"),file=Path.Combine(output,key+".png");
    using(var b=new Bitmap(ow,oh,PixelFormat.Format32bppArgb)){var data=b.LockBits(new Rectangle(0,0,ow,oh),ImageLockMode.WriteOnly,PixelFormat.Format32bppArgb);Marshal.Copy(target,0,data.Scan0,target.Length);b.UnlockBits(data);b.Save(file,ImageFormat.Png);}
    result.Add(new Pose{key=key,file=file,rect=new[]{0,0,ow,oh},sourceBounds=new[]{x0,y0,x1,y1},sourceOpaquePixels=g.Sum(c=>c.Pixels.Count),removedSpeckPixels=removed});
   }return result.ToArray();
  }
 }
}
