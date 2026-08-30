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

if (failures.Count > 0)
{
    Console.Error.WriteLine($"{failures.Count} core tests failed");
    return 1;
}

Console.WriteLine("PAPAluLive.Core tests passed");
return 0;
