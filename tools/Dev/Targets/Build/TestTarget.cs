namespace __PROJECT__.Dev.Targets.Build;

internal sealed class TestTarget : ITarget
{
    private static readonly TestSuite[] Suites =
    [
        new(
            TargetKeys.TestIntegration,
            "Tests integrations between components of the application.",
            [
                new("integration", "tests/IntegrationTests"),
            ]),
        new(
            TargetKeys.TestUnit,
            "Tests individual components of the application",
            [
                new("domain", "tests/Domain.Facts"),
            ]),
    ];

    public void Setup(Bullseye.Targets targets)
    {
        foreach (var suite in Suites)
        {
            targets.Add(
                suite.Name,
                suite.Description,
                dependsOn: [TargetKeys.Dotnet],
                forEach: suite.Projects,
                ExecuteAsync);
        }

        targets.Add(
            TargetKeys.Test,
            "Executes automated test suites.",
            dependsOn: Suites.Select(suite => suite.Name)
                .ToArray());
    }

    private static async Task ExecuteAsync(TestProject project)
    {
        var testResultsPath = string.Format(null, ArtifactPaths.TestResultFormat, project.Name);
        await DotnetCli
            .RunAsync(
                "test",
                $"--project {project.Path}",
                "--no-build",
                $"--results-directory {testResultsPath}",
                "--config-file tests/testconfig.json",
                "--coverage",
                "--coverage-output-format xml",
                "--coverage-settings tests/code-coverage.xml")
            .ConfigureAwait(false);
    }
}
