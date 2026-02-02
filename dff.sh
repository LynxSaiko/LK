ensure_users() {
    log_msg "Ensuring user database exists in overlay..."
    
    # **INI YANG BENAR**: Buat di overlay (/.root), BUKAN di squashfs
    
    # Jika tidak ada passwd di overlay, buat minimal
    if [ ! -f /.root/etc/passwd ] || [ ! -s /.root/etc/passwd ]; then
        log_msg "Creating minimal /etc/passwd in overlay..."
        cat > /.root/etc/passwd << 'EOF'
root:x:0:0:root:/root:/bin/bash
live:x:1000:1000:Live User:/home/live:/bin/bash
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
EOF
    fi
    
    # Group file
    if [ ! -f /.root/etc/group ] || [ ! -s /.root/etc/group ]; then
        log_msg "Creating minimal /etc/group in overlay..."
        cat > /.root/etc/group << 'EOF'
root:x:0:
live:x:1000:
nogroup:x:65534:
EOF
    fi
    
    # Shadow file
    if [ ! -f /.root/etc/shadow ] || [ ! -s /.root/etc/shadow ]; then
        log_msg "Creating minimal /etc/shadow in overlay..."
        cat > /.root/etc/shadow << 'EOF'
root:*:19490:0:99999:7:::
live:*:19490:0:99999:7:::
nobody:*:19490:0:99999:7:::
EOF
        chmod 600 /.root/etc/shadow
    fi
    
    # Buat home directory untuk live user dengan semua folder standard
    if [ ! -d /.root/home/live ]; then
        log_msg "Creating home directory for live user with standard folders..."
        mkdir -p /.root/home/live
        
        # **FOLDER STANDARD XDG USER DIRECTORY**
        mkdir -p /.root/home/live/{Desktop,Documents,Downloads,Music,Pictures,Videos,Public,Templates}
        
        # **FOLDER STANDARD LAINNYA**
        mkdir -p /.root/home/live/{.local/share,.config,.cache,.ssh,.gnupg}
        
        # **FOLDER APLIKASI UMUM**
        mkdir -p /.root/home/live/{projects,workspace,temp,backup,bin}
        
        # Set permissions
        chown -R 1000:1000 /.root/home/live
        chmod 700 /.root/home/live
        chmod 755 /.root/home/live/{Desktop,Documents,Downloads,Music,Pictures,Videos,Public,Templates}
        chmod 700 /.root/home/live/{.ssh,.gnupg}
        
        log_msg "Created standard folders for live user"
    else
        # Jika home sudah ada, pastikan folder-folder standard ada
        log_msg "Home directory exists, ensuring standard folders..."
        
        for folder in Desktop Documents Downloads Music Pictures Videos Public Templates; do
            if [ ! -d "/.root/home/live/$folder" ]; then
                mkdir -p "/.root/home/live/$folder"
                chown 1000:1000 "/.root/home/live/$folder"
                chmod 755 "/.root/home/live/$folder"
            fi
        done
        
        for folder in projects workspace temp backup bin; do
            if [ ! -d "/.root/home/live/$folder" ]; then
                mkdir -p "/.root/home/live/$folder"
                chown 1000:1000 "/.root/home/live/$folder"
                chmod 755 "/.root/home/live/$folder"
            fi
        done
    fi
    
    # **BUAT FILE SKEL DEFAULT** (template untuk user baru)
    if [ ! -d /.root/etc/skel ]; then
        log_msg "Creating /etc/skel with standard folders..."
        mkdir -p /.root/etc/skel
        
        # Folder standard untuk semua user baru
        mkdir -p /.root/etc/skel/{Desktop,Documents,Downloads,Music,Pictures,Videos,Public,Templates}
        mkdir -p /.root/etc/skel/{.local/share,.config,.cache}
        
        # Buat file contoh
        cat > /.root/etc/skel/README.txt << 'EOF'
Welcome to your new LFS system!

This is your home directory. Standard folders have been created:
- Desktop    : For desktop files
- Documents  : For documents
- Downloads  : For downloaded files
- Music      : For music files
- Pictures   : For images
- Videos     : For video files
- Public     : For shared files
- Templates  : For document templates

Enjoy your LFS experience!
EOF
        
        # File konfigurasi bash default
        cat > /.root/etc/skel/.bashrc << 'EOF'
# ~/.bashrc: executed by bash for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
fi

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Alias definitions.
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
EOF
        
        # File profile default
        cat > /.root/etc/skel/.profile << 'EOF'
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi
EOF
        
        chmod 644 /.root/etc/skel/.bashrc /.root/etc/skel/.profile
        log_msg "/etc/skel created with standard configuration"
    fi
    
    # **BUAT XDG USER DIRS CONFIGURATION**
    if [ ! -f /.root/home/live/.config/user-dirs.dirs ]; then
        log_msg "Creating XDG user directories configuration..."
        mkdir -p /.root/home/live/.config
        cat > /.root/home/live/.config/user-dirs.dirs << 'EOF'
# This file is written by xdg-user-dirs-update
# If you want to change or add directories, just edit the line you're
# interested in.

# All localizations will respect these directories
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_TEMPLATES_DIR="$HOME/Templates"
EOF
        chown -R 1000:1000 /.root/home/live/.config
    fi
    
    # **BUAT XDG USER DIRS LOCALE** (English)
    if [ ! -f /.root/home/live/.config/user-dirs.locale ]; then
        echo "en_US" > /.root/home/live/.config/user-dirs.locale
        chown 1000:1000 /.root/home/live/.config/user-dirs.locale
    fi
    
    # **COPY SKEL KE HOME LIVE USER** (jika home kosong)
    if [ ! -f /.root/home/live/.bashrc ]; then
        log_msg "Copying skel files to live user home..."
        cp -r /.root/etc/skel/. /.root/home/live/ 2>/dev/null || true
        chown -R 1000:1000 /.root/home/live/
    fi
    
    log_msg "User setup complete with all standard folders"
}
