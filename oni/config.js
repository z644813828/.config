"use strict";
exports.__esModule = true;
exports.activate = function (oni) {
    console.log("config activated");
    // Input
    //
    // Add input bindings here:
    //
    // oni.input.bind("<c-enter>", () => console.log("Control+Enter was pressed"))
    oni.input.bind("<m-o>", "workspace.openFolder");
    oni.input.bind("<m-s-n>", "oni.process.openWindow");
    oni.input.bind("<m-u>", "vcs.sidebar.toggle");
    //
    // Or remove the default bindings here by uncommenting the below line:
    //
    oni.input.unbind("<c-p>");
    oni.input.unbind("<c-/>");
    oni.input.bind("<M-\\>", "explorer.toggle");
    oni.input.unbind("<m-s-f>");
    oni.input.unbind("<m-p>");
    oni.input.unbind("<m-d>");
    oni.input.unbind("<m-s-d>");
    oni.input.unbind("<m-t>");
    oni.input.unbind("<m-'>");
    oni.input.unbind("<c-c>");
};
exports.deactivate = function (oni) {
    console.log("config deactivated");
};
exports.configuration = {
    activate: exports.activate,
    //add custom config here, such as
    "ui.colorscheme": "nord",
    "wildmenu.mode": false,
    "oni.bookmarks": ["~/oni/bookmarks"],
    // "editor.fontSize": "13px",
    // "editor.fontFamily": "Hack"
    // "editor.fontFamily": "Monaco"
    // "tabs.wrap" : true
    // "tabs.wrap" : false
    // UI customizations
    "ui.animations.enabled": true,
    "ui.fontSmoothing": "auto",
    "oni.hideMenu": "hidden",
    "oni.loadInitVim": true,
    //"oni.useDefaultConfig"     : false, // Do not load Oni's init.vim
    "autoClosingPairs.enabled": true,
    "commandline.mode": false,
    "browser.enabled": false,
    "oni.exclude": ["*tags*", ".git*", "*.o"],
    // "editor.completions.mode"   : 'native', //mb not working with lsp when off,
    // "experimental.markdownPreview.enabled": true
    "experimental.vcs.sidebar": true,
    "tabs.mode": "native",
    // "statusbar.enabled"        : false, // use vim's default statusline
    // "sidebar.enabled"          : false, // sidebar ui is gone
    "sidebar.default.open": true,
    // "sidebar.default.open"     : false, // the side bar collapse
    "learning.enabled": false,
    "achievements.enabled": false,
    "editor.typingPrediction": false
};
