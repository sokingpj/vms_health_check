#!/usr/bin/python
from functools import wraps
import os
import traceback
import argparse
from conf.read_parameters import Init_Parameters
from conf.check_logger import Check_Logger
from do_project_check import Do_Project_Check
import shutil

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

class Health_Check():
    def __init__(self,operate='',svrType='',freq='', area='') -> None:
        try:
            self.logger = Check_Logger(rootLogger=None,logger_name='')
            self.lowOperate = operate.lower()
            self.lowSvrType = svrType.lower()
            self.lowFreq = freq.lower()
            self.lowArea = area.lower()

            self.logger.info('parameters: lowOperate=%s, lowSvrType=%s,lowFreq=%s, lowArea=%s' % (self.lowOperate,self.lowSvrType,self.lowFreq,self.lowArea))

            if self.lowOperate not in ['check','cpumem']:
                raise Exception('parameters is not correct, Server should only be [x86 | arm]\n\nexample: python health_check.py --operate "check" --svrType "x86" --freq "daily" --area "interior"')
            if self.lowSvrType not in ['x86','arm']:
                raise Exception('parameters is not correct, Server should only be [x86 | arm]\n\nexample: python health_check.py --operate "check" --svrType "x86" --freq "daily" --area "interior"')
            if self.lowFreq not in ['daily','biweekly','monthly']:
                raise Exception('parameters is not correct, frequent should only be [daily | biweekly | monthly]\n\nexample: python health_check.py --operate "check" --svrType "x86" --freq "daily" --area "interior"')
            if self.lowArea not in ['interior','exterior']:
                raise Exception('exterior area is not correct, area should only be [ interior | exterior ]\n\nexample: python health_check.py --operate "check" --svrType "x86" --freq "daily" --area "interior"')
            init_pra = Init_Parameters(logger=self.logger,lowSvrType=self.lowSvrType)
            self.conf_E_Gov_yml = init_pra.get_conf_E_Gov_yml()
            '''
            {
                '01_ioc': ['01_ioc'],
                '02_digital_twins': ['01_digital_twins'],
                '03_urban_brain': ['01_auth', '02_app_base', '03_industrial_economics', '04_data_hub', '05_traffic', '06_onekey_escorts', '07_city_app', '08_city_security', '09_ai_platform'],
                '04_shared_exchange': ['01_shared_exchange', '02_big_data']
            }
            '''
            self.projectDict = {}
        except Exception as e:
            raise Exception('health check init has failed, %s, traceback.format_exc(): %s' % (e, traceback.format_exc()))

    def __prepare_project_dict(self):
        try:
            for pro,cld in self.conf_E_Gov_yml['projects'].items():
                if pro not in self.projectDict.keys():
                    self.projectDict[pro] = list(cld.keys())
            self.logger.info(self.projectDict)

        except Exception as e:
            raise Exception('init has failed, %s, traceback.format_exc(): %s' % (e, traceback.format_exc()))

    def __prepare_result_folder(self):
        try:
            self.logger.info('prepare result folder.')
            rstTmpFolder = os.path.join(BASE_DIR,'result')
            if os.path.exists(rstTmpFolder):
                shutil.rmtree(rstTmpFolder, ignore_errors=True)
            os.makedirs(rstTmpFolder)
                
        except Exception as e:
            raise Exception('prepare result folder exception %s, trace: %s'%(e, traceback.format_exc())) 

    def check_main(self):
        try:
            self.__prepare_project_dict()
            self.__prepare_result_folder()
            # projectStr: 03_urban_brain-07_city_app
            chkObj = Do_Project_Check(logger=self.logger,lowFreq=self.lowFreq,lowArea=self.lowArea,lowOperate=self.lowOperate,lowSvrType=self.lowSvrType)
            for pro,clds in self.projectDict.items():
                for cld in clds:
                    projectStr = pro + '-' + cld
                    chkObj.prepare_variables(project=projectStr)
                    chkObj.check_main()
            chkObj.tar_exec_back_files(BASE_DIR,tar_file_path=chkObj.backTarFile,flag='back')
            chkObj.clean_desktop()
            self.logger.info('Execute Do_Project_Check has finished.')
        except Exception as e:
            raise Exception('init has failed, %s, traceback.format_exc(): %s' % (e, traceback.format_exc()))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='execute parameters.')
    parser.add_argument('--operate', type=str, default='check', help='Should be "[check | cpumem]"')
    parser.add_argument('--svrType', type=str, default='x86', help='Should be "[x86 | arm]"')
    parser.add_argument('--freq', type=str, default='daily', help='Should be "[daily | biweekly | monthly]"')
    parser.add_argument('--area', type=str, default='interior', help='Should be "[interior | exterior]"')
    args = parser.parse_args()
    obj = Health_Check(operate=args.operate,svrType=args.svrType,freq=args.freq,area=args.area)
    ret = obj.check_main()
    if ret != 0:
        exit(ret)
        