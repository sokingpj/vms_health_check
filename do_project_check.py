#!/usr/bin/python
from functools import wraps
import os
import shutil
import time
import traceback
import argparse
from yaml import loader
import yaml
import tarfile
import paramiko
from retrying import retry
from conf.collect_restlt import CollectResult
from conf.check_logger import Check_Logger
import base64
from concurrent.futures import ThreadPoolExecutor,wait,ALL_COMPLETED


BASE_DIR = os.path.dirname(os.path.abspath(__file__))


class ClientSSH():
    def __init__(self,svrIP=None,user=None,pwd=None,port=22,logger=None) -> None:
        self.svrIP = svrIP
        self.user = user
        self.pwd = pwd
        self.logger = logger
        try:
            self.client = paramiko.SSHClient()
            self.client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            self.logger.info('connect info: svrIP=%s,user=%s,pwd=******'%(svrIP,user))
            if not self.svrIP or not self.user or not self.pwd:
                raise Exception('ClientSSH()->ssh info is not correct, ip=%s, user=%s, pwd=******' % (svrIP,user))
            if not self.client.get_transport():
                self._client_connect()
        except Exception as e:
            raise Exception('connect exception: %s, ip=%s, user=%s, pwd=******' % (e,svrIP,user))


    @retry(stop_max_attempt_number=6)
    def _client_connect(self):
        try:
            self.client.connect(hostname=self.svrIP,username=self.user,password=self.pwd,timeout=60)
            self.logger.info('connect to %s successfully.' % (self.svrIP))
        except paramiko.AuthenticationException as e:
            raise Exception('%s username: %s or password: %s is/are not correct.' % (self.svrIP,self.user,self.pwd))
        except Exception as e:
            raise Exception('ssh connect to %s exception %s' %(self.svrIP, e))
    

    def sendCmd(self,cmd: str=''):
        try:
            self.logger.info('execute cmd: %s' % cmd)
            if not cmd:
                raise Exception('Execute command should not be None.')
            cmd = f'{cmd}\n'
            cmdLen = len(cmd)
            channel = self.client.invoke_shell()
            sendLen = channel.send(cmd.encode('UTF-8'))
            idx = 1
            while idx < 40:
                time.sleep(1)
                self.logger.info('%d times run cmd %s' % (idx,cmd))
                if cmdLen == sendLen:
                    break
                idx += 1
            out = channel.recv(10240).decode('UTF-8')
            self.logger.info('out %s' % out)
        except Exception as e:
            raise Exception('Execute cmd=%s has failed.' % cmd)


    def uploadFile(self, srcFile: str='', destFile: str='', methord='put'):
        try:
            lowMethord = methord.lower()
            self.logger.info('def uploadFile(srcFile=%s,destFile=%s,methord=%s) start...'%(srcFile,destFile,lowMethord))
            if not srcFile or not destFile or not lowMethord in ['put', 'get']:
                raise Exception('upload parameters is not correct, please check!!')
            
            sftp = paramiko.SFTPClient.from_transport(self.client.get_transport())
            rmtDir = os.path.dirname(destFile)
            lclDir = os.path.dirname(srcFile)
            if lowMethord == 'put':
                fileName = os.path.basename(srcFile)
                self.sendCmd('mkdir -p {rmtDir}'.format(rmtDir=rmtDir))
                sftp.put(srcFile,rmtDir+'/'+fileName)
            else:
                fileName = os.path.basename(destFile)
                if not os.path.exists(lclDir):
                    os.makedirs(lclDir)
                sftp.get(destFile,os.path.join(lclDir,fileName))
            self.logger.info('sftp %s %s <--> %s has successed.' % (lowMethord,srcFile,destFile))
        except Exception as e:
            raise Exception('sftp exception %s %s <--> %s.' % (lowMethord,srcFile,destFile))


    def close(self):
        try:
            self.client.close()
            for item in ["svrIP","user","pwd", "client"]:
                if hasattr(self,item):
                    delattr(self,item)
        except:
            pass


class Do_Project_Check():
    def __init__(self,logger=None,lowFreq='',lowArea='',lowOperate='',lowSvrType='') -> None:
        '''
        lowOperate: 'check'
        lowSvrType: 'x86'
        lowFreq: 'daily'
        lowArea: 'goverment'
        '''
        self.logger = logger
        self.lowOperate = lowOperate.strip('"').strip("'").lower()
        self.lowSvrType = lowSvrType.strip('"').strip("'").lower()
        self.lowFreq = lowFreq.strip('"').strip("'").lower()
        self.lowArea = lowArea.strip('"').strip("'").lower()

        self.main_script = 'check_main.sh'
        if self.lowOperate == 'cpumem':
            self.main_script = 'cpumem_main.sh'

    def prepare_variables(self,project='') -> None:
        try:
            
            if not self.logger:
                self.logger = Check_Logger('Do_Project_Check')
            '''
            project: '03_store_01_auth-01_auth'
            ''' 
            self.projStr = project.strip('"').strip("'").lower()
            self.project = self.projStr.split('-')[0]
            self.child = self.projStr.split('-')[1]
            
            self.logger.info('\nparameters: ')
            self.logger.info('self.lowOperate: %s, self.lowSvrType: %s' % (self.lowOperate, self.lowSvrType))
            self.logger.info('self.lowFreq: %s, self.project: %s, self.child: %s\n' % (self.lowFreq, self.project, self.child))
            if self.lowFreq not in ['daily', 'biweekly', 'monthly']:
                raise Exception('The health check frequency should be "[daily | biweekly | monthly]"')
            
            if self.project not in ['01_ioc', '02_digital_twins', '03_store_01_auth', '04_shared_exchange']:
                raise Exception('The health check frequency should be "[daily | biweekly | monthly]"')

            self.config = os.path.join(BASE_DIR, 'conf','config.yaml')
            if not os.path.exists(self.config):
                raise Exception('The config.yaml file is not exist, please check!!')
            
            self.timeStr = time.strftime("%Y%m%d%H%M%S", time.localtime())
            self.rstTmpFolder = os.path.join(BASE_DIR,'result')
            self.resultFolder = os.path.join(self.rstTmpFolder,self.projStr)
            if not os.path.exists(self.resultFolder):
                os.makedirs(self.resultFolder)

            self.check_items_conf = os.path.join(BASE_DIR, 'conf', self.timeStr+'_check_items.conf')
            self.check_svrs_yaml = os.path.join(BASE_DIR, 'conf', 'check_servers.yaml')
            self.tarfileName = 'checkCode.tar.gz'
            self.healthCheckRST = '/home/healthCheck/health_checkRst_'+self.timeStr+'.tgz'
            self.rmtExecFolder = '/tmp/healthCheck'
            self.rmtBackFolder = '/home/healthCheck'
            self.back_folder = '/opt/check_result'

            self.localFolder = '/tmp'
            if os.name == 'nt':
                self.localFolder = BASE_DIR
            self.localTarFile = os.path.join(self.localFolder, self.tarfileName)
            self.backTarFile = os.path.join(self.back_folder, '{}_{}_{}_{}.tgz'.format(self.lowSvrType,self.lowArea,self.lowOperate,self.timeStr))
            
            self.resultXlsFileName = 'healthCheck_'+self.lowArea+'.xlsx'
            self.conf_E_Gov_yml = {}
            self.check_items = []
            self.chk_failed_svrs = []
            self.check_svrs = {}

        except Exception as e:
            raise Exception('init has failed, %s, traceback.format_exc(): %s' % (e, traceback.format_exc()))


    def read_config_yaml(self):
        try:
            self.logger.info('process yaml: %s' % (self.config))
            fread = open(self.config, 'r', encoding='utf-8')
            self.conf_E_Gov_yml = yaml.load(fread.read(), Loader=loader.FullLoader)
            fread.close()
        except Exception as e:
            raise Exception('read_config_yaml has failed, %s, traceback.format_exc(): %s' % (e, traceback.format_exc()))


    def prepare_chk_items(self):
        try:
            for item_k,item_v in self.conf_E_Gov_yml['check_items'].items():
                for app_k, app_v in item_v.items():
                    for k,v in app_v.items():
                        if self.lowFreq in v['check_freq']:
                            itemStr = "%s_%s_%s" % (item_k,app_k,k)
                            self.check_items.append(itemStr)
            # self.logger.info('%s' %(self.check_items))
        except Exception as e:
            raise Exception('print projects has failed {e}, {trace}'.format(e=e, trace=traceback.format_exc()))


    def prepare_chk_svrs(self):
        try:
            child_lst = self.conf_E_Gov_yml['projects'][self.project].keys()
            if self.child not in child_lst:
                raise Exception('The parameter project-"child" not in the project, child list should be "{c}", please check!!'.format(c=child_lst))

            svrTmp = {}
            # self.check_svrs
            svrTmp = self.conf_E_Gov_yml['projects'][self.project][self.child]['interior']
            if self.lowArea == 'internet':
                svrTmp = self.conf_E_Gov_yml['projects'][self.project][self.child]['internet']
            for k,v in svrTmp.items():
                if k not in self.check_svrs.keys():
                    self.check_svrs[k] = {}
                    # on this step skip the windows server, because jump server's user is administrator
                    if v['user'] in ['root']:
                        self.check_svrs[k] = v
                        self.check_svrs[k]['pwd'] = v['pwd']
            # self.logger.info('check servers: %s' % self.check_svrs)

        except Exception as e:
            raise Exception('print projects has failed {e}'.format(e=e))

    def prepare_shell_exec_conf(self,fillRst=False,failedSvrLst=[]):
        try:
            if os.path.exists(self.check_items_conf):
                os.remove(self.check_items_conf)
            self.logger.info('save health check itmes info into: %s' % self.check_items_conf)
            svrStr=','.join(list(self.check_svrs.keys())).replace("_",'.')

            # self.titleStr.append('%-60s| %-10s\n'%('check_project',self.projStr))
            self.titleStr = {}
            self.titleStr['Execute_Time'] = self.timeStr
            self.titleStr['Operation'] = self.lowOperate
            self.titleStr['Server_Type'] = self.lowSvrType
            self.titleStr['Check_Project'] = self.projStr
            self.titleStr['Correlation_Servers'] = svrStr
            
            self.titleStr['Net_Area'] = self.lowArea
            self.titleStr['CURR_PATH'] = self.rmtExecFolder
            self.titleStr['Server_IP'] = 'Server_IP'
            self.titleStr['HealthCheckRST'] = self.healthCheckRST

            failSvrs = ','.join(failedSvrLst)
            if not fillRst:
                failSvrs = ''    
            self.titleStr['Check_Failed_Servers'] = failSvrs
            
            self.titleStr['Health_Check_Item'] = 'Check Result'

            if not fillRst:
                for item in self.check_items:
                    self.titleStr[item] = 'NotCheck'                

            fw = open(self.check_items_conf,'w',encoding='utf-8')
            for k,v in self.titleStr.items():
                wrtStr = '%-60s| %-10s\n' % (k, v)
                fw.write(wrtStr)
            fw.close()

            if os.path.exists(self.check_items_conf):
                filename = os.path.basename(self.check_items_conf)
                dstFile = os.path.join(self.resultFolder,filename)
                shutil.copyfile(self.check_items_conf,dstFile)
            self.resultFolder

        except Exception as e:
            raise Exception('print projects has failed {e}, {trace}'.format(e=e, trace=traceback.format_exc()))

    
    def write_into_yml(self):
        try:
            if os.path.exists(self.check_svrs_yaml):
                os.remove(self.check_svrs_yaml)
            self.logger.info('save health check servers info into: %s' % self.check_svrs_yaml)
            fwrite = open(self.check_svrs_yaml, 'w', encoding='utf-8')
            yaml.safe_dump(self.check_svrs, fwrite, sort_keys=True, encoding='utf-8', default_flow_style=False,
                        canonical=False, width=800, default_style=None, indent=2)
            fwrite.close()
        except Exception as e:
            raise Exception('write server has failed, exception: %s' % e)

    def exclude_folder(self,tarinfo=None):
        if tarinfo.name in ['result', 'logs','nohup.out']:
            return None
        return tarinfo

    def tar_exec_back_files(self,srcFolder='',tar_file_path='',flag='exec'):
        try:
            self.logger.info('def tar_exec_back_files({srcFolder},{tar_file_path},{flag})'.format(srcFolder=srcFolder,tar_file_path=tar_file_path,flag=flag))
            tar_file_folder = os.path.dirname(tar_file_path)
            if not os.path.exists(tar_file_folder):
                os.makedirs(tar_file_folder)

            if os.path.exists(tar_file_path):
                os.remove(tar_file_path)

            if not os.path.exists(srcFolder):
                raise Exception('tar folder is not exist, folder: %s' % srcFolder)
            
            tarf = tarfile.open(tar_file_path,'w:gz')            
            if flag == 'exec':
                tarf.add(srcFolder,arcname='',recursive=True,filter=self.exclude_folder)
            elif flag == 'back':
                for dir in ['result', 'logs']:
                    tarf.add(os.path.join(srcFolder,dir),arcname=dir,recursive=True)
                os.popen('chown zabbix:zabbix %s' % (tar_file_path))
            else:
                raise Exception('tar_files() parameter flag:%s is not correct!!' % flag)

            self.logger.info('"%s" tar src folder %s into %s' % (flag,srcFolder,tar_file_path))
            tarf.close()
                
        except Exception as e:
            self.logger.error('tar file has failed, exception %s, trace: %s'%(e, traceback.format_exc()))  

    def do_exec_chk_svrs(self,svrIP='',user='',pwd='',srcFile=''):
        try:
            if svrIP == '' or user == '' or pwd == '':
                self.logger.error('parameter check ssh info is not correct, ip=%s, user=%s, pwd=******' % (svrIP,user))
            
            sshClient = ClientSSH(svrIP=svrIP,user=user,pwd=pwd,logger=self.logger)
            fileName = os.path.basename(srcFile)
            rmtTmpFile = os.path.dirname(self.rmtExecFolder) + '/' + fileName
            sshClient.uploadFile(srcFile,rmtTmpFile,'put')

            sshClient.sendCmd('rm -rf {execFolder}; mkdir {execFolder}; tar xf {rmtTmpFile} -C {execFolder}'.format(execFolder=self.rmtExecFolder,rmtTmpFile=rmtTmpFile))
            self.logger.info('rm -rf {execFolder}; mkdir {execFolder}; tar xf {rmtTmpFile} -C {execFolder}'.format(execFolder=self.rmtExecFolder,rmtTmpFile=rmtTmpFile))
            sshClient.sendCmd('rm -f {rmtTmpFile}; cd {execDir}; ls; nohup bash {script} "{timeStr}" "{svrIP}" &'.format(rmtTmpFile=rmtTmpFile, execDir=self.rmtExecFolder,script=self.main_script,timeStr=self.timeStr,svrIP=svrIP))
            self.logger.info('rm -f {rmtTmpFile}; cd {execDir}; ls; nohup bash {script} "{timeStr}" "{svrIP}" &'.format(rmtTmpFile=rmtTmpFile, execDir=self.rmtExecFolder,script=self.main_script,timeStr=self.timeStr,svrIP=svrIP))

            idx = 1
            while idx <= 120:
                time.sleep(2)
                self.logger.info('%d: time.sleep(2), run on %s' % (idx,svrIP))
                stdin, stdout, stderr = sshClient.client.exec_command('ls %s' % self.healthCheckRST)
                cmdOut = stdout.read().strip().decode()
                errOut = stderr.read().strip().decode()
                self.logger.info('stdout: {out}, stderr: {err}'.format(out=cmdOut, err=errOut))
                if cmdOut == self.healthCheckRST:
                    self.logger.info('break')
                    break
                idx += 1

            svrIPTmp = svrIP.replace('.','_')
            fileName = os.path.basename(srcFile)
            lclBackDir = os.path.join(self.resultFolder,svrIPTmp)
            execResultFile = os.path.join(self.rmtExecFolder+'/result/'+self.timeStr+'/check_items.conf')
            lclBackFile = os.path.join(lclBackDir,fileName)
            lclResultFile = os.path.join(lclBackDir,'check_items.conf')
            if not os.path.exists(lclBackDir):
                os.makedirs(lclBackDir)
            sshClient.uploadFile(lclBackFile,self.healthCheckRST,'get')
            sshClient.uploadFile(lclResultFile,execResultFile,'get')

            stdin, stdout, stderr = sshClient.client.exec_command('rm -rf %s %s' % (self.rmtExecFolder,self.healthCheckRST))

            self.logger.info('Execute Health Check has finished, server IP: %s.' % svrIP)
            self.logger.info('Execute Health Check result tar.gz file: %s.' % lclBackFile)
            self.logger.info('Execute Health Check result file: %s.' % lclResultFile)
            sshClient.close()
        except Exception as e:
            self.chk_failed_svrs.append(svrIP)
            self.logger.error('do health check on %s exception: %s, format: %s' % (svrIP, e, traceback.format_exc()))

    def exec_chk_svrs(self):
        try:
            exec = ThreadPoolExecutor(max_workers=20)
            # ipStr='192.168.4.101'
            # user = 'root'
            # pwd = 'root'
            # ipTmp = ipStr.replace('_', '.')
            # self.logger.info('')
            # self.logger.info('')
            # self.logger.info('self.do_exec_chk_svrs({svrIP},{user},{pwd},{srcFile})'.format(svrIP=ipTmp,user=user,pwd=pwd,srcFile=self.localTarFile))
            # all_tasks = [exec.submit(self.do_exec_chk_svrs, svrIP=ipTmp,user=user,pwd=pwd,srcFile=self.localTarFile)]
            # wait(all_tasks,return_when=ALL_COMPLETED)

            all_tasks = []
            for ipStr,v in self.check_svrs.items():
                if 'user' not in v.keys():
                    self.chk_failed_svrs.append(ipStr)
                    continue
                if ipStr in ['10_250_143_244','10_250_143_245','10_250_143_155','172_21_57_41','172_21_57_47','172_21_57_48',]:
                    continue
                user = v['user']
                pwdTmp = v['pwd']
                pwd = str(base64.b64decode(pwdTmp), encoding='utf-8')
                ipTmp = ipStr.replace('_','.')
                self.logger.info('')
                self.logger.info('')
                self.logger.info('self.do_exec_chk_svrs({svrIP},{user},****,{srcFile})'.format(svrIP=ipTmp,user=user,srcFile=self.localTarFile))
                all_tasks.append(exec.submit(self.do_exec_chk_svrs, svrIP=ipTmp,user=user,pwd=pwd,srcFile=self.localTarFile))
            self.logger.info(all_tasks)
            wait(all_tasks,return_when=ALL_COMPLETED)

            self.logger.info('all health check task has completed.')

        except Exception as e:
            self.chk_failed_svrs.append(ipStr)
            self.logger.error('Health check has failed servers: %s, exception: %s, traceback.format_exc: %s' % (self.chk_failed_svrs, e, traceback.format_exc()))

    def collect_health_Result(self):
        try:
            colRstFile = os.path.join(BASE_DIR,'result',self.resultXlsFileName)
            self.logger.info('collect health result from %s' % self.rstTmpFolder)
            collectObj = CollectResult(resultFolder=self.rstTmpFolder,resultXlsPath=colRstFile,logger=self.logger)
            collectObj.collectRst()
        except Exception as e:
            raise Exception('collect health check result from %s has failed, exception: %s' % (self.rstTmpFolder,e))

    def clean_desktop(self):
        try:
            clean_lst = [self.check_items_conf,self.check_svrs_yaml,self.localTarFile]
            for rm_file in clean_lst:
                if os.path.exists(rm_file):
                    self.logger.info('clean desktop remove %s' % (rm_file))
                    os.remove(rm_file)
        except Exception as e:
            self.logger.error('clean desktop exception %s, trace: %s'%(e, traceback.format_exc()))  


    def check_main(self):
        try:
            self.read_config_yaml()
            self.prepare_chk_items()
            self.prepare_chk_svrs()
            self.prepare_shell_exec_conf(fillRst=False, failedSvrLst=[])
            self.write_into_yml()
            self.tar_exec_back_files(BASE_DIR,tar_file_path=self.localTarFile,flag='exec')
            self.exec_chk_svrs()
            self.prepare_shell_exec_conf(fillRst=False, failedSvrLst=self.chk_failed_svrs)
            self.collect_health_Result()
            return 0
        except Exception as e:
            self.logger.info('health check has failed, please check: {e} \n{traceback}'.format(e=e, traceback=traceback.format_exc()))
            return 1


if __name__ == "__main__":
    project = 'Project should be [01_ioc | 02_digital_twins | 03_store_01_auth | 04_shared_exchange]'
    child = 'Child should be {if project=01_ioc, child shoud be "01_ioc", '
    child += 'if project=02_digital_twins, child shoud be "01_digital_twins", '
    child += 'if project=03_store_01_auth, child shoud be "[01_auth | 02_app_base]", '
    child += 'if project=01_ioc, child shoud be "[01_shared | 02_big_data]"}.'

    print('Example: python do_project_check.py --lowFreq "daily" --project "03_store_01_auth-07_city_app" --lowArea "interior"')
    parser = argparse.ArgumentParser(description='health check parameters.')
    parser.add_argument('--operate', type=str, default='check', help='Should be "[check | cpumem]"')
    parser.add_argument('--svrType', type=str, default='x86', help='Should be "[x86 | arm]"')
    parser.add_argument('--lowFreq', type=str, default='daily', help='Should be "[daily | biweekly | monthly]"')
    parser.add_argument('--project', type=str, default='03_store_01_auth-07_city_app', help='{project}; {child}; like "03_store_01_auth-07_city_app"'.format(project=project, child=child))
    parser.add_argument('--lowArea', type=str, default='interior', help='Should be "[internet | interior]"')
    args = parser.parse_args()
    obj = Do_Project_Check(logger=None,lowFreq=args.lowFreq,lowArea=args.lowArea,lowOperate=args.operate,lowSvrType=args.svrType)
    obj.prepare_variables(project=args.project)
    ret = obj.check_main()
    if ret != 0:
        exit(ret)
