namespace __PROJECT__.Dev.Targets.Build;

internal sealed class DotnetTarget : ITarget
{
    public void Setup(Bullseye.Targets targets)
        => targets.Add(
            TargetKeys.Dotnet,
            "Builds the solution into output binaries.",
            dependsOn: [TargetKeys.Clean],
            ExecuteAsync);

    private static async Task ExecuteAsync()
    {
        var arguments = new List<string>();
        if (!DevEnvironmentVariable.LocalBuild.IsTruthy)
        {
            arguments.Add("/warnaserror");
        }

        await DotnetCli.RunAsync($"build {ArtifactPaths.Solution}", [.. arguments])
                .ConfigureAwait(false);
    }
}
