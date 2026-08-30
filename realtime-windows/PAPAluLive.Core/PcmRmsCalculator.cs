using System.Buffers.Binary;

namespace PAPAluLive.Core;

public enum PcmSampleFormat
{
    Float32,
    Pcm16,
    Pcm24,
    Pcm32,
}

public static class PcmRmsCalculator
{
    public static double Calculate(
        ReadOnlySpan<byte> bytes,
        PcmSampleFormat format)
    {
        var bytesPerSample = format switch
        {
            PcmSampleFormat.Pcm16 => 2,
            PcmSampleFormat.Pcm24 => 3,
            PcmSampleFormat.Float32 or PcmSampleFormat.Pcm32 => 4,
            _ => throw new ArgumentOutOfRangeException(nameof(format)),
        };

        var sampleCount = bytes.Length / bytesPerSample;
        if (sampleCount == 0)
        {
            return 0;
        }

        double squareSum = 0;
        for (var index = 0; index < sampleCount; index++)
        {
            var sampleBytes = bytes.Slice(index * bytesPerSample, bytesPerSample);
            var sample = ReadSample(sampleBytes, format);
            squareSum += sample * sample;
        }

        return Math.Sqrt(squareSum / sampleCount);
    }

    private static double ReadSample(
        ReadOnlySpan<byte> bytes,
        PcmSampleFormat format)
    {
        return format switch
        {
            PcmSampleFormat.Float32 =>
                BitConverter.Int32BitsToSingle(
                    BinaryPrimitives.ReadInt32LittleEndian(bytes)),
            PcmSampleFormat.Pcm16 =>
                BinaryPrimitives.ReadInt16LittleEndian(bytes) / 32768.0,
            PcmSampleFormat.Pcm24 => ReadPcm24(bytes) / 8388608.0,
            PcmSampleFormat.Pcm32 =>
                BinaryPrimitives.ReadInt32LittleEndian(bytes) / 2147483648.0,
            _ => throw new ArgumentOutOfRangeException(nameof(format)),
        };
    }

    private static int ReadPcm24(ReadOnlySpan<byte> bytes)
    {
        var value = bytes[0] | bytes[1] << 8 | bytes[2] << 16;
        return (value & 0x00800000) == 0 ? value : value | unchecked((int)0xff000000);
    }
}
