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
    
    fn_recordLog "INFO" "do OS disk usage check start..."
    local diskChk="${LOG_FOLDER}/df.log"
    df -hT> ${diskChk}
    lsblk -alp >> ${diskChk}
    lvdisplay -a >> ${diskChk}
    vgdisplay >> ${diskChk}
    pvdisplay >> ${diskChk}

    local diskInfo=`df -hT | sed -n '1!P'|grep -vE 'Filesystem|tmpfs|/dev/sr|iso|tmpfs' |awk '{print $1"_"$6}'|sed 's/%//g'|xargs`
    failedDisk=''
    fn_recordLog "INFO" ""
    for item in ${diskInfo}
    do
        disk=`echo $item|awk -F'_' '{print $1}'`
        usage=`echo $item|awk -F'_' '{print $2}'`
        fn_recordLog "INFO" "usage=${usage},disk=${disk},item=${item}"
        if [ ${usage} -ge 80 ];then failedDisk="${item}"; fi
    done

    chk_rst=0  # default 0 check Success
    # awk if $diskInfo >= 85, the check result should be failed.
    if [ "x" != "x${failedDisk}" ];then
        chk_rst=1
    fi
    fn_recordLog "INFO" "failed disk failedDisk=${failedDisk}, Check disk result: chk_rst=$chk_rst"
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
