using Ardalis.SmartEnum;

namespace __PROJECT__.Dev;

internal sealed class DevEnvironmentVariable : SmartEnum<DevEnvironmentVariable, string>
{
    public static readonly DevEnvironmentVariable ContainerRuntime =
        new("CONTAINER_RUNTIME", "The container runtime to use for target commands.", "podman");

    public static readonly DevEnvironmentVariable Linters =
        new("LINTERS", "The linters to execute as part of the lint target.");

    public static readonly DevEnvironmentVariable LocalLint =
        new("LOCAL_LINT", "Denotes that linters should fix issues where applicable.")
        {
            IsBoolean = true,
        };

    public static readonly DevEnvironmentVariable MegaLinterVersion =
        new("MEGALINTER_VERSION", "The version of the MegaLinter image to use.", "latest");

    private const string Prefix = "__ENVIRONMENT_VARIABLE_PREFIX___";

    private static readonly string[] TrueValues =
    [
        "1",
        "on",
        "true",
        "yes",
    ];

    private DevEnvironmentVariable(string name, string description)
        : base(name, Prefix + name)
    {
        ArgumentException.ThrowIfNullOrEmpty(name);
        ArgumentException.ThrowIfNullOrEmpty(description);
        Description = description;
    }

    private DevEnvironmentVariable(string name, string description, string defaultValue)
        : this(name, description)
    {
        ArgumentException.ThrowIfNullOrEmpty(defaultValue);
        DefaultValue = defaultValue;
    }

    public string Description { get; }

    public string? DefaultValue { get; }

    public bool IsBoolean { get; init; }

    public string? SystemValue => Environment.GetEnvironmentVariable(Value);

    public string ResultValue
        => SystemValue
        ?? DefaultValue
        ?? string.Empty;

    public bool IsTruthy
        => TrueValues.Contains(ResultValue, StringComparer.OrdinalIgnoreCase);
}
