using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
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
    private readonly WindowScale windowScale;
    private readonly ThoughtCloudPlan thoughtCloudPlan = new();
    private CharacterAssets assets;
    private CharacterId selectedCharacterId;
    private CharacterDisplayState microphoneDisplayState = CharacterDisplayState.Idle;

    public MainWindow()
    {
        InitializeComponent();
        catalog = CharacterCatalog.LoadBundled();
        var settings = settingsStore.Load();
        selectedCharacterId = ParseBundledCharacter(settings.SelectedCharacterId);
        assets = catalog[selectedCharacterId];
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
        Dispatcher.BeginInvoke(() => MessageBox.Show(
            this,
            "无法读取默认麦克风。请在 Windows 设置 → 隐私和安全性 → 麦克风中允许桌面应用访问麦克风，然后重新打开 PAPAlu Live。\n\n" +
            exception.Message,
            "PAPAlu Live 麦克风不可用",
            MessageBoxButton.OK,
            MessageBoxImage.Information));
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
    }

    private void ConfigureCustomCharacter()
    {
        MessageBox.Show(
            this,
            "自定义角色导入将在下一步连接。Windows V1 会要求一张闭嘴 PNG 和一张张嘴 PNG。",
            "设置自定义角色",
            MessageBoxButton.OK,
            MessageBoxImage.Information);
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
        if (settings.Left is not null && settings.Top is not null)
        {
            Left = settings.Left.Value;
            Top = settings.Top.Value;
            return;
        }

        var workArea = SystemParameters.WorkArea;
        Left = workArea.Right - Width - 48;
        Top = workArea.Bottom - Height - 48;
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

    private static CharacterId ParseBundledCharacter(string value)
    {
        return Enum.TryParse<CharacterId>(value, out var parsed) &&
            CharacterDefinition.BundledCharacters.Any(item => item.Id == parsed)
            ? parsed
            : CharacterId.CatMeme;
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
