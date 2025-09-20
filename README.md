# Template

This repository provides various templates for new Git repositories.

## Usage

1. Define variables.

   ```powershell
   $repository = "PATH"
   $specification = "PATH"
   $template = "NAME"
   ```

1. Clone template repository to a local directory.

   ```powershell
   git clone https://github.com/lancra/template.git $repository
   ```

1. Setup current repository.

   ```powershell
   & "$repository/.template/scripts/setup-repository.ps1" -RepositoryPath $repository -Specification $specification -Template $template
   ```

1. Populate token values in the copied specification.

   ```powershell
   & "$repository/.template/scripts/populate-token-values.ps1" -Specification $specification
   ```

1. Apply each commit for the template.

   ```powershell
   & "$repository/.template/scripts/apply-commit.ps1" -Specification $specification
   ```

1. Remove remnants of the template process.

   ```powershell
   & "$repository/.template/scripts/cleanup.ps1" -RepositoryPath $repository
   ```
