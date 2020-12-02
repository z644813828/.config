# Create an alias-icon
# Set cmd: `powershell.exe -ExecutionPolicy Bypass -File "path to this file"`
# Set hidden execution 
# Put in start-programs folder
#
# Enable scripts execution PS-admin: `Set-ExecutionPolicy RemoteSigned` -> `Y`
#
# Create `grubenv_0` file: copy of original file `grubenv` with `next_entry=0`. File need to be edited in Unix (LF)


# @echo off
# 
# :choice
# set /P c=Launch Debian GNU/Linux [y/N]?
# if /I "%c%" EQU "Y" goto :grub
# exit
# goto :choice
# 
# :grub
# cd /d G:/boot/grub/
# copy /y grubenv_0 grubenv
# pause 
# shutdown -r -t 00
 
$drive     = "G"
$grub_path = "${drive}:/boot/grub"
$file      = "${grub_path}/grubenv"
$file_0    = "${grub_path}/grubenv_0"

$nt = new-object -comobject wscript.shell 
$ret = $nt.popup("Launch Debian GNU/Linux from Drive ${drive}:/ ?", 0,"Linux Debian 9",4+32) 
If ($ret -eq 6) { 
    If(!(Test-Path "$file") ) {
        $ret = $nt.popup("$file doesn't exist",   0,"File not found",0+16)
    } elseif(!(Test-Path "$file_0") ) {
        $ret = $nt.popup("$file_0 doesn't exist", 0,"File not found",0+16)
    } else {
        Copy-Item $file_0 -Destination $file
        $ret = $nt.popup("GRUBENV patched. Reboot in Linux?", 0,"shutdown -r -t 00",1+32)
        If ($ret -eq 1) {
            shutdown -r -t 00
        }
    }
}
 
