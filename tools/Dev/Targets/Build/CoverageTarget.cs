using System.Text;
using static SimpleExec.Command;

namespace __PROJECT__.Dev.Targets.Build;

internal sealed class CoverageTarget : ITarget
{
    private static readonly CompositeFormat AssemblyPatternFormat = CompositeFormat.Parse("{0}__PROJECT__.**{1}");

    public void Setup(Bullseye.Targets targets)
        => targets.Add(
            TargetKeys.Coverage,
            "Generates a code coverage report from test results.",
            dependsOn: [TargetKeys.Test],
            ExecuteAsync);

    private static async Task ExecuteAsync()
    {
        string[] assemblyFilterPatterns =
        [
            string.Format(null, AssemblyPatternFormat, "+", string.Empty),
            string.Format(null, AssemblyPatternFormat, "-", "Dev"),
            string.Format(null, AssemblyPatternFormat, "-", "Facts"),
            string.Format(null, AssemblyPatternFormat, "-", "Testbed"),
            string.Format(null, AssemblyPatternFormat, "-", "Tests"),
        ];
        var assemblyFilters = string.Join(',', assemblyFilterPatterns);

        var commitId = await GitCli.GetCommitIdAsync()
            .ConfigureAwait(false);

        string[] arguments =
        [
            "reportgenerator",
            $"-assemblyFilters:{assemblyFilters}",
            $"-reports:{ArtifactPaths.TestCoverageResults}",
            $"-targetdir:{ArtifactPaths.TestCoverageReports}",
            $"-tag:{commitId}",
            "-reporttypes:Html",
            "-title:\"__TITLE__\"",
        ];

        await RunAsync("dotnet", string.Join(' ', arguments))
            .ConfigureAwait(false);
    }
}
