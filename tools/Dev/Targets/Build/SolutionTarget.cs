using System.Reflection;
using System.Text.Json;

namespace __PROJECT__.Dev.Targets.Build;

internal sealed class SolutionTarget : ITarget
{
    private const string SolutionName = "__PROJECT__";

    public void Setup(Bullseye.Targets targets)
        => targets.Add(
            TargetKeys.Solution,
            "Generates the solution filter used for the build process.",
            Execute);

    private static async Task Execute()
    {
        var rootDirectory = Directory.GetCurrentDirectory();
        var solutionFilterPath = Path.Combine(rootDirectory, ArtifactPaths.Root, $"{SolutionName}.slnf");

        var assemblyName = Assembly.GetExecutingAssembly()
            .GetName();
        var projectEnumerationOptions = new EnumerationOptions
        {
            MaxRecursionDepth = 2,
            RecurseSubdirectories = true,
        };
        var projectPaths = Directory.GetFiles(rootDirectory, "*.csproj", projectEnumerationOptions)
            .Where(path => Path.GetFileNameWithoutExtension(path) != assemblyName.Name)
            .Select(path => path.Replace($"{rootDirectory}\\", string.Empty))
            .ToArray();

        var solutionRelativePath = Path.Combine("..", $"{SolutionName}.slnx");
        var solutionFilter = new SolutionFilter(new(solutionRelativePath, projectPaths));

        using var solutionFilterStream = File.OpenWrite(solutionFilterPath);
        await JsonSerializer
            .SerializeAsync(solutionFilterStream, solutionFilter, typeof(SolutionFilter), JsonSourceGenerationContext.Default)
            .ConfigureAwait(false);
    }
}
