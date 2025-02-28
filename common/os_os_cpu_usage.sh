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
    
    fn_recordLog "INFO" "do_healthCheck() start..."
    local top1="${LOG_FOLDER}/top1.log"
    local top2="${LOG_FOLDER}/top2.log"
    for i in {1..10}
    do
        top -n 1 -c -b > ${top1}
        cat ${top1} | tee -a ${MAIN_LOG_FILE}
        ild1=`cat ${top1} | grep '%Cpu(s):'|awk '{print $7"="$8}' | sed -e 's/ni,//g; s/id,//g; s/=//g'`

        sleep 3s
        top -n 1 -c -b > ${top2}
        cat ${top2} | tee -a ${MAIN_LOG_FILE}
        ild2=`cat ${top2} | grep '%Cpu(s):'|awk '{print $7"="$8}' | sed -e 's/ni,//g; s/id,//g; s/=//g'`
        fn_recordLog "INFO" "ild1=${ild2},ild2=${ild2}"
        if [ "x" != "x${ild1}" -a "x" != "x${ild2}" ];then break; fi
    done
    local cpuIlde=`echo "scale=2;$ild1/2+$ild2/2" | bc`
    fn_recordLog "INFO" "cpuIlde=$cpuIlde, echo \"scale=2;$ild1/2+$ild2/2\" | bc"

    chk_rst=0  # default 0 check Success
    # if CPU ilde little then 15, that means user stat add system stat time great then (100-15=85)
    # awk if $cpuIlde > 15 means ilde CPU not busy. but if idle close to 15, the CPU is/are very busy too.
    if [ `awk "BEGIN{print ($cpuIlde>15.00)?1:0}"` -eq 0 ];then
        chk_rst=1
    fi
    fn_recordLog "INFO" "CPU idle: $cpuIlde, Check result: chk_rst=$chk_rst"
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
