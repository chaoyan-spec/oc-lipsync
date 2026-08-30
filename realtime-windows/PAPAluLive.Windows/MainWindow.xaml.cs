using System.Windows;
using System.Windows.Input;
using PAPAluLive.Core;
using PAPAluLive.Windows.Characters;

namespace PAPAluLive.Windows;

public partial class MainWindow : Window
{
    private readonly IReadOnlyDictionary<CharacterId, CharacterAssets> catalog;
    private CharacterAssets assets;

    public MainWindow()
    {
        InitializeComponent();
        catalog = CharacterCatalog.LoadBundled();
        assets = catalog[CharacterId.CatMeme];
        CharacterImage.Source = assets.Images[assets.Definition.IdleAssetName];
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
}
