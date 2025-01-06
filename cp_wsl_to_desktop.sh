windows_user=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')

cp -r $1 /mnt/c/Users/$windows_user/OneDrive/Desktop/
