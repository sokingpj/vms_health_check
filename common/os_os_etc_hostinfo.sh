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
    
    
    chk_rst=""  # default empty check Success
    fn_recordLog "INFO" "do OS host configuration Check start..."
    local cnf_list='/etc/redhat-release /etc/os-release /proc/version /etc/hosts /etc/hostname /etc/localtime /etc/profile /etc/security/limits.conf'
    for file_path in ${cnf_list}
    do
        fn_recordLog "INFO" "------------------check ${file_path}------------------\n" | tee -a ${MAIN_LOG_FILE}
        ls -l ${file} | tee -a ${MAIN_LOG_FILE}
        cat ${file} | tee -a ${MAIN_LOG_FILE}
        stat ${file} | tee -a ${MAIN_LOG_FILE}
    done

    local cmd_list='uname_-a hostnamectl_status date date_-R date_-u clock_--show ulimit_-a '
    for cmd_str in ${cmd_list}
    do
        cmd=`echo "${cmd_str}" | sed 's/_/ /g'`
        fn_recordLog "INFO" "------------------check cmd_str=${cmd_str},cmd=${cmd}------------------" | tee -a ${MAIN_LOG_FILE}
        $cmd | tee -a ${MAIN_LOG_FILE}
    done

    fn_recordLog "INFO" "check and recording system info has successed."
    return 0
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
