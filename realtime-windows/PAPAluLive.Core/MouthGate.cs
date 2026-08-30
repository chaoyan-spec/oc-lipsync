namespace PAPAluLive.Core;

public enum MouthState
{
    Idle,
    Talking,
}

public sealed record MouthGateConfiguration(
    double OpenThreshold,
    double CloseThreshold,
    double SmoothingFactor,
    double ReleaseDelay)
{
    public static MouthGateConfiguration Default { get; } = new(
        OpenThreshold: 0.012,
        CloseThreshold: 0.010,
        SmoothingFactor: 0.35,
        ReleaseDelay: 0.60);

    public void Validate()
    {
        if (OpenThreshold <= CloseThreshold ||
            CloseThreshold < 0 ||
            SmoothingFactor is < 0 or > 1 ||
            ReleaseDelay < 0)
        {
            throw new ArgumentOutOfRangeException(
                nameof(MouthGateConfiguration));
        }
    }
}

public sealed class MouthGate
{
    private readonly MouthGateConfiguration configuration;
    private double smoothedRms;
    private bool hasSample;
    private double quietDuration;

    public MouthState State { get; private set; } = MouthState.Idle;

    public MouthGate(MouthGateConfiguration? configuration = null)
    {
        this.configuration = configuration ?? MouthGateConfiguration.Default;
        this.configuration.Validate();
    }

    public MouthState Update(double rms, double duration)
    {
        var sample = double.IsFinite(rms) ? Math.Max(0, rms) : 0;
        var elapsed = double.IsFinite(duration) ? Math.Max(0, duration) : 0;

        if (hasSample)
        {
            var alpha = configuration.SmoothingFactor;
            smoothedRms = alpha * sample + (1 - alpha) * smoothedRms;
        }
        else
        {
            smoothedRms = sample;
            hasSample = true;
        }

        switch (State)
        {
            case MouthState.Idle:
                if (sample >= configuration.OpenThreshold)
                {
                    State = MouthState.Talking;
                    quietDuration = 0;
                }
                break;
            case MouthState.Talking:
                if (smoothedRms < configuration.CloseThreshold)
                {
                    quietDuration += elapsed;
                    if (quietDuration >= configuration.ReleaseDelay)
                    {
                        State = MouthState.Idle;
                        quietDuration = 0;
                    }
                }
                else
                {
                    quietDuration = 0;
                }
                break;
            default:
                throw new InvalidOperationException("Unknown mouth state.");
        }

        return State;
    }
}
