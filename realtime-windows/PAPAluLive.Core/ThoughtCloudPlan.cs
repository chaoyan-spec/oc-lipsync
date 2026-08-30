namespace PAPAluLive.Core;

public sealed record ThoughtCloudFrame(
    double X,
    double Y,
    double Width,
    double Height);

public sealed class ThoughtCloudPlan
{
    public const double AppearanceDelay = 0.5;
    public const double FadeDuration = 0.18;
    public const double DotStepInterval = 0.3;
    public const double InactiveDotAlpha = 0.35;
    public const double ActiveDotAlpha = 1.0;

    private static readonly ThoughtCloudFrame NormalizedFrame = new(
        X: 0.525,
        Y: 0.725,
        Width: 0.45,
        Height: 0.27);

    public int NextDotIndex(int currentIndex) => (Math.Max(0, currentIndex) + 1) % 3;

    public IReadOnlyList<double> DotAlphas(int activeIndex) => Enumerable
        .Range(0, 3)
        .Select(index => index == activeIndex ? ActiveDotAlpha : InactiveDotAlpha)
        .ToArray();

    public ThoughtCloudFrame Frame(double windowWidth, double windowHeight) => new(
        X: NormalizedFrame.X * windowWidth,
        Y: NormalizedFrame.Y * windowHeight,
        Width: NormalizedFrame.Width * windowWidth,
        Height: NormalizedFrame.Height * windowHeight);
}
