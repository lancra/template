namespace __PROJECT__.Dev.Targets.Build;

internal sealed class BuildTarget : ITarget
{
    private static readonly string[] Dependencies =
    [
        TargetKeys.Dotnet,
    ];

    public void Setup(Bullseye.Targets targets)
        => targets.Add(
            TargetKeys.Build,
            "Executes the complete build process.",
            dependsOn: Dependencies);
}
