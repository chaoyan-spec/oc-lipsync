using PAPAluLive.Core;

namespace PAPAluLive.Windows.Characters;

public static class CharacterCatalog
{
    public static IReadOnlyDictionary<CharacterId, CharacterAssets> LoadBundled() =>
        CharacterDefinition.BundledCharacters.ToDictionary(
            definition => definition.Id,
            CharacterAssets.LoadBundled);
}
