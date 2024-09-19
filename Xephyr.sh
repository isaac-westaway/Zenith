Xephyr -br -ac -noreset -screen 1024x768 :0 &
sleep 1
DISPLAY=:0 zig-out/bin/zwm &
DISPLAY=:0 kitty