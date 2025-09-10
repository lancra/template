using System.Text.Json.Serialization;

namespace __PROJECT__.Dev;

[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase, WriteIndented = true)]
[JsonSerializable(typeof(SolutionFilter))]
internal sealed partial class JsonSourceGenerationContext : JsonSerializerContext
{
}
