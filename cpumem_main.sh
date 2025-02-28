#!/bin/bash

export CURR_PATH=`cd $(dirname $0);pwd`
sourceFile="$CURR_PATH/common/common.sh"

export MAIN_SCRIPT_NAME=`echo ${0##*/} | sed "s/\(.*\)\.sh$/\1/g"`
export job_resultStatus="$CURR_PATH/result/job_result_status.log"
export MAIN_LOG_FILE="$CURR_PATH/logs/${MAIN_SCRIPT_NAME}.log"
backup_logs_forder='/home/healthCheck'

function fn_backRunlogs()
{
    fn_recordLog "INFO" "fn_backRunlogs() start..."

    backup_file=`sed -n '/HealthCheckRST/p' ${job_conf} | awk '{print $NF}'|tr '\r' ' '`
    backup_folder=`dirname ${backup_file}`
    mkdir -p ${backup_folder}

    cd /var/log/sa/
    tar zcf ${backup_file} *
    local ret=$?
    cd -

    fn_recordLog "backup logs cmd: cd ${CURR_PATH}/logs; tar zcf ${backup_file} * ../result/*"
    fn_recordLog "INFO" "ret=${ret}, backup hekalth check logs files into \"${backup_file}\""
    fn_recordLog "INFO" "backup logs has finished.."
    return 0
}

function fn_main()
{
    if [ ! -f $sourceFile ];then
        echo -e "The source profile or job list file is not exist, please check!!"
        echo -e "sourceFile: $sourceFile"
        return 11
    fi
    source $sourceFile

    timeStr="$1"
    svrIP="$2"
    fn_recordLog "INFO" "bash ${MAIN_SCRIPT_NAME}.sh parameters: timeStr=${timeStr},svrIP=${svrIP}."

    sed -i "s/\(^Server_IP.*|\).*/\1 ${svrIP}/g" $CURR_PATH/conf/${timeStr}_check_items.conf
    mkdir -p $CURR_PATH/result/${timeStr}
    cp -f $CURR_PATH/conf/${timeStr}_check_items.conf $CURR_PATH/result/${timeStr}/check_items.conf
    ret=$?
    fn_recordLog "INFO" "cp -f $CURR_PATH/conf/${timeStr}_check_items.conf $CURR_PATH/result/${timeStr}/check_items.conf, cmd result ret=$ret"
    export job_conf="$CURR_PATH/result/${timeStr}/check_items.conf"

    fn_recordLog "INFO" ""
    fn_recordLog "INFO" "**************************************************"
    fn_recordLog "INFO" "           Run ${MAIN_SCRIPT_NAME}.sh"
    fn_recordLog "INFO" "**************************************************"
    fn_recordLog "INFO" "source $sourceFile"

    find ${CURR_PATH} -type f |xargs -i dos2unix {} 2>&1 > /dev/null

    fn_backRunlogs
    fn_recordLog "INFO" "==========Health Check execution have been finished=========="
    fn_recordLog "INFO" ""
    fn_recordLog "INFO" ""
    return 0
}

fn_main $@
MAIN_RET=$?

if [ $MAIN_RET -eq 0 ];then
    echo "run \"${MAIN_SCRIPT_NAME}\" has Successful" | tee -a ${MAIN_LOG_FILE}
    exit 0
fi
echo "run \"${SCRIPT_NAME}\" has failed, result: MAIN_RET=$MAIN_RET." | tee -a ${MAIN_LOG_FILE}
exit $MAIN_RET
