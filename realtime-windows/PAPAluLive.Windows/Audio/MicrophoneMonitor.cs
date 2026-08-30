using NAudio.CoreAudioApi;
using NAudio.Wave;
using PAPAluLive.Core;

namespace PAPAluLive.Windows.Audio;

public sealed class MicrophoneMonitor : IDisposable
{
    private const int CaptureBufferMilliseconds = 20;

    private WasapiRecorder? recorder;
    private PcmSampleFormat sampleFormat;
    private int averageBytesPerSecond;

    public event Action<double, double>? SampleAvailable;

    public event Action<Exception>? Faulted;

    public bool IsRunning { get; private set; }

    public void Start()
    {
        if (IsRunning)
        {
            return;
        }

        try
        {
            recorder = new WasapiRecorderBuilder()
                .WithSharedMode()
                .WithEventSync()
                .WithBufferLength(CaptureBufferMilliseconds)
                .WithLowLatency(required: false)
                .Build();
            sampleFormat = ResolveSampleFormat(recorder.WaveFormat);
            averageBytesPerSecond = recorder.WaveFormat.AverageBytesPerSecond;
            recorder.DataAvailable += OnDataAvailable;
            recorder.RecordingStopped += OnRecordingStopped;
            recorder.StartRecording();
            IsRunning = true;
        }
        catch (Exception exception)
        {
            DisposeCapture();
            Faulted?.Invoke(exception);
        }
    }

    public void Stop()
    {
        if (!IsRunning)
        {
            DisposeCapture();
            return;
        }

        IsRunning = false;
        recorder?.StopRecording();
    }

    public void Dispose()
    {
        Stop();
        DisposeCapture();
        GC.SuppressFinalize(this);
    }

    private void OnDataAvailable(
        ReadOnlySpan<byte> buffer,
        AudioClientBufferFlags flags,
        long devicePosition,
        long qpcPosition)
    {
        if (!IsRunning || buffer.IsEmpty)
        {
            return;
        }

        var rms = flags.HasFlag(AudioClientBufferFlags.Silent)
            ? 0
            : PcmRmsCalculator.Calculate(buffer, sampleFormat);
        var duration = averageBytesPerSecond > 0
            ? buffer.Length / (double)averageBytesPerSecond
            : CaptureBufferMilliseconds / 1000.0;
        SampleAvailable?.Invoke(rms, duration);
    }

    private void OnRecordingStopped(object? sender, StoppedEventArgs eventArgs)
    {
        IsRunning = false;
        DisposeCapture();
        if (eventArgs.Exception is not null)
        {
            Faulted?.Invoke(eventArgs.Exception);
        }
    }

    private static PcmSampleFormat ResolveSampleFormat(WaveFormat format)
    {
        var encoding = format.Encoding;
        if (format is WaveFormatExtensible extensible)
        {
            encoding = extensible.SubFormat == AudioMediaSubtypes.MEDIASUBTYPE_IEEE_FLOAT
                ? WaveFormatEncoding.IeeeFloat
                : extensible.SubFormat == AudioMediaSubtypes.MEDIASUBTYPE_PCM
                    ? WaveFormatEncoding.Pcm
                    : encoding;
        }

        if (encoding == WaveFormatEncoding.IeeeFloat && format.BitsPerSample == 32)
        {
            return PcmSampleFormat.Float32;
        }

        if (encoding != WaveFormatEncoding.Pcm)
        {
            throw new NotSupportedException($"Unsupported microphone format: {format}");
        }

        return format.BitsPerSample switch
        {
            16 => PcmSampleFormat.Pcm16,
            24 => PcmSampleFormat.Pcm24,
            32 => PcmSampleFormat.Pcm32,
            _ => throw new NotSupportedException($"Unsupported microphone format: {format}"),
        };
    }

    private void DisposeCapture()
    {
        if (recorder is not null)
        {
            recorder.DataAvailable -= OnDataAvailable;
            recorder.RecordingStopped -= OnRecordingStopped;
            recorder.Dispose();
            recorder = null;
        }
    }
}
