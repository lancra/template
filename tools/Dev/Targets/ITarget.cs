namespace __PROJECT__.Dev.Targets;

/// <summary>
/// Represents a target task execution.
/// </summary>
internal interface ITarget
{
    /// <summary>
    /// Performs the setup required for inclusion into a target collection.
    /// </summary>
    /// <param name="targets">The target collection to modify.</param>
    void Setup(Bullseye.Targets targets);
}
