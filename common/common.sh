#!/bin/bash
if [ -z $CURR_PATH ];then
    export CURR_PATH=`cd $(dirname $0);pwd`
    root_forder=${CURR_PATH}/..
else
    root_forder=${CURR_PATH}
fi
export root_forder

[ -z $SCRIPT_NAME ] && SCRIPT_NAME=`echo ${0##*/} | sed "s/\(.*\)\.sh$/\1/g"`
[ -d $root_forder/logs ] || mkdir -p $root_forder/logs
[ -z $MAIN_LOG_FILE ] && export MAIN_LOG_FILE="$root_forder/logs/${SCRIPT_NAME}.log"
[ -f $MAIN_LOG_FILE ] || touch $MAIN_LOG_FILE

function fn_recordLog() {
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

function fn_initJobFlag() {
    if [ ! -f $job_lists ];then
        fn_recordLog "ERROR" "Job status flag is not exist, please check ${job_lists}."
        return 11
    fi

    [ -f ${job_resultStatus} ] && rm -f ${job_resultStatus}

    local jobStatus="init"
    printf "%-60s\n" "-----------------------------------------------------------------------+--------------" | tee -a ${job_resultStatus}
    printf "%-60s\n" "|                Job Name                                              +  result     |" | tee -a ${job_resultStatus}
    printf "%-60s\n" "-----------------------------------------------------------------------+--------------" | tee -a ${job_resultStatus}
    for job in `cat ${job_lists} |grep -vE '^#|^\['`
    do
        local jobStrLine=`echo ${job} | awk -F':' '{print $1":"$2":"$3}'`
        printf "| %-69s| %-12s|\n" "${jobStrLine}" "${jobStatus}" | tee -a ${job_resultStatus}
    done
    printf "%-60s\n" "|----------------------------------------------------------------------+-------------|" | tee -a ${job_resultStatus}

    fn_recordLog "INFO" "init ${job_resultStatus} has finish."
    return 0    
}

function fn_updateJobFlag() {
    if [ ! -f $job_lists ];then
        fn_recordLog "ERROR" "Job status flag is not exist, please check ${job_lists}."
        return 15
    fi

    local jobStrLine="$1"
    shift
    local jobStatus="$1"
    fn_recordLog "INFO" "upgrade job flag jobName:$jobStrLine to jobStatus:$jobStatus"

    local jobTmp="${root_forder}/jobTmp"
    [ -f ${jobTmp} ] && rm -f ${jobTmp}

    while read line 
    do
        if [[ "x$line" =~ '.sh' ]];then
            local ntmp=`echo "${line}" | awk '{print $2}'`
            local stmp=`echo "${line}" | awk '{print $4}'`
            if [[ "$line" =~ "$jobStrLine" ]];then
                printf "| %-69s| %-12s|\n" "${ntmp}" "${jobStatus}" | tee -a ${jobTmp}
            else
                printf "| %-69s| %-12s|\n" "${ntmp}" "${stmp}" | tee -a ${jobTmp}
            fi
        else
            echo "$line" >> ${jobTmp}
        fi
    done < ${job_resultStatus}

    cat ${jobTmp} > ${job_resultStatus}
    [ -f ${jobTmp} ] && rm -f ${jobTmp}

    fn_recordLog "INFO" "upgrade ${jobStrLine} status into "${jobStatus}" has finish."
    return 0
}


export -f fn_recordLog
export -f fn_initJobFlag
export -f fn_updateJobFlag
