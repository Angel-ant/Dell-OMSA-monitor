#!/bin/bash
#encoding:utf-8
#2015/6/17
#lianglian8866@163.com

#$1	选择模式discovery或get-data
#$2 	检测内容,监控项名称
#$3 	发现设备,LLD发现

##判断OMSA套件支持
#if [ ! -e /opt/dell/srvadmin/bin/omreport ]
#then 	yum install srvadmin-omacs srvadmin-storage srvadmin-storelib srvadmin-isvc-snmp srvadmin-argtable2 srvadmin-storage-cli srvadmin-sysfsutils srvadmin-omcommon srvadmin-idrac7 srvadmin-rac4-populator srvadmin-idrac-vmcli srvadmin-realssd srvadmin-idracadm7 srvadmin-ominst srvadmin-deng-snmp srvadmin-omacore srvadmin-rac-components srvadmin-idrac-ivmcli srvadmin-itunnelprovider srvadmin-racdrsc srvadmin-omilcore srvadmin-isvc srvadmin-racsvc srvadmin-racadm4 srvadmin-oslog srvadmin-cm srvadmin-smcommon srvadmin-nvme srvadmin-racadm5 srvadmin-deng srvadmin-xmlsup srvadmin-storage-snmp srvadmin-rnasoap srvadmin-idrac-snmp srvadmin-storelib-sysfs srvadmin-idracadm srvadmin-hapi
#fi
#
##解决OMSA系统不支持问题
#true=$(egrep -w -o "OEM String 1" /opt/dell/srvadmin/sbin/CheckSystemType >> /dev/null && echo $?)
#if [ $true ! -eq 0 ]
#thensed -i '97 s/"OEM String 1"/"Vendor"/' /opt/dell/srvadmin/sbin/CheckSystemType
#fi

#获取硬件信息命令(通过DELL OMSA组件)
CMD="/opt/dell/srvadmin/bin/omreport chassis"
MegaCli="sudo /usr/sbin/MegaCli"
check=$2  #检查项定义为全局变量，方便到函数中使用

#===========================================================硬件自动发现================================================================#
discovery(){
case $check in
        fans)
        data=($($CMD fans | grep "Probe Name" |awk -F ":" '{print $2}'| awk -F "System Board " '{gsub(" ","_",$2)} {print $2}')) 
        ;;
        memory)
	memory=($($CMD memory |grep "Connector Name" | egrep -o [A-B][0-9]\{\1,}))
        num=0
        for dev in ${memory[@]}
        do
                status=$($CMD memory | egrep -A 2 -B 2 "$dev" | grep "Status" |awk -F ": " '{print $2}')
                if [ $status != "Unknown" ];then
                        data[$num]=$dev
                        let num++
                fi
        done
        ;;
        cpu)
        data=($($CMD processors | grep "Connector Name" | awk -F ": " '{print $2}'))
        ;;
        temp)
        data=($($CMD temps | grep "Probe Name" |awk -F ": " '{gsub(" ","_",$2)} {print $2}'))
        ;;
        interface)
        data=($($CMD nics | grep "Interface Name" |awk -F ": " '{print $2}'))
        ;;
        volts)
        data=($($CMD volts | grep "Probe Name" |awk -F ": " '{gsub(" ","_",$2)} {print $2}'))
        #num=0
        #for test in ${volts[@]}
        #do
        #        dev=$(echo $test | awk '{gsub("_"," ",$0)}  {print $0}')
        #        status=$($CMD volts | egrep -A 5 -B 2 "$dev" | grep "Status" |awk -F ": " '{print $2}')
        #        if [ $status != "Unknown" ];then
        #                true=$(echo $dev | awk '{gsub(" ","_",$0)}  {print $0}')
        #                data[$num]=$true
        #                let num++
        #        fi
        #done
        ;;
        power)
        data=($($CMD pwrmonitoring | egrep -w -A 2 "Amperage" | grep "Current" | awk -F " :" '{gsub(" ","_",$1)} {print $1}'))
        ;;
        disk)
        data=($($MegaCli -PDList -aALL | grep "Slot Number: " | awk -F ": " '{print $2}'))
        ;;
	raid)
	data=($($MegaCli -cfgdsply -aALL |egrep "^DISK GROUP: " |awk -F ": " '{print $2}'))
	;;
esac

#将发现的数据以JSON形式打印
         printf '{\n'
            printf '\t"data":[\n'
               for key in ${!data[@]}
                   do
                       if [[ "${#data[@]}" -gt 1 && "${key}" -ne "$((${#data[@]}-1))" ]];then
                          printf '\t {\n'
                          printf "\t\t\t\"{#DEV}\":\"${data[${key}]}\"},\n"
                     else [[ "${key}" -eq "((${#data[@]}-1))" ]]
                          printf '\t {\n'
                          printf "\t\t\t\"{#DEV}\":\"${data[${key}]}\"}\n"
                       fi
               done
                          printf '\t ]\n'
                          printf '}\n'

}
#============================================================获取数据=================================================================#
#这里放回结果0或1都是要设置触发器告警
#1为ok,0为故障2位不支持
discovery_dev=$3
get-data(){

#检测OMSA是否启动正常
omsa_status=$(ps aux | grep srvadmin |wc -l)
if [ $omsa_status -le 4 ]
then exit 0
fi

case $check in
        fans_zhuansu) #风扇转速
		discovery_dev=$(echo $discovery_dev |awk '{gsub("_"," ",$0)}  {print $0}')  #转换到实际格式
                $CMD fans |egrep -w -A 5 -B 2 "$discovery_dev" | grep Reading |awk -F ": " '{print $2}' |awk -F " RPM" '{print $1}'
                ;;
        fans_status) #风扇状态
		discovery_dev=$(echo $discovery_dev |awk '{gsub("_"," ",$0)}  {print $0}')
                fans_status=$($CMD fans |egrep -w -A 5 -B 2 "$discovery_dev" |grep Status |awk -F ": " '{print $2}')
                if [ "$fans_status" = "Ok" ]
                then    echo 1
                else    echo 0
                fi
                ;;
        hostname) #主机名
                $CMD info | grep "Host Name" | awk -F ": " '{print $2}'
                ;;
        server_model) #机箱型号
                $CMD info | grep "Chassis Model" | awk -F ": " '{print $2}'
                ;;
        server_lock) #机箱锁状态检测
                Present_status=$($CMD info | grep "Chassis Lock" | awk -F ": " '{print $2}')
                if [ "$Present_status" = "Present" ]
                then    echo 1 #锁ok百D
		elif [ -z "$Present_status" ]
		then 	echo 2
                else    echo 0 #锁有问题百D
                fi
                ;;
        server_tag) #资产编号
                $CMD info | grep "Chassis Service Tag" | awk -F ": " '{print $2}'
                ;;
        server_code) #快速服务号
                $CMD info | grep "Express Service Code" | awk -F ": " '{print $2}'
                ;;
        intrusion_check) #入侵检测
                intrusion_status=$($CMD intrusion | grep "Status" | awk -F ": " '{print $2}')
                if [ "$intrusion_status" = "Ok" ]
                then    echo 1
                else    echo 0
                fi
                ;;
        memory_status) #内存状态
                memory_status=$($CMD memory |  egrep -A 2 -B 2 "$discovery_dev" | grep "Status" | awk -F ": " '{print $2}')
                if [ "$memory_status" = "Ok" ]
                then    echo 1 #表示ok
                elif [ "$memory_status" = "Unknown" ]
                then    echo 2 #表示没有
                else    echo 0 #表示有问题的
                fi
                ;;
        memory_slots_num) #服务器可使用内存插槽数量
                $CMD memory | grep "Slots Available" | awk -F ": " '{print $2}'
                ;;
        memory_slots_used) #服务器已使用内存插槽
                $CMD memory | grep "Slots Used" | awk -F ": " '{print $2}'
                ;;
        memory_max_used) #服务器最大支持使用的内存容量
                expr $($CMD memory | grep "Total Installed Capacity                     : " | awk -F ": " '{print $2}' | awk '{print $1}') / 1024
                ;;
        memory_size) #内存大小
                memory_size=$(expr $($CMD memory | egrep -A 2 -B 2 "$discovery_dev" | grep "Size" | awk -F ": " '{print $2}' | awk '{print $1}') / 1024 2> /dev/null)
		if [ -z $memory_size ];then echo 2;else echo $memory_size; fi
                ;;
        memory_type)  #内存类型
                memory_type=$($CMD memory | egrep -A 2 -B 2 "$discovery_dev" | grep "Type" | awk -F ": " '{print $2}' | awk '{print $1}')
                if [ "$memory_type" = "[Not" ]
                then    echo "Unknown"
                else    echo $memory_type
                fi
                ;;
        cpu_status) #CPU状态
                cpu_status=$($CMD processors | egrep -w -A 6 -B 1 "$discovery_dev" | grep "Status" | awk -F ": " '{print $2}')
                if [ "$cpu_status" = "Ok" ]
                then    echo 1  #表示ok
                elif [ "$cpu_status" = "Unknown" ]
                then    echo 2  #表示没有
                else    echo 0  #表示有问题的
                fi
                ;;
        cpu_type)  #CPU类型
                $CMD processors | egrep -w -A 5 -B 2 "$discovery_dev" | grep "Processor Brand" | awk -F ": " '{print $2}'
                ;;
        cpu_core)  #CPU核心?0
                $CMD processors | egrep -w -A 5 -B 2 "$discovery_dev" | grep "Core Count" | awk -F ": " '{print $2}'
                ;;
             temp)  #机箱温度,单位℃
                discovery_dev=$(echo $discovery_dev | awk '{gsub("_"," ",$0)}  {print $0}')
                $CMD temps | egrep -w -A 5 -B 2 "$discovery_dev" | grep "Reading" | awk -F ": " '{print $2}' | awk '{print $1}'
                ;;
        temp_status) #机箱温度状态
                discovery_dev=$(echo $discovery_dev |awk '{gsub("_"," ",$0)}  {print $0}')
                temp_status=$($CMD temps | egrep -w -A 5 -B 2 "$discovery_dev" | grep "Status" | awk -F ": " '{print $2}')
                if [ "$temp_status" = "Ok" ]
                then    echo 1
                else    echo 0
                fi
                ;;
        interface_status)  #网卡连接状态
                interface_status=$($CMD nics | egrep -w -A 4 -B 1 "$discovery_dev" | grep "Connection Status" | awk -F ": " '{print $2}')
                if [ "$interface_status" = "Connected" ]
                then    echo 1  
                elif [ "$interface_status" = "Disabled" ]
                then    echo 0  
                fi
                ;;
        interface_vendor)  #网卡厂商
                $CMD nics | egrep -w -A 4 -B 1 "$discovery_dev" | grep "Vendor" | awk -F ": " '{print $2}'
                ;;
        interface_type) #网卡类型
                $CMD nics | egrep -w -A 4 -B 1 "$discovery_dev" | grep "Description" | awk -F ": " '{print $2}'
                ;;
        volts_status)  #组件电压状态
                discovery_dev="$(echo $discovery_dev |awk '{gsub("_"," ",$0)}  {print $0}')"
                volts_status=$($CMD volts | egrep -w -A 5 -B 2 "$discovery_dev" | grep "Reading" | awk -F ": " '{print $2}' | awk '{print $1}')
		status=$($CMD volts | egrep -w -A 5 -B 2 "$discovery_dev" | grep "Status" |awk -F ": " '{print $2}') 
                if [ $status = "Unknown" ]
                then    echo 2
                else
                        if [ "$volts_status" = "Good" ]
                        then    echo 1  #1表示OK的
                        elif [ $volts_status -gt 10 ]
                        then    echo $volts_status
                        else    echo 0
                        fi
                fi
                ;;
        cmos_status) #CMOS电池状态
                cmos_status=$($CMD batteries | grep "Status" | awk -F ": " '{print $2}')
                if [ "$cmos_status" = "Ok" ]
                then    echo 1 
		elif [ -z $cmos_status ]
		then 	echo 2
                else    echo 0
                fi
                ;;
        power_status) #电池状态
                status=$($CMD pwrmonitoring |grep "not support power monitoring" &> /dev/null && echo $?)
                power_status=$($CMD pwrmonitoring | grep "Status" | awk -F ": " '{print $2}')
                if [ "$power_status" = "Ok" ];then    
                        echo 1
                elif [ $status = 0 ];then
                        echo 2
                else    echo 0
                fi
                ;;
        power_dissipation)  #电源功耗（设备在单位时间中所消耗的能源的数量）,单位瓦特(W)
                power_dissipation=$($CMD pwrmonitoring | egrep -w -B 2 -A 3 "System Board Pwr Consumption" | grep "Reading" | awk -F ": " '{print $2}' | awk '{print $1}')
		if [ -z $power_dissipation ];then exit 0;else echo $power_dissipation; fi 
                ;;
        power_consumption) #电源能耗，单位千瓦时（kwh）
                power_consumption=$($CMD pwrmonitoring | egrep -w -A 3 "Energy Consumption" | grep "Reading" | awk -F ": " '{print $2}' | awk '{print $1}')
		if [ -z $power_consumption ];then exit 0;else echo $power_consumption; fi 
                ;;
        power_peak_Watt)  #系统峰值功率,单位瓦特（W）
                power_peak_Watt=$($CMD pwrmonitoring | egrep -w -A 3 "System Peak Power" | grep "Peak Reading " | awk -F ": " '{print $2}' | awk '{print $1}')
		if [ -z $power_peak_Watt ];then exit 0;else echo $power_peak_Watt; fi 
                ;;
        power_peak_Amperage)  #系统峰值安培，单位安培（A）
                power_peak_Amperage=$($CMD pwrmonitoring | egrep -w -A 3 "System Peak Amperage" | grep "Peak Reading " | awk -F ": " '{print $2}' | awk '{print $1}')
		if [ -z $power_peak_Amperage ];then exit 0;else echo $power_peak_Amperage; fi 
                ;;
        power_in) #电源接入电流
                discovery_dev=$(echo $discovery_dev |awk '{gsub("_"," ",$0)}  {print $0}')
                $CMD pwrmonitoring | grep "$discovery_dev" | awk -F ": " '{print $2}' | awk '{print $1}'
                ;;
        bmc)
                $CMD bmc |egrep -w -A 14 "Device Type"
                ;;
        disk_connect_status) #硬盘连接状态
                disk_connect_status=$($MegaCli -PDList -aALL | grep -A 40 -B 1 "Slot Number: $discovery_dev" | grep "Firmware state: " |awk -F ": " '{print $2}')
                if [[ "$disk_connect_status" == *Spun" "Up* || "$disk_connect_status" == *JBOD* ]]
                then echo 1
                else echo 0
                fi
                ;;
	disk_raid_status)
		disk_raid_status=$($MegaCli -cfgdsply -aALL | egrep -A 13 "^DISK GROUP: $discovery_dev" | grep "State               :"|awk -F ": " '{print $2}')
		if [ $disk_raid_status = "Optimal" ];then echo 1;else echo 0;fi
		;;
        disk_media_status) #硬盘连接错误数
                $MegaCli -PDList -aALL | grep -A 40 -B 1 "Slot Number: $discovery_dev" | grep "Media Error Count: " |awk -F ": " '{print $2}'
		;;
        disk_other_status) #硬盘其他错误数
                $MegaCli -PDList -aALL | grep -A 40 -B 1 "Slot Number: $discovery_dev" | grep "Other Error Count: " |awk -F ": " '{print $2}'
                ;;
        disk_type) #硬盘类型
                $MegaCli -PDList -aALL | grep -A 40 -B 1 "Slot Number: $discovery_dev" | grep "PD Type: " |awk -F ": " '{print $2}'
                ;;
        disk_info) #硬盘信息
                $MegaCli -PDList -aALL | grep -A 40 -B 1 "Slot Number: $discovery_dev" | grep "Inquiry Data:" |awk -F ": " '{print $2}' | awk '{print $2,$3,$4,$5,$6}'
                ;;
        disk_sudu) #硬盘传输速度
                disk_sudu$MegaCli -PDList -aALL | grep -A 40 -B 1 "Slot Number: $discovery_dev" | egrep -w "Device Speed:" |awk -F ": " '{print $2}'
                ;;
        bbu_voltage) #BBU电压,单位mV
                bbu_voltage=$($MegaCli -AdpBbuCmd -GetBbuStatus -aALL | grep "Voltage: " | awk -F ": " '{print $2}' |awk '{print $1}')
		if [ -z $bbu_voltage ]
		then exit 0
		else echo $bbu_voltage
		fi
                ;;
        bbu_current) #BBU电流,单位mA
                bbu_current=$($MegaCli -AdpBbuCmd -GetBbuStatus -aALL | grep "Current: " | awk -F ": " '{print $2}' |awk '{print $1}')
                if [ -z $bbu_current ]
                then exit 0
                else echo $bbu_current
                fi
                ;;
        bbu_temperature) #BBU温度
                bbu_temperature=$($MegaCli -AdpBbuCmd -GetBbuStatus -aALL | grep "Temperature:" | awk -F ": " '{print $2}' |awk '{print $1}')
                if [ -z $bbu_temperature ]
                then exit 0
                else echo $bbu_temperature
                fi
                ;;
        bbu_capacity) #BBU电池剩余容量,单位%
                bbu_capacity=$($MegaCli -AdpBbuCmd -GetBbuCapacityInfo -aALL | grep "Relative State of Charge:" | awk -F ": " '{print $2}' |awk '{print $1}')
                if [ -z $bbu_capacity ]
                then exit 0
                else echo $bbu_capacity
                fi
                ;;
        bbu_remaining_capacity) #BBU电池剩余容量,单位(mAh)
                bbu_remaining_capacity=$($MegaCli -AdpBbuCmd -GetBbuCapacityInfo -aALL | grep "Remaining Capacity: " | awk -F ": " '{print $2}' |awk '{print $1}')
                if [ -z $bbu_remaining_capacity ]
                then exit 0
                else echo $bbu_remaining_capacity
                fi
                ;;
        bbu_full_capacity) #BBU电池完整容量,单位(mAh)
                bbu_full_capacity=$($MegaCli -AdpBbuCmd -GetBbuCapacityInfo -aALL | grep "Full Charge Capacity: " | awk -F ": " '{print $2}' |awk '{print $1}')
                if [ -z $bbu_full_capacity ]
                then exit 0
                else echo $bbu_full_capacity
                fi
		;;
	bbu_Learn_Cycle_time) #距离下次BBU放电时间还有多少秒 
		next_time=$($MegaCli -AdpBbuCmd -GetBbuProperties-aAll | grep "Next" | cut -d" " -f4) 
		next_date=$(date +%s -d "$(date -d "2000-01-01 UTC $next_time sec" +"%Y/%m/%d %H:%M:%S")")
		now_date=$(date +%s -d "now")
		if [ -z $next_time ];then exit 0
		else	expr $next_date - $now_date
		fi
		;;
	bbu_Learn_Cycle) #是否开始进行BBU放电 
		bbu_Learn_Cycle=$($MegaCli -AdpBbuCmd -GetBbuStatus -aALL | grep "Learn Cycle Requested" | awk -F ": " '{print $2}')
		if [ -z $bbu_Learn_Cycle ];then exit 0 ;elif [ $bbu_Learn_Cycle != "Yes" ];then echo 1;else echo 0;fi
		;;
	bbu_Replacement) #BBU电池是否需要更换#
		Replacement_value1=$($MegaCli -AdpBbuCmd -GetBbuStatus -aALL | grep "Battery Replacement required" | awk -F ": " '{print $2}')
		Replacement_value2=$($MegaCli -AdpBbuCmd -GetBbuStatus -aALL | grep "Remaining Capacity Low " | awk -F ": " '{print $2}')
		if [ -z $Replacement_value1 ] && [ -z $Replacement_value2 ];then exit 0;elif [ $Replacement_value1 != "Yes" ] || [ $Replacement_value2 != "Yes" ];then echo 1;else echo 0;fi
		;;
        dev_info)
                dev_cpu=$($CMD processors | grep "Connector Name" | awk -F ": " '{print $2}')
                for dev in $dev_cpu
                do
                        cpu_status=$($CMD processors | egrep -w -A 6 -B 1 "$dev" | grep "Status" | awk -F ": " '{print $2}')
                        cpu_type=$($CMD processors | egrep -w -A 5 -B 2 "$dev" | grep "Processor Brand" | awk -F ": " '{print $2}')
                        cpu_core=$($CMD processors | egrep -w -A 5 -B 2 "$dev" | grep "Core Count" | awk -F ": " '{print $2}')
                        /bin/echo -e "$dev状态:\t$cpu_status\n$dev类型:\t$cpu_type\n$dev核心数:\t$cpu_core\n"
                done

                memory_slots_num=$($CMD memory | grep "Slots Available" | awk -F ": " '{print $2}')
                memory_slots_used=$($CMD memory | grep "Slots Used" | awk -F ": " '{print $2}')
                memory_max_used=`expr $($CMD memory | grep "Maximum Capacity   :" | awk -F ": " '{print $2}' | awk '{print $1}') / 1024`
                /bin/echo -e "服务器可使用内存插槽数量:\t$memory_slots_num\n服务器已使用内存插槽:\t$memory_slots_used\n服务器最大支持使用的内存容量:\t$memory_max_used"G"\n"
                dev_memory=$($CMD memory | egrep -w -A 4 "Index          : "[0-9]\{1,3\} | grep "Connector Name" | awk -F ": " '{print $2}')
                for dev in $dev_memory
                do
                        memory_status=$($CMD memory |  egrep -A 2 -B 2 "$dev" | grep "Status" | awk -F ": " '{print $2}')
                        memory_size=`expr $($CMD memory | egrep -A 2 -B 2 "$dev" | grep "Size" | awk -F ": " '{print $2}' | awk '{print $1}') / 1024`
                        memory_type=$($CMD memory | egrep -A 2 -B 2 "$dev" | grep "Type" | awk -F ": " '{print $2}' | awk '{print $1}')
                        if [ $memory_type = "[Not" ]
                        then memory_type=Unknown
                        fi
                        /bin/echo -e "$dev内存状态:\t$memory_status\n$dev内存容量:\t$memory_size"G"\n$dev内存类型:\t$memory_type\n"
                done

                dev_interface=$($CMD nics | grep "Interface Name" |awk -F ": " '{print $2}')
                for dev in $dev_interface
                do
                        interface_type=$($CMD nics | egrep -w -A 4 -B 1 "$dev" | grep "Description" | awk -F ": " '{print $2}')
                        interface_vendor=$($CMD nics | egrep -w -A 4 -B 1 "$dev" | grep "Vendor" | awk -F ": " '{print $2}')
                        interface_status=$($CMD nics | egrep -w -A 4 -B 1 "$dev" | grep "Connection Status" | awk -F ": " '{print $2}')
                        /bin/echo -e "网卡$dev类型:\t$interface_type\n网卡$dev厂商:\t$interface_vendor\n网卡$dev连接状态:\t$interface_status\n"
                done
                dev_disk=$($MegaCli -PDList -aALL | grep "Slot Number: " | awk -F ": " '{print $2}')
                for dev in $dev_disk
                do
                        disk_type=$($MegaCli -PDList -aALL | grep -A 24 -B 1 "Slot Number: $dev" | grep "PD Type: " |awk -F ": " '{print $2}')
                        disk_info=$($MegaCli -PDList -aALL | grep -A 24 -B 1 "Slot Number: $dev" | grep "Inquiry Data:" |awk -F ": " '{print $2}' | awk '{print $2,$3,$4,$5,$6}')
                        disk_sudu=$($MegaCli -PDList -aALL | grep -A 24 -B 1 "Slot Number: $dev" | egrep -w "Device Speed:" |awk -F ": " '{print $2}')
                        disk_media_status=$($MegaCli -PDList -aALL | grep -A 24 -B 1 "Slot Number: $dev" | grep "Media Error Count: " |awk -F ": " '{print $2}')
                        disk_other_status=$($MegaCli -PDList -aALL | grep -A 24 -B 1 "Slot Number: $dev" | grep "Other Error Count: " |awk -F ": " '{print $2}')
                        /bin/echo -e "硬盘$dev类型:\t$disk_type\n硬盘$dev信息:\t$disk_info\n硬盘$dev连接错误状态:\t$disk_media_status\n硬盘$dev其他错误状态:\t$disk_other_status\n"
                done
                raid_info=$($MegaCli -cfgdsply -aALL |egrep -A 21 "^Name                :")
                bbu_voltage=$($MegaCli -AdpBbuCmd -GetBbuStatus -aALL | grep "Voltage: " | awk -F ": " '{print $2}' )
                bbu_current=$($MegaCli -AdpBbuCmd -GetBbuStatus -aALL | grep "Current: " | awk -F ": " '{print $2}')
                bbu_temperature=$($MegaCli -AdpBbuCmd -GetBbuStatus -aALL | grep "Temperature: " | awk -F ": " '{print $2}')
                bbu_capacity_info=$($MegaCli -AdpBbuCmd -GetBbuCapacityInfo -aALL | egrep -w -A 12 "BBU Capacity Info for Adapter:" | grep -v "^$")
                bbu_status_info=$($MegaCli -AdpBbuCmd -GetBbuStatus -aALL | egrep -w -A 28 "BBU Firmware Status:" | grep -v "^$")

                /bin/echo -e "RAID卡信息:\n""$raid_info\n\n""\nBBU电压:\t$bbu_voltage\n""BBU电流:\t$bbu_current\n""BBU温度:\t$bbu_temperature\n""\nBUU容量情况:\n$bbu_capacity_info"%"\n\n""\nBBU固件情况:\n$bbu_status_info\n"
                ;;
esac
}
$1  #执行操作，开始工作。
