using Ardalis.SmartEnum;

namespace __PROJECT__.Dev;

internal sealed class DevEnvironmentVariable : SmartEnum<DevEnvironmentVariable, string>
{
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
