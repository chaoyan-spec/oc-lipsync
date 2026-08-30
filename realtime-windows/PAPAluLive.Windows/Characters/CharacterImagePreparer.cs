using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace PAPAluLive.Windows.Characters;

public sealed record PreparedCharacterImages(
    BitmapSource Idle,
    BitmapSource Talking,
    bool HasAlpha);

public static class CharacterImagePreparer
{
    public static PreparedCharacterImages Prepare(
        BitmapSource idle,
        BitmapSource talking)
    {
        ArgumentNullException.ThrowIfNull(idle);
        ArgumentNullException.ThrowIfNull(talking);

        var width = Math.Max(idle.PixelWidth, talking.PixelWidth);
        var height = Math.Max(idle.PixelHeight, talking.PixelHeight);
        if (width <= 0 || height <= 0)
        {
            throw new InvalidDataException("角色图片尺寸无效。");
        }

        return new PreparedCharacterImages(
            DrawBottomCentered(idle, width, height),
            DrawBottomCentered(talking, width, height),
            HasAlpha(idle) && HasAlpha(talking));
    }

    private static BitmapSource DrawBottomCentered(
        BitmapSource source,
        int width,
        int height)
    {
        var visual = new DrawingVisual();
        using (var context = visual.RenderOpen())
        {
            context.DrawImage(
                source,
                new Rect(
                    (width - source.PixelWidth) / 2.0,
                    height - source.PixelHeight,
                    source.PixelWidth,
                    source.PixelHeight));
        }

        var output = new RenderTargetBitmap(
            width,
            height,
            96,
            96,
            PixelFormats.Pbgra32);
        output.Render(visual);
        output.Freeze();
        return output;
    }

    private static bool HasAlpha(BitmapSource source) =>
        source.Format.Masks.Count >= 4;
}
