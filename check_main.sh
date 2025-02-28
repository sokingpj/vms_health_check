#!/bin/bash

export CURR_PATH=`cd $(dirname $0);pwd`
sourceFile="$CURR_PATH/common/common.sh"

export MAIN_SCRIPT_NAME=`echo ${0##*/} | sed "s/\(.*\)\.sh$/\1/g"`
export job_resultStatus="$CURR_PATH/result/job_result_status.log"
export MAIN_LOG_FILE="$CURR_PATH/logs/${MAIN_SCRIPT_NAME}.log"
backup_logs_forder='/home/healthCheck'


# prepare health check list.
function do_healthCheck()
{
    local item="${1}"
    fn_recordLog "INFO" ""
    fn_recordLog "INFO" ""
    fn_recordLog "INFO" "check: ${item}"
    local proj=`echo $chk_project | awk -F'-' '{print $1}'`
    local child=`echo $chk_project | awk -F'-' '{print $2}'`

    # find the script in "01_ioc\01_ioc\government\10_25_13_11"
    pro_chk_file=`find ${CURR_PATH}/${proj}/${child}/${net_area}/${svrIP} -maxdepth 1 -type f -name "${item}\.*"`
    fn_recordLog "INFO" "cmd: find ${CURR_PATH}/${proj}/${child}/${net_area}/${svrIP} -maxdepth 1 -type f -name '${item}\.*', pro_chk_file=${pro_chk_file}"
    if [ 'x' == "x${pro_chk_file}" ];then
        # find the script in "01_ioc\01_ioc\government"
        pro_chk_file=`find ${CURR_PATH}/${proj}/${child}/${net_area}/ -maxdepth 1 -type f -name "${item}\.*"`
        fn_recordLog "INFO" "cmd: find ${CURR_PATH}/${proj}/${child}/${net_area}/ -maxdepth 1 -type f -name \"${item}\.*\", pro_chk_file=${pro_chk_file}"
    fi
    if [ 'x' == "x${pro_chk_file}" ];then
        pro_chk_file=`find ${CURR_PATH}/common -maxdepth 1 -type f -name "${item}\.*"`
        fn_recordLog "INFO" "cmd: 'find ${CURR_PATH}/common -maxdepth 1 -type f -name \"${item}\.*\"', pro_chk_file=${pro_chk_file}"
    fi

    if [ 'x' == "x${pro_chk_file}" ];then
        fn_recordLog "ERROR" "Can not find the \"${item}\" health check file, please confirm the file is exist in \"${CURR_PATH}/${proj}/${child}\" or \"${CURR_PATH}/common\""
        return 31
    fi
    fn_recordLog "INFO" "cd ${CURR_PATH}; rst=${rst}; bash ${pro_chk_file}"

    cd ${CURR_PATH}
    bash ${pro_chk_file} | tee -a ${MAIN_LOG_FILE}
    local rst=${PIPESTATUS[0]}
    cd -
    rstStr='Failed'
    if [ 0 -eq ${rst} ];then rstStr='Success'; fi
    fn_recordLog "INFO" "sed -i \"s/\(^${item}.*| \).*/\1${rstStr}/g\" ${job_conf}"
    sed -i "s/\(^${item}.*| \).*/\1${rstStr}/g" ${job_conf}
    local updateRst=$?

    fn_recordLog "INFO" "${item} health check result: ${rst}, sed update result: updateRst=${updateRst}"
    return 0
}

# 01_auth 02_app_base 03_industrial_economics 04_data_hub 05_traffic 06_onekey_escorts 07_city_app 08_city_security 09_ai_platform
# prepare health check list.
function prepare_chk_variables()
{
    fn_recordLog 'INFO' "prepare_chk_variables() start...job_conf=${job_conf}"
    export chk_project=`sed -n '/Check_Project/p' ${job_conf} | awk '{print $NF}'|tr '\r' ' ' | xargs`
    export job_lists=`sed -n '/Check Result/,${//!p}' ${job_conf} |grep -v '\-\-\-' | awk '{print $1}'|tr '\r' ' ' | xargs`
    export svrIP=`sed -n '/Server_IP/p' ${job_conf} | awk '{print $NF}'|tr '\r' ' '| sed 's/\./_/g' | xargs`
    export net_area=`sed -n '/Net_Area/p' ${job_conf} | awk '{print $NF}'|tr '\r' ' ' | xargs`

    fn_recordLog "INFO" "health check project-name: ${chk_project},check list: ${job_lists},server IP: ${svrIP}"

    if [ "x${chk_project}" == "x" ];then
        fn_recordLog "ERROR" "project should not be None, please check!!"
        return 21
    fi

    if [ "x${job_lists}" == "x" ];then
        fn_recordLog "ERROR" "health check items should not be None, please check!!"
        return 22
    fi
}

function fn_backRunlogs()
{
    fn_recordLog "INFO" "fn_backRunlogs() start..."

    backup_file=`sed -n '/HealthCheckRST/p' ${job_conf} | awk '{print $NF}'|tr '\r' ' '`
    backup_folder=`dirname ${backup_file}`
    mkdir -p ${backup_folder}
    
    cd ${CURR_PATH}
    tar zcf ${backup_file} logs/* result/*
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
    
    prepare_chk_variables || return 11
    for item in ${job_lists}
    do
        do_healthCheck "${item}"
    done

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
