namespace __PROJECT__.Dev.Targets.Build;

internal sealed class CleanTarget : ITarget
{
    public void Setup(Bullseye.Targets targets)
        => targets.Add(
            TargetKeys.Clean,
            "Cleans .NET build artifacts from prior executions.",
            dependsOn: [TargetKeys.Solution],
            ExecuteAsync);

    private static async Task ExecuteAsync()
    {
        await DotnetCli.RunAsync($"clean {ArtifactPaths.Solution}")
            .ConfigureAwait(false);

        if (Directory.Exists(ArtifactPaths.TestResults))
        {
            Directory.Delete(ArtifactPaths.TestResults, recursive: true);
        }
    }
}
