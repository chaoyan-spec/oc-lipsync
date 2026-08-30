namespace PAPAluLive.Core;

public sealed class WindowScale
{
    public const double Minimum = 0.5;
    public const double Maximum = 2.0;
    public const double DefaultFactor = 1.0;
    public const double Step = 0.1;

    public double Factor { get; private set; }

    public WindowScale(double factor = DefaultFactor)
    {
        Factor = Clamp(factor);
    }

    public void Increase() => Factor = Math.Min(Maximum, Round(Factor + Step));

    public void Decrease() => Factor = Math.Max(Minimum, Round(Factor - Step));

    public void Reset() => Factor = DefaultFactor;

    public void SetFactor(double value) => Factor = Clamp(value);

    private static double Round(double value) => Math.Round(value * 10) / 10;

    private static double Clamp(double value) => double.IsFinite(value)
        ? Math.Clamp(value, Minimum, Maximum)
        : DefaultFactor;
}
