# 这是用于巡检虚拟机状态、配置、日志、关键程序状态、获取关键日志、虚拟机日志、登录信息等的一系列工具脚本

### 使用方法：
Example: python health_check.py --operate "check" --svrType "x86" --freq "daily" --area interior

## 执行流程
程序依据init_config.yaml文件内容 结合Servers-x86.xlsx(用于x86云虚拟机)或Servers-arm.xlsx（国产arm云平台虚拟机），生成用于程序执行的config.yaml配置文件

所有机器检查的内容大体相同，其用于检查的脚本放在./common目录下面，如果机器有特别的检查脚本，该脚本放置在具体的机器目录下面如：\01_city\01_ioc\exterior\process_check.sh

# 结果展示
执行中将运行脚本拷贝至目标机器，在目标机器的/tmp目录下创建用于本次巡检的工作目录，执行完成之后，将结果拷贝回执行机，用于汇总；

最终的巡检结果文件由./conf/collect_restlt.py 汇集成.xlsx用于故障排查和结果展示。

执行的结果文件如：arm_interior_cpumem_20230418150522.tgz或arm_exterior_cpumem_20230418143014.tgz 

所有机器的检查结果汇总如下表，其中如果有一个机器的检查结果失败，则该项标记为Failed， 只有全部成功时才标记为Success
Execute_Time                                                | 20230418141749
Operation                                                   | cpumem    
Server_Type                                                 | x86       
Check_Project                                               | 01_city-01_ioc
Correlation_Servers                                         | 10.250.143.100,10.250.143.101
Net_Area                                                    | interior
CURR_PATH                                                   | /tmp/healthCheck
Server_IP                                                   | Server_IP 
HealthCheckRST                                              | /home/healthCheck/health_checkRst_20230418141749.tgz
Check_Failed_Servers                                        |           
Health_Check_Item                                           | Check Result
app_docker_container_status                                 | Success  
app_java_conf_folder_status                                 | Success  
app_java_conf_status                                        | Success  
app_java_process_log                                        | Failed  
app_java_process_status                                     | Success  
app_nginx_conf_folder_status                                | Success  
app_nginx_conf_status                                       | Success  
app_nginx_process_log                                       | Success  
app_nginx_process_status                                    | Success  
app_rabbitmq_container_status                               | Success  
db_mysql_db_disk_status                                     | Success  
db_mysql_db_version                                         | Failed  
db_mysql_etc_my_cnf                                         | Success  
db_mysql_log_mysqlerror                                     | Success  
db_mysql_log_slow                                           | Success  
db_mysql_master_slavbe_status                               | Success  
db_mysql_qcache_hits_insert_delete_update                   | Success  
db_mysql_show_conn_status                                   | Success  
db_mysql_show_tables                                        | Success  
db_mysql_show_variables_and_expire                          | Success  
db_mysql_uptime_con_sessions                                | Success  
os_os_cpu_usage                                             | Success  
os_os_disk_usage                                            | Success  
os_os_etc_hostinfo                                          | Success  
os_os_etc_selinux_service                                   | Success  
os_os_etc_sys_nics_ifcfg                                    | Success  
os_os_group_pwd_shadow                                      | Success  
os_os_mem_usage                                             | Success  
os_os_os_last                                               | Success  
os_os_os_nics_ip                                            | Success  
os_os_os_sysctl                                             | Success  
os_os_var_log_boot                                          | Success  
os_os_var_log_cron                                          | NotCheck  



