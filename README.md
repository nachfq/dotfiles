# Development dotfiles

Shared terminal development configuration for my Omarchy laptop and disposable
Ubuntu environments managed by Incus.

## Repository layout and setup profiles

Git versions the ordinary files under `config/`. They do not have to be scattered
through the home directory inside this repository: the setup script connects
them to each application's expected location using symlinks.

| Versioned source | Location used by the application |
| --- | --- |
| `config/nvim/` | `~/.config/nvim/` |
| `config/herdr/config.toml` and `helpers/` | The matching paths under `~/.config/herdr/` |
| `config/bash/` | The selected files under `~/.config/bash/` |
| `config/starship.toml` | `~/.config/starship.toml` |

`setup-agent.sh` is the Ubuntu agent-environment profile. It installs terminal
development tools and applies the shared editor/shell configuration. There is no
desktop setup script yet. Desktop-only configuration can also live under
`config/`; a separate desktop profile can select those files without installing
a desktop inside the agent environments. Shared configurations remain single
files rather than separate copies for each profile.

## Contents

- `config/nvim`: the current LazyVim configuration, personal mappings, Rust and
  Markdown extras, Herdr integration, and `lazy-lock.json` for plugin revisions.
- `config/herdr`: Herdr keybindings and navigation/font helpers. Commands use the
  current user's config directory rather than a laptop-specific home path.
- `config/bash/worktrees.bash`: the `cdworktree` / `cdw` command and completion.
- `config/bash/interactive.bash` and `inputrc`: portable Bash history, completion,
  navigation aliases and Readline bindings adapted from the laptop's Omarchy setup.
- `config/starship.toml`: the laptop's prompt, directory and Git status styling.
- `setup-agent.sh`: explicit tool installation, configuration linking, and plugin setup.

The old chezmoi source state is preserved in the
[`legacy-chezmoi-2026-11-05`](https://github.com/nachfq/dotfiles/tree/legacy-chezmoi-2026-11-05)
tag. The current branch uses ordinary files and symlinks; chezmoi is not required.

## Apply configuration

Run as your regular user, inside the environment where the tools will run:

```bash
git clone https://github.com/nachfq/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup-agent.sh apply
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
./setup-agent.sh install-tools
./setup-agent.sh apply
./setup-agent.sh install-codex
./setup-agent.sh install-herdr
./setup-agent.sh plugins
```

`install-tools` requires root or sudo. When the container user does not have sudo,
run that step from the Incus host, replacing `ENVIRONMENT` and the user path:

```bash
incus exec ENVIRONMENT -- bash /home/dev/dotfiles/setup-agent.sh install-tools
```

Then run `apply`, `install-codex`, `install-herdr` and `plugins` as `dev` inside that environment. The installer
checks archive SHA-256 digests and pins Neovim 0.12.6, Tree-sitter CLI 0.27.1,
LazyGit 0.66.2, Node.js 24.22.2, Starship 1.27.0, and GitHub CLI 2.103.3.
Supporting system packages,
including Eza, Bash completion, Bubblewrap and AppArmor, come from Ubuntu.
The installer loads `config/apparmor/dotfiles-bwrap`, which permits Bubblewrap
to create user namespaces without disabling Ubuntu's AppArmor restriction globally.
Authentication and project-specific toolchains are configured separately.
`plugins` downloads the Spanish spelling dictionary and suggestions to Neovim's
user data directory (English is bundled), restores the Neovim plugins, and waits
for the configured Mason tools and Tree-sitter parsers to finish installing. Additional
language servers and tools may download when their language integration is first
used; language toolchains such as Rust are project dependencies.

`install-codex` runs the official command as the regular user, without pinning a
version or assembling the package manually:

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

The official installer manages the complete package and installs the command in
`~/.local/bin`. Run `install-codex` again to update to the latest release, then
open a new Bash shell. After installation, this command checks the runtime path
as the regular user without making a model request:

```bash
codex app-server daemon start
```

For Codex's Linux sandbox inside an unprivileged Incus container, enable nesting
on that instance from the Incus host:

```bash
incus config set ENVIRONMENT security.nesting=true
```

This relaxes the container's AppArmor restrictions for nested sandboxes; keep
`security.privileged=false` and the isolated ID mapping. Verify command execution
inside the environment without making a model request:

```bash
codex sandbox -c 'permissions.check.extends=":workspace"' -P check -C ~/PROJECT -- /bin/true
```

`install-herdr` runs Herdr's official installer and `herdr integration install codex`.
The integration installs Herdr's agent-status hooks in the user's Codex configuration;
Codex may ask you to trust them when starting a session. SSH access and the saved
machine connection in the laptop's Herdr are configured separately.

Once the setup is stable, build a reusable image before signing into GitHub or
Codex. Keep this script as the recipe for rebuilding and updating that image.

The shell setup enables the Bash worktree helper automatically. It preserves the
existing `.bashrc` instead of replacing it with an Omarchy-specific startup file.

## Update and edit

Configuration paths are symlinks into this checkout, so ordinary configuration
edits appear in `git diff` here. Review and commit intended changes, then push.
On another environment:

```bash
cd ~/dotfiles
git pull --ff-only
./setup-agent.sh apply
./setup-agent.sh plugins
```

Avoid editing the shared configuration simultaneously while pulling updates.
`lazy-lock.json` records plugin revisions; commit deliberate plugin updates with
the configuration changes that need them.

## Desktop and remote behavior

On Omarchy, Neovim loads the generated active theme from its standard state
directory and watches theme selections for live reloading. On other systems it
uses the included `tokyonight-night` fallback. Generated Omarchy theme state is
not committed, and theme selections are not propagated to remote environments.

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

Each environment signs in independently, as its regular user:

```bash
gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key
gh auth setup-git --hostname github.com
codex login --device-auth
```

Open the printed URLs on the laptop and complete each authorization. Codex device
code login may need to be enabled in the account's security settings. Use
`gh auth status` and `codex login status` to inspect the result.

Credentials stay in that environment's standard user storage. Restarting the
environment preserves them; deleting it removes the local copies. A new
environment requires new sign-ins. Credentials are not mounted from the Incus
host, copied from the laptop, or included in images. In particular, do not share
the same Codex `auth.json` across independently running environments: token
refreshes can conflict. Removing local files is separate from revoking the
authorization with GitHub or OpenAI.
