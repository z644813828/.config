let uname = substitute(system('uname'), '\n', '', '')
let user_name = 'dmitriy'
let path_cfg = '/' . user_name . '/.config/nvim/init.vim'
if uname == 'Darwin'
    let path_cfg = '/Users' . path_cfg
else
    let path_cfg = '/home' . path_cfg
endif
exec 'source ' . path_cfg
