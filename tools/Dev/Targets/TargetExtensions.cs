using System.Diagnostics.CodeAnalysis;
using Microsoft.Extensions.DependencyInjection;

namespace __PROJECT__.Dev.Targets;

internal static class TargetExtensions
{
    public static IServiceCollection AddTargets(this IServiceCollection services)
        => services.AddTarget<DefaultTarget>();

    private static IServiceCollection AddTarget<
        [DynamicallyAccessedMembers(DynamicallyAccessedMemberTypes.PublicConstructors)] TTarget>(
        this IServiceCollection services)
        where TTarget : class, ITarget
        => services.AddScoped<ITarget, TTarget>();
}
