# Personal development dotfiles

Shared editor and terminal configuration used by my Omarchy laptop and disposable
agent environments. [Factory](https://github.com/nachfq/factory) installs tools,
configures agents and builds/manages the Incus environments; this repository owns
my configuration files and the script that applies them.

## Contents

| Versioned source | Application location |
| --- | --- |
| `config/nvim/` | `~/.config/nvim/` |
| `config/herdr/config.toml` and `helpers/` | Matching paths under `~/.config/herdr/` |
| `config/bash/` | Selected files under `~/.config/bash/` |
| `config/starship.toml` | `~/.config/starship.toml` |
| `config/hypr/bindings.lua` | `~/.config/hypr/bindings.lua` (laptop only) |
| `config/omarchy/shell.json` | `~/.config/omarchy/shell.json` (laptop only) |

- `apply.sh`: links config files with backups; its `plugins` command prepares the
  dependencies associated with this Neovim configuration.
- `scripts/prepare-nvim.lua`: waits for the configured Mason tools and parsers.
- `scripts/tests/`: checks for the headless GitHub clipboard/browser helpers and
  configuration application.

The old chezmoi state is preserved in
[`legacy-chezmoi-2026-11-05`](https://github.com/nachfq/dotfiles/tree/legacy-chezmoi-2026-11-05).
The current checkout uses ordinary files and symlinks; chezmoi is not required.

## Apply configuration

As the regular user inside a prepared environment:

```bash
git clone https://github.com/nachfq/dotfiles.git ~/dotfiles
cd ~/dotfiles
./apply.sh apply
./apply.sh plugins
```

`apply` links the versioned configs and adds one source line for the shared Bash
setup to the existing `.bashrc`, preserving that file and backing up conflicts.
It leaves Herdr's sessions, sockets and logs in their existing locations.
Configuration backups live under `~/.local/state/dotfiles/backups/`.
The laptop's existing config symlinks keep pointing to the same files during
this migration. Applying the full shared Bash setup is an explicit choice;
there is no Omarchy installation step.

`plugins` downloads Spanish spelling files, restores `lazy-lock.json` revisions
and waits for the configured Mason tools and Tree-sitter parsers. It preserves
the original lockfile even if Lazy's first bootstrap rewrites it. This step
requires the editor/build tools installed by Factory.

Factory can apply another dotfiles checkout through the same two-command
interface. For this checkout, its command is:

```bash
/path/to/factory/setup-agent.sh apply-dotfiles ~/dotfiles
```

## Tools, agents and images

Those installation steps now live in
[Factory's agent setup](https://github.com/nachfq/factory/blob/main/docs/agent-setup.md).
The image recipe and exact Incus host configuration are documented in
[Factory's Incus recipe](https://github.com/nachfq/factory/tree/main/infra/incus).
The former `setup-agent.sh`, `agent-env` source, Codex-defaults helper and AppArmor
policy have moved there. Install the laptop's command from Factory:

```bash
cd /path/to/factory
./setup-agent.sh install-client
```

For an existing command symlink from dotfiles, use `install-client --replace`.
It preserves the old symlink in a backup. This command does not apply dotfiles or
install Ubuntu tools on the laptop. Existing environment connections/state remain
where they were.

## Update and edit

Symlinked configuration edits appear in `git diff` in this checkout. Review,
commit and push intended changes. On another environment:

```bash
cd ~/dotfiles
git pull --ff-only
./apply.sh apply
./apply.sh plugins
```

Commit deliberate plugin lock updates with the configuration changes that need
them. Running environments have their own checkout; they do not live-sync files
from the laptop. Images record the dotfiles revision used for their build.

## Desktop and remote behavior

The laptop's Hyprland shortcuts and Omarchy bar layout are also versioned here.
Their active files are symlinks to this checkout, so editing either location
appears in `git diff`. `apply.sh` deliberately applies only the shared development
configuration; it does not install or link these desktop files in containers.
On the laptop, link these two files individually after backing up existing files.
The remaining Omarchy desktop configuration continues to use the installed
defaults and local settings.

The bar layout uses two separately maintained plugins:
[nachfq.agents](https://github.com/nachfq/omarchy-agents) and
[nachfq.yuragi](https://github.com/nachfq/omarchy-yuragi). Install them according
to their repositories before reusing the layout on another Omarchy desktop.
Plugin source, usage statistics and authentication are not stored in dotfiles.
Personal shell startup files (`.bashrc`, `.bash_profile`, `.profile`, `.zshrc`)
and the monitor arrangement remain local and are not versioned here.

On Omarchy, Neovim loads the generated active theme from its standard state
directory and watches theme selections for live reloading. On other systems it
uses the included `tokyonight-night` fallback. Generated Omarchy theme state is
not committed, and theme selections are not propagated to remote environments.

Neovim/Herdr selection and pane-navigation integrations require a running Herdr
session with its CLI/socket available in the same environment. In Visual mode,
`<leader>a` opens a card containing the selected code and space for feedback;
in Normal mode it opens a message-only card. A unique Pi or Codex agent in the
editor's current Herdr tab is linked automatically. Multiple agents or no matching
agent leave the destination unlinked until you choose one. Explicit choices are
preserved; use `Ctrl+c` to choose or change the destination. `Enter` sends the comment
and selection; `Ctrl+s` appends them to the destination's draft without submitting.
Existing draft text is preserved. Busy agents, changed processes and unrecognized
composers leave the card intact; unconfirmed transfers require checking the
recipient before trying again. These are user prompts, not inter-agent messages.
Copying these files alone does not connect a remote editor to a local Herdr
session. Font zoom requires the laptop's Hyprland/Foot desktop; fonts and the terminal itself remain
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
pulling the update and running `./apply.sh apply`.

Credentials stay in that environment's standard user storage. Restarting the
environment preserves them; deleting it removes the local copies. A new
environment requires new sign-ins. Credentials are not mounted from the Incus
host, copied from the laptop, or included in images. In particular, do not share
the same Codex `auth.json` across independently running environments: token
refreshes can conflict. Removing local files is separate from revoking the
authorization with GitHub or OpenAI.
