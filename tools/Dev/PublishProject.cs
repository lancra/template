namespace __PROJECT__.Dev;

internal sealed record PublishProject(string Name, string Path, IReadOnlyCollection<string> Runtimes)
{
    public override string ToString() => Name;
}
