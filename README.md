# Contents
- [MacOS settings and applications](#macos-settings-and-applications)
- [Applications](#applications)
    - [Writing Code](#writing-code)
        -  Atom
        -  VimR
        -  MacVim
        -  Emacs
        -  Dash
        -  Fork
    - [Utilities](#utilities)
        -  iTerm
        -  UpTerm
        -  Keka
        -  1Password
        -  Parallels
        -  IINA
        -  Reeder
        -  Joplin
        -  Marked
    - [Connecting to other devices](#connecting-to-other-devices)
        -  Transmit
        -  XQuartz
        -  Android File Transfer
        -  Transmission Remote GUI
    - [System customization](#system-customization)
        -  Karabiner
        -  Bartender
        -  Alfred
        -  Browserosaurus
        -  NTFS for Mac
        -  Paste
        -  Spectacle
        -  Ukelele
        -  BeardedSpice
        -  SlowQuitApps
    - [Other software](#other-software)
- [Cli-tools](#cli-tools)
-  [Fixing errors and usefull commands](#fixing-errors-and-usefull-commands)
    -  BeardedSpice
    -  TimeMachine on NAS fail fixing
    -  Remove tittle-bar
    -  Remove invisible shadow around windows
    -  Remove symbols on long press
    -  Add dock separator
    -  Get program Identifier
    -  Volume error (sometimes no sound, sometimes very low level)
    -  Create self-signed software
- [Server NAS configuration](#server-nas-configuration)
    -  [Server build](#server-build)
    -  [Network](#network)
    -  [Hosts](#hosts)
    -  [Server software: ](#server-software)
    -  [Client software: ](#client-software)
- [Windows configuration](#windows-configuration)
    -  [Dependencies](#Dependencies)
    -  [Terminal settings](#terminal-settings)
    -  [WSL installation](#wsl-installation)


#  MacOS settings and applications
##  Applications
### Writing code
#### [Atom](https://atom.io/) - Text Editor

>  <img src="https://user-images.githubusercontent.com/36923451/61751003-927c1c00-adaf-11e9-97fc-b5515fc78aa6.png" width="1280" alt="img">
> 
>  -  Working with [vim-mode-plus](https://atom.io/packages/vim-mode-plus) plugin
> 
>  -  ALL setting are in gists below:  
> [init.cofee](https://gist.github.com/z644813828/8301dbce846de5b8579c461b21905e00##file-init-coffee) with startup scripts, now it's empty cause sometimes it's necessary to load clean instance of editor   
> [packages.json](https://gist.github.com/z644813828/8301dbce846de5b8579c461b21905e00##file-packages-json) storing information of plugins and setting of build-in packages  
> [settings.json](https://gist.github.com/z644813828/8301dbce846de5b8579c461b21905e00##file-settings-json) including setting of downloaded commmunity packages. Many packages are working only on UNIX-based OS.    
> [snippets.json](https://gist.github.com/z644813828/8301dbce846de5b8579c461b21905e00##file-snippets-cson) storing snippets  
> [keymap.json](https://gist.github.com/z644813828/8301dbce846de5b8579c461b21905e00##file-keymap-cson) with keybinds for each type of text editor.  Now using vim-mode and some keymaps unbinded. Works only with MacOS. To recompile to Windows use [script]()  
> [styless.less](https://gist.github.com/z644813828/8301dbce846de5b8579c461b21905e00##file-styles-less) where stored GUI setting of text editor  
>  - Using many plugins, for syncronisation using plugin [Sync settings](https://atom.io/packages/sync-settings)  
    Sync plugin settings (fork):  
    Name :    dmitriy_k  
    Gist id:  8301dbce846de5b8579c461b21905e00
> 
> List of installed packages (`# apm list`). 
    Community Packages (73): atom-console@0.4.6; atom-cscope@1.1.0; atom-ctags@5.1.2; atom-fuzzy-grep@0.17.2; atom-ide-ui@0.13.0 (disabled); atom-material-ui@2.1.3; atom-ui-tweaks@0.3.0; auto-c-heade@0.1.0; auto-encoding@0.7.2; autocomplete-clang@0.12.0; autocomplete-paths@2.12.2 (disabled); busy-signal@2.0.1; clang-format@2.0.8; codewall@0.1.2; coneal@0.0.4; dash@1.7.1; date@2.6.0; dbg@1.6.3 (disabled); dbg-gdb@1.7.8 (disabled); ex-mode@0.18.0; file-icons@2.1.33; highlight-selected@0.16.0; import-sf-mono@1..1; indent-guide-improved@1.4.13; inline-git-diff@2.4.0; intentions@1.1.5; keyboard-scroll@0.7.0; language-markdown@0.37.0; language-ocaml@1.9.5; language-iml@1.1.10; last-cursor-position@0.9.3; line-count-status@0.0.3; linter@2.3.0; linter-clang@4.1.2; linter-javac@1.10.0; linter-jsonlint@1.4.0; linter-markdown@5.2.9 linter-pylint@2.1.1; linter-ui-default@1.7.1; markdown-image-paste@2.5.2; markdown-pdf@2.2.0; markdown-scroll-sync@2.1.2 (disabled); markdown-writer@2.116; minimap@4.29.9 (disabled); minimap-bookmarks@0.4.2 (disabled); minimap-cursorline@0.2.0 (disabled); minimap-find-and-replace@4.5.2 (disabled); minimap-hide@0.3. (disabled); minimap-highlight-selected@4.6.1 (disabled); minimap-linter@2.2.1 (disabled); multi-cursor@2.1.5; output-panel@0.3.4 (disabled); persistent-bookmarks@0.3.0; persistent-und@1.3.0; plain-simple@1.1.0; platformio-ide-terminal@2.9.1; prompt-big-file@0.5.0; quick-highlight@0.13.0; relative-numbers@0.9.0; remember-folds@0.3.0; scolloff@0.2.0; split-diff@1.6.0; switch-header-source@0.34.1; symbols-navigator@1.8.1; sync-settings@0.8.6; tab-numbers@0.6.1 (disabled); tab-switcher@1.5.6; todo-show@2.3.2; tree-view-git-status@1.5.2; vim-mode@0.66.0 (disabled); vim-mode-plus@1.36.0; vim-mode-plus-ex-mode@0.11.0; vim-mode-zz@0.2.0; 

#### [VimR](https://github.com/qvacua/vimr) - Text Editor (nvim GUI)
  > Just fast GUI version of fast test editor :)  
  Works fine, no other settings required  
  VIM Config [here](https://github.com/z644813828/.config/blob/master/nvim/init.vim)  
  GUI Config [here]()

#### [MacVim](https://github.com/macvim-dev/macvim) - Text Editor (vim GUI)
  > Vim Config [here](https://github.com/z644813828/.config/blob/master/.vimrc)  
  > GUI Config [here](https://github.com/z644813828/.config/blob/master/.gvimrc)  
  > sshrc config [here](https://github.com/z644813828/.config/blob/master/.vimrc_)  

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
  > [Fish](https://github.com/fish-shell/fish-shell) as shell with [fuzzy finder](https://github.com/junegunn/fzf) and integration with [Karabiner](##karabiner) hotkeys  
  Supports profiles for different use cases. Can quickly change between them.  
  Config files: [iTerm](https://github.com/z644813828/.config/blob/master/com.googlecode.iterm2.plist) [Fish](https://github.com/z644813828/.config/blob/master/fish/config.fish) [Bash](https://github.com/z644813828/.config/blob/master/.bashrc) [Tmux](https://github.com/z644813828/.config/blob/master/.tmux.conf)  
  To install all config files created [install script](https://github.com/z644813828/.config/blob/master/install.sh)  
  >  <img src="https://user-images.githubusercontent.com/36923451/61751014-9b6ced80-adaf-11e9-89cf-9c08c0a76591.png" width="500" alt="img">  

#### [UpTerm](https://github.com/railsware/upterm) - Terminal Emulator
  > Very nice looking terminal with GUI autocomplete and animations  
  No way to use it (no way to customize, not working VIM or any other tool inside it), but looks nice.  
  >  <img src="https://user-images.githubusercontent.com/36923451/61750982-842e0000-adaf-11e9-900f-5b05e5dd6bed.png" width="500" alt="img">

#### [Keka](https://apps.apple.com/us/app/keka/id470158793?mt=12) - File archiver
  > The only one GUI tool that I found that can archive in passworded ZIP package
  > Now using winrar-cli tool, it's nice  

#### [1Password](https://1password.com/) - Cloud Password Manager
  > Addons in all browsers on all OS, integration working in whole system  
  Storing keys  
  Sync through all devices  
  Has 2FA for sites and itself  

#### [Parallels](https://www.parallels.com/) - Virtualization software
  > Supports [coherence](https://kb.parallels.com/4670) mode  
  The best integration with virtual machine on MacOS  

#### [IINA](https://github.com/lhc70000/iina) - Video player
  > Very nice looking and fast video player. Supports customization via .conf files.  
  > Config [here](https://github.com/z644813828/.config/blob/master/IINA.conf)  

#### [Reeder](http://reederapp.com/mac/) - RSS Reeder
  > Just simple and convinent reader. Has dark theme, nice matching with system dark mode.

#### [Joplin](https://joplinapp.org/) - Notes
 > Note keeping app, supporting markdown.  
 Openes vim instance while editing files.  
 Cloud synchronising via many services, OneDrive allow not to index notes path.  
 >  <img src="https://user-images.githubusercontent.com/36923451/61751029-a1fb6500-adaf-11e9-90d5-6ddacbc407d2.png" width="1280" alt="img">

#### [Marked](http://marked2app.com) - Preview rendered markdown files
  > Works much better then many other preview utilities, supports many customization settings. But i didn't find a way to synchronise scrolling in any text aditor with preview. 

### Connecting to other devices
#### [Transmit](https://panic.com/transmit/) - File-transfer Client
  > Simplify connection to remote host via FTP or SFTP protocols. Use ssh certs. Splits etc.  
  > <img src="https://user-images.githubusercontent.com/36923451/61750998-8d1ed180-adaf-11e9-86a7-117ed1dadab7.png" width="1280" alt="img">

#### [XQuartz](https://www.xquartz.org/) - X11 Server for MacOS

#### [Android File Transfer](https://www.android.com/filetransfer/)
  > Connecting Android device to MacOS
  Looking for alternative, since Siera not working with Finder, no way to mount phone as a disk  

#### [Transmission Remote GUI](https://github.com/transmission-remote-gui/transgui/releases) - remote connection to transmission daemon
  >  Config [here](https://github.com/z644813828/.config/blob/master/Transmission%20Remote%20GUI/transgui.ini)  

### System customization
#### [Karabiner](https://pqrs.org/osx/karabiner/) - Keyboard remapper
  > Creates new virtual keyboard, with custom actions.  
  Can remap keys to work them natvely system wide.  
  Config is [here](https://github.com/z644813828/.config/blob/master/karabiner/karabiner.json)  
  All available keys codes are [here](https://github.com/z644813828/.config/blob/master/karabiner/key_codes)  

#### [Bartender](https://www.macbartender.com/) - Menu bar organizer
 > Hides unused applications in menu bar, has nice functionality.
  
#### [Alfred](https://www.alfredapp.com/) - Launcher
  > Looks ugly, works too, but able to fix spotlight broken index hash  
  Sometimes Spotlight is not able to rebuild files hash, works adding new path in indexing exception [step-by-step](https://support.apple.com/en-au/HT201716)  
  But if it fails, alfred recovery tool `Rebuild MacOS metaDATA` works well [step-by-step](https://www.alfredapp.com/help/advanced/##rebuild)  

#### [Browserosaurus](https://github.com/will-stone/browserosaurus) - Browser prompt
  > GUI tools that prompts you to choose a browser to open link with.  
  Works well (if building it yourself and using as service).  
  I'm using this [script](https://github.com/z644813828/.config/blob/master/scripts/browserosaurus.sh) added in startup launch options.  
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
  Config is [here](https://github.com/z644813828/.config/blob/master/Russian.keylayout). Symbols here are the same as in `ABC-extended`.  

#### [BeardedSpice](https://github.com/beardedspice/beardedspice)
  >  Utility to change Mac function keys, allow to switch music/video on all sites.  
  Now supporting VK.  
  Till Mojave neccesary to setup it in browsers (Safari/ Google Chrome). Shown below.

#### [SlowQuitApps](https://github.com/dteoh/SlowQuitApps)
 >  The best utility ever!!!  
  Notice! to work properly need to download from repo and build it yourself.  
  Fixes accidental apps close via CMD-Q. Remaps it to itself. Delay in 3 seconds before closing all windows.  
 >  <img src="https://user-images.githubusercontent.com/36923451/61751007-9740d000-adaf-11e9-96f4-69ee6374c09b.png" width="1280" alt="img">

### Other software
-  **Adobe Photoshop CC** - Raster graphics editor 
-  **balenaEtcher** - Writing image files onto storage media 
-  **Blackmagic Disk Speed Test** - tool to quickly measure and certify your disk performance
-  **Google Chrome** - browser 
-  **Keynote** - presentation software
-  **Macs Fan Control** - Control fans on Apple computers
-  **Mattermost** - chat service
-  **Microsoft Excel** - spreadsheet app
-  **Microsoft OneNote** - Note keeping app
-  **Microsoft PowerPoint** - presentation software
-  **Microsoft Remote Desktop** - app to connect to a remote PC
-  **Microsoft Word** - word processor
-  **Numbers** - spreadsheet app
-  **Pages** - word processor
-  **PDF Editor 6 Pro** - PDF editor
-  **PyCharm CE** - integrated development environment
-  **Skype** - telecommunications application
-  **Speedtest** - check your internet speed
-  **Sublime Merge** - text editor
-  **TeamViewer** - app to connect to a remote PC
-  **Telegram** - chat service
-  **uTorrent** - torrent client
-  **VK Messenger** - chat service
-  **WhatsApp** - chat service
-  **Windscribe** - VPN service
-  **Wireshark** - packet analyzer tool

## Cli-tools
> Here some cli tools that are specific for MacOS  
>
- [trash](https://github.com/sindresorhus/trash) - Move files and folders to the trash.  
- [mas](https://github.com/mas-cli/mas) - CLI for mac app store.  
- [m-cli](https://github.com/rgcr/m-cli) - Useful utils for macOS.

## Fixing errors and usefull commands
### BeardedSpice
  >  Safari > Preferences, and click Advanced.  
   At the bottom of the pane, select the “Show Develop menu in menu bar” checkbox.  
   From the menu bar, go to Developer and check the Allow JavaScript from Apple Events  

### [No clamshell mode](https://github.com/pirj/noclamshell)

### TimeMachine on NAS fail fixing 
>  Sometime TimeMachine on NAS failes to check it's backup copy and tries to make a new one. This software can fix it's behavior and let to continue using old backup.  
add `fsck_hfs` to `settings-> full disk access`  
Download and run this [software](https://github.com/chase-miller/time-machine-sparce-bundle-fix)  


### Remove tittle-bar
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

# Server NAS configuration
>  Now setting up NAS, that performs work like **TimeCapsule**, **AppleTV**, **Airport V1** not documented.  
Here's list of used software, hardware and utilities that helped me setup all this.  

##  Server build:
  - CPU i3-2100
  - GPU gtx550-ti
  - RAM 4Gb
  - HDD Internal - WD RED in Raid-mode
  - HDD External - WD GREEN

##  Network:
  - ASUS RT-AC88U
  - ASUS DDNS - for connecting via Internet

##  Hosts:
  - Linux 
  - Windows 
  - Android 
  - MacOS 

##  Server software:  
  -  **OS**  [Linux Debian 9](https://www.debian.org/)  
  -  **NAS** [OpenMediaVault(OMV) 4](https://www.openmediavault.org/)  
    **There're a few services that can be installed via NAS directly**     
    To install any of them you need to download and install [omv-extra plugin](http://omv-extras.org/) first from official site.  
    -  [Apple Filing](https://www.openmediavault.org/?p=401) - apple connection protocol, only using it (without addition software on client side) is able to use TimeMachine, disk is seen as a normal afp share with TM support, emulation of TimeCapsule  
    -  **Bit Torrent** - Torrent client, Transmission remote client can connect to it, also started a NGINX site with web GUI for Windows users.  
    -  **SMB/CIFS** - Windows share protocol  
    -  **and many others…**  
  
  -  Other tools   
    -  [Shairport](https://github.com/shivasiddharth/shairport-sync) - AirServer v1 (Only audio) streaming on server from Apple devices  
    -  [Fail2ban](https://www.fail2ban.org/) - detect attacks on web sites and ssh-server and blocking atackers IP.  
    -  [Tonido](https://www.tonido.com/) - very simple cloud storage server. Can work with relay server, so can have access even without DDNS  
    -  [Kodi](https://kodi.tv/) - media player, using for playing downloaded video, maybe can work as AirServer v2 (video) idk.  
    -  [CUPS](https://www.cups.org/) - printing system server  
  
  -  Backup  
     Using [script](https://github.com/z644813828/.config/blob/master/scripts/rsync.sh) started every month on external HDD  

##  Client software:  
  -  **PC:**  
     - Transmission remote GUI  
     - Tonido  
     - Transmit  
     - SSH client  

  -  **Phone:**     
     - Tonido    
     - Asus Router    
     - Transmission remote GUI  

# Windows configuration
## Dependencies

-   terminal text editor [vim](https://www.vim.org/download.php)
-   terminal file manager [vifm](https://vifm.info)
-   terminal emulator [Windows terminal](https://github.com/microsoft/terminal)
-   Monospace patched fonts [Nerd fonts for terminal (Cascadia Code)](https://github.com/microsoft/cascadia-code)
        Unzip and install both ttl->PL fonts

## Terminal settings

-   open default configuration file: alt + click on arrow -> settings (gvim is required)
-   merge WSL.json to configuration file `default.json`
-   set WSL as a default (startup) profile    
-   relaunch terminal

## WSL installation

Some info on this [link](https://aka.ms/wslinstall)

-   The Windows Subsystem for Linux optional component is not enabled:
    `dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart`
-   optional: update to WSL ver2
-   `bash -c "$(wget https://raw.githubusercontent.com/mskyaxl/wsl-terminal/master/scripts/install.sh -qO -)"`
-   WSL default user name MUST be the same as Windows (Unix conf file)
-   install dependencies `sudo apt install vim neovim ctags fish tmux sudo git curl autoconf autopoint libtool bison flex ranger highlight silversearcher-ag fzf make cmake grc`
-   get install script
-   install dependencies
