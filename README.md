# Template

This repository provides various templates for new Git repositories.

## Usage

1. Define variables.

   ```powershell
   $repository = "PATH"
   $template = "NAME"
   ```

1. Clone template repository to a local directory.

   ```powershell
   git clone https://github.com/lancra/template.git $repository
   ```

1. Setup current repository.

   ```powershell
   & "$repository/.template/scripts/setup.ps1" -Repository $repository -Template $template
   ```

1. Apply all commits for the template.

   ```powershell
   & "$repository/.template/scripts/apply.ps1"
   ```

   Alternatively, apply all commits for the template without prompting the user between each.

   ```powershell
   & "$repository/.template/scripts/apply.ps1" -SkipWait
   ```

1. Remove remnants of the template process.

   ```powershell
   & "$repository/.template/scripts/cleanup.ps1" -Repository $repository
   ```
