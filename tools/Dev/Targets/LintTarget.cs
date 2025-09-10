namespace __PROJECT__.Dev.Targets;

internal sealed class LintTarget : ITarget
{
    public void Setup(Bullseye.Targets targets)
        => targets.Add(
            TargetKeys.Lint,
            "Flags stylistic and functional issues using static code analysis tools.",
            Execute);

    private static async Task Execute()
    {
        List<string> arguments =
        [
            "run",
            "--rm",
            $"--volume {Directory.GetCurrentDirectory()}:/tmp/lint:rw",
        ];

        if (EnvironmentVariables.LocalLint.IsTruthy)
        {
            arguments.Add("--env APPLY_FIXES=all");
        }

        arguments.Add("oxsecurity/megalinter-dotnet:v8");

        await SimpleExec.Command.RunAsync(EnvironmentVariables.ContainerRuntime.Value, string.Join(' ', arguments))
            .ConfigureAwait(false);

        if (Directory.Exists(ArtifactPaths.LintResults))
        {
            Directory.Delete(ArtifactPaths.LintResults, recursive: true);
        }

        Directory.Move("megalinter-reports", ArtifactPaths.LintResults);
    }
}
