using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Animation;
using PAPAluLive.Core;

namespace PAPAluLive.Windows.Presentation;

public sealed class CharacterAnimator : IDisposable
{
    private readonly CharacterRuntime runtime;
    private readonly FrameworkElement characterVisual;
    private readonly ThoughtCloudControl thoughtCloud;
    private readonly Action<string> showFrame;
    private readonly TranslateTransform translation = new();
    private readonly RotateTransform rotation = new();
    private readonly Random random = new();
    private CancellationTokenSource? animationCancellation;
    private bool started;

    public CharacterDisplayState State => runtime.State;

    public CharacterAnimator(
        CharacterRuntime runtime,
        FrameworkElement characterVisual,
        ThoughtCloudControl thoughtCloud,
        Action<string> showFrame)
    {
        this.runtime = runtime;
        this.characterVisual = characterVisual;
        this.thoughtCloud = thoughtCloud;
        this.showFrame = showFrame;

        characterVisual.RenderTransformOrigin = new Point(0.5, 0.92);
        characterVisual.RenderTransform = new TransformGroup
        {
            Children = new TransformCollection { rotation, translation },
        };
    }

    public void Start()
    {
        if (started)
        {
            return;
        }

        started = true;
        Restart(includeSettle: false);
    }

    public void SetState(CharacterDisplayState state)
    {
        if (started && runtime.State == state)
        {
            return;
        }

        var includeSettle = runtime.State == CharacterDisplayState.Talking &&
            state == CharacterDisplayState.Idle;
        runtime.SetState(state);
        if (started)
        {
            Restart(includeSettle);
        }
    }

    public void SetCharacter(
        CharacterDefinition definition,
        CharacterDisplayState currentState)
    {
        runtime.SetCharacter(definition, currentState);
        if (started)
        {
            Restart(includeSettle: false);
        }
    }

    public void Dispose()
    {
        CancelCurrentAnimation();
        GC.SuppressFinalize(this);
    }

    private void Restart(bool includeSettle)
    {
        CancelCurrentAnimation();
        animationCancellation = new CancellationTokenSource();
        var token = animationCancellation.Token;

        if (runtime.State == CharacterDisplayState.Talking)
        {
            showFrame(runtime.CurrentAssetName);
            _ = RunSafelyAsync(() => RunTalkingAsync(token), token);
        }
        else
        {
            _ = RunSafelyAsync(() => RunIdleAsync(includeSettle, token), token);
        }
    }

    private async Task RunTalkingAsync(CancellationToken token)
    {
        var interval = TimeSpan.FromSeconds(
            1 / runtime.Definition.TalkingFramesPerSecond);
        while (true)
        {
            await Task.Delay(interval, token);
            runtime.AdvanceTalkingFrame();
            showFrame(runtime.CurrentAssetName);
        }
    }

    private async Task RunIdleAsync(
        bool includeSettle,
        CancellationToken token)
    {
        if (includeSettle)
        {
            foreach (var step in runtime.Definition.SettleSteps)
            {
                token.ThrowIfCancellationRequested();
                showFrame(step.AssetName);
                await Task.Delay(TimeSpan.FromSeconds(step.Duration), token);
            }
        }

        showFrame(runtime.Definition.IdleAssetName);
        _ = RunSafelyAsync(() => RunIdleSwayAsync(token), token);
        _ = RunSafelyAsync(() => RunBlinkAsync(token), token);
        await Task.Delay(
            TimeSpan.FromSeconds(ThoughtCloudPlan.AppearanceDelay),
            token);
        if (runtime.Definition.ThoughtCloudEnabled)
        {
            thoughtCloud.ShowAnimated();
        }
    }

    private async Task RunIdleSwayAsync(CancellationToken token)
    {
        var plan = new IdleAnimationPlan(runtime.Definition.IdleMotion);
        var direction = IdleSwayDirection.Left;
        while (true)
        {
            token.ThrowIfCancellationRequested();
            var step = plan.GetStep(
                direction,
                random.NextDouble(),
                random.NextDouble());
            AnimateTransform(step);
            await Task.Delay(
                TimeSpan.FromSeconds(step.Duration + step.HoldDuration),
                token);
            direction = direction == IdleSwayDirection.Left
                ? IdleSwayDirection.Right
                : IdleSwayDirection.Left;
        }
    }

    private async Task RunBlinkAsync(CancellationToken token)
    {
        var definition = runtime.Definition;
        if (definition.BlinkSteps.Count == 0 ||
            definition.MinimumBlinkDelay is null ||
            definition.MaximumBlinkDelay is null)
        {
            return;
        }

        while (true)
        {
            var delay = definition.MinimumBlinkDelay.Value +
                (definition.MaximumBlinkDelay.Value -
                    definition.MinimumBlinkDelay.Value) * random.NextDouble();
            await Task.Delay(TimeSpan.FromSeconds(delay), token);

            foreach (var step in definition.BlinkSteps)
            {
                token.ThrowIfCancellationRequested();
                showFrame(step.AssetName);
                await Task.Delay(TimeSpan.FromSeconds(step.Duration), token);
            }

            showFrame(definition.IdleAssetName);
        }
    }

    private void AnimateTransform(IdleSwayStep step)
    {
        var duration = TimeSpan.FromSeconds(step.Duration);
        translation.BeginAnimation(
            TranslateTransform.XProperty,
            new DoubleAnimation(step.HorizontalOffset, duration)
            {
                EasingFunction = new SineEase
                {
                    EasingMode = EasingMode.EaseInOut,
                },
            });
        rotation.BeginAnimation(
            RotateTransform.AngleProperty,
            new DoubleAnimation(step.RotationDegrees, duration)
            {
                EasingFunction = new SineEase
                {
                    EasingMode = EasingMode.EaseInOut,
                },
            });
    }

    private async Task RunSafelyAsync(
        Func<Task> animation,
        CancellationToken token)
    {
        try
        {
            await animation();
        }
        catch (OperationCanceledException) when (token.IsCancellationRequested)
        {
        }
    }

    private void CancelCurrentAnimation()
    {
        animationCancellation?.Cancel();
        animationCancellation?.Dispose();
        animationCancellation = null;
        thoughtCloud.HideAnimated();
        translation.BeginAnimation(TranslateTransform.XProperty, null);
        rotation.BeginAnimation(RotateTransform.AngleProperty, null);
        translation.X = 0;
        rotation.Angle = 0;
    }
}
