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
    echo -e "\033[33mUsage: install.sh [OPTION]...\033[0m"
    echo "Installs Jellyfin systemd-inhibit service to inhibit shutdown and idle states when there is an active Jellyfin Session."
    echo -e "  \033[34m\033[1m-a\033[0m - supplies the Jellyfin API Key used to build the service (will ask if not supplied)"
    echo -e "  \033[34m\033[1m-d\033[0m - sets the delay between Jellyfin session checks, in seconds (defaults to 30)"
    echo -e "  \033[34m\033[1m-h\033[0m - displays this help and exits"
    echo -e "  \033[34m\033[1m-u\033[0m - supplies the base Jellyfin URL (defaults to 'localhost:8096')"
}

echo -e "\033[36mJellyfin systemd-inhibit Service Installer\033[0m"
echo -e "\033[36mhttps://github.com/Ethirix/jellyfin-systemd-inhibit\033[0m\n"

while getopts ":a:d:h:u" opts; do
    case $opts in
        (a) api_key=${OPTARG};;
        (d) jf_delay=${OPTARG};;
        (u) jf_url=${OPTARG};;
        (*) print_help; exit 0;;
    esac
done

if ! sudo -p "Please confirm sudo access to install Jellyfin inhibitor: " true &> /dev/null; then
    echo -e "\033[31mError - sudo required to install Jellyfin inhibitor\033[0m"
    exit 1
fi

if [ "$api_key" = "" ]; then
    read -rp "Please enter a Jellyfin API Key: " api_key
fi

if [ "$api_key" = "" ]; then
    echo -e "\033[31mError - API Key is empty\033[0m"
    exit 1
fi

# Test Jellyfin API Key
api_test=$(curl -o /dev/null -s -w "%{http_code}\n" -H "Authorization: MediaBrowser Token=$api_key" "$jf_url/Sessions")
if [ "$api_test" = "401" ] || [ "$api_test" = "403" ]; then
    echo -e "\033[31mError - API Key rejected by Jellyfin\033[0m"
    exit 1
elif [ "$api_test" = "000" ]; then
    echo -e "\033[31mError - could not reach Jellyfin API\033[0m"
    exit 1
elif [ ! "$api_test" = "200" ]; then
    echo -e "\033[31mError - Unknown error occured with Jellyfin API\033[0m"
    exit 1
fi

echo -e "\033[35mInstalling Jellyfin systemd-inhibit Service\033[0m"

if [ -f "/usr/local/bin/jellyfin-systemd-inhibit.sh" ]; then
    echo -e "\033[33m/usr/local/bin/jellyfin-systemd-inhibit.sh already exists...\033[0m"
    read -rp "Do you want to overwrite the script (such as to change API Key)? [y/N]: " response

    if [ "$response" == "" ] || [ "$response" != "${response#[Nn]}" ]; then
        echo "Cancelling..."
        exit 0
    fi
fi

sudo mkdir -p /etc/systemd/system

sudo tee /usr/local/bin/jellyfin-systemd-inhibit.sh << JELLYFIN_INHIBITOR_SCRIPT > /dev/null
#!/usr/bin/env bash

jellyfin_url=$jf_url
jellyfin_key=$api_key
jellyfin_delay=$jf_delay
pid="jellyfin-systemd-inhibitor.lock"

check_jellyfin_sessions()
{
    session_response=\$(curl -sH "Authorization: MediaBrowser Token=\$jellyfin_key" "\$jellyfin_url/Sessions?activeWithinSeconds=30")

    if [ "\$session_response" = "[]" ]; then
        return 1
    fi

    return 0
}

kill_inhibitor_process()
{
    if [ -d /run/lock/"\$pid" ]; then
        kill "\$(</run/lock/"\$pid"/pid)"
        rm -rf /run/lock/"\$pid"
    fi
}

create_inhibitor_process()
{
    if [ ! -d /run/lock/"\$pid" ]; then
        mkdir /run/lock/"\$pid"
        echo \$\$ | tee /run/lock/"\$pid"/pid

        systemd-inhibit --what=shutdown:sleep:idle:handle-lid-switch:handle-power-key \\
                        --who="Jellyfin Inhibitor" \\
                        --why="There is at least one active session in Jellyfin" \\
                        --mode=block \\
                        tail -f /dev/null &
    fi
}

trap kill_inhibitor_process EXIT

while true; do
    if check_jellyfin_sessions; then
        create_inhibitor_process
    else
        kill_inhibitor_process
    fi

    sleep "\$jellyfin_delay"s
done
JELLYFIN_INHIBITOR_SCRIPT

sudo chmod +x /usr/local/bin/jellyfin-systemd-inhibit.sh

echo -e "\033[90mWritten Jellyfin systemd-inhibit script\033[0m"

sudo tee /etc/systemd/system/jellyfin-systemd-inhibit.service << JELLYFIN_INHIBITOR_SERVICE > /dev/null
[Unit]
Description=Jellyfin systemd-inhibitor
After=jellyfin.service

[Service]
Type=simple
ExecStart=/usr/local/bin/jellyfin-systemd-inhibit.sh
Restart=always

[Install]
WantedBy=multi-user.target
JELLYFIN_INHIBITOR_SERVICE

sudo systemctl daemon-reload

echo -e "\033[90mWritten and starting jellyfin-systemd-inhibit.service\033[0m"
sudo systemctl enable --now jellyfin-systemd-inhibit.service &> /dev/null

if sudo systemctl is-active --quiet jellyfin-systemd-inhibit; then
    echo -e "\033[32mService is successfully activated\033[0m"

    echo -e "\033[32mInstallation successful\033[0m"
    echo "This service is now active in the background and will automatically start on reboot"
else
    echo -e "\033[31mError - Service failed to start\033[0m"
    echo "The service is installed, however did not activate successfully"
fi

echo -e "\033[90mTo find the logs, please use: journalctl -u jellyfin-systemd-inhibit -f\033[0m"
echo -e "\033[90mAdditionally, if there is an error with the variables in the script, please edit the script at: /usr/local/bin/jellyfin-systemd-inhibit.sh\033[0m"
