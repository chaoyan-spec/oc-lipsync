using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;

namespace PAPAluLive.Windows.Presentation;

public static class WindowPlacement
{
    private const uint MonitorDefaultToNearest = 2;

    public static void Restore(
        Window window,
        double? savedLeft,
        double? savedTop,
        double defaultMargin)
    {
        ArgumentNullException.ThrowIfNull(window);

        if (savedLeft is not null && savedTop is not null)
        {
            window.Left = savedLeft.Value;
            window.Top = savedTop.Value;
        }
        else
        {
            var primaryWorkArea = SystemParameters.WorkArea;
            window.Left = primaryWorkArea.Right - window.Width - defaultMargin;
            window.Top = primaryWorkArea.Bottom - window.Height - defaultMargin;
        }

        var workArea = NearestWorkArea(window);
        var maximumLeft = Math.Max(workArea.Left, workArea.Right - window.Width);
        var maximumTop = Math.Max(workArea.Top, workArea.Bottom - window.Height);
        window.Left = Math.Clamp(window.Left, workArea.Left, maximumLeft);
        window.Top = Math.Clamp(window.Top, workArea.Top, maximumTop);
    }

    private static Rect NearestWorkArea(Window window)
    {
        var handle = new WindowInteropHelper(window).Handle;
        var monitor = MonitorFromWindow(handle, MonitorDefaultToNearest);
        var info = new MonitorInfo
        {
            Size = Marshal.SizeOf<MonitorInfo>(),
        };
        if (monitor == IntPtr.Zero || !GetMonitorInfo(monitor, ref info))
        {
            return SystemParameters.WorkArea;
        }

        var transform = PresentationSource.FromVisual(window)?
            .CompositionTarget?.TransformFromDevice ?? Matrix.Identity;
        var topLeft = transform.Transform(new Point(
            info.WorkArea.Left,
            info.WorkArea.Top));
        var bottomRight = transform.Transform(new Point(
            info.WorkArea.Right,
            info.WorkArea.Bottom));
        return new Rect(topLeft, bottomRight);
    }

    [DllImport("user32.dll")]
    private static extern IntPtr MonitorFromWindow(
        IntPtr windowHandle,
        uint flags);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetMonitorInfo(
        IntPtr monitorHandle,
        ref MonitorInfo monitorInfo);

    [StructLayout(LayoutKind.Sequential)]
    private struct MonitorInfo
    {
        public int Size;
        public NativeRect MonitorArea;
        public NativeRect WorkArea;
        public uint Flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct NativeRect
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
}
