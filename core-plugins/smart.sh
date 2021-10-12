#!/usr/bin/env bash
command -v smartctl >/dev/null 2>&1 || { echo >&2 "Script requires smartctl but it's not installed. On debian-ish systems try: sudo apt-get install smartmontools . Aborting."; exit 1; }
SERIALS=()

function smart() {
        local error=0

        # Obtain the serial
        output=$(smartctl -v 1,raw48:54 -v 7,raw48:54 -v 195,raw48:54 -a $1)
        serial=`echo "$output" | egrep "Serial Number:|Serial number:" | grep -v "\[No" | awk '{print $3}'`
        if [[ "${SERIALS[@]}" =~ "${serial}" ]] &&  [ ${serial} ]; then
                # allready done exit
                return 0;
        fi
        if [ ${serial} ]; then
                SERIALS+=(${serial})                
        fi

        # SSD Wear Level

        #var=`smartctl -a $1 | grep Wear_Leveling | awk '{print $4}' | sed 's/^0\|^00//'`
        var=`echo "$output" | egrep -i "177 Wear_Leveling|231 SSD_Life_Left|^173 Un|233 Media_Wearout_" | awk '{print $4}' | sed 's/^0\|^00//' | head -n 1`
        if [[ ${var#0} -lt 20 ]] && [[ ${var#0} -gt 0 ]]; then
                echo -e "\e[0;41m$1 is at ${var#0}% SSD wear\e[0m"
                error+=1
        fi

        # Reallocated sectors on SATA drives

        #var=`smartctl -a $1 | grep Reallocated_Sector | awk '{print $10}' `
        var=`echo "$output" | grep Reallocated_Sector | awk '{print $10}' `
        if [[ $var -gt 0 ]]; then
                echo -e "\e[0;41m$1 has $var Sector Errors\e[0m"
                error+=1
        fi

        # Early Warning Offline_Uncorrectable

        #var=`smartctl -a $1 | grep Offline_Uncorrectable | awk '{print $10}' `
        var=`echo "$output" | grep Offline_Uncorrectable | awk '{print $10}' `
        if [[ $var -gt 0 ]]; then
                echo -e "\e[0;41m$1 has $var Offline Uncorrectable Errors\e[0m"
                error+=1       
        fi

        # Early Warning Raw_Read_Error_Rate

        var=`echo "$output" | egrep -i "1 Raw_Read_Error_Rate" | awk '{print $10}' | sed 's/^0\|^00//'`
        if [[ ${var#0} -gt 10 ]] && [[ ${var#0} -gt 0 ]]; then
                echo -e "\e[0;41m$1 has a Read Error Rate of ${var#0}\e[0m"
                error+=1
        fi

        # SAS Read errors

        #var=`smartctl -a $1 | egrep "read:" | awk '{print $8}'`
        var=`echo "$output" | egrep "read:" | awk '{print $8}'`
        if [[ $var -gt 0 ]]; then
                echo -e "\e[0;41m$1 $var SAS Read Errors\e[0m"
                error+=1    
        fi

        # SAS Write errors

        #var=`smartctl -a $1 | egrep "write:" | awk '{print $8}'`
        var=`echo "$output"  | egrep "write:" | awk '{print $8}'`
        if [[ $var -gt 0 ]]; then
                echo -e "\e[0;41m$1 $var SAS Write Errors\e[0m"
                error+=1
        fi

        # SAS Verify errors

        #var=`smartctl -a $1 | egrep "verify:" | awk '{print $8}'`
        var=`echo "$output"  | egrep "verify:" | awk '{print $8}'`
        if [[ $var -gt 0 ]]; then
                echo -e "\e[0;41m$1 $var SAS Verify Errors\e[0m"                
                error+=1        
        fi

        # SAS post factory defects

        var=`echo "$output"  | grep -i "grown defect" | sed 's/Elements in grown defect list: //' | grep -iv "not available"`
        if [[ $var -gt 0 ]]; then
                sleep 0
                echo -e "\e[30;43m$1 $var SAS accumulated defects\e[0m"                        
        fi


        return $error
}

agerror=0

# Check disks attached to the board directly or in passthrough
#for i in `ls /dev/sd*|egrep '^(\/)dev(\/)sd[a-z]$'`;
for i in `find /dev -type b -name 'sd*' | egrep '^(\/)dev(\/)sd[a-z]$'`;
do
        smartcheck $i $DEBUG
        rval=$?
        agerror=$(($agerror + $rval))
done
# Check disks attached to the board directly or in passthrough (BSD)
#for i in `ls /dev/pass*|egrep '^(\/)dev(\/)pass[0-9]+$'`;
for i in `find /dev -type c -name 'pass*' | egrep '^(\/)dev(\/)pass[0-9]+$'`;
do
        smartcheck "$i" $DEBUG
        rval=$?
        agerror=$(($agerror + $rval))
done

# Check disks behind LSISAS2008 LV
#for i in `ls /dev/sg*|egrep '^(\/)dev(\/)sg[0-9]+$'`;
for i in `find /dev -type c -name 'sg*' | egrep '^(\/)dev(\/)sg[0-9]+$'`;
do
        smartcheck $i $DEBUG
        rval=$?
        agerror=$(($agerror + $rval))
done
# Check disks behind a 3ware card
for i in `seq 0 20`
do
        smartcheck "-d 3ware,$i /dev/twl0 -T permissive" $DEBUG
        rval=$?
        agerror=$(($agerror + $rval))
done

# Check scsi disks behind an lsi card - fixed at sda at the moment
for i in `seq 0 20`
do
        smartcheck "-d megaraid,$i /dev/sda -T permissive" $DEBUG
        rval=$?
        agerror=$(($agerror + $rval))
done

#Check disks behind an lsi card - fixed at sda at the moment
for i in `seq 0 20`
do
        smartcheck "-d sat+megaraid,$i /dev/sda -T permissive" $DEBUG
        rval=$?
        agerror=$(($agerror + $rval))
done

# Check scsi disks behind an HPcard - fixed at sda at the moment
for i in `seq 0 20`
do
        smartcheck "-d cciss,$i /dev/sda -T permissive 2> /dev/null" $DEBUG
        rval=$?
        agerror=$(($agerror + $rval))
done


if [[ ${DEBUG} &&  ${sas} ]]
then
        echo -e "---"
        echo "NOTICE: SAS error counters can be reset using sg3_utils command"
        echo "sg_logs -R /dev/device"
        echo -e "---"
fi

if [[ $agerror -gt 0 ]]
then
        echo -e "\e[0;41m$agerror Errors were found\e[0m"
        exit $agerror
else
        echo -e "\e[30;42mNo errors were found\e[0m"
        exit 0
fi