#!/usr/bin/env bash

service_found=0
script_found=0

echo -e "\033[36mJellyfin systemd-inhibit Service Uninstaller\033[0m"
echo -e "\033[36mhttps://github.com/Ethirix/jellyfin-systemd-inhibit\033[0m\n"

if ! sudo -p "Please confirm sudo access to uninstall Jellyfin inhibitor: " true &> /dev/null; then
    echo -e "\033[31mError - sudo required to install Jellyfin inhibitor\033[0m"
    exit 1
fi

echo -e "\033[35mUninstalling Jellyfin systemd-inhibit Service\033[0m"

if systemctl list-unit-files jellyfin-systemd-inhibit.service &> /dev/null; then
    sudo systemctl disable --now jellyfin-systemd-inhibit.service &> /dev/null
    sudo rm /etc/systemd/system/jellyfin-systemd-inhibit.service
    echo -e "\033[90mRemoved jellyfin-systemd-inhibit.service\033[0m"
else
    echo -e "\033[33mWarning - Service not found\033[0m"
    service_found=1
fi

if [ -f "/usr/local/bin/jellyfin-systemd-inhibit.sh" ]; then
    sudo rm /usr/local/bin/jellyfin-systemd-inhibit.sh
    echo -e "\033[90mRemoved jellyfin-systemd-inhibit.sh\033[0m"
else
    echo -e "\033[33mWarning - Script not found\033[0m"
    script_found=1
fi

sudo systemctl daemon-reload

if [ $script_found -eq 0 ] && [ $service_found -eq 0 ]; then
    echo -e "\033[32mJellyfin systemd-inhibit Service has been uninstalled\033[0m"
elif [ $script_found -ne $service_found ]; then
    echo -e "\033[33mJellyfin systemd-inhibit Service has been partially uninstalled\033[0m"
else
    echo -e "\033[31mJellyfin systemd-inhibit Service has not been uninstalled - no files found\033[0m"
fi


