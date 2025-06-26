# Function wrapper is for .bashrc
# cpdesktop() {
# [ -z "$1" ] && { echo "Usage: cpdesktop <file/directory>"; return 1; }
    
local windows_user=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
local desktop_path
    
if [ -d "/mnt/c/Users/$windows_user/OneDrive/Desktop" ]; then
    desktop_path="/mnt/c/Users/$windows_user/OneDrive/Desktop"
else
    desktop_path="/mnt/c/Users/$windows_user/Desktop"
fi
    
cp -r "$1" "$desktop_path/"
# }
