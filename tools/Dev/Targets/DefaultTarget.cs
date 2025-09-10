namespace __PROJECT__.Dev.Targets;

internal sealed class DefaultTarget : ITarget
{
    public void Setup(Bullseye.Targets targets)
        => targets.Add(
            TargetKeys.Default,
            dependsOn: [TargetKeys.Build]);
}
