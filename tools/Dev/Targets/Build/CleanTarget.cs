namespace __PROJECT__.Dev.Targets.Build;

internal sealed class CleanTarget : ITarget
{
    public void Setup(Bullseye.Targets targets)
        => targets.Add(
            TargetKeys.Clean,
            "Cleans .NET build artifacts from prior executions.",
            dependsOn: [TargetKeys.Solution],
            Execute);

    private static async Task Execute()
        => await DotnetCli.Run($"clean {ArtifactPaths.Solution}")
        .ConfigureAwait(false);
}
