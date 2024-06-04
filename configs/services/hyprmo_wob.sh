[Unit]
Description=A lightweight overlay volume/backlight/progress/anything bar for Wayland

[Service]
Type=simple
Restart=always
ExecStart=/usr/bin/hyprmo_ob.sh wob
