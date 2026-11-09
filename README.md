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

## Create and open environments from the laptop

Install only the laptop command, without applying the Ubuntu shell profile:

```bash
~/dotfiles/setup-agent.sh install-client
agent-env new demo
agent-env new another-project https://github.com/OWNER/REPOSITORY.git
agent-env list
agent-env open demo
agent-env remove demo
```

Run these from the laptop's Herdr. The default host is `nacho@homelab`; override
`AGENT_ENV_HOST` if needed. The host must have the existing `agent-pilot` profile,
its Incus bridge/firewall setup, and the private `agent-base` image.
The [Factory Incus recipe](https://github.com/nachfq/factory/tree/main/infra/incus)
records how to recreate that host configuration on another server.
Use Incus 6.0.1 or newer: 6.0.0 has an upstream image-unpacking bug that skips
folders named `dev`, including `/home/dev`. `new` refuses that server version.

Each new environment is named `dev-NAME` on Incus. It receives only the laptop's
SSH public key for access, plus Git's name/email when configured on the laptop.
SSH uses a ProxyJump through homelab and pins the environment's
host key obtained through Incus. Managed connection entries are kept in
`~/.ssh/agent-env.conf` and `~/.ssh/agent-env_known_hosts`; the first use adds an
Include to `~/.ssh/config` after making a backup.

The command adds `homelab / NAME` to Herdr and prepares a project workspace with
Neovim on the right and a shell on the left. First sign into GitHub and Codex in
that shell, then run `codex`. A repository that requires authentication can be
cloned after login. Credentials belong to that environment and are not shared.
`open` starts a stopped environment and reconnects without duplicating the
connection or workspace. After an environment restart it starts Herdr again and
restores the project editor in its managed pane. Existing running panes are left
alone. Environments retain the profile's manual-start policy after host reboot.

`remove` permanently deletes that environment's filesystem and its managed
connection entries. It refuses to operate on instances not created by this
command, including the original `agent-pilot`.

The SSH first-boot regression check uses the real image on homelab. It creates
and deletes a uniquely named test environment without adding Herdr connections:

```bash
AGENT_ENV_INTEGRATION=1 python3 -m unittest discover -s scripts/tests -v
```

## Build the base image

Image construction and host configuration now live in
[Factory's Incus recipe](https://github.com/nachfq/factory/tree/main/infra/incus).
Follow its build instructions with the published Factory and dotfiles commits.
This repository supplies `setup-agent.sh` and the shared configuration used by
the builder; Factory owns the build script and image cleanup helper.

The image has no project checkout, logins, authorized SSH keys, host SSH keys or
machine ID. `agent-env new` provisions access and generates unique host keys for
each instance. `dev` has sudo inside each environment. Rust toolchains, browser
downloads, Docker and project services are added only where needed.

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
./setup-agent.sh install-runtimes
./setup-agent.sh install-codex
./setup-agent.sh configure-codex
./setup-agent.sh install-herdr
./setup-agent.sh plugins
```

`install-tools` requires root or sudo. When the container user does not have sudo,
run that step from the Incus host, replacing `ENVIRONMENT` and the user path:

```bash
incus exec ENVIRONMENT -- bash /home/dev/dotfiles/setup-agent.sh install-tools
incus exec ENVIRONMENT -- bash /home/dev/dotfiles/setup-agent.sh grant-sudo
```

Run `grant-sudo` as root inside Incus too; it gives `dev` passwordless sudo
inside that environment so agents can install project dependencies themselves.
It refuses to run outside Incus and does not grant any permissions on the host.

Then run `apply`, `install-runtimes`, `install-codex`, `configure-codex`, `install-herdr` and `plugins` as `dev` inside that environment. The installer
checks archive SHA-256 digests and pins Neovim 0.12.6, Tree-sitter CLI 0.27.1,
LazyGit 0.66.2, dua 3.0.0, Starship 1.27.0, and GitHub CLI 2.103.3.
Supporting system packages,
including Eza, Bash completion, fzf, bat, zoxide, btop, rsync, pkgconf,
Bubblewrap and AppArmor, come from Ubuntu.
The installer loads `config/apparmor/dotfiles-bwrap`, which permits Bubblewrap
to create user namespaces without disabling Ubuntu's AppArmor restriction globally.
Authentication and project-specific toolchains are configured separately.
`plugins` downloads the Spanish spelling dictionary and suggestions to Neovim's
user data directory (English is bundled), restores the Neovim plugins, and waits
for the configured Mason tools and Tree-sitter parsers to finish installing. Additional
language servers and tools may download when their language integration is first
used; language toolchains such as Rust are project dependencies.

`install-runtimes` uses the official mise and uv installers, then installs Node LTS
and npm through mise. The shell activates mise and zoxide. mise can select other
versions for individual projects. Rust, browsers, Docker and databases are not
installed by this base profile. Ubuntu's `batcat` and `fdfind` are also available
through the usual `bat` and `fd` commands.

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

`configure-codex` sets `model = "gpt-6.1-sol"` and
`model_reasoning_effort = "high"`. It also sets the environment user's default
`sandbox_mode` to `danger-full-access` and `approval_policy` to `never`: the
equivalent of YOLO. `agent-env new` applies the laptop's version of these
defaults after provisioning, including when its cached base image is older.
It preserves existing settings and hook trust, backs up changes, and leaves
authentication files alone. Restart Codex after changing these defaults.
Run this step inside the agent environment; the Incus container provides the
isolation. This step is separate from `apply`, so sharing editor and shell
configuration with the laptop does not change its Codex permissions.

If you choose to use Codex's internal Linux sandbox as well, enable nesting
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

For interactive `gh auth login` and `gh auth refresh` in headless Incus
environments, the shared Bash setup forwards clipboard writes through the
terminal with OSC 52. It uses a write-only adapter scoped to those commands;
other programs keep their normal clipboard tools. With an attached Herdr client
and an outer terminal that permits OSC 52, the device code reaches the laptop's
clipboard. After Enter, Ctrl-click the displayed web link in Herdr and paste the
code in the laptop's browser. Browser opening is deliberately manual; there is
no desktop service or credential forwarding. Explicit `GH_BROWSER` / `BROWSER`
settings still take precedence. Existing shells need `source ~/.bashrc` after
pulling the update and running `./setup-agent.sh apply`.

Credentials stay in that environment's standard user storage. Restarting the
environment preserves them; deleting it removes the local copies. A new
environment requires new sign-ins. Credentials are not mounted from the Incus
host, copied from the laptop, or included in images. In particular, do not share
the same Codex `auth.json` across independently running environments: token
refreshes can conflict. Removing local files is separate from revoking the
authorization with GitHub or OpenAI.
