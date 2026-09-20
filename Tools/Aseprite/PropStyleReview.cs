using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Collections.Generic;
using System.IO;

// Review-only extraction: refuse any lossy "native" conversion of legacy art.
public static class PropStyleReview {
    static bool Equal(Color a, Color b) { return a.A == b.A && (a.A == 0 || a.ToArgb() == b.ToArgb()); }
    public static string Extract(string input, string output) {
        using (var src = new Bitmap(input)) {
            int best = int.MaxValue, bx = 0, by = 0;
            for (int oy=0; oy<4; oy++) for (int ox=0; ox<4; ox++) {
                int errors=0;
                for (int y=oy-4; y<src.Height; y+=4) for (int x=ox-4; x<src.Width; x+=4) {
                    if (x+4<=0 || y+4<=0) continue;
                    Color first=src.GetPixel(Math.Max(0,x),Math.Max(0,y));
                    for(int j=Math.Max(0,y); j<Math.Min(y+4,src.Height); j++)
                    for(int i=Math.Max(0,x); i<Math.Min(x+4,src.Width); i++)
                        if(!Equal(first,src.GetPixel(i,j))) errors++;
                }
                if(errors<best) {best=errors; bx=ox; by=oy;}
            }
            if(best!=0) throw new Exception("Reference is not an exact 4px grid: "+input+" mismatches="+best);
            int px=(4-bx)%4, py=(4-by)%4;
            using(var dst=new Bitmap((src.Width+px+3)/4,(src.Height+py+3)/4)) {
                for(int y=0;y<dst.Height;y++) for(int x=0;x<dst.Width;x++)
                    dst.SetPixel(x,y,src.GetPixel(Math.Max(0,Math.Min(src.Width-1,x*4-px)),Math.Max(0,Math.Min(src.Height-1,y*4-py))));
                for(int y=0;y<src.Height;y++)for(int x=0;x<src.Width;x++)
                    if(!Equal(src.GetPixel(x,y),dst.GetPixel((x+px)/4,(y+py)/4)))throw new Exception("Grid round-trip mismatch: "+input);
                dst.Save(output,ImageFormat.Png);
                return String.Format("{0}: {1}x{2} world -> {3}x{4} art, grid=({5},{6}), mismatch=0; leading pad=({7},{8}) world px",Path.GetFileName(input),src.Width,src.Height,dst.Width,dst.Height,bx,by,px,py);
            }
        }
    }
    public static string Stats(string path) {
        using(var b=new Bitmap(path)) {
            int opaque=0, pairs=0, edges=0, partial=0, border=0;
            int minx=b.Width,miny=b.Height,maxx=-1,maxy=-1;
            var colors=new HashSet<int>();
            for(int y=0;y<b.Height;y++) for(int x=0;x<b.Width;x++) {
                Color c=b.GetPixel(x,y);
                if(c.A>0&&c.A<255)partial++;
                if(c.A==0)continue;
                if(x==0||y==0||x==b.Width-1||y==b.Height-1)border++;
                minx=Math.Min(x,minx);miny=Math.Min(y,miny);maxx=Math.Max(x,maxx);maxy=Math.Max(y,maxy);
                if(c.A!=255)continue;
                opaque++; colors.Add(c.ToArgb());
                for(int axis=0;axis<2;axis++) {
                    int nx=x+(axis==0?1:0),ny=y+(axis==1?1:0);
                    if(nx>=b.Width||ny>=b.Height)continue;
                    Color n=b.GetPixel(nx,ny); if(n.A!=255)continue;
                    pairs++;
                    // RGB max channel delta >=24; transparent edges do not enter denominator.
                    if(Math.Max(Math.Abs(c.R-n.R),Math.Max(Math.Abs(c.G-n.G),Math.Abs(c.B-n.B)))>=24)edges++;
                }
            }
            return String.Format(System.Globalization.CultureInfo.InvariantCulture,
                "{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12:F2}",
                Path.GetFileName(path),b.Width,b.Height,opaque,colors.Count,partial,border,minx,miny,maxx,maxy,pairs,pairs==0?0:100.0*edges/pairs);
        }
    }
    public static void Blit(Bitmap dst,Bitmap src,int x0,int y0,int scale,bool gray) {
        for(int y=0;y<src.Height;y++)for(int x=0;x<src.Width;x++) {
            Color c=src.GetPixel(x,y);if(c.A==0)continue;
            if(gray){int l=(54*c.R+183*c.G+19*c.B)/256;c=Color.FromArgb(c.A,l,l,l);}
            for(int dy=0;dy<scale;dy++)for(int dx=0;dx<scale;dx++) {
                int xx=x0+x*scale+dx, yy=y0+y*scale+dy;
                if(xx>=0&&yy>=0&&xx<dst.Width&&yy<dst.Height)dst.SetPixel(xx,yy,c);
            }
        }
    }
    public static void Plate(string output,string[] paths,string[] labels,int scale,bool gray) {
        int cellW=120*scale+32, h=100*scale+70;
        using(var dst=new Bitmap(cellW*paths.Length,h)) {
            using(var g=Graphics.FromImage(dst)) {
                g.Clear(Color.FromArgb(33,35,44));
                using(var font=new Font("Consolas",11))using(var brush=new SolidBrush(Color.FromArgb(216,217,210)))
                for(int n=0;n<paths.Length;n++)g.DrawString(labels[n]+" / x"+scale,font,brush,n*cellW+12,10);
            }
            for(int n=0;n<paths.Length;n++)using(var src=new Bitmap(paths[n])) {
                int bottom=-1;
                for(int y=0;y<src.Height;y++)for(int x=0;x<src.Width;x++)if(src.GetPixel(x,y).A!=0)bottom=Math.Max(bottom,y);
                Blit(dst,src,n*cellW+(cellW-src.Width*scale)/2,45+(89-bottom)*scale,scale,gray);
            }
            dst.Save(output,ImageFormat.Png);
        }
    }
    public static void AssertEqual(string a,string b) {
        using(var aa=new Bitmap(a))using(var bb=new Bitmap(b)) {
            if(aa.Size!=bb.Size)throw new Exception("Dimension mismatch: "+a);
            for(int y=0;y<aa.Height;y++)for(int x=0;x<aa.Width;x++)
                if(aa.GetPixel(x,y).ToArgb()!=bb.GetPixel(x,y).ToArgb())throw new Exception("Pixel mismatch: "+a+" at "+x+","+y);
        }
    }
    public static void Assembly(string output,string macroPath,string[] paths,int scale) {
        // Offline composition only: a 560x160 art-pixel slice, not a gameplay screenshot.
        using(var art=new Bitmap(560*scale,160*scale))using(var macro=new Bitmap(macroPath)) {
            // Background remains the exact runtime world texture, including any legacy grid defects.
            // Sample at pixel centers, equivalent to a nearest camera scale of scale/4.
            for(int y=0;y<128*scale;y++)for(int x=0;x<560*scale;x++)
                art.SetPixel(x,y,macro.GetPixel(((int)((x+0.5)*4/scale))%macro.Width,((int)((y+0.5)*4/scale))%macro.Height));
            using(var g=Graphics.FromImage(art)) {
                using(var brush=new SolidBrush(Color.FromArgb(24,25,34)))g.FillRectangle(brush,0,128*scale,560*scale,32*scale);
                using(var brush=new SolidBrush(Color.FromArgb(58,56,65)))g.FillRectangle(brush,0,128*scale,560*scale,2*scale);
            }
            int[] centers={74,207,296,389,492};
            for(int i=0;i<paths.Length;i++)using(var prop=new Bitmap(paths[i])) {
                int bottom=-1;
                for(int y=0;y<prop.Height;y++)for(int x=0;x<prop.Width;x++)if(prop.GetPixel(x,y).A!=0)bottom=Math.Max(bottom,y);
                Blit(art,prop,(centers[i]-prop.Width/2)*scale,(129-bottom)*scale,scale,false);
            }
            art.Save(output,ImageFormat.Png);
        }
    }
    public static void SelfTest(string directory) {
        Directory.CreateDirectory(directory);
        string grid=Path.Combine(directory,"grid.png"),native=Path.Combine(directory,"grid-native.png");
        using(var b=new Bitmap(13,11)) {
            for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++)
                b.SetPixel(x,y,Color.FromArgb(255,((x+2)/4)*50,((y+1)/4)*70,20));
            b.Save(grid,ImageFormat.Png);
        }
        string proof=Extract(grid,native);if(!proof.Contains("grid=(2,3)"))throw new Exception("Incorrect phase recovery");
        string bad=Path.Combine(directory,"off-grid.png");
        using(var b=new Bitmap(grid)){b.SetPixel(5,5,Color.Magenta);b.Save(bad,ImageFormat.Png);}
        bool rejected=false;try{Extract(bad,Path.Combine(directory,"must-not-exist.png"));}catch(Exception e){rejected=e.Message.Contains("not an exact 4px grid");}
        if(!rejected)throw new Exception("Lossy reference was accepted");
        string pairs=Path.Combine(directory,"pair-test.png");
        using(var b=new Bitmap(2,2)){b.SetPixel(0,0,Color.Black);b.SetPixel(1,1,Color.White);b.Save(pairs,ImageFormat.Png);}
        if(!Stats(pairs).EndsWith(",0,0.00"))throw new Exception("Transparent boundaries entered density denominator");
        string edge=Path.Combine(directory,"threshold-test.png");
        using(var b=new Bitmap(2,1)){b.SetPixel(0,0,Color.Black);b.SetPixel(1,0,Color.FromArgb(24,0,0));b.Save(edge,ImageFormat.Png);}
        if(!Stats(edge).EndsWith(",1,100.00"))throw new Exception("Delta threshold changed");
    }
}
