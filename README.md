# Template

This repository provides various templates for new Git repositories.

## Usage

1. Define variables.

   ```powershell
   $repository = "PATH"
   $tokens = "PATH"
   $template = "NAME"
   ```

1. Clone template repository to a local directory.

   ```powershell
   git clone https://github.com/lancra/template.git $repository
   ```

1. Setup current repository.

   ```powershell
   & "$repository/.template/scripts/setup-repository.ps1" -RepositoryPath $repository -TokenPath $tokens -Template $template
   ```

1. Populate values in the copied token specification.

   ```powershell
   & "$repository/.template/scripts/populate-token-values.ps1" -TokenPath $tokens
   ```

1. Apply each commit for the template.

   ```powershell
   & "$repository/.template/scripts/apply-commit.ps1" -TokenPath $tokens -Template $template
   ```
