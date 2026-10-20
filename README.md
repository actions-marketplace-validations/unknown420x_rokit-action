<div align="center">
  <h1><code>Rokit Action</code></h1>
  <p>
    <a href="https://github.com/unknown420x/rokit-action/actions?query=workflow%3Atest"><img src="https://github.com/unknown420x/rokit-action/workflows/test/badge.svg" alt="CI" /></a>
  </p>
</div>

GitHub action to install and run [rokit](https://github.com/rojo-rbx/rokit); a toolchain manager for Roblox.

## Updates

This repository with the action will be rarely updated, because is currently working fine and will probably updating if a good pull request got viewed or a issue got viewed, or if i try to make it better, more optimized or change something.

## Usage

With this use you automatically use the latest release of `rokit` with the default parameters:

```yaml
steps:
  - uses: unknown420x/rokit-action@1.0.0
```

The parameters values are these in this file, [check here](https://github.com/unknown420x/rokit-action/blob/main/action.yml#L5-L20).

### Advanced

If you want to make custom settings for your project, you can use parameters like this.

```yaml
steps:
  - uses: unknown420x/rokit-action@1.0.0
    with:
      version: v1.2.0 # This is the latest version of rokit, recommended (uses the latest tag by default)
      path: some_dir/my_project # path to the directory that contains the `rokit.toml`, `aftman.toml`, or `foreman.toml` ("." (current dir) by default)
      cache: false # whether to enable binary caching between runs (false by default and recommended if you dont have a github token)
      token: ${{ github.token }} # GitHub token to bypass the github rate limit (${{ github.token }} set by default)
```

## Inputs

### `version`

The git release version of `rokit` to install and use. By default this input will be assigned to the latest version of `rokit`.

### `path`

The path to the directory containing the `rokit.toml` to install tools from. The default is the current directory (`.`).

### `cache`

Enable to cache tools installed by `rokit`, the default value of this input is `false`. Note, in many cases enabling this feature will slow down `rokit-action`.

There are a few reasons you may choose to enable caching:

- Action runs often, causing the GitHub rate-limit to be reached
- A large amount of tools to install
- Server downloading from is slow

In any case, it is recommended to benchmark before enabling this feature.

### `token`

Set a GitHub token to be used by `rokit` to avoid the GitHub rate-limit. Note, these two options, `${{ github.token }}` and `${{ secrets.GITHUB_TOKEN }}`, are equivalent and passed by default.

## Credits

- [@CompeyDev](https://github.com/CompeyDev) - Creating `setup-rokit`, which i forked.
- [@rojo-rbx](https://github.com/rojo-rbx) - The group that created `rokit`, the toolchain.
