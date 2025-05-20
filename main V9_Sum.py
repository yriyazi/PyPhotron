import os
import cv2
import time
import utils
import logging
import numpy as np
from datetime import datetime

class Logger:
    def __init__(self, base_path="logs"):
        self.logger = logging.getLogger("VideoLogger")
        self.logger.setLevel(logging.INFO)
        self.base_path = base_path
        self.log_handler = None
        self.log_file = None

        if not os.path.exists(base_path):
            os.makedirs(base_path)

    def new_log_file(self):
        now = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        self.log_file = os.path.join(self.base_path, f"log_{now}.log")

        if self.log_handler:
            self.logger.removeHandler(self.log_handler)

        self.log_handler = logging.FileHandler(self.log_file)
        formatter = logging.Formatter('%(asctime)s - %(message)s')
        self.log_handler.setFormatter(formatter)
        self.logger.addHandler(self.log_handler)

    def log(self, message, veboose= False):
        if veboose:
            print(message)
        self.logger.info(message)



class timing_loc():
    def __init__(self, shape_frames, fps=30):
        self._DO            = True
        self.begin_start    = False
        self.begin_end      = False

        self.fps            = fps
        self.shape_frames   = shape_frames
        self.memory         = 5721292800
        self.delay          = 0.016
        self.usable_memory  = self.memory
        self.const1         = self.shape_frames[0] * self.shape_frames[1] * self.fps
        self.usable_mem_per = self.memory / 100

    def memory_calclulate(self,global_logger):
        if not self._DO:
            passed = time.time() - self.start_time
            passed = passed * self.const1
            global_logger.log(f"Memory passed: {passed/self.usable_mem_per:02.02f} %")
            return passed > self.usable_memory
        
    def main(self, x1, x2,global_logger):
        if self.start_recording(x1, x2) and self._DO:
            self._DO        = False
            self.start_time = time.time()
            self.begin_start= True
            
            
        elif self.end_recording(x1, x2) or self.memory_calclulate(global_logger):
            self.begin_end  = True

    def restart(self):
        self._DO = True

    def start_recording(self, x1, x2):
        return x1 < 1200 or x2 < self.shape_frames[0] - 10
        
    @staticmethod       
    def end_recording(x1, x2):
        return x2 < 100 or x1 < 20


def main(crop_bellow=10, fps_index=3, shutter_index=5, resolution_index=12):
    # Instantiate global logger
    global_logger = Logger()    
    global_logger.new_log_file()

    Show_now            = 0

    _hsc_camera         = utils.HSC_camera(
                            fps_index       = fps_index,
                            shutter_index   = shutter_index,
                            resolution_index= resolution_index)

    _timing             = timing_loc(
                            shape_frames    = _hsc_camera.shape_frames,
                            fps             = _hsc_camera.fps_list[fps_index])

    prev_gray           = _hsc_camera.get_frame()
    h                   = prev_gray.shape[0]
    x2_base             = prev_gray.shape[1]
    processed_height    = h - crop_bellow
    prev_gray           = prev_gray[:processed_height, :]

    length = 25
    height = 25

    y                   = 0
    select_condition    = (h-height)*255
    x1               = x2_base
    x2               = x2_base 
    while True:
        node_lock_n_load = True
        if node_lock_n_load:
            Show_now += 1
            drop_detected = False
            # global_logger.log(f"{utils.log_timestamp()} Setting camera as READY to record.")

            frame_orig  = _hsc_camera.get_frame()
            fff         = frame_orig[:,:x2].sum(axis=0, dtype=np.uint32)
            mask        = fff < select_condition
            if np.count_nonzero(mask) > length:
                drop_detected   = True
                ffff            = fff[mask]
                x1              = np.argmin(fff)
                x2              = np.argmax(fff)
                if Show_now % 2 == 0:
                    cv2.rectangle(frame_orig, (x1, y), (x2, y + h), (0), 2)
                print(f"X1: {x1}, x2: {x2}")
            
            # if drop_detected:
            #     _timing.main(x, crop_x2,global_logger)
            # else:
            #     _hsc_camera.set_statet_ready()
            #     _timing.begin_end = False
            #     _timing.restart()

            if  x1 < 20 or x2 < 100:
                x1               = x2_base
                x2               = x2_base      
                # utils.clear_screen()

            key = cv2.waitKey(1) & 0xFF
            if key == ord('q'):
                break

            elif key == ord('s') or _timing.begin_start:
                _hsc_camera.set_Satate_rec()
                global_logger.log("SAVING Initiated")
                _timing.begin_start = False

            elif key == ord('e') or _timing.begin_end:
                _hsc_camera.set_state_save(_hsc_camera.fps_list[fps_index])
                global_logger.log("Downloading video...")
                _hsc_camera.set_statet_ready()
                global_logger.log(f"Downlaod complete")
                _timing.begin_end = False
                _timing.restart()
                global_logger.log('Done')
                global_logger.new_log_file()


            
            if Show_now % 2 == 0:
                cv2.imshow("Live Feed", frame_orig)
                Show_now = 0
        else:
            global_logger.log(f"Lock and load is OFF. Waiting for the next cycle.")

    _hsc_camera.set_state_off()
    

if __name__ == "__main__":
    main()
