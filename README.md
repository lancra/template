# Template

This repository provides various templates for new Git repositories.

## Usage

1. Define variables.

   ```powershell
   $repository = "PATH"
   $tokens = "PATH"
   $template = "NAME"
   ```

1. Clone this repository to a local directory.

   ```powershell
   git clone https://github.com/lancra/template.git $repository
   git -C $repository pull --all
   ```

1. Add this repository as a remote in the target repository.

   ```powershell
   git remote add template $repository
   ```

1. Fetch the target template branch and default branch from the remote.

   ```powershell
   git fetch template "$template-base"
   git fetch template "$template"
   ```

1. Extract the template tokens to a target location.

   ```powershell
   git show "template/${template}:.template/tokens.json" > $tokens
   ```

1. Populate values in the copied token specification.

   ```powershell
   & "$repository/.template/scripts/populate-token-values.ps1" -Source $tokens
   ```

1. Apply each commit for the template.

   ```powershell
   & "$repository/.template/scripts/apply-commit.ps1" -Template $template -TokenPath $tokens
   ```
