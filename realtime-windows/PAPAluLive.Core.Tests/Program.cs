using PAPAluLive.Core;

var failures = new List<string>();

void Check(string name, bool condition)
{
    if (condition)
    {
        Console.WriteLine($"PASS: {name}");
    }
    else
    {
        failures.Add(name);
        Console.Error.WriteLine($"FAIL: {name}");
    }
}

var gate = new MouthGate();
Check("quiet stays idle", gate.Update(0.001, 0.02) == MouthState.Idle);
Check("loud sample opens immediately", gate.Update(0.03, 0.02) == MouthState.Talking);

for (var index = 0; index < 20; index++)
{
    gate.Update(0.0, 0.02);
}
Check("short pause remains talking", gate.State == MouthState.Talking);

for (var index = 0; index < 20; index++)
{
    gate.Update(0.0, 0.02);
}
Check("release delay closes", gate.State == MouthState.Idle);

var floatSamples = new[] { 0.5f, -0.5f, 0.0f, 0.0f };
var floatBytes = new byte[floatSamples.Length * sizeof(float)];
Buffer.BlockCopy(floatSamples, 0, floatBytes, 0, floatBytes.Length);
Check(
    "float32 RMS",
    Math.Abs(PcmRmsCalculator.Calculate(floatBytes, PcmSampleFormat.Float32) -
        Math.Sqrt(0.125)) < 0.000001);

var pcm16Samples = new short[] { 16384, -16384, 0, 0 };
var pcm16Bytes = new byte[pcm16Samples.Length * sizeof(short)];
Buffer.BlockCopy(pcm16Samples, 0, pcm16Bytes, 0, pcm16Bytes.Length);
Check(
    "pcm16 RMS",
    Math.Abs(PcmRmsCalculator.Calculate(pcm16Bytes, PcmSampleFormat.Pcm16) -
        Math.Sqrt(0.125)) < 0.0001);
Check(
    "empty audio RMS",
    PcmRmsCalculator.Calculate([], PcmSampleFormat.Float32) == 0);

var catalog = CharacterDefinition.BundledCharacters;
Check(
    "character order",
    catalog.Select(item => item.Id).SequenceEqual(
        new[]
        {
            CharacterId.CatMeme,
            CharacterId.HuhCat,
            CharacterId.HappyCat,
            CharacterId.ScreamingCat,
            CharacterId.Papalu,
        }));

var runtime = new CharacterRuntime(CharacterDefinition.Papalu);
runtime.SetState(CharacterDisplayState.Talking);
Check("talking starts on frame 2", runtime.CurrentAssetName == "2");
runtime.AdvanceTalkingFrame();
Check("talking advances to frame 1", runtime.CurrentAssetName == "1");
runtime.SetCharacter(CharacterDefinition.HuhCat, CharacterDisplayState.Talking);
Check("character change uses current state", runtime.CurrentAssetName == "talking");

var sway = new IdleAnimationPlan().GetStep(
    IdleSwayDirection.Left,
    durationRandomUnit: 0.5,
    holdRandomUnit: 0.5);
Check("idle sway points left", sway.HorizontalOffset == -4 && sway.RotationDegrees == -1);
Check("idle sway maps duration", Math.Abs(sway.Duration - 1.05) < 0.0001);
Check("idle sway maps hold", Math.Abs(sway.HoldDuration - 0.165) < 0.0001);

var cloud = new ThoughtCloudPlan();
Check("cloud wraps dot index", cloud.NextDotIndex(2) == 0);
Check(
    "cloud highlights one dot",
    cloud.DotAlphas(1).SequenceEqual(new[] { 0.35, 1.0, 0.35 }));
var cloudFrame = cloud.Frame(200, 100);
Check(
    "cloud geometry scales",
    cloudFrame == new ThoughtCloudFrame(105, 72.5, 90, 27));

var scale = new WindowScale(9);
Check("scale clamps maximum", scale.Factor == 2.0);
scale.Decrease();
Check("scale decreases by one step", scale.Factor == 1.9);
scale.Reset();
Check("scale resets", scale.Factor == 1.0);

var normalizedSettings = new AppSettingsData(
    SelectedCharacterId: "not-a-character",
    Left: double.NaN,
    Top: double.PositiveInfinity,
    Scale: 9).Normalize();
Check(
    "settings fall back to the default character",
    normalizedSettings.SelectedCharacterId == CharacterId.CatMeme.ToString());
Check(
    "settings discard invalid placement",
    normalizedSettings.Left is null && normalizedSettings.Top is null);
Check("settings clamp scale", normalizedSettings.Scale == WindowScale.Maximum);

if (failures.Count > 0)
{
    Console.Error.WriteLine($"{failures.Count} core tests failed");
    return 1;
}

Console.WriteLine("PAPAluLive.Core tests passed");
return 0;
