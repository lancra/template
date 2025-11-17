using System.Text;
using Ardalis.SmartEnum;

namespace __PROJECT__.Dev.Targets;

internal sealed class VariablesTarget : ITarget
{
    public void Setup(Bullseye.Targets targets)
        => targets.Add(
            TargetKeys.Variables,
            "Shows variables used to modify target behaviors.",
            ExecuteAsync);

    private static async Task ExecuteAsync()
    {
        foreach (var variable in DevEnvironmentVariable.List)
        {
            var valueKind = VariableValueKind.FromVariable(variable);

            var builder = new StringBuilder()
                .Append(variable.Value)
                .Append(" = ")
                .Append(AnsiEscapeSequences.Underline)
                .Append(variable.ResultValue)
                .Append(AnsiEscapeSequences.UnderlineReset);

            if (!string.IsNullOrEmpty(variable.ResultValue))
            {
                builder.Append(' ');
            }

            if (variable.IsBoolean)
            {
                builder.Append(AnsiEscapeSequences.ForegroundBlue)
                    .Append($"[{(variable.IsTruthy ? "true" : "false")}] ")
                    .Append(AnsiEscapeSequences.ForegroundReset);
            }

            builder.Append(valueKind.EscapeSequence)
                .Append($"({valueKind.Name})")
                .Append(AnsiEscapeSequences.ForegroundReset)
                .Append(": ")
                .Append(variable.Description);

            Console.WriteLine(builder.ToString());
        }
    }

    private static class AnsiEscapeSequences
    {
        public const string ForegroundBlue = "\e[34m";
        public const string ForegroundGreen = "\e[32m";
        public const string ForegroundRed = "\e[31m";
        public const string ForegroundReset = "\e[39m";
        public const string ForegroundYellow = "\e[33m";
        public const string Underline = "\e[4m";
        public const string UnderlineReset = "\e[24m";
    }

    private sealed class VariableValueKind : SmartEnum<VariableValueKind>
    {
        public static readonly VariableValueKind Unset = new(1, "unset", AnsiEscapeSequences.ForegroundRed);
        public static readonly VariableValueKind Default = new(2, "default", AnsiEscapeSequences.ForegroundYellow);
        public static readonly VariableValueKind System = new(3, "system", AnsiEscapeSequences.ForegroundGreen);

        private VariableValueKind(int value, string name, string escapeSequence)
            : base(name, value)
            => EscapeSequence = escapeSequence;

        public string EscapeSequence { get; }

        public static VariableValueKind FromVariable(DevEnvironmentVariable variable)
            => variable.SystemValue is not null
            ? System
            : variable.DefaultValue is not null
                ? Default
                : Unset;
    }
}
