@pushd %~dp0
@dotnet run --project ".\tools\Dev" -- %*
@popd
