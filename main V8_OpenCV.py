import os
import cv2
import time
import utils
import logging
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
    x                   = 1280
    drop_positions      = []

    _hsc_camera         = utils.HSC_camera(
                            fps_index       = fps_index,
                            shutter_index   = shutter_index,
                            resolution_index= resolution_index)

    _timing             = timing_loc(
                            shape_frames    = _hsc_camera.shape_frames,
                            fps             = _hsc_camera.fps_list[fps_index])

    kernel              = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
    prev_gray           = _hsc_camera.get_frame()
    crop_x2             = prev_gray.shape[1]
    processed_height    = prev_gray.shape[0] - crop_bellow
    prev_gray           = prev_gray[:processed_height, :]
    while True:
        node_lock_n_load = True
        if node_lock_n_load:
            # global_logger.log(f"{utils.log_timestamp()} Setting camera as READY to record.")

            frame_orig  = _hsc_camera.get_frame()
            frame       = frame_orig[:processed_height, :crop_x2]
            prev_gray   = prev_gray[:processed_height, :crop_x2]
            contours    = utils.preProcess(prev_gray, frame, kernel)
            prev_gray   = frame

            drop_detected = False
            for cnt in contours:
                area = cv2.contourArea(cnt)
                if area > 500:
                    x, y, w, h = cv2.boundingRect(cnt)
                    crop_x2     = x + w
                    center_x    = x + w // 2
                    center_y    = y + h // 2
                    drop_positions.append((center_x, center_y, time.time()))
                    cv2.rectangle(frame, (x, y), (x + w, y + h), (0), 2)
                    global_logger.log(f"Detected drop at: {x}, {y}, {x+w}, {y+h}")
                    drop_detected = True

            if drop_detected:
                _timing.main(x, crop_x2,global_logger)
            else:
                _hsc_camera.set_statet_ready()
                _timing.begin_end = False
                _timing.restart()

            key = cv2.waitKey(1) & 0xFF
            if key == ord('q'):
                break

            elif key == ord('s') or _timing.begin_start:
                _hsc_camera.set_Satate_rec()
                global_logger.log("SAVING Initiated")
                _timing.begin_start = False

            elif key == ord('e') or _timing.begin_end or crop_x2 < 100 or x < 20:
                _hsc_camera.set_state_save(_hsc_camera.fps_list[fps_index])
                global_logger.log("Downloading video...")
                _hsc_camera.set_statet_ready()
                global_logger.log(f"Downlaod complete")
                _timing.begin_end = False
                _timing.restart()
                global_logger.log('Done')
                global_logger.new_log_file()


            if crop_x2 < 100 or x < 20:
                x               = 1280      
                crop_x2         = frame_orig.shape[1]
                prev_gray       = frame_orig
                drop_positions  = []
                utils.clear_screen()

            Show_now += 1
            if Show_now % 1 == 0:
                cv2.imshow("Live Feed", frame_orig)
                Show_now = 0
        else:
            global_logger.log(f"Lock and load is OFF. Waiting for the next cycle.")

    _hsc_camera.set_state_off()
    

if __name__ == "__main__":
    main()
