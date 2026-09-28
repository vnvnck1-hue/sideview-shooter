param([switch] $Build)

$ErrorActionPreference = 'Stop'
$root = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path 'Assets\Generated\CoolantPumpRoom\modular_v1'
$source = Join-Path $root 'Source'
$background = Join-Path $root 'Background'
$props = Join-Path $root 'Props'
$preview = Join-Path $root 'Preview'
foreach ($dir in @($background, $props, $preview)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

if (-not $Build) { Write-Output 'Pass -Build to create the modular coolant-pump pack.'; return }

$refVersion = Get-ChildItem 'C:\Program Files\dotnet\packs\Microsoft.NETCore.App.Ref' -Directory |
    Sort-Object Name -Descending | Select-Object -First 1
$references = Get-ChildItem (Join-Path $refVersion.FullName 'ref\net10.0') -Filter '*.dll' |
    ForEach-Object FullName
$references += [System.Reflection.Assembly]::Load('System.Drawing.Common').Location
$references += [System.Reflection.Assembly]::Load('System.Private.Windows.GdiPlus').Location
$references += [System.Reflection.Assembly]::Load('System.Private.Windows.Core').Location

Add-Type -ReferencedAssemblies $references -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Collections.Generic;
using System.IO;

public static class CoolantPumpPack {
    static Bitmap B(int w, int h) { return new Bitmap(w, h, PixelFormat.Format32bppArgb); }
    static void Save(Bitmap bitmap, string path) { bitmap.Save(path, ImageFormat.Png); bitmap.Dispose(); }
    static Color Solid(Color c) { return Color.FromArgb(255, c.R, c.G, c.B); }

    static Rectangle AlphaBounds(Bitmap source, int left, int right) {
        int x0 = right, y0 = source.Height, x1 = left - 1, y1 = -1;
        for (int y = 0; y < source.Height; y++) for (int x = left; x < right; x++) {
            if (source.GetPixel(x, y).A < 160) continue;
            x0 = Math.Min(x0, x); y0 = Math.Min(y0, y);
            x1 = Math.Max(x1, x); y1 = Math.Max(y1, y);
        }
        if (x1 < x0 || y1 < y0) throw new Exception("No opaque prop pixels found");
        return Rectangle.FromLTRB(x0, y0, x1 + 1, y1 + 1);
    }

    static Bitmap Prop(string sourcePath, int maxWidth, int maxHeight, int segment) {
        using (Bitmap source = new Bitmap(sourcePath)) {
            int left = segment == 2 ? source.Width / 2 : 0;
            int right = segment == 1 ? source.Width / 2 : source.Width;
            Rectangle box = AlphaBounds(source, left, right);
            double scale = Math.Min((double)maxWidth / box.Width, (double)maxHeight / box.Height);
            int w = Math.Max(1, (int)Math.Round(box.Width * scale));
            int h = Math.Max(1, (int)Math.Round(box.Height * scale));
            Bitmap result = B(w + 4, h + 4);
            for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
                int sx = box.Left + Math.Min(box.Width - 1, (int)((x + 0.5) * box.Width / w));
                int sy = box.Top + Math.Min(box.Height - 1, (int)((y + 0.5) * box.Height / h));
                Color c = source.GetPixel(sx, sy);
                if (c.A >= 160) result.SetPixel(x + 2, y + 2, Solid(c));
            }
            return result;
        }
    }

    static Bitmap MirroredMacro(Bitmap plate) {
        Bitmap result = B(256, 768);
        for (int y = 0; y < 768; y++) for (int x = 0; x < 256; x++) {
            int sourceX = 780 + (x < 128 ? x : 255 - x);
            result.SetPixel(x, y, Solid(plate.GetPixel(sourceX, y)));
        }
        return result;
    }

    static Bitmap WallFill(Bitmap plate) {
        Bitmap result = B(128, 128);
        for (int y = 0; y < 128; y++) for (int x = 0; x < 128; x++) {
            int sourceX = 825 + (x < 64 ? x : 127 - x);
            int sourceY = 300 + (y < 64 ? y : 127 - y);
            result.SetPixel(x, y, Solid(plate.GetPixel(sourceX, sourceY)));
        }
        return result;
    }

    static Bitmap Crop(Bitmap source, int x0, int y0, int w, int h) {
        Bitmap result = B(w, h);
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) result.SetPixel(x, y, source.GetPixel(x0 + x, y0 + y));
        return result;
    }

    static void Draw(Bitmap canvas, Bitmap part, int x, int y) {
        using (Graphics g = Graphics.FromImage(canvas)) { g.DrawImageUnscaled(part, x, y); }
    }

    public static string Build(string sourceDir, string backgroundDir, string propsDir, string previewDir) {
        using (Bitmap plate = new Bitmap(Path.Combine(sourceDir, "empty_plate_generated.png"))) {
            using (Bitmap macro = MirroredMacro(plate)) {
                macro.Save(Path.Combine(backgroundDir, "background_repeat_2x6_128.png"), ImageFormat.Png);
                for (int y = 0; y < 6; y++) for (int x = 0; x < 2; x++) {
                    string name = "bg_r" + y + "_c" + x + ".png";
                    Save(Crop(macro, x * 128, y * 128, 128, 128), Path.Combine(backgroundDir, name));
                }
                using (Bitmap fill = WallFill(plate)) {
                    for (int y = 0; y < fill.Height; y++) if (fill.GetPixel(0, y).ToArgb() != fill.GetPixel(fill.Width - 1, y).ToArgb()) throw new Exception("Wall-fill horizontal seam mismatch");
                    for (int x = 0; x < fill.Width; x++) if (fill.GetPixel(x, 0).ToArgb() != fill.GetPixel(x, fill.Height - 1).ToArgb()) throw new Exception("Wall-fill vertical seam mismatch");
                    fill.Save(Path.Combine(backgroundDir, "wall_fill_repeat_128.png"), ImageFormat.Png);
                }
                using (Bitmap repeated = B(2048, 768)) {
                    for (int x = 0; x < 2048; x += 256) Draw(repeated, macro, x, 0);
                    repeated.Save(Path.Combine(previewDir, "background_repeat_8x.png"), ImageFormat.Png);
                    string[] names = {"pump", "tank", "console", "door", "valve_manifold", "ceiling_lamp"};
                    string[] files = {"pump_cutout_generated.png", "tank_cutout_generated.png", "console_cutout_generated.png", "door_cutout_generated.png", "valve_lamp_sheet_generated.png", "valve_lamp_sheet_generated.png"};
                    int[] widths = {970, 230, 360, 250, 160, 180};
                    int[] heights = {350, 410, 240, 365, 225, 80};
                    int[] segments = {0, 0, 0, 0, 1, 2};
                    var assetSizes = new List<string>();
                    var parts = new Dictionary<string, Bitmap>();
                    try {
                        for (int i = 0; i < names.Length; i++) {
                            Bitmap prop = Prop(Path.Combine(sourceDir, files[i]), widths[i], heights[i], segments[i]);
                            if (prop.GetPixel(0, 0).A != 0 || prop.GetPixel(prop.Width - 1, prop.Height - 1).A != 0) throw new Exception("Prop padding is not transparent: " + names[i]);
                            parts[names[i]] = prop;
                            prop.Save(Path.Combine(propsDir, names[i] + ".png"), ImageFormat.Png);
                            assetSizes.Add(names[i] + "=" + prop.Width + "x" + prop.Height);
                        }
                        using (Bitmap scene = B(2048, 768)) {
                            Draw(scene, repeated, 0, 0);
                            Draw(scene, parts["door"], 105, 596 - parts["door"].Height);
                            Draw(scene, parts["tank"], 1530, 596 - parts["tank"].Height);
                            Draw(scene, parts["valve_manifold"], 1400, 565 - parts["valve_manifold"].Height);
                            Draw(scene, parts["pump"], 375, 606 - parts["pump"].Height);
                            Draw(scene, parts["console"], 1615, 612 - parts["console"].Height);
                            Draw(scene, parts["ceiling_lamp"], 505, 137);
                            Draw(scene, parts["ceiling_lamp"], 1355, 137);
                            scene.Save(Path.Combine(previewDir, "assembled_example.png"), ImageFormat.Png);
                        }
                        using (Bitmap scene = B(2048, 768)) {
                            Draw(scene, repeated, 0, 0);
                            Draw(scene, parts["tank"], 305, 594 - parts["tank"].Height);
                            Draw(scene, parts["console"], 620, 612 - parts["console"].Height);
                            Draw(scene, parts["valve_manifold"], 1080, 575 - parts["valve_manifold"].Height);
                            Draw(scene, parts["pump"], 1050, 606 - parts["pump"].Height);
                            Draw(scene, parts["door"], 40, 596 - parts["door"].Height);
                            Draw(scene, parts["ceiling_lamp"], 910, 137);
                            scene.Save(Path.Combine(previewDir, "recombined_example.png"), ImageFormat.Png);
                        }
                    } finally { foreach (Bitmap part in parts.Values) part.Dispose(); }
                    for (int y = 0; y < macro.Height; y++) if (macro.GetPixel(0, y).ToArgb() != macro.GetPixel(macro.Width - 1, y).ToArgb()) throw new Exception("Macro horizontal seam mismatch");
                    return "repeat=256x768, seam=exact, props: " + string.Join(", ", assetSizes);
                }
            }
        }
    }
}
'@

[CoolantPumpPack]::Build($source, $background, $props, $preview)

$runtime = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path 'GodotPrototype\assets\coolant_pump_room'
foreach ($dir in @((Join-Path $runtime 'Background'), (Join-Path $runtime 'Props'))) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}
Copy-Item -Path (Join-Path $background '*.png') -Destination (Join-Path $runtime 'Background')
Copy-Item -Path (Join-Path $props '*.png') -Destination (Join-Path $runtime 'Props')
