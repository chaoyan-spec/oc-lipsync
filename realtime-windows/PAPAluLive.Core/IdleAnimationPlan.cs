namespace PAPAluLive.Core;

public enum IdleSwayDirection
{
    Left,
    Right,
}

public sealed record IdleSwayStep(
    double HorizontalOffset,
    double RotationDegrees,
    double Duration,
    double HoldDuration);

public sealed class IdleAnimationPlan
{
    private readonly IdleMotionConfiguration configuration;

    public IdleAnimationPlan(IdleMotionConfiguration? configuration = null)
    {
        this.configuration = configuration ?? IdleMotionConfiguration.Gentle;
    }

    public IdleSwayStep GetStep(
        IdleSwayDirection direction,
        double durationRandomUnit,
        double holdRandomUnit)
    {
        var sign = direction == IdleSwayDirection.Left ? -1.0 : 1.0;
        return new IdleSwayStep(
            HorizontalOffset: sign * configuration.HorizontalOffset,
            RotationDegrees: sign * configuration.RotationDegrees,
            Duration: Map(
                durationRandomUnit,
                configuration.MinimumDuration,
                configuration.MaximumDuration),
            HoldDuration: Map(
                holdRandomUnit,
                configuration.MinimumHold,
                configuration.MaximumHold));
    }

    private static double Map(double randomUnit, double minimum, double maximum)
    {
        var finite = double.IsFinite(randomUnit) ? randomUnit : 0;
        var clamped = Math.Clamp(finite, 0, 1);
        return minimum + (maximum - minimum) * clamped;
    }
}
