namespace PAPAluLive.Core;

public enum CharacterId
{
    CatMeme,
    HuhCat,
    HappyCat,
    ScreamingCat,
    Papalu,
    Custom,
}

public enum CharacterDisplayState
{
    Idle,
    Talking,
}

public sealed record FrameStep(string AssetName, double Duration);

public sealed record CharacterSize(double Width, double Height);

public sealed record IdleMotionConfiguration(
    double HorizontalOffset,
    double RotationDegrees,
    double MinimumDuration,
    double MaximumDuration,
    double MinimumHold,
    double MaximumHold)
{
    public static IdleMotionConfiguration Gentle { get; } = new(
        HorizontalOffset: 4,
        RotationDegrees: 1,
        MinimumDuration: 0.95,
        MaximumDuration: 1.15,
        MinimumHold: 0.08,
        MaximumHold: 0.25);
}

public sealed record CharacterDefinition(
    CharacterId Id,
    string Name,
    string ResourceDirectoryName,
    string IdleAssetName,
    IReadOnlyList<string> TalkingAssetNames,
    double TalkingFramesPerSecond,
    IReadOnlyList<FrameStep> BlinkSteps,
    IReadOnlyList<FrameStep> SettleSteps,
    double? MinimumBlinkDelay,
    double? MaximumBlinkDelay,
    IdleMotionConfiguration IdleMotion,
    bool ThoughtCloudEnabled,
    CharacterSize DefaultSize)
{
    public static CharacterDefinition CatMeme { get; } = TwoFrameBuiltIn(
        CharacterId.CatMeme,
        "猫 Meme",
        "CatMeme");

    public static CharacterDefinition HuhCat { get; } = TwoFrameBuiltIn(
        CharacterId.HuhCat,
        "Huh 猫",
        "HuhCat");

    public static CharacterDefinition HappyCat { get; } = TwoFrameBuiltIn(
        CharacterId.HappyCat,
        "Happy 猫",
        "HappyCat");

    public static CharacterDefinition ScreamingCat { get; } = TwoFrameBuiltIn(
        CharacterId.ScreamingCat,
        "抱头尖叫猫",
        "ScreamingCat");

    public static CharacterDefinition Papalu { get; } = new(
        Id: CharacterId.Papalu,
        Name: "PAPAlu",
        ResourceDirectoryName: "PAPAlu",
        IdleAssetName: "0",
        TalkingAssetNames: ["2", "1", "3", "4", "6", "3"],
        TalkingFramesPerSecond: 8,
        BlinkSteps:
        [
            new FrameStep("5", 0.11),
            new FrameStep("7", 0.10),
            new FrameStep("0", 0.12),
        ],
        SettleSteps:
        [
            new FrameStep("3", 0.08),
            new FrameStep("1", 0.08),
            new FrameStep("7", 0.08),
            new FrameStep("0", 0.08),
        ],
        MinimumBlinkDelay: 3,
        MaximumBlinkDelay: 5,
        IdleMotion: IdleMotionConfiguration.Gentle,
        ThoughtCloudEnabled: true,
        DefaultSize: new CharacterSize(288, 312));

    public static IReadOnlyList<CharacterDefinition> BundledCharacters { get; } =
    [
        CatMeme,
        HuhCat,
        HappyCat,
        ScreamingCat,
        Papalu,
    ];

    public static CharacterDefinition Custom(string name = "自定义角色") => new(
        Id: CharacterId.Custom,
        Name: name,
        ResourceDirectoryName: "CustomCharacter",
        IdleAssetName: "idle",
        TalkingAssetNames: ["talking"],
        TalkingFramesPerSecond: 1,
        BlinkSteps: [],
        SettleSteps: [],
        MinimumBlinkDelay: null,
        MaximumBlinkDelay: null,
        IdleMotion: IdleMotionConfiguration.Gentle,
        ThoughtCloudEnabled: false,
        DefaultSize: new CharacterSize(288, 312));

    public IReadOnlySet<string> RequiredAssetNames => new HashSet<string>(
        new[] { IdleAssetName }
            .Concat(TalkingAssetNames)
            .Concat(BlinkSteps.Select(step => step.AssetName))
            .Concat(SettleSteps.Select(step => step.AssetName)));

    private static CharacterDefinition TwoFrameBuiltIn(
        CharacterId id,
        string name,
        string resourceDirectoryName) => new(
            Id: id,
            Name: name,
            ResourceDirectoryName: resourceDirectoryName,
            IdleAssetName: "idle",
            TalkingAssetNames:
            [
                "talking",
                "idle",
                "talking",
                "idle",
                "talking",
                "talking",
            ],
            TalkingFramesPerSecond: 8,
            BlinkSteps: [],
            SettleSteps:
            [
                new FrameStep("talking", 0.08),
                new FrameStep("idle", 0.08),
            ],
            MinimumBlinkDelay: null,
            MaximumBlinkDelay: null,
            IdleMotion: IdleMotionConfiguration.Gentle,
            ThoughtCloudEnabled: true,
            DefaultSize: new CharacterSize(288, 312));
}
