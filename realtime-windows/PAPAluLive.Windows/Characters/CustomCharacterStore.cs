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
    private readonly Action? beforePointerCommit;

    public CustomCharacterStore(
        string? localAppData = null,
        Action? beforePointerCommit = null)
    {
        var root = localAppData ?? Environment.GetFolderPath(
            Environment.SpecialFolder.LocalApplicationData);
        directory = Path.Combine(root, "PAPAluLive", "CustomCharacter");
        this.beforePointerCommit = beforePointerCommit;
    }

    public CharacterAssets? Load()
    {
        try
        {
            var currentPath = Path.Combine(directory, "current.txt");
            if (File.Exists(currentPath))
            {
                var version = File.ReadAllText(currentPath).Trim();
                if (Guid.TryParseExact(version, "N", out _))
                {
                    return LoadPair(Path.Combine(directory, "versions", version));
                }
            }

            return LoadPair(directory);
        }
        catch (Exception exception) when (
            exception is IOException or NotSupportedException or
                ArgumentException or FormatException)
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

        var version = Guid.NewGuid().ToString("N");
        var versionsDirectory = Path.Combine(directory, "versions");
        var pendingDirectory = Path.Combine(versionsDirectory, $".{version}.pending");
        var versionDirectory = Path.Combine(versionsDirectory, version);
        var pendingPointer = Path.Combine(directory, $"current.{version}.tmp");
        Directory.CreateDirectory(versionsDirectory);
        try
        {
            Directory.CreateDirectory(pendingDirectory);
            File.WriteAllBytes(
                Path.Combine(pendingDirectory, "idle.png"),
                idleBytes);
            File.WriteAllBytes(
                Path.Combine(pendingDirectory, "talking.png"),
                talkingBytes);
            Directory.Move(pendingDirectory, versionDirectory);
            beforePointerCommit?.Invoke();
            File.WriteAllText(pendingPointer, version);
            File.Move(
                pendingPointer,
                Path.Combine(directory, "current.txt"),
                overwrite: true);
        }
        finally
        {
            TryDeleteFile(pendingPointer);
            TryDeleteDirectory(pendingDirectory);
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

    private static CharacterAssets? LoadPair(string pairDirectory)
    {
        var idlePath = Path.Combine(pairDirectory, "idle.png");
        var talkingPath = Path.Combine(pairDirectory, "talking.png");
        return File.Exists(idlePath) && File.Exists(talkingPath)
            ? CreateAssets(LoadBitmap(idlePath), LoadBitmap(talkingPath))
            : null;
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

    private static void TryDeleteFile(string path)
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

    private static void TryDeleteDirectory(string path)
    {
        try
        {
            if (Directory.Exists(path))
            {
                Directory.Delete(path, recursive: true);
            }
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }
    }
}
