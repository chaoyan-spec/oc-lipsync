using System.Windows.Media;
using System.Windows.Media.Imaging;
using PAPAluLive.Windows.Characters;

var idle = SolidBitmap(100, 120, 255, 0, 0);
var talking = SolidBitmap(80, 140, 0, 0, 255);
var prepared = CharacterImagePreparer.Prepare(idle, talking);

Check("idle output size", prepared.Idle.PixelWidth == 100 && prepared.Idle.PixelHeight == 140);
Check("talking output size", prepared.Talking.PixelWidth == 100 && prepared.Talking.PixelHeight == 140);
Check("idle top is transparent", PixelAlpha(prepared.Idle, 50, 0) == 0);
Check("idle touches bottom", PixelAlpha(prepared.Idle, 50, 139) == 255);
Check("talking is horizontally centered", PixelAlpha(prepared.Talking, 9, 70) == 0);
Check("talking begins at centered edge", PixelAlpha(prepared.Talking, 10, 70) == 255);
Check("talking touches bottom", PixelAlpha(prepared.Talking, 50, 139) == 255);

Console.WriteLine("PAPAluLive Windows smoke tests passed");
return 0;

static WriteableBitmap SolidBitmap(
    int width,
    int height,
    byte red,
    byte green,
    byte blue)
{
    var bitmap = new WriteableBitmap(width, height, 96, 96, PixelFormats.Bgra32, null);
    var pixels = new byte[width * height * 4];
    for (var index = 0; index < pixels.Length; index += 4)
    {
        pixels[index] = blue;
        pixels[index + 1] = green;
        pixels[index + 2] = red;
        pixels[index + 3] = 255;
    }
    bitmap.WritePixels(
        new System.Windows.Int32Rect(0, 0, width, height),
        pixels,
        width * 4,
        0);
    bitmap.Freeze();
    return bitmap;
}

static byte PixelAlpha(BitmapSource bitmap, int x, int y)
{
    var pixel = new byte[4];
    bitmap.CopyPixels(new System.Windows.Int32Rect(x, y, 1, 1), pixel, 4, 0);
    return pixel[3];
}

static void Check(string name, bool condition)
{
    if (!condition)
    {
        throw new InvalidOperationException(name);
    }
}
