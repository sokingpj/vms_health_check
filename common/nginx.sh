#!/bin/bash
#
# chkconfig: - 85 15
# description: nginx is a World Wide Web server. It is used to serve
# Source Function Library
. /etc/init.d/functions

SCRIPT_NAME=`echo ${0##*/} | sed "s/\(.*\)\.sh$/\1/g"`
# Nginx Settings
NGX_PREFIX=/usr/local/nginx
NGX_SBIN="${NGX_PREFIX}/sbin/nginx"
NGX_CONF="${NGX_PREFIX}/conf/nginx.conf"
NGX_LOGS="${NGX_PREFIX}/logs/"
NGX_PID="${NGX_PREFIX}/logs/nginx.pid"


function fn_Logger() {
    local level=`echo "$1" | tr '[a-z]' '[A-Z]'`
    local content="\n"
    local TIMESTAMPT="$(date +'%Y.%m.%d-%H:%M:%S.%3N')"
    local levelStr=""

    if [ "x" != "x$level" ];then
        if [ "xINFO" != "x$level" -a "xWARN" != "x$level" -a "xERROR" != "x$level" ];then
            levelStr="[WARN ]"
            content="$*"
        else
            case $level in
                'INFO' )
                    levelStr='[INFO ]'
                    ;;
                'ERROR' )
                    levelStr='[ERROR]'
                    ;;
                
                'WARN' )
                    levelStr='[WARN ]'
                    ;;
            esac
            shift
            content="$*"
        fi
    fi

    echo -e "[$TIMESTAMPT]$levelStr ${content}" | tee -a $MAIN_LOG_FILE
}

function ensure_pid_exist() {
    fn_Logger "INFO" "ensure the nginx process is exist!"
	ps_pid=0
    ps_pTmp=`ps aux |grep -w 'nginx: master process /usr/local/nginx/sbin/nginx' | grep -v grep | awk '{print $2}'`
    fn_Logger "INFO" "ps aux |grep -w 'nginx: master process' | grep -v grep | awk '{print $2}', result: ps_pTmp=${ps_pTmp}"
	if [ "x" == "x${ps_pTmp}" ];then
	    fn_Logger "INFO" "ensure_pid_exist() -> Nginx is not running now!!"
        export ps_pid
        return 0
	fi
    fn_Logger "INFO" "Nginx is running now, process pid is ps_pTmp=${ps_pTmp}."
    export ps_pid=${ps_pTmp}
}

function ngx_start() {
    fn_Logger "INFO" "Exec Start Nginx..."

    ensure_pid_exist
    if [ 0 -ne ${ps_pid} ];then
        fn_Logger "ERROR" "Please do not repeat the Nginx execution!!"
        return 11
    fi

    ${NGX_SBIN} -p ${NGX_PREFIX} -c ${NGX_CONF}
    start_rst=$?
    fn_Logger "INFO" "${NGX_SBIN} -p ${NGX_PREFIX} -c ${NGX_CONF}, result: ${start_rst}"

    if [ 0 -ne ${start_rst} ];then
        fn_Logger "ERROR" "Start Nginx has failed, please check the nginx log in ${NGX_LOGS}"
        return 12
    fi    

    ensure_pid_exist
    return 0
}

function ngx_stop() {
    fn_Logger "INFO" "Exec Stop Nginx..."

    ensure_pid_exist
    if [ 0 -eq ${ps_pid} ];then
        fn_Logger "INFO" "ngx_stop() -> Nginx is not running now, ps_pid=${ps_pid}"
        return 0
    fi

    ${NGX_SBIN} -p ${NGX_PREFIX} -c ${NGX_CONF} -s stop
    exec_rst=$?
    fn_Logger "INFO" "${NGX_SBIN} -p ${NGX_PREFIX} -c ${NGX_CONF} -s stop, result: ${exec_rst}"
    if [ 0 -eq ${exec_rst} ];then
        fn_Logger "INFO" "Stop Nginx(-s stop) has successed."
        return 0
    fi

    fn_Logger "INFO" "ps_pid=${ps_pid}."
    if [ "x" == "x${ps_pid}" ];then
        fn_Logger "INFO" "ps_pid=${ps_pid} is None, skip kill processes."
        return 0
    fi
    ngx_pid_list=`ps -ef |grep -w "${ps_pid}" | awk '{print $2}'|xargs`
    fn_Logger "INFO" "ps -ef |grep -w \"${ps_pid}\" | awk '{print \$2}'|xargs, ngx_pid_list=${ngx_pid_list}"

    kill -9 ${ngx_pid_list}
    fn_Logger "INFO" "kill -9 ${ngx_pid_list}"

    ensure_pid_exist
    fn_Logger "INFO" "Stop Nginx result ps_pid=${ps_pid}."
    if [ 0 -ne ${ngx_pids} ];then
        fn_Logger "ERROR" "Stop Nginx has failed, please check the nginx log in ${NGX_LOGS}"
        return 23
    fi

    fn_Logger "INFO" "Nginx has stoped."
    return 0
}

function ngx_reload(){
    fn_Logger "INFO" "Exec Reload Nginx..."
    ensure_pid_exist
    ngx_pids=$?
    fn_Logger "INFO" "Nginx pids is ngx_pids=${ngx_pids}."
    if [ 0 -eq ${ngx_pids} ];then
        ngx_start
        start_rst=$?
        fn_Logger "INFO" "Nginx is not running, Execute Nginx start result=${start_rst}"
        return ${start_rst}
    fi

    ${NGX_SBIN} -p ${NGX_PREFIX} -c ${NGX_CONF} -s reload
    exec_rst=$?
    fn_Logger "INFO" "${NGX_SBIN} -p ${NGX_PREFIX} -c ${NGX_CONF} -s reload, result: ${exec_rst}"
    if [ 0 -ne ${exec_rst} ];then
        fn_Logger "ERROR" "Reload Nginx has failed, please check the nginx log in ${NGX_LOGS}"
        return 32
    fi

    fn_Logger "INFO" "Reload Nginx has successed."
    return 0

}

function ngx_restart(){
    fn_Logger "INFO" "Exec Restart Nginx..."
    ngx_stop
    ngx_start
    fn_Logger "INFO" "Restart Finish..."
}

function ngx_configtest(){
    fn_Logger "INFO" "Test  Nginx Configuration file..."
    ${NGX_SBIN} -p ${NGX_PREFIX} -c ${NGX_CONF} -t
    exec_rst=$?
    if [ 0 -ne ${exec_rst} ];then
        fn_Logger "ERROR" "Nginx config test has failed, please check the nginx log in ${NGX_LOGS}"
        return 51
    fi

    fn_Logger "INFO" "Nginx config test has successed."
    return 0
}

function fn_main(){
    case "$1" in
    start)
        ngx_start
        ;;
    stop)
        ngx_stop
        ;;
    reload)
        ngx_reload
        ;;
    restart)
        ngx_restart
        ;;
    configtest)
        ngx_configtest
        ;;
    *)
        fn_Logger "INFO" $"Usage: $0 {start|stop|reload|restart|configtest}"
        return 1
    esac
}

fn_main $@
MAIN_RET=$?
if [ $MAIN_RET -eq 0 ];then
    fn_Logger "INFO" "run \"${SCRIPT_NAME}\" script has successful."
    exit 0
fi
fn_Logger "ERROR" "run \"${SCRIPT_NAME}\" script has failed, result: MAIN_RET=$MAIN_RET."
exit $MAIN_RET
