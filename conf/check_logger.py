#!/usr/bin/pythond
import os
import traceback
import logging
import time


BASE_DIR = os.path.dirname(os.path.abspath(__file__))

class Check_Logger():
    def __init__(self,rootLogger=None,logger_name='') -> None:
        try:
            chk_log_name = 'health_check'
            if rootLogger.__class__ == 'logging.Logger':
                if rootLogger.name == logger_name:
                    return
                else:           # if give the 'logging.Logger' object, in this class use the rootLogger and ignor 'logger_name'.
                    chk_log_name = rootLogger.name
            elif logger_name:
                chk_log_name = logger_name
                
            self.logger = logging.getLogger(chk_log_name)
            self.logger.setLevel(logging.DEBUG)
            ls = logging.StreamHandler()
            ls.setLevel(logging.DEBUG)
            logFormat = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s: %(message)s')
            ls.setFormatter(logFormat)
            self.logger.addHandler(ls)
            logDir = os.path.join(BASE_DIR, '..','logs')
            if not os.path.exists(logDir):
                os.makedirs(logDir)
            logFile = os.path.join(logDir,self.logger.name+'.log')
            lf = logging.FileHandler(filename=logFile,encoding='utf8')
            lf.setLevel(logging.DEBUG)
            lf.setFormatter(logFormat)
            self.logger.addHandler(lf)
            self.logger.info('log file: %s' % logFile)

        except Exception as e:
            raise Exception('init has failed, %s, traceback.format_exc(): %s' % (e, traceback.format_exc()))
    
    def info(self,msg=''):
        self.logger.info(msg)

    def error(self,msg=''):
        self.logger.error(msg)

    def warn(self,msg=''):
        self.logger.warn(msg)
    
    def debug(self,msg=''):
        self.logger.debug(msg)

    def critical(self,msg=''):
        self.logger.critical(msg)

    def check_main(self):
        print(self.__dict__)            # {'logger': <Logger health_check (DEBUG)>}
        print(self.__getattribute__)    # <method-wrapper '__getattribute__' of Check_Logger object at 0x00000146B2E555D0>
        print(self.__hash__)            # <method-wrapper '__hash__' of Check_Logger object at 0x00000146B2E555D0>
        print(self.__class__)           # <class '__main__.Check_Logger'>
        print(self.logger.__class__)    # <class 'logging.Logger'>


if __name__ == "__main__":
    obj = Check_Logger()
    obj.check_main()