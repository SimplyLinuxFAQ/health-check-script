#!/bin/bash
function usage() {
        echo "------------------"
        echo "Smart check plugin"
        echo "------------------"
        echo -e "Checks for smart errors in hdd-s.\nIn case of raid masked disk set HC_DISK with export to desired disk defaults to /dev/sda!"
}
if test "${HC_USAGE+x}"; then
    usage
    exit
fi

command -v smartctl >/dev/null 2>&1 || { echo >&2 "Script requires smartctl but it's not installed. On debian-ish systems try: sudo apt-get install smartmontools . Aborting."; exit 1; }

SERIALS=()

if ! test "${HC_VERBOSE+x}"; then
    HC_VERBOSE=false
fi

if ! test "${HC_DISK+x}"; then
    HC_DISK="/dev/sda"
fi



function smart() {
        local error=0

        # Obtain the serial
        local output=$(smartctl -v 1,raw48:54 -v 7,raw48:54 -v 195,raw48:54 -a $1)
        local serial=`echo "$output" | egrep "Serial Number:|Serial number:" | grep -v "\[No" | awk '{print $3}'`
        if [[ "${SERIALS[@]}" =~ "${serial}" ]] &&  [ ${serial} ]; then
                # allready done exit
                return 0;
        fi
        if [ ${serial} ]; then                
                echo "Checking disk: $1, Serial Number:$serial"                
                SERIALS+=(${serial})                
        fi

        # SSD Wear Level

        #var=`smartctl -a $1 | grep Wear_Leveling | awk '{print $4}' | sed 's/^0\|^00//'`
        var=`echo "$output" | egrep -i "177 Wear_Leveling|231 SSD_Life_Left|^173 Un|233 Media_Wearout_" | awk '{print $4}' | sed 's/^0\|^00//' | head -n 1`
        if [[ ${var#0} -lt 20 ]] && [[ ${var#0} -gt 0 ]]; then
                echo -e "$ERR_MARK $1 is at ${var#0}% SSD wear $END_MARK"
                error+=1
        elif [[ HC_VERBOSE ]] && [[ ${var#0} -gt 0 ]]; then
                echo -e "\t$1 is at normal value of ${var#0}% SSD wear $END_MARK"

        fi

        # Reallocated sectors on SATA drives

        #var=`smartctl -a $1 | grep Reallocated_Sector | awk '{print $10}' `
        var=`echo "$output" | grep Reallocated_Sector | awk '{print $10}' `
        if [[ $var -gt 0 ]]; then
                echo -e "$ERR_MARK $1 has $var Sector Errors $END_MARK"
                error+=1
        elif [[ HC_VERBOSE ]] && [[ "${var}" == "0" ]]; then
                echo -e "\t$1 is at normal value of ${var} Sector Errors"

        fi

        # Early Warning Offline_Uncorrectable        
        var=`echo "$output" | grep Offline_Uncorrectable | awk '{print $10}' `
        if [[ $var -gt 0 ]]; then
                echo -e "$ERR_MARK $1 has $var Offline Uncorrectable Errors $END_MARK"
                error+=1 
        elif [[ HC_VERBOSE ]] && [[ "${var}" == "0" ]]; then
                echo -e "\t$1 is at normal value of ${var} Offline Uncorrectable Errors"

        fi

        # Early Warning Raw_Read_Error_Rate
        var=`echo "$output" | egrep -i "1 Raw_Read_Error_Rate" | awk '{print $10}' | sed 's/^0\|^00//'`
        if [[ ${var#0} -gt 10 ]] && [[ ${var#0} -gt 0 ]]; then
                echo -e "$ERR_MARK $1 has a Read Error Rate of ${var#0} $END_MARK"
                error+=1
        elif [[ HC_VERBOSE ]] && [[ "${var#0}" == "0" ]]; then
                echo -e "\t$1 is at normal value of ${var#0} Read Error Rate"                
        fi

        # SAS Read errors
        var=`echo "$output" | egrep "read:" | awk '{print $8}'`
        if [[ $var -gt 0 ]]; then
                echo -e "$ERR_MARK $1 $var SAS Read Errors $END_MARK"
                error+=1                    
        elif [[ HC_VERBOSE ]] && [[ "${var}" == "0" ]]; then
                echo -e "\t$1 is at normal value of ${var} SAS Read Error"                                
        fi

        # SAS Write errors
        var=`echo "$output"  | egrep "write:" | awk '{print $8}'`
        if [[ $var -gt 0 ]]; then
                echo -e "$ERR_MARK $1 $var SAS Write Errors $END_MARK"
                error+=1
        elif [[ HC_VERBOSE ]] && [[ "${var}" == "0" ]]; then
                echo -e "\t$1 is at normal value of ${var} SAS Write Errors"                                
        fi

        # SAS Verify errors
        var=`echo "$output"  | egrep "verify:" | awk '{print $8}'`
        if [[ $var -gt 0 ]]; then
                echo -e "$ERR_MARK $1 $var SAS Verify Errors $END_MARK"                
                error+=1        
        elif [[ HC_VERBOSE ]] && [[ "${var}" == "0" ]]; then
                echo -e "\t$1 is at normal value of ${var} SAS Verify Errors"                                
        fi

        # SAS post factory defects
        var=`echo "$output"  | grep -i "grown defect" | sed 's/Elements in grown defect list: //' | grep -iv "not available"`
        if [[ $var -gt 0 ]]; then
                sleep 0
                echo -e "$WRN_MARK $1 $var SAS accumulated defects $END_MARK" 
        elif [[ HC_VERBOSE ]] && [[ "${var}" == "0" ]]; then
                echo -e "\t$1 is at normal value of ${var} SAS accumulated defects"                                
        fi

        # NVMe Media and Data Integrity Errors
        var=`echo "$output" | egrep -i "Media and Data Integrity Errors" | awk '{print $6}'`
        if [[ $var -gt 0 ]]; then        
                echo -e "$WRN_MARK $1 $var Media and Data Integrity Errors $END_MARK" 
                error+=1
        elif [[ HC_VERBOSE ]] && [[ "${var}" == "0" ]]; then
                echo -e "\t$1 is at normal value of ${var} Media and Data Integrity Errors"
        fi
        # NVMe Unsafe Shutdowns
        var=`echo "$output" | egrep -i "Unsafe Shutdowns" | awk '{print $3}'`
        if [[ $var -gt 0 ]]; then        
                echo -e "$WRN_MARK $1 $var Unsafe Shutdowns $END_MARK"         
        elif [[ HC_VERBOSE ]] && [[ "${var}" == "0" ]]; then
                echo -e "\t$1 is at normal value of ${var} Unsafe Shutdowns"
        fi

        # NVMe Percentage Used
        var=`echo "$output" | egrep -i "Percentage Used" | awk '{print $3}' | sed 's/%//'`
        if [[ ${var} -gt 75 ]]; then        
                echo -e "$WRN_MARK $1 $var Percentage Used $END_MARK"         
        elif [[ HC_VERBOSE ]] && [[ ${var} -gt 0 ]]; then
                echo -e "\t$1 is at normal value of ${var}% Percentage Used"
        fi

        # NVMe Available Spare
        var=`echo "$output" | egrep -i "Available Spare:" | awk '{print $3}' | sed 's/%//'`
        if [[ $var -gt 0 ]] && [[ $var -lt 50 ]]; then        
                echo -e "$WRN_MARK $1 $var Available Spare $END_MARK" 
                error+=1
        elif [[ HC_VERBOSE ]] &&  [[ ${var} -gt 0 ]]; then
                echo -e "\t$1 is at normal value of ${var}% Available Spare"
        fi

        # NVMe Critical Warning
        var=`echo "$output" | egrep -i "Critical Warning" | awk '{print $3}' | sed 's/0x0//'`
        if [[ $var -gt 0 ]]; then        
                echo -e "$WRN_MARK $1 $var Critical Warning $END_MARK" 
                error+=1
        elif [[ HC_VERBOSE ]] &&  [[ "${var}" = "0" ]]; then
                echo -e "\t$1 is at normal value of ${var} Critical Warning"
        fi

        return $error
}

D="-------------------------------------"
if [ "$HC_COLOR" == "y" ]; then
        ERR_MARK="\e[0;41m"
        WRN_MARK="\e[30;43m"
        OK_MARK="\e[30;42m"
        END_MARK="\e[0m"
else
        ERR_MARK="!!!"
        WRN_MARK="???"
        OK_MARK=""
        END_MARK=""
fi 

echo -e "\n\nSMART report"
echo -e "$D$D"
agg_error=0

# Check disks attached to the board directly or in passthrough
for i in `find /dev -type b -name 'sd*' | egrep '^(\/)dev(\/)sd[a-z]$'`;
do
        smart $i
        rval=$?
        agg_error+=$rval
done
for i in `find /dev -type c -name 'nvme*' | egrep '^(\/)dev(\/)nvme[0-9]$'`;
do
        smart $i
        rval=$?
        agg_error+=$rval
done

# Check disks attached to the board directly or in passthrough (BSD)
for i in `find /dev -type c -name 'pass*' | egrep '^(\/)dev(\/)pass[0-9]+$'`;
do
        smart "$i"
        rval=$?
        agg_error+=$rval
done

# Check disks behind LSISAS2008 LV
for i in `find /dev -type c -name 'sg*' | egrep '^(\/)dev(\/)sg[0-9]+$'`;
do
        smart $i
        rval=$?
        agg_error+=$rval
done

# Check disks behind a 3ware card
for i in `seq 0 20`
do
        smart "-d 3ware,$i /dev/twl0 -T permissive"
        rval=$?
        agg_error+=$rval
done

# Check scsi disks behind an lsi card 
for i in `seq 0 20`
do
        smart "-d megaraid,$i $HC_DISK -T permissive"
        rval=$?
        agg_error+=$rval
done
for i in `seq 0 20`
do
        smart "-d sat+megaraid,$i $HC_DISK -T permissive"
        rval=$?
        agg_error+=$rval
done

# Check scsi disks behind an HPcard
for i in `seq 0 20`
do
        smart "-d cciss,$i $HC_DISK -T permissive 2> /dev/null"
        rval=$?
        agg_error+=$rval
done

if [[ ${sas} ]]
then
        echo -e "---"
        echo "NOTICE: SAS error counters can be reset using sg3_utils command"
        echo "sg_logs -R /dev/device"
        echo -e "---"
fi

if [[ $agg_error -gt 0 ]]
then
        echo -e "$ERR_MARK $agg_error Errors were found $END_MARK"
        exit $agg_error
else
        echo -e "${OK_MARK}No errors were found in smart capable disks $END_MARK"
        exit 0
fi