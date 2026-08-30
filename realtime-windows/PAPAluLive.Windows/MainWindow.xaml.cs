using System.Windows;
using System.Windows.Input;
using PAPAluLive.Core;
using PAPAluLive.Windows.Audio;
using PAPAluLive.Windows.Characters;

namespace PAPAluLive.Windows;

public partial class MainWindow : Window
{
    private readonly IReadOnlyDictionary<CharacterId, CharacterAssets> catalog;
    private readonly CharacterRuntime runtime;
    private readonly MouthGate mouthGate = new();
    private readonly MicrophoneMonitor microphone = new();
    private CharacterAssets assets;

    public MainWindow()
    {
        InitializeComponent();
        catalog = CharacterCatalog.LoadBundled();
        assets = catalog[CharacterId.CatMeme];
        runtime = new CharacterRuntime(assets.Definition);
        ShowCurrentFrame();

        microphone.SampleAvailable += OnMicrophoneSample;
        microphone.Faulted += OnMicrophoneFaulted;
        Loaded += (_, _) => microphone.Start();
        Closed += (_, _) => microphone.Dispose();
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

        Dispatcher.BeginInvoke(() =>
        {
            runtime.SetState(state);
            ShowCurrentFrame();
        });
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
}
