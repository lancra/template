namespace __PROJECT__.Dev;

internal sealed class DevEnvironmentVariable
{
    private const string Prefix = "__ENVIRONMENT_VARIABLE_PREFIX___";

    private static readonly string[] TrueValues =
    [
        "1",
        "on",
        "true",
        "yes",
    ];

    private bool _hydratedValue;

    public DevEnvironmentVariable(string name)
    {
        ArgumentException.ThrowIfNullOrEmpty(name);
        Name = Prefix + name;
    }

    public DevEnvironmentVariable(string name, string defaultValue)
        : this(name)
    {
        ArgumentException.ThrowIfNullOrEmpty(defaultValue);
        DefaultValue = defaultValue;
    }

    public string Name { get; }

    public string? DefaultValue { get; }

    public string Value
    {
        get
        {
            if (!_hydratedValue)
            {
                field = Environment.GetEnvironmentVariable(Name) ?? DefaultValue;
                _hydratedValue = true;
            }

            return field ?? string.Empty;
        }
    }

    public bool IsTruthy
        => TrueValues.Contains(Value, StringComparer.OrdinalIgnoreCase);
}
