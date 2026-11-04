#!/usr/bin/env bash

# Parameters:
# -a - Jellyfin API Key (will be asked if not present)
# -h - Help
# -u - Jellyfin URL (defaults to 'localhost:8096')

api_key=""
jf_url="localhost:8096"

print_help()
{
    echo "Usage: install.sh [OPTION]..."
    echo "Installs Jellyfin systemd-inhibit service to inhibit shutdown and idle states when there is an active Jellyfin Session."
    echo -e "  \033[1m-a\033[0m - supplies the Jellyfin API Key used to build the service (will ask if not supplied)"
    echo -e "  \033[1m-h\033[0m - displays this help and exits"
    echo -e "  \033[1m-u\033[0m - supplies the base Jellyfin URL (defaults to 'localhost:8096')"
}

while getopts ":a:u:h" opts; do
    case $opts in
        (a) api_key=${OPTARG};;
        (u) jf_url=${OPTARG};;
        (*) print_help; exit 0;;
    esac
done

if [ "$api_key" = "" ]; then
    read -p "Please enter a Jellyfin API Key: " api_key
fi

if [ "$api_key" = "" ]; then
    echo "Error - API Key is empty"
    exit 1
fi

# Test Jellyfin API Key
api_test=$(curl -o /dev/null -s -w "%{http_code}\n" -H "Authorization: MediaBrowser Token=$api_key" "$jf_url/Sessions")
if [ "$api_test" = "401" ] || [ "$api_test" = "403" ]; then
    echo "Error - API Key rejected by Jellyfin"
    exit 1
elif [ "$api_test" = "000" ]; then
    echo "Error - could not reach Jellyfin API"
    exit 1
elif [ ! "$api_test" = "200" ]; then
    echo "Error - Unknown error occured with Jellyfin API"
    exit 1
fi

echo "Installing Jellyfin systemd-inhibit Service"

#if [ -f "/usr/sbin/jellyfin-systemd-inhibit.sh" ]; then
    echo "/usr/sbin/jellyfin-systemd-inhibit.sh already exists..."
    read -p "Do you want to overwrite the script (such as to change API Key)? [y/N]: " response

    if [ "$response" == "" ] || [ "$response" != "${response#[Nn]}" ]; then
        echo "Cancelling..."
        exit 0
    fi
#fi

#sudo mkdir -p /etc/systemd/system

