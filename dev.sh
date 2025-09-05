#!/bin/bash
set -euo pipefail
dotnet run --project "./tools/Dev" -- "$@"
