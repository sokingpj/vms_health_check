#!/bin/bash
[ -z "${CURR_PATH}" ] && CURR_PATH=`cd $(dirname $0);pwd`/../
SCRIPT_NAME=`echo ${0##*/} | sed "s/\(.*\)\.sh$/\1/g"`
LOG_FOLDER="$CURR_PATH/logs"
[ -d ${LOG_FOLDER} ] || mkdir -p ${LOG_FOLDER}
MAIN_LOG_FILE="$LOG_FOLDER/${SCRIPT_NAME}.log"
[ -f $MAIN_LOG_FILE ] || touch $MAIN_LOG_FILE
chk_rst=0  # default 0 check Success

function fn_print_cron_info()
{
    fn_recordLog "INFO" "fn_print_cron_info() start..."
    local cron="${LOG_FOLDER}/cron.log"
    # tail -50 /var/log/cron
    # crontab -l
    # ls -l /etc/cron*
    # cat /etc/crontab
    cmdLst="tail_-50_/var/log/cron crontab_-l ls_-l_/etc/cron* cat_/etc/crontab"
    echo > ${cron}
    for cmdStr in $cmdLst
    do
        cmd=`echo "${cmdStr}" | sed 's/_/ /g'`
        echo -e "\n-----------------cmdStr=$cmdStr,cmd=${cmd}-----------------" >> ${cron}
        $cmd | tee -a ${cron}
        fn_recordLog "INFO" "Execute cmd=${cmd}, cmdStr=${cmdStr}"
    done

    fn_recordLog "INFO" "Print OS crontab has finished."
    return 0
}

function fn_main()
{
    if [ ! -f ${CURR_PATH}/common/common.sh ];then
        echo "ERROR, the common.sh is not exist, please check!!"
        return 1
    fi
    source ${CURR_PATH}/common/common.sh

    fn_recordLog "INFO" "**************************************************"
    fn_recordLog "INFO" "           Run ${SCRIPT_NAME}.sh"
    fn_recordLog "INFO" "**************************************************"
    
    fn_print_cron_info
    chk_rst=$?
    fn_recordLog "INFO" "Print OS crontab result: chk_rst=$chk_rst"
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
