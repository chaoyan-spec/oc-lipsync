using System.IO;
using System.Windows.Media.Imaging;
using PAPAluLive.Core;

namespace PAPAluLive.Windows.Characters;

public sealed record CustomCharacterImportResult(
    CharacterAssets Assets,
    string? Warning);

public sealed class CustomCharacterStore
{
    private readonly string directory;

    public CustomCharacterStore(string? localAppData = null)
    {
        var root = localAppData ?? Environment.GetFolderPath(
            Environment.SpecialFolder.LocalApplicationData);
        directory = Path.Combine(root, "PAPAluLive", "CustomCharacter");
    }

    public CharacterAssets? Load()
    {
        var idlePath = Path.Combine(directory, "idle.png");
        var talkingPath = Path.Combine(directory, "talking.png");
        if (!File.Exists(idlePath) || !File.Exists(talkingPath))
        {
            return null;
        }

        try
        {
            return CreateAssets(
                LoadBitmap(idlePath),
                LoadBitmap(talkingPath));
        }
        catch (Exception exception) when (
            exception is IOException or NotSupportedException)
        {
            return null;
        }
    }

    public CustomCharacterImportResult Import(
        string idlePath,
        string talkingPath)
    {
        var prepared = CharacterImagePreparer.Prepare(
            LoadBitmap(idlePath),
            LoadBitmap(talkingPath));
        var idleBytes = EncodePng(prepared.Idle);
        var talkingBytes = EncodePng(prepared.Talking);

        Directory.CreateDirectory(directory);
        var pendingId = Guid.NewGuid().ToString("N");
        var pendingIdle = Path.Combine(directory, $"idle.{pendingId}.tmp");
        var pendingTalking = Path.Combine(directory, $"talking.{pendingId}.tmp");
        try
        {
            File.WriteAllBytes(pendingIdle, idleBytes);
            File.WriteAllBytes(pendingTalking, talkingBytes);
            File.Move(
                pendingIdle,
                Path.Combine(directory, "idle.png"),
                overwrite: true);
            File.Move(
                pendingTalking,
                Path.Combine(directory, "talking.png"),
                overwrite: true);
        }
        finally
        {
            TryDelete(pendingIdle);
            TryDelete(pendingTalking);
        }

        return new CustomCharacterImportResult(
            CreateAssets(prepared.Idle, prepared.Talking),
            prepared.HasAlpha
                ? null
                : "图片没有透明背景，录屏时会保留原背景。");
    }

    private static CharacterAssets CreateAssets(
        BitmapSource idle,
        BitmapSource talking)
    {
        var definition = CharacterDefinition.Custom();
        return new CharacterAssets(
            definition,
            new Dictionary<string, BitmapSource>
            {
                [definition.IdleAssetName] = idle,
                [definition.TalkingAssetNames[0]] = talking,
            });
    }

    private static BitmapSource LoadBitmap(string path)
    {
        var bitmap = new BitmapImage();
        bitmap.BeginInit();
        bitmap.CacheOption = BitmapCacheOption.OnLoad;
        bitmap.UriSource = new Uri(path, UriKind.Absolute);
        bitmap.EndInit();
        bitmap.Freeze();
        return bitmap;
    }

    private static byte[] EncodePng(BitmapSource bitmap)
    {
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var stream = new MemoryStream();
        encoder.Save(stream);
        return stream.ToArray();
    }

    private static void TryDelete(string path)
    {
        try
        {
            File.Delete(path);
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }
    }
}
