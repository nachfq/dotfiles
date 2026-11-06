# Development dotfiles

Shared terminal development configuration for my Omarchy laptop and disposable
Ubuntu environments managed by Incus.

## Contents

- `config/nvim`: the current LazyVim configuration, personal mappings, Rust and
  Markdown extras, Herdr integration, and `lazy-lock.json` for plugin revisions.
- `config/herdr`: Herdr keybindings and navigation/font helpers. Commands use the
  current user's config directory rather than a laptop-specific home path.
- `config/bash/worktrees.bash`: the `cdworktree` / `cdw` command and completion.
- `config/bash/interactive.bash` and `inputrc`: portable Bash history, completion,
  navigation aliases and Readline bindings adapted from the laptop's Omarchy setup.
- `config/starship.toml`: the laptop's prompt, directory and Git status styling.
- `setup.sh`: explicit tool installation, configuration linking, and plugin setup.

The old chezmoi source state is preserved in the
[`legacy-chezmoi-2026-11-05`](https://github.com/nachfq/dotfiles/tree/legacy-chezmoi-2026-11-05)
tag. The current branch uses ordinary files and symlinks; chezmoi is not required.

## Apply configuration

Run as your regular user, inside the environment where the tools will run:

```bash
git clone https://github.com/nachfq/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh apply
```

The script links Neovim's configuration directory and individual Herdr/Bash/Starship
configuration paths. It preserves Herdr's runtime directory, sockets, logs and
saved sessions. Existing configuration is backed up under
`~/.local/state/dotfiles/backups/` (or `$XDG_STATE_HOME/dotfiles/backups/`). Applying
the same checkout again leaves existing matching symlinks alone. It adds one
source line to `~/.bashrc`, preserving a backup before the first change. A new Bash
shell loads the shared prompt and helper configuration.

The laptop already supplies its tools through Omarchy. For a new **Ubuntu x86_64**
environment, install the editor tools first:

```bash
./setup.sh install-tools
./setup.sh apply
./setup.sh plugins
```

`install-tools` requires root or sudo. When the container user does not have sudo,
run that step from the Incus host, replacing `ENVIRONMENT` and the user path:

```bash
incus exec ENVIRONMENT -- bash /home/dev/dotfiles/setup.sh install-tools
```

Then run `apply` and `plugins` as `dev` inside that environment. The installer
checks archive SHA-256 digests and pins Neovim 0.12.6, Tree-sitter CLI 0.27.1,
LazyGit 0.66.2, Node.js 24.22.2, and Starship 1.27.0. Supporting system packages,
including Eza and Bash completion, come from Ubuntu.
Herdr, coding agents, GitHub authentication and project-specific toolchains are
configured separately. `plugins` restores the Neovim plugins and waits for the
configured Mason tools and Tree-sitter parsers to finish installing. Additional
language servers and tools may download when their language integration is first
used; language toolchains such as Rust are project dependencies.

The shell setup enables the Bash worktree helper automatically. It preserves the
existing `.bashrc` instead of replacing it with an Omarchy-specific startup file.

## Update and edit

Configuration paths are symlinks into this checkout, so ordinary configuration
edits appear in `git diff` here. Review and commit intended changes, then push.
On another environment:

```bash
cd ~/dotfiles
git pull --ff-only
./setup.sh apply
./setup.sh plugins
```

Avoid editing the shared configuration simultaneously while pulling updates.
`lazy-lock.json` records plugin revisions; commit deliberate plugin updates with
the configuration changes that need them.

## Desktop and remote behavior

The included Neovim theme is a regular file containing the laptop's current
`tokyonight-night` theme. It does not depend on Omarchy files existing remotely.
Omarchy theme changes are not automatically propagated to remote environments.

Neovim/Herdr selection and pane-navigation integrations require a running Herdr
session with its CLI/socket available in the same environment. Copying these
files alone does not connect a remote editor to a local Herdr session. Font zoom
requires the laptop's Hyprland/Foot desktop; fonts and the terminal itself remain
on the laptop. No desktop compositor is installed by this repository.
The container uses the same Starship prompt and portable shell settings. Font
rendering, terminal palette, padding and window appearance come from the local
terminal that displays the remote session.

## Credentials and local data

This repository is public. It contains configuration and installation recipes,
not credentials, editor caches, agent sessions, or project checkouts. In
particular, GitHub's `~/.config/gh/hosts.yml`, SSH private keys, `.env` files and
coding-agent authentication stay outside the repository and its images.

GitHub credentials can be provided separately by the Incus host. Removing an
environment does not revoke those credentials or remove the host's copy.
