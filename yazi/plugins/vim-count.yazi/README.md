# vim-count.yazi

Silent, unbounded Vim/ranger-style numeric prefixes for Yazi 26.9.1.

`keymap.toml` binds the first digit (`1` through `9`) to this plugin. The
plugin then reads further digits plus `j`/`k` with `ya.which { silent = true }`,
so no key-indicator popup is shown.

Examples:

- `3j` moves down 3 files.
- `12k` moves up 12 files.
- `123j` moves down 123 files.
- `Esc` cancels a pending count.

`0` is deliberately not a starting binding, so it retains Yazi's standalone
meaning. Once a count has started, it is accepted as a normal digit (`10j`,
`20k`, `105j`).
