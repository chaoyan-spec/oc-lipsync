using System.IO;
using System.Text.Json;
using PAPAluLive.Core;

namespace PAPAluLive.Windows.Storage;

public sealed class AppSettingsStore
{
    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        WriteIndented = true,
    };

    private readonly string settingsPath;

    public AppSettingsStore(string? localAppData = null)
    {
        var root = localAppData ?? Environment.GetFolderPath(
            Environment.SpecialFolder.LocalApplicationData);
        settingsPath = Path.Combine(root, "PAPAluLive", "settings.json");
    }

    public AppSettingsData Load()
    {
        try
        {
            if (!File.Exists(settingsPath))
            {
                return AppSettingsData.Default;
            }

            return (JsonSerializer.Deserialize<AppSettingsData>(
                File.ReadAllText(settingsPath),
                SerializerOptions) ?? AppSettingsData.Default).Normalize();
        }
        catch (JsonException)
        {
            return AppSettingsData.Default;
        }
        catch (IOException)
        {
            return AppSettingsData.Default;
        }
        catch (UnauthorizedAccessException)
        {
            return AppSettingsData.Default;
        }
    }

    public void Save(AppSettingsData settings)
    {
        var directory = Path.GetDirectoryName(settingsPath) ??
            throw new InvalidOperationException("Settings directory is unavailable.");
        Directory.CreateDirectory(directory);
        var temporaryPath = settingsPath + ".tmp";
        File.WriteAllText(
            temporaryPath,
            JsonSerializer.Serialize(settings.Normalize(), SerializerOptions));
        File.Move(temporaryPath, settingsPath, overwrite: true);
    }
}
