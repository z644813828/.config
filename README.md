# Dotfiles

Personal macOS, Linux, and Windows configuration, with home server notes.

- [macOS and applications](#macos-settings-and-applications)
- [CLI tools](#cli-tools)
- [Useful commands](#fixing-errors-and-useful-commands)
- [Home server and NAS](#home-server-and-nas)
- [Windows and WSL](#windows-configuration)

# macOS settings and applications

## Applications

### Writing code

#### [VS Code](https://code.visualstudio.com/) - Code editor

Main editor, replacing Atom. Vim-style editing, clangd for C/C++, Qt and Python
tooling, Remote SSH, and Dev Containers.

![VS Code workspace with Markdown preview](https://github.com/user-attachments/assets/2a9555a0-3e26-4983-93e5-8d7d6cbe7a33)

- [Settings](vscode/settings.json): Atom One Dark theme, SF Mono, relative line
  numbers, hidden tabs, and Fish terminal with Hack Nerd Font.
- [Keybindings](vscode/keybindings.json): Vim motions, navigation, bookmarks,
  folding, and terminal shortcuts.
- [Snippets](vscode/snippets/): C/C++ templates.
- Local extensions: [Multi Cursor](vscode/extensions/vscode-mulitcursor/),
  [Open in Parallels](vscode/extensions/open-in-parallels/),
  [Trixie Dev Container](vscode/extensions/trixie-devcontainer/),
  [Server Version Cleaner](vscode/extensions/server-version-cleaner/), and
  [Hex Editor](vscode/extensions/hex-editor/README.md).


Export installed extensions from the client with `code --list-extensions`.

#### [Emacs](https://www.gnu.org/software/emacs/) - Text Editor
  > This day will come.. And I will check it.

#### [Dash](https://kapeli.com/dash) - API Documentation Browser
  > Has many docsets available for any platform.
  Bindable hotkeys
  Integration with Spotlight
  >  <img src="https://user-images.githubusercontent.com/36923451/61750955-74162080-adaf-11e9-97dd-670cedacfe91.png" width="1280" alt="img">

#### [Fork](https://git-fork.com/) - A fast and friendly git client
  > Support native MacOS dark theme
  Search through commits, branches etc
  >  <img src="https://user-images.githubusercontent.com/36923451/61750950-70829980-adaf-11e9-8350-26612549550b.png" width="1280" alt="img">

### Utilities

#### [iTerm](https://www.iterm2.com/) - Terminal Emulator
  > [Fish](https://github.com/fish-shell/fish-shell) as shell with [fuzzy finder](https://github.com/junegunn/fzf) and integration with [Karabiner](#karabiner---keyboard-remapper) hotkeys
  Supports profiles for different use cases. Can quickly change between them.  
  Config files: [iTerm](com.googlecode.iterm2.plist) [Fish](fish/config.fish) [Bash](.bashrc) [Tmux](.tmux.conf)  
  > <img src="https://github.com/user-attachments/assets/0bbe8a61-12b3-4ff3-a625-7db48bd988a8" width="500" alt="img">

#### [UpTerm](https://github.com/railsware/upterm) - Terminal Emulator (historical note)
  > Very nice looking terminal with GUI autocomplete and animations
  No way to use it (no way to customize, not working VIM or any other tool inside it), but looks nice.
  >  <img src="https://user-images.githubusercontent.com/36923451/61750982-842e0000-adaf-11e9-900f-5b05e5dd6bed.png" width="500" alt="img">

#### [Keka](https://apps.apple.com/us/app/keka/id470158793?mt=12) - File archiver
  > The only one GUI tool that I found that can archive in passworded ZIP package
  > Now using winrar-cli tool, it's nice

#### [Parallels](https://www.parallels.com/) - Virtualization software
  > Supports [coherence](https://kb.parallels.com/4670) mode
  The best integration with virtual machine on MacOS

#### [IINA](https://github.com/lhc70000/iina) - Video player
  > Very nice looking and fast video player. Supports customization via .conf files.
  > Config [here](IINA.conf)

#### [Reeder](http://reederapp.com/mac/) - RSS Reeder
  > Just simple and convinent reader. Has dark theme, nice matching with system dark mode.

#### [Joplin](https://joplinapp.org/) - Notes
 > Note keeping app, supporting markdown.
 Openes vim instance while editing files.
 Cloud synchronising via many services, OneDrive allow not to index notes path.
 >  <img src="https://user-images.githubusercontent.com/36923451/61751029-a1fb6500-adaf-11e9-90d5-6ddacbc407d2.png" width="1280" alt="img">

### Connecting to other devices

#### [Transmit](https://panic.com/transmit/) - File-transfer Client
  > Simplify connection to remote host via FTP or SFTP protocols. Use ssh certs. Splits etc.
  > <img src="https://user-images.githubusercontent.com/36923451/61750998-8d1ed180-adaf-11e9-86a7-117ed1dadab7.png" width="1280" alt="img">

#### [XQuartz](https://www.xquartz.org/) - X11 Server for MacOS

#### [Android File Transfer](https://www.android.com/filetransfer/)
  > Connecting Android device to MacOS
  Looking for alternative, since Siera not working with Finder, no way to mount phone as a disk

#### [Transmission Remote GUI](https://github.com/transmission-remote-gui/transgui/releases) - remote connection to transmission daemon
  >  Config [here](Transmission%20Remote%20GUI/transgui.ini)

### System customization

#### [Karabiner](https://pqrs.org/osx/karabiner/) - Keyboard remapper
  > Creates new virtual keyboard, with custom actions.
  Can remap keys to work them natvely system wide.
  Config is [here](karabiner/karabiner.json)
  All available keys codes are [here](karabiner/key_codes)

#### [Bartender](https://www.macbartender.com/) - Menu bar organizer
 > Hides unused applications in menu bar, has nice functionality.

#### [Alfred](https://www.alfredapp.com/) - Launcher
  > Looks ugly, works too, but able to fix spotlight broken index hash
  Sometimes Spotlight is not able to rebuild files hash, works adding new path in indexing exception [step-by-step](https://support.apple.com/en-au/HT201716)
  But if it fails, alfred recovery tool `Rebuild MacOS metaDATA` works well [step-by-step](https://www.alfredapp.com/help/advanced/#rebuild)

#### [Browserosaurus](https://github.com/will-stone/browserosaurus) - Browser prompt
  > GUI tools that prompts you to choose a browser to open link with.
  > <img src="https://user-images.githubusercontent.com/36923451/61750971-7b3d2e80-adaf-11e9-9d5f-89fdc55ac6a6.png" width="500" alt="img">

#### [NTFS for Mac](https://www.paragon-software.com/ru/home/ntfs-mac/) - NTFS (Windows) driver
  >  The bast utility to connect Windows NTFS share.
  Looking for analog, which can mount it as a native drive, cause Paragon not allow to use it via system, only via this Software.

#### [Paste](https://apps.apple.com/ru/app/paste-2/id967805235?mt=12) - Clipboard history navigation
  > Stores all copy buffers per month. Syncying to all devices via cloud.
  > <img src="https://user-images.githubusercontent.com/36923451/61750991-87c18700-adaf-11e9-9761-230d23af8101.png" width="1280" alt="img">

#### [Spectacle](https://www.spectacleapp.com/) - Windows manager
  >  Change window arrangment, add hotkeys to control app window size and swap them between several monitors.
  > <img src="https://user-images.githubusercontent.com/36923451/61750975-7f694c00-adaf-11e9-9f8f-1e13a800b95f.png" width="500" alt="img">

#### [Ukelele](https://ukelele.en.softonic.com/mac) - Unicode Keyboard Layout Editor
  >  Change keyboard layout, I use it only for symbols and `ё`, cause Option + same letters on different layouts give several symbols.
  Config is [here](Russian.keylayout). Symbols here are the same as in `ABC-extended`.

## CLI tools

### Yazi

[Yazi](https://yazi-rs.github.io/) replaces Ranger as the primary terminal file manager.
The configuration in [yazi/](yazi/) targets **26.9.1** and belongs in
`~/.config/yazi/`. Restart Yazi after changing the configuration.

- [yazi.toml](yazi/yazi.toml): general settings, openers, and preview rules.
- [keymap.toml](yazi/keymap.toml): Ranger-like keys, including `hjkl`, numeric
  movement counts, Space to select and move down, and `DD` for permanent deletion
  **with confirmation**.
- `r`: enter an application command before `%s`; `F4`: choose a configured opener.
- `l` / Enter: enter a directory or open selected files.
- [Archive browser](yazi/plugins/archive-browser.yazi/): `l` / Enter mounts
  archives as **read-only** directories through macFUSE and `ratarmount`.
  `h`/Left at the archive root unmounts it; `w` shows the initial mount task.
- [theme.toml](yazi/theme.toml) and [init.lua](yazi/init.lua): Nord colours,
  monochrome icons, hybrid line numbers, path and right-aligned tabs on one row,
  creation time and search position in the status bar.
- [image-fit](yazi/plugins/image-fit.yazi/): macOS image upscaling via built-in
  `sips`; Linux uses ordinary image preview. PDF and video previews are disabled.
- [Migration notes](yazi/README-MIGRATION.md): remaining differences from Ranger.

The current [Fish configuration](fish/config.fish) defines `r` as Yazi when
available, with Ranger as a fallback. [ranger/](ranger/) remains for those hosts.
The openers and Quick Look key in this Yazi configuration are macOS-oriented.

Install binaries using the [Yazi installation instructions](https://yazi-rs.github.io/docs/installation/).
On older Linux systems such as Debian 11, use a compatible musl build when the
GNU build requires a newer glibc. For a user-local installation, put `yazi` and
`ya` in `~/.local/bin` and add it to Fish's PATH:

```fish
fish_add_path ~/.local/bin
```

### macOS utilities

- [trash](https://github.com/sindresorhus/trash) - Move files and folders to the trash.
- [mas](https://github.com/mas-cli/mas) - CLI for mac app store.
- [m-cli](https://github.com/rgcr/m-cli) - Useful utils for macOS.

## Fixing errors and useful commands

Historical troubleshooting notes; menus and behaviour may differ on newer macOS versions.

### [No clamshell mode](https://github.com/pirj/noclamshell)

### TimeMachine on NAS fail fixing

>  Sometime TimeMachine on NAS failes to check it's backup copy and tries to make a new one. This software can fix it's behavior and let to continue using old backup.
add `fsck_hfs` to `settings-> full disk access`
Download and run this [software](https://github.com/chase-miller/time-machine-sparce-bundle-fix)


### Remove title bar

` defaults write com.qvacua.VimR MMNoTitleBarWindow true`

### Remove invisible shadow around windows

`defaults write com.apple.screencapture disable-shadow -bool TRUE`

### Remove symbols on long press

`defaults write -g ApplePressAndHoldEnabled -bool false`

### Add dock separator

`defaults write com.apple.dock persistent-apps -array-add '{tile-data={}; tile-type="spacer-tile";}'`

### Get program Identifier

`/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' /Applications/VimR.app/Contents/Info.plist`

### Volume error (sometimes no sound, sometimes very low level)
  Not fixed `sudo pkill coreaudiod`

### Create self-signed software

`sudo codesign --force --deep --sign - /Applications/…`

# Home Server and NAS

OpenMediaVault home server for files, Time Machine, and backups. Debian 9 / OMV 4.

| Component | Purpose / configuration |
| --- | --- |
| OpenMediaVault | NAS, SMB/AFP shares, and Time Machine. |
| nginx | HTTPS reverse proxy; [configuration](server/nginx/). |
| WireGuard gateway | Remote access through a VPS; [setup](server/vps/WIREGUARD_DOCKER_GATEWAY.md). |
| Docker firewall | Restrictions on published ports; [rules](server/docker/firewall/README.md). |
| Vaultwarden + PostgreSQL | Password manager. |
| GitLab | Self-hosted Git service. |
| OpenClaw | Telegram agent; [setup](server/docker/openclaw/README.md). |
| rclone-cloud | Encrypted off-site backups; [setup](server/docker/rclone-cloud/README.md). |
| Monit | Service, backup, certificate, and network checks; [configuration](server/monit/). |
| Fail2ban | SSH protection; [configuration](server/jail.local). |

Backups include Time Machine, monthly system images and MacBook archives,
local copies to an external disk, daily VPS backups, and encrypted Google Drive
copies. Scripts are in [scripts/](scripts/).

Further documentation: [server overview](server/README.md),
[VPS and MTProto](server/vps/README.md).

# Windows configuration

## Dependencies

- [Windows Terminal](https://github.com/microsoft/terminal).
- WSL with Fish, Vim/Neovim, and Yazi installed inside the Linux distribution.
- A [Nerd Font](https://www.nerdfonts.com/) for file icons.

The repository's [WSL.json](WSL.json) is a legacy Windows Terminal 1.1 profile
snapshot. Its Cascadia Code PL setting is not a Nerd Font icon configuration.

## Terminal settings

Open Windows Terminal's `settings.json` by holding Shift while choosing Settings.
Merge only relevant colours/keybindings from [WSL.json](WSL.json), preserving the
profiles generated for the installed WSL distributions. Set the desired WSL
distribution as the default profile in Settings.
See [Microsoft's Terminal setup documentation](https://learn.microsoft.com/en-us/windows/terminal/install).

## WSL installation

Follow [Microsoft's WSL installation guide](https://learn.microsoft.com/en-us/windows/wsl/install).
On a supported Windows installation, run in an administrator PowerShell:

```powershell
wsl --install -d Debian
```

After installation and any required restart, create the Linux user and install
the tools inside Debian:

```sh
sudo apt update
sudo apt install vim neovim fish tmux git curl file unzip fzf ripgrep
```

Install Yazi separately using its [installation guide](https://yazi-rs.github.io/docs/installation/),
then copy the [yazi/](yazi/) configuration to `~/.config/yazi/`.
Adapt macOS-specific openers and the `i` Quick Look binding for Linux/WSL.
The Linux username need not match the Windows username; adapt the personal paths
and `_USER` setting in [fish/config.fish](fish/config.fish) to the target machine.
