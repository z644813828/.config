#!/bin/bash

echo -n 'User name: '
read user_name

if [ -z "$user_name" ]; then
    echo "Error: User name can not be empty"
    exit 1
fi

echo -n 'Password : '
read -s password
echo


if [ ${#password} -lt 6 ]; then
   echo "Error: Password need to be at least 6 symbols" 
   exit 1
fi



# add linux user (for ssh/sftp connection)
useradd -m -d /sharedfolders/$user_name $user_name
echo $user_name:$password | chpasswd

# allow this user to connect via sftp and ssh
usermod -aG sftp $user_name
usermod -aG ssh $user_name

# create default directories and chown them for new user
cp -r /sharedfolders/_new/* /sharedfolders/$user_name/
chown -R $user_name:$user_name /sharedfolders/$user_name

# allow file-browser to access this folder for web gui
setfacl -R -m user:file-browser:rwx /sharedfolders/$user_name/ 

# create symlink for sftp
mkdir /home/$user_name
ln -s /sharedfolders/$user_name/* /home/$user_name

# add user if filebrowser config
service filebrowser stop
filebrowser users add $user_name $password --scope /sharedfolders/$user_name/ -d /home/file-browser/filebrowser.db
service filebrowser start

# set new user in list for rsync backup script
ln -s $user_name/ /sharedfolders/UserData/$user_name



# gpasswd --delete $user_name ssh
# gpasswd --delete $user_name sftp
# rm -rf /sharedfolders/$user_name
# rm -rf /sharedfolders/UserData/$user_name
# rm -rf /home/$user_name
# userdel $user_name
# service filebrowser stop
# filebrowser users rm $user_name -d /home/file-browser/filebrowser.db
# service filebrowser start
