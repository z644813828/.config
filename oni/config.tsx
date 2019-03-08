import * as React from "react"
import * as Oni from "oni-api"

export const activate = (oni: Oni.Plugin.Api) => {
    console.log("config activated")

    // Input
    //
    // Add input bindings here:
    //
    // oni.input.bind("<c-enter>", () => console.log("Control+Enter was pressed"))
    oni.input.bind("<m-o>", "workspace.openFolder")
    oni.input.bind("<m-s-n>", "oni.process.openWindow")
    oni.input.bind("<m-u>", "vcs.sidebar.toggle")
    //
    // Or remove the default bindings here by uncommenting the below line:
    //
    oni.input.unbind("<c-p>")
    oni.input.unbind("<c-/>")
    oni.input.bind("<M-\\>", "explorer.toggle")
    oni.input.unbind("<m-s-f>")
    oni.input.unbind("<m-p>")
    oni.input.unbind("<m-d>")
    oni.input.unbind("<m-s-d>")
    oni.input.unbind("<m-t>")
    oni.input.unbind("<m-'>")

    oni.input.unbind("<c-c>")
}

export const deactivate = (oni: Oni.Plugin.Api) => {
    console.log("config deactivated")
}

export const configuration = {
    activate,
    //add custom config here, such as

    "ui.colorscheme": "nord",

    "wildmenu.mode" :false

    "oni.bookmarks": ["~/oni/bookmarks"],
    // "editor.fontSize": "13px",
    // "editor.fontFamily": "Hack"
    // "editor.fontFamily": "Monaco"
    // "tabs.wrap" : true
    // "tabs.wrap" : false

    // UI customizations
    "ui.animations.enabled": true,
    "ui.fontSmoothing": "auto",

    "oni.hideMenu"              : "hidden", // Hide top bar menu
    "oni.loadInitVim"           : true, // Load user's init.vim
    //"oni.useDefaultConfig"     : false, // Do not load Oni's init.vim
    "autoClosingPairs.enabled"  : true, // disable autoclosing pairs
    "commandline.mode"          : false, // Do not override commandline UI
    "browser.enabled"           : false,
    "oni.exclude"         : ["*tags*", ".git*", "*.o"],
    // "editor.completions.mode"   : 'native', //mb not working with lsp when off,
    // "experimental.markdownPreview.enabled": true
    "experimental.vcs.sidebar": true

    "tabs.mode"                : "native", // Use vim's tabline, need completely quit Oni and restart a few times
    // "statusbar.enabled"        : false, // use vim's default statusline
    // "sidebar.enabled"          : false, // sidebar ui is gone
    "sidebar.default.open"     : true, // the side bar collapse
    // "sidebar.default.open"     : false, // the side bar collapse
    "learning.enabled"         : false, // Turn off learning pane
    "achievements.enabled"     : false, // Turn off achievements tracking / UX
    "editor.typingPrediction"  : false, // Wait for vim's confirmed typed characters, avoid edge cases
    // "editor.textMateHighlighting.enabled" : false, // Use vim syntax highlighting

    // "language.c.languageServer.command": "/usr/local/Cellar/llvm/7.0.1/bin/clangd",
    // "language.c.languageServer.command": "/usr/local/Cellar/llvm/7.0.1/bin/clang-query",
    // "language.c.languageServer.command": "clangd",
    // "language.c.languageServer.command": "clang-query",
    // "language.cpp.languageServer.command": "clangd",
    // "language.c.completionTriggerCharacters": [".", ">", ":"],
    // "language.cpp.completionTriggerCharacters": [".", ">", ":"],
    // "language.c.languageServer.arguments": ["-I/Library/Developer/CommandLineTools/SDKs/MacOSX10.14.sdk/usr/include --log-file=/tmp/clang.log"],
    // "language.c.languageServer.arguments": ["-log-file=/tmp/cquery.log"],
    // "language.cpp.languageServer.arguments": ["-log-file=/tmp/clang.log"],

}

