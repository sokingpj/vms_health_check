#!/bin/bash
[ -z "${CURR_PATH}" ] && CURR_PATH=`cd $(dirname $0);pwd`/../
SCRIPT_NAME=`echo ${0##*/} | sed "s/\(.*\)\.sh$/\1/g"`
LOG_FOLDER="$CURR_PATH/logs"
[ -d ${LOG_FOLDER} ] || mkdir -p ${LOG_FOLDER}
MAIN_LOG_FILE="$LOG_FOLDER/${SCRIPT_NAME}.log"
[ -f $MAIN_LOG_FILE ] || touch $MAIN_LOG_FILE
chk_rst=0  # default 0 check Success


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
    
    fn_recordLog "INFO" "do OS memory usage Check start..."
    local meminfo="${LOG_FOLDER}/meminfo.log"
    cat /proc/meminfo > ${meminfo}
    memTotal=`cat ${meminfo} | grep -w 'MemTotal' | awk '{print $2}'`
    memFree=`cat ${meminfo} | grep -w 'MemFree' | awk '{print $2}'`

    local memUsage=`echo "($memTotal-$memFree)*100" | bc`
    local usageRate=`echo "scale=2;$memUsage/$memTotal" | bc`
    fn_recordLog "INFO" "usageRate=$usageRate, memUsage=$memUsage; echo \"scale=2;($memTotal-$memFree)*100/$memTotal\" | bc"

    chk_rst=0  # default 0 check Success
    # awk if $usageRate > 85 report memory check failed.
    if [ `awk "BEGIN{print ($usageRate>85.00)?1:0}"` -eq 1 ];then
        chk_rst=1
    fi
    fn_recordLog "INFO" "Memory Check result: $usageRate, Check result: chk_rst=$chk_rst"
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
