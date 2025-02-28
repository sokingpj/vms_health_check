#!/bin/bash
[ -z "${CURR_PATH}" ] && CURR_PATH=`cd $(dirname $0);pwd`/../
SCRIPT_NAME=`echo ${0##*/} | sed "s/\(.*\)\.sh$/\1/g"`
LOG_FOLDER="$CURR_PATH/logs"
[ -d ${LOG_FOLDER} ] || mkdir -p ${LOG_FOLDER}
MAIN_LOG_FILE="$LOG_FOLDER/${SCRIPT_NAME}.log"
[ -f $MAIN_LOG_FILE ] || touch $MAIN_LOG_FILE
chk_rst=0  # default 0 check Success

function fn_print_dmesg_info()
{
    fn_recordLog "INFO" "fn_print_net_info() start..."
    local dmesg="${LOG_FOLDER}/dmesg.log"
    # cat /var/log/boot.log
    # dmesg
    # dmidecode
    # journalctl_xe
    cmdLst="tail_-50_/var/log/boot.log dmesg dmidecode journalctl_xe"
    echo > ${dmesg}
    for cmdStr in $cmdLst
    do
        cmd=`echo "${cmdStr}" | sed 's/_/ /g'`
        echo -e "\n-----------------cmdStr=$cmdStr,cmd=${cmd}-----------------" >> ${dmesg}
        $cmd | tee -a ${dmesg}
        fn_recordLog "INFO" "Execute cmd=${cmd}, cmdStr=${cmdStr}"
    done

    fn_recordLog "INFO" "OS boot record print has finished."
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
    
    fn_print_dmesg_info
    chk_rst=$?
    fn_recordLog "INFO" "OS boot log print result: chk_rst=$chk_rst"
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
