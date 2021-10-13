#!/usr/bin/env bash

trap "kill 0" SIGINT

connectivity_check_frequency=30
speed_test_frequency=3600
alreadyDownArray=()
gatewayIP=$(ip route get 8.8.8.8 | awk {'print $3'})
echo "Gateway IP is $gatewayIP"

connectivity_check() {
    tests_passed=0
    tests_failed=0
    noResponseArray=()
    
    # Array of IP addresses to ping whilst checking connectivity
    # Google , Cloudflare , Level 3 DNS, Open DNS Virgin Media DNS
    declare -a ExternalIPAddresses=(\
    "8.8.8.8" \
    "8.8.4.4" \
    "1.1.1.1" \
    "4.2.2.1" \
    "4.2.2.5" \
    "208.67.222.222" \
    "208.67.220.220" \
    "194.168.4.100" \
    "194.168.8.100" \
    )
#    declare -a ExternalIPAddresses=(\
#    "192.168.0.146" "192.168.1.11" "192.168.2.22" "192.168.4.44" "192.168.9.99" "192.168.6.66" "192.168.3.33" \
#    )

    for i in "${!alreadyDownArray[@]}"; do
        ping -c 1 -w 1 ${alreadyDownArray[i]} > /dev/null
        if [ $? -eq  0 ]; then
            # Test Successful, No action
            echo "INFO - Service has come UP : "${alreadyDownArray[i]}
#            alreadyDownArray=( "${alreadyDownArray[@]}/${alreadyDownArray[i]}" )
            unset 'alreadyDownArray[i]'
        fi
    done
    
    for ExternalService in "${ExternalIPAddresses[@]}"; do
       ping -c 1 -w 1 $ExternalService > /dev/null #&& result="PASS" || result="FAIL"
        if [ $? -eq  0 ]; then
                # Test Successful, No action
                ((tests_passed+=1));
        else
                # Test Failed, check if it was already down and report if not
                ((tests_failed+=1));
                noResponseArray+=($ExternalService)
                # Were they already down?
                alreadyDownTest=false

                for alreadyDown in "${alreadyDownArray[@]}"; do
                        if [ $ExternalService = $alreadyDown ]; then
                            # Service was already down. Move on
                            alreadyDownTest=true
                            break
                        fi
                done
                # Service was previously up. Add to down list.
                if [ "$alreadyDownTest" != true ]; then
                    echo "INFO - Service has gone DOWN : $ExternalService"
                    alreadyDownArray+=("$ExternalService")                            
                fi
        fi
    done
    # Do the math: count/total , then percent
    tests_passedPercent1=$(awk "BEGIN{printf ($tests_passed / ${#ExternalIPAddresses[@]});exit}")
    tests_passedPercent=$(awk "BEGIN{printf ($tests_passedPercent1*100);exit}")

    if [ $tests_failed -eq  ${#ExternalIPAddresses[@]} ]; then
        ping -c 1 -w 1 $gatewayIP > /dev/null #&& result="PASS" || result="FAIL"
        if [ $? -eq  0 ]; then
                # Test Successful, No action
                echo "ALERT - All external connectivity checks failed. Gateway is still Online.";
        else
                echo "ALERT - All connectivity checks are failing. Gateway is Offline.";
        fi
    fi
    echo  $(date +"%T %d-%b-%y") > /var/log/lastConnectivityCheck.log
}

speed_test() {
    speedtest=speedtest.py
    if [ ! -f "$speedtest" ]; then
        echo "speedtest.py does NOT exist. Downloading"
        curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py > $speedtest 
    fi
    uploadspeed=$(python $speedtest --no-download | grep Mbit | awk {'print $2'})
    downloadspeed=$(python $speedtest --no-upload | grep Mbit | awk {'print $2'})
    echo "SPEEDTEST - $downloadspeed Mbit/s Down - $uploadspeed Mbit/s Up"
}

if [ ! -f "/var/log/lastConnectivityCheck.log" ]; then
    echo "Monitoring Started - No last known check time"
else
    echo "Monitoring Started - Last Known Check $(cat /var/log/lastConnectivityCheck.log)"
fi

while true; do connectivity_check ; sleep $connectivity_check_frequency;done&
while true; do speed_test ; sleep $speed_test_frequency;done&

while true;
do
  sleep 86400
done

