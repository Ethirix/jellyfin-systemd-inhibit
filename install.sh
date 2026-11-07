#!/usr/bin/env bash

# Parameters:
# -a - Jellyfin API Key (will be asked if not present)
# -d - Delay between Jellyfin session checks, in seconds (defaults to 30)
# -h - Help
# -u - Jellyfin URL (defaults to 'localhost:8096')

api_key=""
jf_url="localhost:8096"
jf_delay=30

print_help()
{
    echo "Usage: install.sh [OPTION]..."
    echo "Installs Jellyfin systemd-inhibit service to inhibit shutdown and idle states when there is an active Jellyfin Session."
    echo -e "  \033[1m-a\033[0m - supplies the Jellyfin API Key used to build the service (will ask if not supplied)"
    echo -e "  \033[1m-d\033[0m - sets the delay between Jellyfin session checks, in seconds (defaults to 30)"
    echo -e "  \033[1m-h\033[0m - displays this help and exits"
    echo -e "  \033[1m-u\033[0m - supplies the base Jellyfin URL (defaults to 'localhost:8096')"
}

while getopts ":a:d:h:u" opts; do
    case $opts in
        (a) api_key=${OPTARG};;
        (d) jf_delay=${OPTARG};;
        (u) jf_url=${OPTARG};;
        (*) print_help; exit 0;;
    esac
done

if ! sudo -p "Please confirm sudo access to install Jellyfin inhibitor: " true; then
    echo "Error - sudo required to install Jellyfin inhibitor"
    exit 1
fi

if [ "$api_key" = "" ]; then
    read -rp "Please enter a Jellyfin API Key: " api_key
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
    read -rp "Do you want to overwrite the script (such as to change API Key)? [y/N]: " response

    if [ "$response" == "" ] || [ "$response" != "${response#[Nn]}" ]; then
        echo "Cancelling..."
        exit 0
    fi
#fi

#sudo mkdir -rp /etc/systemd/system

tee /usr/local/bin/jellyfin-systemd-inhibit.sh << JELLYFIN_INHIBITOR_SCRIPT
#!/usr/bin/env bash

jellyfin_url=$jf_url
jellyfin_key=$api_key
jellyfin_delay=$jf_delay
pid="jellyfin-systemd-inhibitor.lock"

check_jellyfin_sessions()
{
    session_response=\$(curl -H "Authorization: MediaBrowser Token=\$jellyfin_key" "\$jellyfin_url/Sessions?activeWithinSeconds=30")

    if [ "\$session_response" = "[]" ]; then
        return 1
    fi

    return 0
}

kill_inhibitor_process()
{
    sudo kill "\$(</run/lock/"\$pid"/pid)"
    sudo rm -rf /run/lock/"\$pid"
}

create_inhibitor_process()
{
    if [ -d /run/lock/"\$pid" ]; then
        systemd-inhibit --what=shutdown:sleep:idle:handle-lid-switch:handle-power-key \\
                        --who="Jellyfin Inhibitor" \\
                        --why="There is at least one active session in Jellyfin" \\
                        --mode=block \\
                        sudo mkdir /run/lock/"\$pid" && \$\$ | sudo tee /run/lock/"\$pid"/pid \\
                            && tail -f /dev/null
    fi
}

trap kill_inhibitor_process EXIT

while true; do
    if check_jellyfin_sessions; then
        create_inhibitor_process
    else
        kill_inhibitor_process
    fi

    sleep $jellyfin_delay
done
JELLYFIN_INHIBITOR_SCRIPT

