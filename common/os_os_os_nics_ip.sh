#!/bin/bash
[ -z "${CURR_PATH}" ] && CURR_PATH=`cd $(dirname $0);pwd`/../
SCRIPT_NAME=`echo ${0##*/} | sed "s/\(.*\)\.sh$/\1/g"`
LOG_FOLDER="$CURR_PATH/logs"
[ -d ${LOG_FOLDER} ] || mkdir -p ${LOG_FOLDER}
MAIN_LOG_FILE="$LOG_FOLDER/${SCRIPT_NAME}.log"
[ -f $MAIN_LOG_FILE ] || touch $MAIN_LOG_FILE
[ "x" == "x$job_conf" ] || job_conf=${CURR_PATH}/conf/check_items.conf
chk_rst=0  # default 0 check Success

function fn_pingTest()
{
    fn_recordLog "INFO" "fn_pingTest() start..."
    correlation=`sed -n '/correlation_servers/p' ${job_conf} | awk '{print $NF}'|tr '\r' ' '| sed 's/,/ /g'`
    fn_recordLog "INFO" "ping test: correlation=$correlation"

    canNotSvr=""
    for rmtIP in ${correlation}
    do
        ping -c 1 $rmtIP | tee -a ${MAIN_LOG_FILE}
        local nromalPing=${PIPESTATUS[0]}
        ping -c 1 -s 1500 $rmtIP | tee -a ${MAIN_LOG_FILE}
        local bigPkgPing=${PIPESTATUS[0]}

        fn_recordLog "INFO" "ping rmtIP=${rmtIP}, ping result: nromalPing=${nromalPing},bigPkgPing=${bigPkgPing}"
        if [ 0 -ne $nromalPing -o 0 -ne $bigPkgPing ]; then canNotSvr="${canNotSvr},${rmtIP}"; fi
    done

    canNotSvrTmp=`echo "${canNotSvr}" | sed 's/,//g'`
    if [ "x" != "x${canNotSvrTmp}" ];then
        fn_recordLog "ERROR" "Can not ping to this/those servers, please check!!"
        fn_recordLog "ERROR" "canNotSvr=${canNotSvr}"
        return 11
    fi
    fn_recordLog "INFO" "Ping test is normal."
    return 0
}

function fn_print_net_info()
{
    fn_recordLog "INFO" "fn_print_net_info() start..."
    local nic_ip_info="${LOG_FOLDER}/nic_ip_info.log"
    # ip a 
    # ip r 
    # ip -6 a
    # ip -6 r
    # iptables-save
    # ip6tables-save

    # lsof -Pnl +M -i4 显示ipv4服务及监听端情况
    # netstat -anp 所有监听端口及对应的进程
    # netstat -tlnp 功能同上
    cmdLst="ip_a ip_r ip_-6_a ip_-6_r iptables-save ip6tables-save netstat_-anp netstat_-tlnp"
    echo > ${nic_ip_info}
    for cmdStr in $cmdLst
    do
        cmd=`echo "${cmdStr}" | sed 's/_/ /g'`
        echo -e "\n-----------------cmdStr=$cmdStr,cmd=${cmd}-----------------" | tee -a ${nic_ip_info}
        $cmd | tee -a ${nic_ip_info}
        fn_recordLog "INFO" "Execute cmd=${cmd}, cmdStr=${cmdStr}"
    done

    fn_recordLog "INFO" "Record nic IP config has finished."
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
    
    fn_print_net_info
    fn_pingTest
    chk_rst=$?
    fn_recordLog "INFO" "OS NIC connection check result: chk_rst=$chk_rst"
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
