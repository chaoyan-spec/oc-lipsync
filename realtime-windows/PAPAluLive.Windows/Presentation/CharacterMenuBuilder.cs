using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using PAPAluLive.Core;
using PAPAluLive.Windows.Characters;

namespace PAPAluLive.Windows.Presentation;

public sealed class CharacterMenuBuilder
{
    private const double ThumbnailSize = 32;

    private readonly IReadOnlyDictionary<CharacterId, CharacterAssets> catalog;
    private readonly Func<CharacterId> selectedCharacter;
    private readonly List<MenuItem> characterItems = [];
    private readonly MenuItem customItem;
    private readonly MenuItem deleteCustomItem;

    public ContextMenu Menu { get; } = new();

    public CharacterMenuBuilder(
        IReadOnlyDictionary<CharacterId, CharacterAssets> catalog,
        Func<CharacterId> selectedCharacter,
        Action<CharacterId> selectBuiltIn,
        Action selectCustom,
        Action configureCustom,
        Action deleteCustom,
        Action increaseScale,
        Action decreaseScale,
        Action resetScale,
        Action exit)
    {
        this.catalog = catalog;
        this.selectedCharacter = selectedCharacter;

        foreach (var definition in CharacterDefinition.BundledCharacters)
        {
            var item = CreateCharacterItem(definition, selectBuiltIn);
            characterItems.Add(item);
            Menu.Items.Add(item);
        }

        Menu.Items.Add(new Separator());
        customItem = new MenuItem
        {
            Header = "自定义角色",
            IsCheckable = true,
            IsEnabled = false,
            Tag = CharacterId.Custom,
        };
        customItem.Click += (_, _) => selectCustom();
        characterItems.Add(customItem);
        Menu.Items.Add(customItem);
        Menu.Items.Add(CreateActionItem("设置自定义角色…", configureCustom));
        deleteCustomItem = CreateActionItem("删除自定义角色…", deleteCustom);
        deleteCustomItem.IsEnabled = false;
        Menu.Items.Add(deleteCustomItem);
        Menu.Items.Add(new Separator());
        Menu.Items.Add(CreateActionItem("放大角色", increaseScale));
        Menu.Items.Add(CreateActionItem("缩小角色", decreaseScale));
        Menu.Items.Add(CreateActionItem("恢复默认大小", resetScale));
        Menu.Items.Add(CreateActionItem("退出", exit));
        Menu.Opened += (_, _) => RefreshChecks();
    }

    public void SetCustomAvailable(
        bool available,
        ImageSource? thumbnail = null)
    {
        customItem.IsEnabled = available;
        deleteCustomItem.IsEnabled = available;
        customItem.Header = thumbnail is null
            ? "自定义角色"
            : CreateCharacterHeader("自定义角色", thumbnail);
        RefreshChecks();
    }

    public void RefreshChecks()
    {
        var selected = selectedCharacter();
        foreach (var item in characterItems)
        {
            item.IsChecked = item.Tag is CharacterId id && id == selected;
        }
    }

    private MenuItem CreateCharacterItem(
        CharacterDefinition definition,
        Action<CharacterId> selectBuiltIn)
    {
        var item = new MenuItem
        {
            Header = CreateCharacterHeader(
                definition.Name,
                catalog[definition.Id].Images[definition.IdleAssetName]),
            IsCheckable = true,
            Tag = definition.Id,
        };
        item.Click += (_, _) => selectBuiltIn(definition.Id);
        return item;
    }

    private static FrameworkElement CreateCharacterHeader(
        string name,
        ImageSource thumbnail)
    {
        var preview = new Image
        {
            Source = thumbnail,
            Width = ThumbnailSize,
            Height = ThumbnailSize,
            Stretch = Stretch.Uniform,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
        };
        var label = new TextBlock
        {
            Text = name,
            Margin = new Thickness(8, 0, 4, 0),
            VerticalAlignment = VerticalAlignment.Center,
        };
        var header = new StackPanel
        {
            Orientation = Orientation.Horizontal,
        };
        header.Children.Add(preview);
        header.Children.Add(label);
        return header;
    }

    private static MenuItem CreateActionItem(string header, Action action)
    {
        var item = new MenuItem { Header = header };
        item.Click += (_, _) => action();
        return item;
    }
}
