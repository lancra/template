using System.Diagnostics.CodeAnalysis;

[assembly: SuppressMessage(
    "Design",
    "CA1034:Nested types should not be visible",
    Justification = "Nested classes are used for methods in unit test classes.")]
[assembly: SuppressMessage(
    "Design",
    "CA1052:Static holder types should be Static or NotInheritable",
    Justification = "Test classes cannot be static.")]
[assembly: SuppressMessage(
    "Design",
    "CA1062:Validate arguments of public methods",
    Justification = "Test methods are not under the same constraints as typical public methods.")]
[assembly: SuppressMessage(
    "Maintainability",
    "CA1506:Avoid excessive class coupling",
    Justification = "Difficult to avoid with a large number of required mocks and fakes.")]
[assembly: SuppressMessage(
    "Maintainability",
    "CA1515:Consider making public types internal",
    Justification = "Test classes must be public.")]
[assembly: SuppressMessage(
    "Naming",
    "CA1707:Identifiers should not contain underscores",
    Justification = "Allowed in test method names.")]
[assembly: SuppressMessage(
    "Reliability",
    "CA2007:Consider calling ConfigureAwait on the awaited task",
    Justification = "Test methods will not be called outside of the scope of the project.")]
[assembly: SuppressMessage(
    "StyleCop.CSharp.ReadabilityRules",
    "SA1118:Parameter should not span multiple lines",
    Justification = "This situation is hard to avoid with complex theory data.")]
[assembly: SuppressMessage(
    "StyleCop.CSharp.MaintainabilityRules",
    "SA1402:File may only contain a single type",
    Justification = "Allows a large test fixture to be contained within a single file.")]
