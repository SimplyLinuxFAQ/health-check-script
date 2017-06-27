#!/bin/bash
##---------- Author : Sadashiva Murthy M ----------------------------------------------------##
##---------- Blog site : http://simplylinuxfaq.blogspot.in ----------------------------------##
##---------- Github page : https://github.com/SimplyLinuxFAQ/health-check-script ------------##
##---------- Purpose : To quickly check and report health status in a linux system.----------##
##---------- Tested on : RHEL7/6/5/, SLES12/11, Ubuntu14, Mint16, Boss6(Debian) variants.----##
##---------- Updated version : v1.0 (Updated on 25th-June-2017) -----------------------------##
##-----NOTE: This script requires root privileges, otherwise you could run the script -------##
##---- as a sudo user who got root privileges. ----------------------------------------------##
##----------- "sudo /bin/bash <ScriptName>" -------------------------------------------------##

S="************************************"
D="-------------------------------------"

MOUNT=$(mount|egrep -iw "ext4|ext3|xfs|gfs|gfs2|btrfs"|sort -u -t' ' -k1,2)
FS_USAGE=$(df -PTh|egrep -iw "ext4|ext3|xfs|gfs|gfs2|btrfs"|sort -k6n|awk '!seen[$1]++')
IUSAGE=$(df -PThi|egrep -iw "ext4|ext3|xfs|gfs|gfs2|btrfs"|sort -k6n|awk '!seen[$1]++')

#--------Checking the availability of sysstat package..........#
if [ ! -x /usr/bin/mpstat ]
then
    printf "\nError : Either \"mpstat\" command not available OR \"sysstat\" package is not properly installed. Please make sure this package is installed and working properly!, then run this script.\n\n"
    exit 1
fi

echo -e "$S Health Status Report $S"
echo -e "\nOperating System Details" 
echo -e "$D"
printf "Hostname :" $(hostname -f > /dev/null 2>&1) && printf " $(hostname -f)" || printf " $(hostname -s)"

[ -x /usr/bin/lsb_release ] &&  echo -e "\nOperating System :" $(lsb_release -d|awk -F: '{print $2}'|sed -e 's/^[ \t]*//')  || echo -e "\nOperating System :" $(cat /etc/system-release)
echo -e "Kernel Version :" $(uname -r) 
printf "OS Architecture :" $(arch | grep x86_64 2>&1 > /dev/null) && printf " 64 Bit OS\n"  || printf " 32 Bit OS\n"

#--------Print system uptime-------#
UPTIME=$(uptime)
echo $UPTIME|grep day 2>&1 > /dev/null
if [ $? != 0 ]
then
  echo $UPTIME|grep -w min 2>&1 > /dev/null && echo -e "System Uptime : "$(echo $UPTIME|awk '{print $2" by "$3}'|sed -e 's/,.*//g')" minutes"  || echo -e "System Uptime : "$(echo $UPTIME|awk '{print $2" by "$3" "$4}'|sed -e 's/,.*//g')" hours" 
else
  echo -e "System Uptime :" $(echo $UPTIME|awk '{print $2" by "$3" "$4" "$5" hours"}'|sed -e 's/,//g') 
fi
echo -e "Current System Date & Time : "$(date +%c)


#--------Check for any read-only file systems--------#
echo -e "\nChecking For Read-only File System[s]"
echo -e "$D"
echo "$MOUNT"|grep -w \(ro\) && echo -e "\n.....Read Only file system[s] found"|| echo -e ".....No read-only file system[s] found. "


#--------Check for currently mounted file systems--------#
echo -e "\n\nChecking For Currently Mounted File System[s]"
echo -e "$D$D"
echo "$MOUNT"|column -t


#--------Check disk usage on all mounted file systems--------#
echo -e "\n\nChecking For Disk Usage On Mounted File System[s]"
echo -e "$D$D"
echo -e "( 0-90% = OK/HEALTHY, 90-95% = WARNING, 95-100% = CRITICAL )"
echo -e "$D$D"
echo -e "Mounted File System[s] Utilization (Percentage Used):\n" 

echo "$FS_USAGE"|awk '{print $1 " "$7}' > /tmp/s1.out
echo "$FS_USAGE"|awk '{print $6}'|sed -e 's/%//g' > /tmp/s2.out
> /tmp/s3.out

for i in $(cat /tmp/s2.out);
do
{
  if [ $i -ge 95 ];
   then
     echo -e $i"% ------------------Critical" >> /tmp/s3.out;
   elif [[ $i -ge 90 && $i -lt 95 ]];
   then
     echo -e $i"% ------------------Warning" >> /tmp/s3.out; 
   else
     echo -e $i"% ------------------Good/Healthy" >> /tmp/s3.out;
  fi
} 
done
paste -d"\t" /tmp/s1.out /tmp/s3.out|column -t

#--------Check for any zombie processes--------#
echo -e "\n\nChecking For Zombie Processes"
echo -e "$D"
ps -eo stat|grep -w Z 1>&2 > /dev/null 
if [ $? == 0 ]
then
  echo -e "Number of zombie process on the system are :" $(ps -eo stat|grep -w Z|wc -l) 
  echo -e "\n  Details of each zombie processes found	"
  echo -e "  $D"
  ZPROC=$(ps -eo stat,pid|grep -w Z|awk '{print $2}')
  for i in $(echo "$ZPROC")
  do
      ps -o pid,ppid,user,stat,args -p $i
  done
else
 echo -e "No zombie processes found on the system."
fi

#--------Check Inode usage--------#
echo -e "\n\nChecking For INode Usage"
echo -e "$D$D"
echo -e "( 0-90% = OK/HEALTHY, 90-95% = WARNING, 95-100% = CRITICAL )"
echo -e "$D$D"
echo -e "INode Utilization (Percentage Used):\n"

echo "$IUSAGE"|awk '{print $1" "$7}' > /tmp/s1.out
echo "$IUSAGE"|awk '{print $6}'|sed -e 's/%//g' > /tmp/s2.out
> /tmp/s3.out

for i in $(cat /tmp/s2.out);
do
  if [[ $i = *[[:digit:]]* ]];
  then
  {
  if [ $i -ge 95 ];
  then
    echo -e $i"% ------------------Critical" >> /tmp/s3.out;
  elif [[ $i -ge 90 && $i -lt 95 ]];
  then
    echo -e $i"% ------------------Warning" >> /tmp/s3.out;
  else
    echo -e $i"% ------------------Good/Healthy" >> /tmp/s3.out;
  fi
  }
  else
    echo -e $i"% (Inode Percentage details not available)" >> /tmp/s3.out
  fi
done
paste -d"\t" /tmp/s1.out /tmp/s3.out|column -t


#--------Check for RAM Utilization--------#
MEM_DETAILS=$(cat /proc/meminfo)
echo -e "\n\nChecking Memory Usage Details"
echo -e "$D"
echo -e "Total RAM (/proc/meminfo) : "$(echo "$MEM_DETAILS"|grep MemTotal|awk '{print $2/1024}') "MB OR" $(echo "$MEM_DETAILS"|grep MemTotal|awk '{print $2/1024/1024}') "GB"
echo -e "Used RAM in MB : "$(free -m|grep -w Mem:|awk '{print $3}')", in GB : "$(free -m|grep -w Mem:|awk '{print $3/1024}')
echo -e "Free RAM in MB : "$(echo "$MEM_DETAILS"|grep -w MemFree|awk '{print $2/1024}')" , in GB : "$(echo "$MEM_DETAILS"|grep -w MemFree |awk '{print $2/1024/1024}')

#--------Check for SWAP Utilization--------#
echo -e "\n\nChecking SWAP Details"
echo -e "$D"
echo -e "Total Swap Memory in MB : "$(echo "$MEM_DETAILS"|grep -w SwapTotal|awk '{print $2/1024}')", in GB : "$(echo "$MEM_DETAILS"|grep -w SwapTotal|awk '{print $2/1024/1024}')
echo -e "Swap Free Memory in MB : "$(echo "$MEM_DETAILS"|grep -w SwapFree|awk '{print $2/1024}')", in GB : "$(echo "$MEM_DETAILS"|grep -w SwapFree|awk '{print $2/1024/1024}')

#--------Check for Processor Utilization (current data)--------#
echo -e "\n\nChecking For Processor Utilization"
echo -e "$D"
echo -e "Manufacturer: "$(dmidecode -s processor-manufacturer|uniq)
echo -e "Processor Model: "$(dmidecode -s processor-version|uniq)
if [ -e /usr/bin/lscpu ]
then
{
	echo -e "No. Of Processor(s) :" $(lscpu|grep -w "Socket(s):"|awk -F: '{print $2}') 
	echo -e "No. of Core(s) per processor :" $(lscpu|grep -w "Core(s) per socket:"|awk -F: '{print $2}') 
}
else
{
	echo -e "No. Of Processor(s) Found :" $(grep -c processor /proc/cpuinfo) 
	echo -e "No. of Core(s) per processor :" $(grep "cpu cores" /proc/cpuinfo|uniq|wc -l) 
}
fi
echo -e "\nCurrent Processor Utilization Summary :\n"
mpstat|tail -2

#--------Check for load average (current data)--------#
echo -e "\n\nChecking For Load Average"
echo -e "$D"
echo -e "Current Load Average : $(uptime|grep -o "load average.*"|awk '{print $3" " $4" " $5}')"

#------Print most recent 3 reboot events if available----#
echo -e "\n\nMost Recent 3 Reboot Events"
echo -e "$D$D" 
last -x 2> /dev/null|grep reboot 1> /dev/null && /usr/bin/last -x 2> /dev/null|grep reboot|head -3 || echo -e "No reboot events are recorded."

#------Print most recent 3 shutdown events if available-----#
echo -e "\n\nMost Recent 3 Shutdown Events"
echo -e "$D$D"
last -x 2> /dev/null|grep shutdown 1> /dev/null && /usr/bin/last -x 2> /dev/null|grep shutdown|head -3 || echo -e "No shutdown events are recorded."

#--------Print top 5 most memory consuming resources---------#
echo -e "\n\nTop 5 Memory Resource Hog Processes"
echo -e "$D$D"
ps -eo pmem,pcpu,pid,ppid,user,stat,args | sort -k 1 -r | head -6|sed 's/$/\n/'

#--------Print top 5 most CPU consuming resources---------#
echo -e "\n\nTop 5 CPU Resource Hog Processes"
echo -e "$D$D"
ps -eo pcpu,pmem,pid,ppid,user,stat,args | sort -k 1 -r | head -6|sed 's/$/\n/'
