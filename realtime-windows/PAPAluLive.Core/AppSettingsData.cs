namespace PAPAluLive.Core;

public sealed record AppSettingsData(
    string SelectedCharacterId,
    double? Left,
    double? Top,
    double Scale)
{
    public static AppSettingsData Default { get; } = new(
        CharacterId.CatMeme.ToString(),
        Left: null,
        Top: null,
        Scale: WindowScale.DefaultFactor);

    public AppSettingsData Normalize()
    {
        var selectedCharacter = Enum.TryParse<CharacterId>(
            SelectedCharacterId,
            ignoreCase: false,
            out var parsedCharacter)
            ? parsedCharacter
            : CharacterId.CatMeme;

        return this with
        {
            SelectedCharacterId = selectedCharacter.ToString(),
            Left = IsFinite(Left) ? Left : null,
            Top = IsFinite(Top) ? Top : null,
            Scale = new WindowScale(Scale).Factor,
        };
    }

    private static bool IsFinite(double? value) =>
        value is not null && double.IsFinite(value.Value);
}
