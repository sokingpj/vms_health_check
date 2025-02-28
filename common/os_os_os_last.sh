#!/bin/bash
[ -z "${CURR_PATH}" ] && CURR_PATH=`cd $(dirname $0);pwd`/../
SCRIPT_NAME=`echo ${0##*/} | sed "s/\(.*\)\.sh$/\1/g"`
LOG_FOLDER="$CURR_PATH/logs"
[ -d ${LOG_FOLDER} ] || mkdir -p ${LOG_FOLDER}
MAIN_LOG_FILE="$LOG_FOLDER/${SCRIPT_NAME}.log"
[ -f $MAIN_LOG_FILE ] || touch $MAIN_LOG_FILE
chk_rst=0  # default 0 check Success

# find recent(three days) reboot or crash recording, if recording is exist, return Failed. 
function fn_findRecent()
{
    processStr=$1
    fn_recordLog "INFO" "fn_findRecent() start...processStr=$1"
    if [ "x" == "x${processStr}" ];then
        fn_recordLog "ERROR" "parameter reboot or crash string is empty, please check."
        return 11
    fi
    
    pStrTmp="${processStr}"
    utlNow=$(date +%s -d "`date '+%Y-%m-%d'` 23:59:59")
    local month='01_Jan 02_Feb 03_Mar 04_Apr 05_May 06_Jun 07_Jul 08_Aug 09_Sept 10_Oct 11_Nov 12_Dec'
    for mon in $month
    do
        fingure=`echo $mon | cut -d'_' -f1`
        shot=`echo $mon | cut -d'_' -f2`
        pStrTmp=`echo ${pStrTmp}|sed "s/${shot}/${fingure}/g"`
        # fn_recordLog "INFO" "echo ${pStrTmp}|sed \"s/${shot}/${fingure}/g\""
    done

    bootRecord=""
    fn_recordLog "INFO" "recording str: pStrTmp=${pStrTmp}, one day utc is 86400*2 second."
    for rec in ${pStrTmp}
    do
        recTmp=`echo ${rec}|sed "s/_/ /g"`
        recUTC=`date +%s -d "${recTmp}"`
        if [ "x" == "x$recUTC" ];then continue; fi
        utcDiff=`echo "$utlNow-$recUTC" | bc`
        # fn_recordLog "INFO" "process recTmp: ${recTmp},utlNow=${utlNow},recUTC=${recUTC},utcDiff=${utcDiff}"
        if [ ${utcDiff} -lt 172800 ];then bootRecord="${bootRecord},${recTmp}"; fi
    done

    bootRecordTmp=`echo "${bootRecord}" | sed -e 's/,//g; s/-//g; s/[ ]?//g'|xargs`
    fn_recordLog "INFO" "boot Record string: bootRecord=${bootRecord},bootRecordTmp=${bootRecordTmp}"
    if [ "x" != "x${bootRecordTmp}" ];then
        fn_recordLog "ERROR" "The server had been rebooted or crashed in the last day."
        return 12
    fi

    fn_recordLog "INFO" "The server has been running normally.\n"
    return 0
}

function fn_main()
{
    if [ ! -f ${CURR_PATH}/common/common.sh ];then
        echo -e "ERROR, the common.sh is not exist, please check!!"
        return 1
    fi
    source ${CURR_PATH}/common/common.sh

    fn_recordLog "INFO" "**************************************************"
    fn_recordLog "INFO" "           Run ${SCRIPT_NAME}.sh"
    fn_recordLog "INFO" "**************************************************"
    
    fn_recordLog "INFO" "do Check OS login and reboot recording..."
    local chkInfo="${LOG_FOLDER}/last.log"
    echo -e "-------------------last -aF-------------------" > ${chkInfo}
    last -aF >> ${chkInfo}
    echo -e "\n-------------------uptime-------------------" >> ${chkInfo}
    uptime >> ${chkInfo}
    echo -e "\n" >> ${chkInfo}

    echo -e "\n-------------------last -aiF -x reboot-------------------" >> ${chkInfo}
    last -aiF -x reboot >> ${chkInfo}
    echo -e "\n" >> ${chkInfo}

    echo -e "\n-------------------last -aiF -x reboot-------------------" >> ${chkInfo}
    last -aiF -x reboot >> ${chkInfo}
    echo -e "\n" >> ${chkInfo}

    rebootStr=`last -aiF -x reboot | awk '{print $8"-"$5"-"$6"_"$7}'|xargs`
    crashStr=`last -aiF -x root | grep -w '\- crash' | awk '{print $7"-"$4"-"$5"_"$6}'|xargs`

    fn_recordLog "INFO" "reboot recording: ${rebootStr}"
    fn_recordLog "INFO" "crash recording: ${crashStr}\n"

    rebootRst=0
    if [ "x" != "x${rebootStr}" ];then
        fn_findRecent "${rebootStr}"
        rebootRst=$?
    fi

    crashRst=0
    if [ "x" != "x${crashStr}" ];then
        fn_findRecent "${crashStr}"
        crashRst=$?
    fi

    chk_rst=0  # default 0 check Success
    # awk if $usageRate > 85 report memory check failed.
    if [ 0 -ne $rebootRst -o 0 -ne $crashRst ];then
        chk_rst=1
    fi
    fn_recordLog "INFO" "OS Reboot/Crash Check result: rebootRst=$rebootRst,crashRst=$crashRst, Check result: chk_rst=$chk_rst"
    return $chk_rst
}

# usage: bash ${SCRIPT_NAME}.sh "nova_compute | nova_libvirt"
fn_main $@
MAIN_RET=$?
if [ $MAIN_RET -eq 0 ];then
    fn_recordLog "INFO" "run \"${SCRIPT_NAME}\" has successful."
    exit 0
fi
fn_recordLog "ERROR" "run \"${SCRIPT_NAME}\" has failed, result: MAIN_RET=$MAIN_RET."
exit $MAIN_RET
