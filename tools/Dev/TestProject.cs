namespace __PROJECT__.Dev;

internal sealed record TestProject(string Name, string Path)
{
    public override string ToString() => Name;
}
