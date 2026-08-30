using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using PAPAluLive.Core;

namespace PAPAluLive.Windows.Presentation;

public sealed class ThoughtCloudControl : FrameworkElement
{
    private static readonly Brush CloudBrush = Brushes.White;
    private static readonly Brush OutlineBrush = new SolidColorBrush(
        Color.FromRgb(73, 61, 119));

    private readonly ThoughtCloudPlan plan = new();
    private readonly DispatcherTimer dotTimer;
    private int activeDot;
    private int visibilityGeneration;

    public ThoughtCloudControl()
    {
        IsHitTestVisible = false;
        Opacity = 0;
        Visibility = Visibility.Collapsed;
        dotTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromSeconds(ThoughtCloudPlan.DotStepInterval),
        };
        dotTimer.Tick += (_, _) =>
        {
            activeDot = plan.NextDotIndex(activeDot);
            InvalidateVisual();
        };
    }

    public void ShowAnimated()
    {
        visibilityGeneration++;
        Visibility = Visibility.Visible;
        activeDot = 0;
        InvalidateVisual();
        BeginAnimation(
            OpacityProperty,
            new DoubleAnimation(
                0,
                1,
                TimeSpan.FromSeconds(ThoughtCloudPlan.FadeDuration)));
        dotTimer.Start();
    }

    public void HideAnimated()
    {
        var generation = ++visibilityGeneration;
        dotTimer.Stop();
        var animation = new DoubleAnimation(
            Opacity,
            0,
            TimeSpan.FromSeconds(ThoughtCloudPlan.FadeDuration));
        animation.Completed += (_, _) =>
        {
            if (generation == visibilityGeneration)
            {
                Visibility = Visibility.Collapsed;
            }
        };
        BeginAnimation(OpacityProperty, animation);
    }

    protected override void OnRender(DrawingContext drawingContext)
    {
        base.OnRender(drawingContext);
        if (ActualWidth <= 0 || ActualHeight <= 0)
        {
            return;
        }

        var width = ActualWidth;
        var height = ActualHeight;
        var pen = new Pen(OutlineBrush, Math.Max(2, width * 0.025));
        pen.Freeze();

        var geometry = new StreamGeometry();
        using (var context = geometry.Open())
        {
            context.BeginFigure(new Point(width * 0.18, height * 0.69), true, true);
            context.BezierTo(
                new Point(width * 0.04, height * 0.55),
                new Point(width * 0.12, height * 0.31),
                new Point(width * 0.30, height * 0.32),
                true,
                false);
            context.BezierTo(
                new Point(width * 0.32, height * 0.10),
                new Point(width * 0.56, height * 0.03),
                new Point(width * 0.67, height * 0.22),
                true,
                false);
            context.BezierTo(
                new Point(width * 0.88, height * 0.15),
                new Point(width * 1.00, height * 0.37),
                new Point(width * 0.88, height * 0.54),
                true,
                false);
            context.BezierTo(
                new Point(width * 0.96, height * 0.77),
                new Point(width * 0.69, height * 0.88),
                new Point(width * 0.56, height * 0.75),
                true,
                false);
            context.BezierTo(
                new Point(width * 0.43, height * 0.91),
                new Point(width * 0.23, height * 0.88),
                new Point(width * 0.18, height * 0.69),
                true,
                false);
        }
        geometry.Freeze();
        drawingContext.DrawGeometry(CloudBrush, pen, geometry);

        drawingContext.DrawEllipse(
            CloudBrush,
            pen,
            new Point(width * 0.17, height * 0.84),
            width * 0.075,
            width * 0.075);
        drawingContext.DrawEllipse(
            CloudBrush,
            pen,
            new Point(width * 0.06, height * 0.96),
            width * 0.045,
            width * 0.045);

        var alphas = plan.DotAlphas(activeDot);
        for (var index = 0; index < 3; index++)
        {
            var dotBrush = OutlineBrush.Clone();
            dotBrush.Opacity = alphas[index];
            dotBrush.Freeze();
            drawingContext.DrawEllipse(
                dotBrush,
                null,
                new Point(width * (0.39 + index * 0.13), height * 0.52),
                width * 0.045,
                width * 0.045);
        }
    }
}
