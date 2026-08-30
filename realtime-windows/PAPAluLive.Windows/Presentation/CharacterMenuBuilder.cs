using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using PAPAluLive.Core;
using PAPAluLive.Windows.Characters;

namespace PAPAluLive.Windows.Presentation;

public sealed class CharacterMenuBuilder
{
    private readonly IReadOnlyDictionary<CharacterId, CharacterAssets> catalog;
    private readonly Func<CharacterId> selectedCharacter;
    private readonly List<MenuItem> characterItems = [];
    private readonly MenuItem customItem;

    public ContextMenu Menu { get; } = new();

    public CharacterMenuBuilder(
        IReadOnlyDictionary<CharacterId, CharacterAssets> catalog,
        Func<CharacterId> selectedCharacter,
        Action<CharacterId> selectBuiltIn,
        Action selectCustom,
        Action configureCustom,
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
        Menu.Items.Add(new Separator());
        Menu.Items.Add(CreateActionItem("放大角色", increaseScale));
        Menu.Items.Add(CreateActionItem("缩小角色", decreaseScale));
        Menu.Items.Add(CreateActionItem("恢复默认大小", resetScale));
        Menu.Items.Add(CreateActionItem("退出", exit));
        Menu.Opened += (_, _) => RefreshChecks();
    }

    public void SetCustomAvailable(bool available)
    {
        customItem.IsEnabled = available;
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
        var thumbnail = new Image
        {
            Source = catalog[definition.Id].Images[definition.IdleAssetName],
            Width = 28,
            Height = 28,
            Stretch = Stretch.Uniform,
        };
        var item = new MenuItem
        {
            Header = definition.Name,
            Icon = thumbnail,
            IsCheckable = true,
            Tag = definition.Id,
        };
        item.Click += (_, _) => selectBuiltIn(definition.Id);
        return item;
    }

    private static MenuItem CreateActionItem(string header, Action action)
    {
        var item = new MenuItem { Header = header };
        item.Click += (_, _) => action();
        return item;
    }
}
