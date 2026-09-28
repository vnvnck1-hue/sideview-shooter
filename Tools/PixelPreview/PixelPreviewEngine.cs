// Fast preview engine for the Aseprite native-pixel pipeline.
// Preserve() is a line-for-line port of Tools/Aseprite/preserve_crisp_prop.lua and
// Coarsen() of Tools/Aseprite/coarsen_crisp_prop.lua. Iteration order, tie-breaks and
// the palette growth during edge cleanup are kept identical so that a preview PNG is
// pixel-equal to the Aseprite output (checked by test_parity.ps1). If either Lua script
// changes, change this file in the same commit and rerun the parity test.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;

public static class PixelPreviewEngine {
 public sealed class Raster {
  public int W,H;public int[] Px; // 0xAARRGGBB
  public Raster(int w,int h){W=w;H=h;Px=new int[w*h];}
 }

 public static Raster Load(string path){
  using(var src=new Bitmap(path)){
   var r=new Raster(src.Width,src.Height);
   var d=src.LockBits(new Rectangle(0,0,src.Width,src.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
   try{for(int y=0;y<r.H;y++)Marshal.Copy(IntPtr.Add(d.Scan0,y*d.Stride),r.Px,y*r.W,r.W);}
   finally{src.UnlockBits(d);}
   return r;
  }
 }

 public static void Save(Raster r,string path){
  using(var dst=new Bitmap(r.W,r.H,PixelFormat.Format32bppArgb)){
   var d=dst.LockBits(new Rectangle(0,0,r.W,r.H),ImageLockMode.WriteOnly,PixelFormat.Format32bppArgb);
   try{for(int y=0;y<r.H;y++)Marshal.Copy(r.Px,y*r.W,IntPtr.Add(d.Scan0,y*d.Stride),r.W);}
   finally{dst.UnlockBits(d);}
   dst.Save(path,ImageFormat.Png);
  }
 }

 static int A(int c){return (c>>24)&255;}
 static int R(int c){return (c>>16)&255;}
 static int G(int c){return (c>>8)&255;}
 static int B(int c){return c&255;}
 static int Opaque(int r,int g,int b){return unchecked((int)0xFF000000)|(r<<16)|(g<<8)|b;}
 static double Lum(int r,int g,int b){return .2126*r+.7152*g+.0722*b;}
 static double Dist(int r1,int g1,int b1,int r2,int g2,int b2){
  double dr=r1-r2,dg=g1-g2,db=b1-b2;return .25*(dr*dr)+.5*(dg*dg)+.25*(db*db);
 }
 static int MaxCh(int r1,int g1,int b1,int r2,int g2,int b2){
  return Math.Max(Math.Abs(r1-r2),Math.Max(Math.Abs(g1-g2),Math.Abs(b1-b2)));
 }

 // Palette of observed colours in insertion order, with an RGB bucket grid so that the
 // "first palette entry with the smallest distance inside a channel bound" search of the
 // Lua script is answered exactly without scanning the whole list.
 sealed class Palette {
  public List<int> Rs=new List<int>(),Gs=new List<int>(),Bs=new List<int>(),Keys=new List<int>();
  public List<double> Ls=new List<double>();
  readonly int cell,side;readonly Dictionary<int,List<int>> grid=new Dictionary<int,List<int>>();
  public Palette(int maxBound){cell=Math.Max(1,maxBound);side=256/cell+2;}
  public int Count{get{return Keys.Count;}}
  int Cell(int r,int g,int b){return ((r/cell)*side+(g/cell))*side+(b/cell);}
  public int Add(int r,int g,int b,double l){
   int i=Keys.Count;Rs.Add(r);Gs.Add(g);Bs.Add(b);Ls.Add(l);Keys.Add(r*65536+g*256+b);
   List<int> list;int k=Cell(r,g,b);if(!grid.TryGetValue(k,out list)){list=new List<int>();grid[k]=list;}
   list.Add(i);return i;
  }
  // Smallest distance, ties to the lowest index: identical to a strict '<' scan in order.
  public int Find(int r,int g,int b,double l,double lumBound,int chBound){
   int best=-1;double score=1e30;int cr=r/cell,cg=g/cell,cb=b/cell;
   for(int i=-1;i<=1;i++)for(int j=-1;j<=1;j++)for(int k=-1;k<=1;k++){
    int xr=cr+i,xg=cg+j,xb=cb+k;if(xr<0||xg<0||xb<0)continue;
    List<int> list;if(!grid.TryGetValue((xr*side+xg)*side+xb,out list))continue;
    foreach(int q in list){
     if(Math.Abs(l-Ls[q])>lumBound)continue;
     if(MaxCh(r,g,b,Rs[q],Gs[q],Bs[q])>chBound)continue;
     double d=Dist(r,g,b,Rs[q],Gs[q],Bs[q]);
     if(d<score||(d==score&&q<best)){best=q;score=d;}
    }
   }
   return best;
  }
 }

 public sealed class PreserveStats {public int Palette,EdgeEdits,ClusterEdits;}

 public static Raster Preserve(Raster src,int tolerance,int snap,bool coherent,int passes,out PreserveStats stats){
  int W=src.W,H=src.H,N=W*H;
  var op=new bool[N];var pr=new int[N];var pg=new int[N];var pb=new int[N];var pk=new int[N];var pl=new double[N];
  var hist=new Dictionary<int,int>();var uKey=new List<int>();var uCount=new List<int>();
  for(int i=0;i<N;i++){
   int c=src.Px[i];if(A(c)<128)continue;
   op[i]=true;pr[i]=R(c);pg[i]=G(c);pb[i]=B(c);pk[i]=pr[i]*65536+pg[i]*256+pb[i];pl[i]=Lum(pr[i],pg[i],pb[i]);
   int u;if(!hist.TryGetValue(pk[i],out u)){u=uKey.Count;hist[pk[i]]=u;uKey.Add(pk[i]);uCount.Add(0);}
   uCount[u]++;
  }
  var order=new int[uKey.Count];for(int i=0;i<order.Length;i++)order[i]=i;
  Array.Sort(order,(a,b)=>uCount[a]!=uCount[b]?uCount[b].CompareTo(uCount[a]):uKey[a].CompareTo(uKey[b]));
  double lumTol=tolerance*.55;
  var pal=new Palette(Math.Max(tolerance,8));var mapping=new Dictionary<int,int>();
  foreach(int u in order){
   int key=uKey[u],r=key>>16,g=(key>>8)&255,b=key&255;double l=Lum(r,g,b);
   int best=pal.Find(r,g,b,l,lumTol,tolerance);
   if(best<0)best=pal.Add(r,g,b,l);
   mapping[key]=best;
  }
  int basePalette=pal.Count;
  Func<int,int,int> at=(x,y)=>(x<0||y<0||x>=W||y>=H||!op[y*W+x])?-1:y*W+x;
  Func<int,int,bool> inTol=(i,q)=>Math.Abs(pl[i]-pal.Ls[q])<=lumTol&&MaxCh(pr[i],pg[i],pb[i],pal.Rs[q],pal.Gs[q],pal.Bs[q])<=tolerance;

  var clustered=new int[N];int clusterEdits=0;
  var cLab=new int[9];var cCnt=new int[9];
  for(int y=0;y<H;y++)for(int x=0;x<W;x++){
   int i=at(x,y);if(i<0)continue;
   int current=mapping[pk[i]];int m=0;
   for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++){
    int n=at(x+dx,y+dy);if(n<0)continue;int lab=mapping[pk[n]];int f=0;
    while(f<m&&cLab[f]!=lab)f++;
    if(f==m){cLab[m]=lab;cCnt[m]=0;m++;}
    cCnt[f]++;
   }
   int best=current,bestCount=0;
   for(int f=0;f<m;f++)if(cLab[f]==current)bestCount=cCnt[f];
   if(coherent&&bestCount<=2){
    for(int f=0;f<m;f++){
     int c=cLab[f],count=cCnt[f];
     if(count>=5&&(count>bestCount||(count==bestCount&&pal.Keys[c]<pal.Keys[best]))&&inTol(i,c)){best=c;bestCount=count;}
    }
   }
   clustered[i]=best;if(best!=current)clusterEdits++;
  }

  var nb=new int[8];var nw=new double[8];
  for(int it=1;it<=passes;it++){
   var next=new int[N];
   for(int y=0;y<H;y++)for(int x=0;x<W;x++){
    int i=at(x,y);if(i<0)continue;
    int current=clustered[i];int m=0;
    var cands=new List<int>(9);cands.Add(current);
    for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++){
     if(dx==0&&dy==0)continue;int n=at(x+dx,y+dy);if(n<0)continue;
     int c=clustered[n];if(!cands.Contains(c))cands.Add(c);
     nb[m]=c;nw[m]=Math.Exp(-Dist(pr[i],pg[i],pb[i],pr[n],pg[n],pb[n])/100)*(dx*dy==0?1:.7);m++;
    }
    int best=current;double score=1e30;
    foreach(int c in cands){
     if(!inTol(i,c))continue;
     double cost=Dist(pr[i],pg[i],pb[i],pal.Rs[c],pal.Gs[c],pal.Bs[c]);
     for(int k=0;k<m;k++)if(pal.Keys[nb[k]]!=pal.Keys[c])cost=cost+12*nw[k];
     if(cost<score||(cost==score&&pal.Keys[c]<pal.Keys[best])){best=c;score=cost;}
    }
    next[i]=best;
   }
   clustered=next;
  }

  var outR=new Raster(W+2,H+2);int edgeEdits=0;
  var tri=new int[3];
  Func<int,int,int,double[],int> median=(a,b,c,range)=>{
   if(a<0||b<0||c<0)return -1;
   tri[0]=a;tri[1]=b;tri[2]=c;
   Array.Sort(tri,(u,v)=>pl[u]!=pl[v]?pl[u].CompareTo(pl[v]):pk[u].CompareTo(pk[v]));
   range[0]=pl[tri[2]]-pl[tri[0]];return tri[1];
  };
  var ra=new double[1];var rb=new double[1];
  for(int y=0;y<H;y++)for(int x=0;x<W;x++){
   int i=at(x,y);if(i<0)continue;
   int q=clustered[i];int baseColour=Opaque(pal.Rs[q],pal.Gs[q],pal.Bs[q]);
   outR.Px[(y+1)*outR.W+x+1]=baseColour;
   int chosen=-1;double confidence=0;
   for(int axis=1;axis<=2;axis++){
    int dx=axis==1?1:0,dy=axis==2?1:0,tx=dy,ty=dx;
    int a=median(at(x-2*dx-tx,y-2*dy-ty),at(x-2*dx,y-2*dy),at(x-2*dx+tx,y-2*dy+ty),ra);
    if(a<0)continue;double ar=ra[0];
    int b=median(at(x+2*dx-tx,y+2*dy-ty),at(x+2*dx,y+2*dy),at(x+2*dx+tx,y+2*dy+ty),rb);
    if(b<0)continue;double br=rb[0];
    double span=Math.Abs(pl[a]-pl[b]);
    if(!(span>=24&&ar<=span*.32&&br<=span*.32))continue;
    int vx=pr[b]-pr[a],vy=pg[b]-pg[a],vz=pb[b]-pb[a];
    int denom=vx*vx+vy*vy+vz*vz;
    double t=(double)((pr[i]-pr[a])*vx+(pg[i]-pg[a])*vy+(pb[i]-pb[a])*vz)/Math.Max(1,denom);
    double e1=pr[i]-pr[a]-t*vx,e2=pg[i]-pg[a]-t*vy,e3=pb[i]-pb[a]-t*vz;
    double residual=e1*e1+e2*e2+e3*e3;
    if(!(t>.08&&t<.92&&Math.Abs(t-.5)>.08&&residual<100))continue;
    int target=t<.5?a:b,other=t<.5?b:a;
    double shift=Math.Abs(pl[target]-pl[i]);
    int support=0;
    for(int k=-1;k<=1;k+=2){int n=at(x+k*tx,y+k*ty);
     if(n>=0&&Dist(pr[n],pg[n],pb[n],pr[target],pg[target],pb[target])<Dist(pr[n],pg[n],pb[n],pr[other],pg[other],pb[other]))support++;}
    double strength=span-ar-br;
    if(support==2&&shift<=snap&&shift>=3&&strength>confidence){chosen=target;confidence=strength;}
   }
   if(chosen>=0){
    int cr=pr[chosen],cg=pg[chosen],cb=pb[chosen];
    if(coherent){
     int e=pal.Find(cr,cg,cb,pl[chosen],3,8);
     if(e<0)pal.Add(cr,cg,cb,pl[chosen]);else{cr=pal.Rs[e];cg=pal.Gs[e];cb=pal.Bs[e];}
    }
    int c=Opaque(cr,cg,cb);
    if(c!=baseColour){outR.Px[(y+1)*outR.W+x+1]=c;edgeEdits++;}
   }
  }
  stats=new PreserveStats{Palette=pal.Count,EdgeEdits=edgeEdits,ClusterEdits=clusterEdits};
  return outR;
 }

 // Aseprite packs rgba as r | g<<8 | b<<16 | a<<24; the Lua tie-break compares that value.
 static long AsepriteValue(int c){return R(c)+G(c)*256L+B(c)*65536L+A(c)*16777216L;}

 public static Raster Coarsen(Raster full,int rawW,int rawH,double step){
  if(full.W!=rawW+2||full.H!=rawH+2)throw new ArgumentException("prepared image must be source size + 2");
  if(step<1||step>4)throw new ArgumentException("step must be 1..4");
  int w=(int)Math.Ceiling(rawW/step),h=(int)Math.Ceiling(rawH/step);
  var o=new Raster(w+2,h+2);
  var sc=new List<int>();var sw=new List<double>();var sd=new List<double>();
  for(int y=0;y<h;y++)for(int x=0;x<w;x++){
   double x0=x*step,y0=y*step,x1=Math.Min(rawW,(x+1)*step),y1=Math.Min(rawH,(y+1)*step);
   double cx=Math.Floor((x0+x1)/2),cy=Math.Floor((y0+y1)/2);
   sc.Clear();sw.Clear();sd.Clear();double area=0;
   for(int sy=(int)Math.Floor(y0);sy<=(int)Math.Ceiling(y1)-1;sy++)for(int sx=(int)Math.Floor(x0);sx<=(int)Math.Ceiling(x1)-1;sx++){
    double weight=(Math.Min(x1,sx+1)-Math.Max(x0,sx))*(Math.Min(y1,sy+1)-Math.Max(y0,sy));
    int c=full.Px[(sy+1)*full.W+sx+1];
    if(A(c)==255&&weight>0){sc.Add(c);sw.Add(weight);sd.Add((sx-cx)*(sx-cx)+(sy-cy)*(sy-cy));area+=weight;}
   }
   if(area>0&&area>=(x1-x0)*(y1-y0)*.5){
    int best=-1;double bestScore=-1;
    for(int a=0;a<sc.Count;a++){
     double score=0;int ca=sc[a];
     for(int b=0;b<sc.Count;b++){int cb=sc[b];if(Dist(R(ca),G(ca),B(ca),R(cb),G(cb),B(cb))<=144)score=score+sw[b];}
     score=score+.08*sw[a]/(1+sd[a]);
     if(score>bestScore||(score==bestScore&&(sd[a]<sd[best]||(sd[a]==sd[best]&&AsepriteValue(ca)<AsepriteValue(sc[best]))))){best=a;bestScore=score;}
    }
    o.Px[(y+1)*o.W+x+1]=sc[best];
   }
  }
  return o;
 }

 // Distinct RGB among pixels the pipeline treats as opaque (alpha >= 128).
 public static int CountColours(Raster r){
  var set=new HashSet<int>();foreach(int c in r.Px)if(A(c)>=128)set.Add(c&0xFFFFFF);return set.Count;
 }

 // Pixels that differ, treating every alpha-0 pixel as the same transparent value.
 public static long Mismatch(Raster a,Raster b){
  if(a.W!=b.W||a.H!=b.H)return -1;long n=0;
  for(int i=0;i<a.Px.Length;i++){int x=a.Px[i],y=b.Px[i];if(A(x)==0&&A(y)==0)continue;if(x!=y)n++;}
  return n;
 }
 public static long MismatchFiles(string a,string b){return Mismatch(Load(a),Load(b));}

 public static Raster Crop(Raster r,int x0,int y0,int w,int h){
  var o=new Raster(w,h);for(int y=0;y<h;y++)Array.Copy(r.Px,(y0+y)*r.W+x0,o.Px,y*w,w);return o;
 }

 static string J(string s){
  var sb=new StringBuilder("\"");
  foreach(char ch in s){if(ch=='"'||ch=='\\')sb.Append('\\').Append(ch);else if(ch<32)sb.Append("\\u").Append(((int)ch).ToString("x4"));else sb.Append(ch);}
  return sb.Append('"').ToString();
 }
 static string N(double v){return v.ToString("0.###",CultureInfo.InvariantCulture);}

 // Preserve once, coarsen every pitch in parallel, write PNGs and return a JSON manifest.
 public static string Run(string sourcePath,string outDir,double[] pitches,int tolerance,int snap,bool coherent,int passes){
  var total=Stopwatch.StartNew();
  Directory.CreateDirectory(outDir);
  var src=Load(sourcePath);
  string stem=Path.GetFileNameWithoutExtension(sourcePath);
  var sw=Stopwatch.StartNew();PreserveStats st;
  var prepared=Preserve(src,tolerance,snap,coherent,passes,out st);
  long preserveMs=sw.ElapsedMilliseconds;
  string sourceCopy="source.png";File.Copy(sourcePath,Path.Combine(outDir,sourceCopy),true);
  var items=new string[pitches.Length];
  Parallel.For(0,pitches.Length,k=>{
   var t=Stopwatch.StartNew();double p=pitches[k];
   var r=p==1?prepared:Coarsen(prepared,src.W,src.H,p);
   string file="pitch-"+N(p).Replace('.','_')+".png";
   Save(r,Path.Combine(outDir,file));
   int opaque=0;foreach(int c in r.Px)if(A(c)==255)opaque++;
   items[k]="{\"pitch\":"+N(p)+",\"file\":"+J(file)+",\"width\":"+r.W+",\"height\":"+r.H+
    ",\"colours\":"+CountColours(r)+",\"opaquePixels\":"+opaque+",\"ms\":"+(p==1?preserveMs:t.ElapsedMilliseconds)+"}";
  });
  return "{\"name\":"+J(stem)+",\"source\":"+J(Path.GetFullPath(sourcePath))+",\"sourceFile\":"+J(sourceCopy)+
   ",\"sourceWidth\":"+src.W+",\"sourceHeight\":"+src.H+",\"sourceColours\":"+CountColours(src)+
   ",\"settings\":{\"tolerance\":"+tolerance+",\"snap\":"+snap+",\"coherent\":"+(coherent?"true":"false")+",\"passes\":"+passes+"}"+
   ",\"preserve\":{\"palette\":"+st.Palette+",\"edgeEdits\":"+st.EdgeEdits+",\"clusterEdits\":"+st.ClusterEdits+",\"ms\":"+preserveMs+"}"+
   ",\"candidates\":["+string.Join(",",items)+"],\"totalMs\":"+total.ElapsedMilliseconds+"}";
 }
}
