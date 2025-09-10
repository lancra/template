namespace __PROJECT__.Dev.Targets;

internal sealed class LintTarget : ITarget
{
    public void Setup(Bullseye.Targets targets)
        => targets.Add(
            TargetKeys.Lint,
            "Flags stylistic and functional issues using static code analysis tools.",
            ExecuteAsync);

    private static async Task ExecuteAsync()
    {
        List<string> arguments =
        [
            "run",
            "--rm",
            $"--volume {Directory.GetCurrentDirectory()}:/tmp/lint:rw",
        ];

        if (DevEnvironmentVariable.LocalLint.IsTruthy)
        {
            arguments.Add("--env APPLY_FIXES=all");
        }

        if (!string.IsNullOrEmpty(DevEnvironmentVariable.Linters.ResultValue))
        {
            arguments.Add($"--env ENABLE_LINTERS={DevEnvironmentVariable.Linters.ResultValue}");
        }

        arguments.Add($"oxsecurity/megalinter-dotnet:{DevEnvironmentVariable.MegaLinterVersion.ResultValue}");

        await SimpleExec.Command.RunAsync(DevEnvironmentVariable.ContainerRuntime.ResultValue, string.Join(' ', arguments))
            .ConfigureAwait(false);

        if (Directory.Exists(ArtifactPaths.LintResults))
        {
            Directory.Delete(ArtifactPaths.LintResults, recursive: true);
        }

        Directory.Move("megalinter-reports", ArtifactPaths.LintResults);
    }
}
