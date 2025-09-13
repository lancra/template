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

1. For each commit in the branch:

   ```shell
   git --no-pager log --oneline --reverse --format="  %H %s" template/<TEMPLATE>-base..template/<TEMPLATE>
   ```

   1. Cherry-pick the commit into the target repository.

      ```shell
      git cherry-pick <COMMIT>
      ```

   1. Replace the tokens in the picked files.

      ```powershell
      & <REPOSITORY>/.template/scripts/replace-tokens.ps1 -Source <TOKENS>
      ```

   1. Amend the latest commit with the token replacements.

      ```shell
      git add .
      git commit --amend --no-edit
      ```
