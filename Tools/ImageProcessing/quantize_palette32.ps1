param(
    [Parameter(Mandatory = $true)] [string] $InputPath,
    [Parameter(Mandatory = $true)] [string] $OutputPath
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$refVersion = Get-ChildItem 'C:\Program Files\dotnet\packs\Microsoft.NETCore.App.Ref' -Directory |
    Sort-Object Name -Descending | Select-Object -First 1
$references = Get-ChildItem (Join-Path $refVersion.FullName 'ref\net10.0') -Filter '*.dll' |
    ForEach-Object FullName
$references += [System.Reflection.Assembly]::Load('System.Drawing.Common').Location
$references += [System.Reflection.Assembly]::Load('System.Private.Windows.GdiPlus').Location
$references += [System.Reflection.Assembly]::Load('System.Private.Windows.Core').Location
Add-Type -ReferencedAssemblies $references -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class Palette32Quantizer {
    sealed class Bin {
        public int Count, RSum, GSum, BSum;
        public int R { get { return RSum / Count; } }
        public int G { get { return GSum / Count; } }
        public int B { get { return BSum / Count; } }
        public double Weight { get { return Math.Sqrt(Count); } }
    }
    sealed class Box {
        public List<int> Ids;
        public Box(List<int> ids) { Ids = ids; }
    }
    static int Channel(Bin b, int axis) { return axis == 0 ? b.R : axis == 1 ? b.G : b.B; }

    public static string Run(string inputPath, string outputPath) {
        using (Bitmap source = new Bitmap(inputPath)) {
            int width = source.Width, height = source.Height;
            using (Bitmap rgb = new Bitmap(width, height, PixelFormat.Format24bppRgb)) {
                using (Graphics g = Graphics.FromImage(rgb)) g.DrawImageUnscaled(source, 0, 0);
                Rectangle rect = new Rectangle(0, 0, width, height);
                BitmapData src = rgb.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
                byte[] srcBytes = new byte[Math.Abs(src.Stride) * height];
                Marshal.Copy(src.Scan0, srcBytes, 0, srcBytes.Length);
                rgb.UnlockBits(src);

                Bin[] bins = new Bin[32768];
                for (int y = 0; y < height; y++) {
                    int row = y * Math.Abs(src.Stride);
                    for (int x = 0; x < width; x++) {
                        int p = row + x * 3;
                        int b = srcBytes[p], g = srcBytes[p + 1], r = srcBytes[p + 2];
                        int key = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3);
                        if (bins[key] == null) bins[key] = new Bin();
                        Bin bin = bins[key]; bin.Count++; bin.RSum += r; bin.GSum += g; bin.BSum += b;
                    }
                }
                List<int> ids = new List<int>();
                for (int i = 0; i < bins.Length; i++) if (bins[i] != null) ids.Add(i);
                List<Box> boxes = new List<Box>(); boxes.Add(new Box(ids));
                while (boxes.Count < 32) {
                    int chosen = -1, chosenAxis = 0; double bestScore = -1;
                    for (int i = 0; i < boxes.Count; i++) {
                        Box box = boxes[i]; if (box.Ids.Count < 2) continue;
                        int[] min = {255, 255, 255}, max = {0, 0, 0}; double weight = 0;
                        foreach (int id in box.Ids) {
                            Bin v = bins[id]; weight += v.Weight;
                            for (int a = 0; a < 3; a++) { int c = Channel(v, a); min[a] = Math.Min(min[a], c); max[a] = Math.Max(max[a], c); }
                        }
                        int axis = 0; for (int a = 1; a < 3; a++) if (max[a] - min[a] > max[axis] - min[axis]) axis = a;
                        double score = (max[axis] - min[axis]) * Math.Sqrt(weight);
                        if (score > bestScore) { bestScore = score; chosen = i; chosenAxis = axis; }
                    }
                    if (chosen < 0) break;
                    List<int> ordered = boxes[chosen].Ids;
                    int sortAxis = chosenAxis;
                    ordered.Sort((a, b) => Channel(bins[a], sortAxis).CompareTo(Channel(bins[b], sortAxis)));
                    double total = 0; foreach (int id in ordered) total += bins[id].Weight;
                    double running = 0; int cut = 1;
                    for (int i = 0; i < ordered.Count - 1; i++) { running += bins[ordered[i]].Weight; if (running >= total / 2) { cut = i + 1; break; } }
                    List<int> left = ordered.GetRange(0, cut), right = ordered.GetRange(cut, ordered.Count - cut);
                    boxes[chosen] = new Box(left); boxes.Add(new Box(right));
                }
                Color[] colors = new Color[boxes.Count];
                for (int i = 0; i < boxes.Count; i++) {
                    double r = 0, g = 0, b = 0, weight = 0;
                    foreach (int id in boxes[i].Ids) { Bin v = bins[id]; double w = v.Weight; r += v.R * w; g += v.G * w; b += v.B * w; weight += w; }
                    colors[i] = Color.FromArgb((int)Math.Round(r / weight), (int)Math.Round(g / weight), (int)Math.Round(b / weight));
                }
                using (Bitmap output = new Bitmap(width, height, PixelFormat.Format8bppIndexed)) {
                    ColorPalette palette = output.Palette;
                    for (int i = 0; i < palette.Entries.Length; i++) palette.Entries[i] = i < colors.Length ? colors[i] : Color.Black;
                    output.Palette = palette;
                    BitmapData dst = output.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format8bppIndexed);
                    byte[] dstBytes = new byte[Math.Abs(dst.Stride) * height];
                    byte[] cache = new byte[32768]; bool[] cached = new bool[32768];
                    for (int y = 0; y < height; y++) {
                        int srcRow = y * Math.Abs(src.Stride), dstRow = y * Math.Abs(dst.Stride);
                        for (int x = 0; x < width; x++) {
                            int p = srcRow + x * 3;
                            int b = srcBytes[p], g = srcBytes[p + 1], r = srcBytes[p + 2];
                            int key = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3);
                            if (!cached[key]) {
                                int nearest = 0; long best = long.MaxValue;
                                for (int i = 0; i < colors.Length; i++) {
                                    long dr = r - colors[i].R, dg = g - colors[i].G, db = b - colors[i].B;
                                    long distance = 2 * dr * dr + 4 * dg * dg + 3 * db * db;
                                    if (distance < best) { best = distance; nearest = i; }
                                }
                                cache[key] = (byte)nearest; cached[key] = true;
                            }
                            dstBytes[dstRow + x] = cache[key];
                        }
                    }
                    byte[] cleaned = (byte[])dstBytes.Clone();
                    int stride = Math.Abs(dst.Stride);
                    for (int y = 1; y < height - 1; y++) {
                        for (int x = 1; x < width - 1; x++) {
                            int p = y * stride + x;
                            int center = dstBytes[p], centerCount = 0, bestIndex = center, bestCount = 0;
                            int[] counts = new int[colors.Length];
                            for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) counts[dstBytes[p + dy * stride + dx]]++;
                            centerCount = counts[center];
                            for (int i = 0; i < colors.Length; i++) if (counts[i] > bestCount) { bestCount = counts[i]; bestIndex = i; }
                            if (centerCount <= 2 && bestCount >= 4 && bestIndex != center) {
                                long dr = colors[center].R - colors[bestIndex].R;
                                long dg = colors[center].G - colors[bestIndex].G;
                                long db = colors[center].B - colors[bestIndex].B;
                                if (2 * dr * dr + 4 * dg * dg + 3 * db * db <= 6000) cleaned[p] = (byte)bestIndex;
                            }
                        }
                    }
                    bool[] used = new bool[colors.Length];
                    for (int y = 0; y < height; y++) for (int x = 0; x < width; x++) used[cleaned[y * stride + x]] = true;
                    Marshal.Copy(cleaned, 0, dst.Scan0, cleaned.Length);
                    output.UnlockBits(dst);
                    output.Save(outputPath, ImageFormat.Png);
                    int usedCount = 0; foreach (bool value in used) if (value) usedCount++;
                    return width + "x" + height + ", palette entries=" + colors.Length + ", used colors=" + usedCount;
                }
            }
        }
    }
}
'@

[Palette32Quantizer]::Run((Resolve-Path -LiteralPath $InputPath).Path, $OutputPath)
