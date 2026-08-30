using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Microsoft.Win32;
using PAPAluLive.Core;
using PAPAluLive.Windows.Audio;
using PAPAluLive.Windows.Characters;
using PAPAluLive.Windows.Presentation;
using PAPAluLive.Windows.Storage;

namespace PAPAluLive.Windows;

public partial class MainWindow : Window
{
    private readonly IReadOnlyDictionary<CharacterId, CharacterAssets> catalog;
    private readonly CharacterRuntime runtime;
    private readonly MouthGate mouthGate = new();
    private readonly MicrophoneMonitor microphone = new();
    private readonly CharacterAnimator animator;
    private readonly CharacterMenuBuilder menuBuilder;
    private readonly AppSettingsStore settingsStore = new();
    private readonly CustomCharacterStore customCharacterStore = new();
    private readonly WindowScale windowScale;
    private readonly ThoughtCloudPlan thoughtCloudPlan = new();
    private CharacterAssets assets;
    private CharacterAssets? customAssets;
    private CharacterId selectedCharacterId;
    private CharacterDisplayState microphoneDisplayState = CharacterDisplayState.Idle;
    private bool microphoneFaultShown;

    public MainWindow()
    {
        InitializeComponent();
        catalog = CharacterCatalog.LoadBundled();
        var settings = settingsStore.Load();
        customAssets = customCharacterStore.Load();
        selectedCharacterId = ParseSelectedCharacter(
            settings.SelectedCharacterId,
            customAssets is not null);
        assets = selectedCharacterId == CharacterId.Custom
            ? customAssets!
            : catalog[selectedCharacterId];
        windowScale = new WindowScale(settings.Scale);
        runtime = new CharacterRuntime(assets.Definition);
        animator = new CharacterAnimator(
            runtime,
            CharacterImage,
            ThoughtCloud,
            ShowFrame);
        menuBuilder = new CharacterMenuBuilder(
            catalog,
            () => selectedCharacterId,
            SelectBuiltInCharacter,
            SelectCustomCharacter,
            ConfigureCustomCharacter,
            IncreaseScale,
            DecreaseScale,
            ResetScale,
            () => Application.Current.Shutdown());
        menuBuilder.SetCustomAvailable(
            customAssets is not null,
            customAssets?.Images[customAssets.Definition.IdleAssetName]);
        ContextMenu = menuBuilder.Menu;

        ApplyScale();
        ShowCurrentFrame();

        microphone.SampleAvailable += OnMicrophoneSample;
        microphone.Faulted += OnMicrophoneFaulted;
        Loaded += (_, _) =>
        {
            RestorePosition(settings);
            UpdateCloudLayout();
            animator.Start();
            microphone.Start();
        };
        Closed += (_, _) =>
        {
            SaveSettings();
            animator.Dispose();
            microphone.Dispose();
        };
    }

    private void OnMouseLeftButtonDown(
        object sender,
        MouseButtonEventArgs eventArgs)
    {
        if (eventArgs.LeftButton == MouseButtonState.Pressed)
        {
            DragMove();
        }
    }

    private void OnMicrophoneSample(double rms, double duration)
    {
        var state = mouthGate.Update(rms, duration) == MouthState.Talking
            ? CharacterDisplayState.Talking
            : CharacterDisplayState.Idle;

        if (state == microphoneDisplayState)
        {
            return;
        }

        microphoneDisplayState = state;

        Dispatcher.BeginInvoke(() => animator.SetState(state));
    }

    private void OnMicrophoneFaulted(Exception exception)
    {
        Dispatcher.BeginInvoke(() =>
        {
            microphoneDisplayState = CharacterDisplayState.Idle;
            animator.SetState(CharacterDisplayState.Idle);
            if (microphoneFaultShown)
            {
                return;
            }

            microphoneFaultShown = true;
            MessageBox.Show(
                this,
                "无法读取默认麦克风。请在 Windows 设置 → 隐私和安全性 → 麦克风中允许桌面应用访问麦克风，然后重新打开 PAPAlu Live。\n\n" +
                exception.Message,
                "PAPAlu Live 麦克风不可用",
                MessageBoxButton.OK,
                MessageBoxImage.Information);
        });
    }

    private void ShowCurrentFrame()
    {
        CharacterImage.Source = assets.Images[runtime.CurrentAssetName];
    }

    private void ShowFrame(string assetName)
    {
        CharacterImage.Source = assets.Images[assetName];
    }

    private void SelectBuiltInCharacter(CharacterId characterId)
    {
        selectedCharacterId = characterId;
        assets = catalog[characterId];
        animator.SetCharacter(assets.Definition, microphoneDisplayState);
        ApplyScale();
        menuBuilder.RefreshChecks();
        SaveSettings();
    }

    private void SelectCustomCharacter()
    {
        if (customAssets is null)
        {
            return;
        }

        selectedCharacterId = CharacterId.Custom;
        assets = customAssets;
        animator.SetCharacter(assets.Definition, microphoneDisplayState);
        ApplyScale();
        menuBuilder.RefreshChecks();
        SaveSettings();
    }

    private void ConfigureCustomCharacter()
    {
        var idlePath = PickPng("选择闭嘴 PNG");
        if (idlePath is null)
        {
            return;
        }

        var talkingPath = PickPng("选择张嘴 PNG");
        if (talkingPath is null)
        {
            return;
        }

        try
        {
            var result = customCharacterStore.Import(idlePath, talkingPath);
            customAssets = result.Assets;
            menuBuilder.SetCustomAvailable(
                available: true,
                thumbnail: customAssets.Images[customAssets.Definition.IdleAssetName]);
            SelectCustomCharacter();
            if (result.Warning is not null)
            {
                MessageBox.Show(
                    this,
                    result.Warning,
                    "自定义角色已导入",
                    MessageBoxButton.OK,
                    MessageBoxImage.Warning);
            }
        }
        catch (Exception exception) when (
            exception is IOException or NotSupportedException or ArgumentException)
        {
            MessageBox.Show(
                this,
                "无法导入这组 PNG。请确认两张图片都能正常打开。\n\n" +
                exception.Message,
                "自定义角色导入失败",
                MessageBoxButton.OK,
                MessageBoxImage.Information);
        }
    }

    private void IncreaseScale()
    {
        windowScale.Increase();
        ApplyScale();
        SaveSettings();
    }

    private void DecreaseScale()
    {
        windowScale.Decrease();
        ApplyScale();
        SaveSettings();
    }

    private void ResetScale()
    {
        windowScale.Reset();
        ApplyScale();
        SaveSettings();
    }

    private void ApplyScale()
    {
        Width = assets.Definition.DefaultSize.Width * windowScale.Factor;
        Height = assets.Definition.DefaultSize.Height * windowScale.Factor;
        UpdateCloudLayout();
    }

    private void RestorePosition(AppSettingsData settings)
    {
        WindowPlacement.Restore(
            this,
            settings.Left,
            settings.Top,
            defaultMargin: 48);
    }

    private void SaveSettings()
    {
        try
        {
            settingsStore.Save(new AppSettingsData(
                selectedCharacterId.ToString(),
                Left,
                Top,
                windowScale.Factor));
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }
    }

    private static CharacterId ParseSelectedCharacter(
        string value,
        bool customAvailable)
    {
        if (!Enum.TryParse<CharacterId>(value, out var parsed))
        {
            return CharacterId.CatMeme;
        }

        if (parsed == CharacterId.Custom)
        {
            return customAvailable ? parsed : CharacterId.CatMeme;
        }

        return CharacterDefinition.BundledCharacters.Any(item => item.Id == parsed)
            ? parsed
            : CharacterId.CatMeme;
    }

    private string? PickPng(string title)
    {
        var dialog = new OpenFileDialog
        {
            Title = title,
            Filter = "PNG 图片 (*.png)|*.png",
            CheckFileExists = true,
            Multiselect = false,
        };
        return dialog.ShowDialog(this) == true ? dialog.FileName : null;
    }

    private void OnSizeChanged(object sender, SizeChangedEventArgs eventArgs)
    {
        UpdateCloudLayout();
    }

    private void UpdateCloudLayout()
    {
        if (!IsInitialized)
        {
            return;
        }

        var frame = thoughtCloudPlan.Frame(ActualWidth, ActualHeight);
        Canvas.SetLeft(ThoughtCloud, frame.X);
        Canvas.SetTop(ThoughtCloud, frame.Y);
        ThoughtCloud.Width = frame.Width;
        ThoughtCloud.Height = frame.Height;
    }
}
