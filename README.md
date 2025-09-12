# Template

This repository provides various templates for new Git repositories.

## Usage

1. Clone this repository to a local directory.

   ```powershell
   git clone https://github.com/lancra/template.git <REPOSITORY>
   git -C <REPOSITORY> pull --all
   ```

1. Add this repository as a remote in the target repository.

   ```shell
   git remote add template <REPOSITORY>
   ```

1. Fetch the target template branch and default branch from the remote.

   ```shell
   git fetch template <TEMPLATE>-base
   git fetch template <TEMPLATE>
   ```

1. Extract the template tokens to a target location.

   ```shell
   git show template/<TEMPLATE>:.template/tokens.json > <TOKENS>
   ```

1. Populate values in the copied token specification.

   ```powershell
   & <REPOSITORY>/.template/scripts/populate-token-values.ps1 -Source <TOKENS>
   ```

1. Apply each commit for the template.

   ```powershell
   & <REPOSITORY>/.template/scripts/apply-commit.ps1 -Template <TEMPLATE> -TokenPath <TOKENS>
   ```
