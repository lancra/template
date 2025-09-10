namespace __PROJECT__.Dev.Targets.Build;

internal sealed class PublishTarget : ITarget
{
    private static readonly PublishProject[] Projects =
    [
    ];

    public void Setup(Bullseye.Targets targets)
        => targets.Add(
            TargetKeys.Publish,
            "Publishes projects as executables for release.",
            dependsOn: [TargetKeys.Dotnet],
            forEach: Projects,
            ExecuteAsync);

    private static async Task ExecuteAsync(PublishProject project)
    {
        foreach (var runtime in project.Runtimes)
        {
            var executablePath = string.Format(null, ArtifactPaths.ExecutableFormat, project.Name, runtime);
            await DotnetCli
                .RunAsync(
                    $"publish {project.Path}",
                    $"--runtime {runtime}",
                    $"--output {executablePath}")
                .ConfigureAwait(false);
        }
    }
}
