using System.IO;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using PAPAluLive.Windows.Characters;
using PAPAluLive.Windows.Storage;

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

var temporaryRoot = Path.Combine(
    Path.GetTempPath(),
    "PAPAluLiveSmokeTests",
    Guid.NewGuid().ToString("N"));
try
{
    Directory.CreateDirectory(temporaryRoot);
    var idlePath = Path.Combine(temporaryRoot, "source-idle.png");
    var talkingPath = Path.Combine(temporaryRoot, "source-talking.png");
    SavePng(idle, idlePath);
    SavePng(talking, talkingPath);

    var store = new CustomCharacterStore(temporaryRoot);
    store.Import(idlePath, talkingPath);
    var loaded = store.Load() ?? throw new InvalidOperationException(
        "custom character did not load");
    Check(
        "custom character store round trips",
        PixelRed(loaded.Images["idle"], 50, 139) == 255 &&
        PixelBlue(loaded.Images["talking"], 50, 139) == 255);

    var replacementIdlePath = Path.Combine(temporaryRoot, "replacement-idle.png");
    var replacementTalkingPath = Path.Combine(temporaryRoot, "replacement-talking.png");
    SavePng(SolidBitmap(100, 120, 0, 255, 0), replacementIdlePath);
    SavePng(SolidBitmap(80, 140, 255, 255, 0), replacementTalkingPath);
    var failingStore = new CustomCharacterStore(
        temporaryRoot,
        beforePointerCommit: () => throw new IOException("injected failure"));
    try
    {
        failingStore.Import(replacementIdlePath, replacementTalkingPath);
        throw new InvalidOperationException("injected failure was not raised");
    }
    catch (IOException exception) when (exception.Message == "injected failure")
    {
    }

    var afterFailure = store.Load() ?? throw new InvalidOperationException(
        "custom character was lost after a failed replacement");
    Check(
        "failed replacement preserves the old pair",
        PixelRed(afterFailure.Images["idle"], 50, 139) == 255 &&
        PixelBlue(afterFailure.Images["talking"], 50, 139) == 255);

    store.Delete();
    Check("custom character store deletes saved assets", store.Load() is null);
    store.Delete();
    Check("repeated custom character delete is safe", store.Load() is null);

    var settingsStore = new AppSettingsStore(temporaryRoot);
    settingsStore.Save(new PAPAluLive.Core.AppSettingsData(
        "Papalu",
        Left: 120,
        Top: 80,
        Scale: 1.4));
    var savedSettings = settingsStore.Load();
    Check(
        "settings store round trips",
        savedSettings.SelectedCharacterId == "Papalu" &&
        savedSettings.Left == 120 &&
        savedSettings.Top == 80 &&
        savedSettings.Scale == 1.4);
    File.WriteAllText(
        Path.Combine(temporaryRoot, "PAPAluLive", "settings.json"),
        "not-json");
    Check(
        "invalid settings fall back",
        settingsStore.Load() == PAPAluLive.Core.AppSettingsData.Default);
}
finally
{
    if (Directory.Exists(temporaryRoot))
    {
        Directory.Delete(temporaryRoot, recursive: true);
    }
}

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

static byte PixelRed(BitmapSource bitmap, int x, int y) =>
    Pixel(bitmap, x, y)[2];

static byte PixelBlue(BitmapSource bitmap, int x, int y) =>
    Pixel(bitmap, x, y)[0];

static byte[] Pixel(BitmapSource bitmap, int x, int y)
{
    var pixel = new byte[4];
    bitmap.CopyPixels(new System.Windows.Int32Rect(x, y, 1, 1), pixel, 4, 0);
    return pixel;
}

static void SavePng(BitmapSource bitmap, string path)
{
    var encoder = new PngBitmapEncoder();
    encoder.Frames.Add(BitmapFrame.Create(bitmap));
    using var stream = File.Create(path);
    encoder.Save(stream);
}

static void Check(string name, bool condition)
{
    if (!condition)
    {
        throw new InvalidOperationException(name);
    }
}
