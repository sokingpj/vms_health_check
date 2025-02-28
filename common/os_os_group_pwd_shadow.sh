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
    fn_recordLog "INFO" "do OS kernel configuration Check start..."
    local cnf_list='/etc/passwd_644 /etc/group_644 /etc/shadow_000 /etc/resolv.conf_644'
    for file_path in ${cnf_list}
    do
        file=`echo "${file}" | awk -F'_' '{print $1}'`
        file_right=`echo "${file}" | awk -F'_' '{print $2}'`
        fn_recordLog "INFO" "------------------check ${file_path}------------------" | tee -a ${MAIN_LOG_FILE}
        right=`stat --format "%A" ${file} | sed 's/\-/_/g'`
        fn_recordLog "INFO" "ls -l ${file}; right=${right}" | tee -a ${MAIN_LOG_FILE}
        cat ${file} | tee -a ${MAIN_LOG_FILE}
        stat ${file} | tee -a ${MAIN_LOG_FILE}

        if [ "x/etc/shadow" != "x${file}" ];then
            right_tmp=`echo "${right}" | grep -E '_rw_[r|_]__[r|_]__'`        # if file right large than 644, such as 660 750, this file will check failed.
            fn_recordLog "INFO" "file access right: right=${right},right_tmp=${right_tmp},file_right=${file_right}"
            if [ "x" != "x${right_tmp}" ];then chk_rst="${chk_rst},${file_path}";fi
        fi

        if [ "x/etc/shadow" == "x${file}" ];then
            right_tmp=`echo "${right}" | grep -E '_[r|_]________'`        # if file right large than 644, such as 660 750, this file will check failed.
            fn_recordLog "INFO" "file access right: right=${right},right_tmp=${right_tmp},file_right=${file_right}"
            if [ "x" != "x${right_tmp}" ];then chk_rst="${chk_rst},${file_path}";fi
        fi
    done

    if [ "x" != "x${chk_rst}" ];then
        fn_recordLog "ERROR" "Check file right has failed, please check, Check result: chk_rst=$chk_rst"
        return 1
    fi
    fn_recordLog "INFO" "Check file right has successed."
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
