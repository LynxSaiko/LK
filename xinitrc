#!/bin/sh
# ~/.xinitrc - dijalankan oleh startx / xinit

# === Bagian default sistem (jangan dihapus, penting untuk resources & setup) ===
userresources=$HOME/.Xresources
usermodmap=$HOME/.Xmodmap
sysresources=/etc/X11/xinit/.Xresources
sysmodmap=/etc/X11/xinit/.Xmodmap

# Merge system defaults
if [ -f $sysresources ]; then
    xrdb -merge $sysresources
fi

if [ -f $sysmodmap ]; then
    xmodmap $sysmodmap
fi

# Merge user defaults
if [ -f "$userresources" ]; then
    xrdb -merge "$userresources"
fi

if [ -f "$usermodmap" ]; then
    xmodmap "$usermodmap"
fi

# Source scripts di /etc/X11/xinit/xinitrc.d/ (untuk dbus, polkit, dll.)
if [ -d /etc/X11/xinit/xinitrc.d ] ; then
    for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
        [ -x "$f" ] && . "$f"
    done
    unset f
fi

# Setup XDG_RUNTIME_DIR (penting untuk pulseaudio, pipewire, dll.)
if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR=/tmp/xdg-$(id -u)
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
fi

# === Optional global autostart (berlaku untuk semua session) ===
# Contoh: compositor, numlock, unclutter mouse, dsb.
# picom --experimental-backends &     # kalau pakai picom
# numlockx on &
# unclutter -idle 1 &                 # sembunyikan cursor saat idle

# === Pilih session berdasarkan argumen startx (default: dwm) ===
session="${1:-dwm}"

case "$session" in
    xfce|xfce4)
        # XFCE biasanya handle dbus sendiri, tapi kalau perlu:
        # dbus-launch --exit-with-session startxfce4
        exec startxfce4 >/dev/null 2>&1
        ;;

    openbox)
        # Optional untuk Openbox: autostart panel, wallpaper, terminal
        # tint2 &                           # kalau pakai tint2 panel
        # feh --bg-fill ~/Pictures/wallpaper.jpg &
        # urxvt &                           # terminal auto-start
        exec openbox-session >/dev/null 2>&1
        ;;

    dwm)
        # Khusus dwm: autostart favorit kamu
        # pulseaudio --start &              # kalau pakai pulse (atau pipewire)
        # feh --bg-fill ~/Pictures/wallpaper.jpg &   # set wallpaper
        # picom &                           # compositor untuk transparency/shadow
        # ~/.dwm/autostart.sh &             # kalau kamu punya script ini (jalankan dulu)
        # urxvt &                           # terminal auto-start di dwm

        # Jalankan dwm (sesuaikan path kalau bukan /usr/local/bin/dwm)
        exec /usr/local/bin/dwm >/dev/null 2>&1
        # atau kalau di $PATH biasa: exec dwm >/dev/null 2>&1
        ;;

    *)
        echo "Session tidak dikenal: $session"
        echo "Pilihan tersedia: xfce, openbox, dwm"
        echo "Contoh: startx xfce"
        exit 1
        ;;
esac
