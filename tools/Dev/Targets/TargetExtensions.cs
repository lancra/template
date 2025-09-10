using System.Diagnostics.CodeAnalysis;
using __PROJECT__.Dev.Targets.Build;
using Microsoft.Extensions.DependencyInjection;

namespace __PROJECT__.Dev.Targets;

internal static class TargetExtensions
{
    public static IServiceCollection AddTargets(this IServiceCollection services)
        => services.AddTarget<DefaultTarget>()
        .AddBuildTargets()
        .AddTarget<LintTarget>();

    private static IServiceCollection AddBuildTargets(this IServiceCollection services)
        => services.AddTarget<BuildTarget>()
        .AddTarget<CleanTarget>()
        .AddTarget<DotnetTarget>()
        .AddTarget<SolutionTarget>();

    private static IServiceCollection AddTarget<
        [DynamicallyAccessedMembers(DynamicallyAccessedMemberTypes.PublicConstructors)] TTarget>(
        this IServiceCollection services)
        where TTarget : class, ITarget
        => services.AddScoped<ITarget, TTarget>();
}
