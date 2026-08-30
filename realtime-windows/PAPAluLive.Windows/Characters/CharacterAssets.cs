using System.Windows.Media.Imaging;
using PAPAluLive.Core;

namespace PAPAluLive.Windows.Characters;

public sealed record CharacterAssets(
    CharacterDefinition Definition,
    IReadOnlyDictionary<string, BitmapSource> Images)
{
    public static CharacterAssets LoadBundled(CharacterDefinition definition)
    {
        var images = definition.RequiredAssetNames.ToDictionary(
            name => name,
            name => LoadBitmap(
                $"Resources/Characters/{definition.ResourceDirectoryName}/{name}.png"));
        return new CharacterAssets(definition, images);
    }

    private static BitmapSource LoadBitmap(string relativePath)
    {
        var uri = new Uri(
            $"pack://application:,,,/{relativePath}",
            UriKind.Absolute);
        var bitmap = new BitmapImage();
        bitmap.BeginInit();
        bitmap.UriSource = uri;
        bitmap.CacheOption = BitmapCacheOption.OnLoad;
        bitmap.EndInit();
        bitmap.Freeze();
        return bitmap;
    }
}
