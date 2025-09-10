namespace __PROJECT__.Dev;

internal static class EnvironmentVariables
{
    public static readonly DevEnvironmentVariable BuildConfiguration = new("BUILD_CONFIGURATION", "Release");
    public static readonly DevEnvironmentVariable ContainerRuntime = new("CONTAINER_RUNTIME", "podman");
    public static readonly DevEnvironmentVariable LocalBuild = new("LOCAL_BUILD");
    public static readonly DevEnvironmentVariable LocalLint = new("LOCAL_LINT");
}
