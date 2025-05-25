import os
import cv2
import time
import utils
from datetime import datetime

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
            # global_logger.log(f"Memory passed: {passed/self.usable_mem_per:02.02f} %")
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

class DropPreProcessor:
    def __init__(self, frame_shape, kernel_size=(5, 5), threshold_val=30, use_cuda=True):
        self.use_cuda = use_cuda and cv2.cuda.getCudaEnabledDeviceCount() > 0
        self.kernel = cv2.getStructuringElement(cv2.MORPH_RECT, kernel_size)
        self.threshold_val = threshold_val

        if self.use_cuda:
            # Pre-allocate GPU mats (reuse across calls)
            self.gpu_prev = cv2.cuda_GpuMat(frame_shape, cv2.CV_8UC1)
            self.gpu_curr = cv2.cuda_GpuMat(frame_shape, cv2.CV_8UC1)
            self.gpu_diff = cv2.cuda_GpuMat(frame_shape, cv2.CV_8UC1)
            self.gpu_thresh = cv2.cuda_GpuMat(frame_shape, cv2.CV_8UC1)
            self.gpu_opened = cv2.cuda_GpuMat(frame_shape, cv2.CV_8UC1)
            self.gpu_dilated = cv2.cuda_GpuMat(frame_shape, cv2.CV_8UC1)

            # Create CUDA filters once
            self.morph_open = cv2.cuda.createMorphologyFilter(cv2.MORPH_OPEN, cv2.CV_8UC1, self.kernel)
            self.morph_dilate = cv2.cuda.createMorphologyFilter(cv2.MORPH_DILATE, cv2.CV_8UC1, self.kernel)
        else:
            # CPU fallback, no prealloc needed
            pass

    def process(self, prev_gray, curr_gray):
        if self.use_cuda:
            # Upload once
            self.gpu_prev.upload(prev_gray)
            self.gpu_curr.upload(curr_gray)

            # GPU operations
            self.gpu_diff = cv2.cuda.absdiff(self.gpu_prev, self.gpu_curr)
            _, self.gpu_thresh = cv2.cuda.threshold(self.gpu_diff, self.threshold_val, 255, cv2.THRESH_BINARY)
            self.gpu_opened = self.morph_open.apply(self.gpu_thresh)
            self.gpu_dilated = self.morph_dilate.apply(self.gpu_opened)

            # Download final binary mask
            dilated = self.gpu_dilated.download()
        else:
            # CPU fallback
            diff = cv2.absdiff(prev_gray, curr_gray)
            _, thresh = cv2.threshold(diff, self.threshold_val, 255, cv2.THRESH_BINARY)
            opened = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, self.kernel)
            dilated = cv2.dilate(opened, self.kernel, iterations=2)

        # Contour detection (CPU)
        contours, _ = cv2.findContours(dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        return contours

def main(crop_bellow=10, fps_index=3, shutter_index=16, resolution_index=12,
         scale_down = 1):

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

    prev_gray           = _hsc_camera.get_frame()
    prev_gray           = cv2.resize(prev_gray,(_hsc_camera.shape_frames[0]//scale_down,
                                                _hsc_camera.shape_frames[1]//scale_down))
    crop_x2             = prev_gray
    # processed_height    = prev_gray.shape[0] - crop_bellow
    # prev_gray           = prev_gray[:processed_height, :]

    font        = cv2.FONT_HERSHEY_SIMPLEX
    _fps        = utils.FPS()
    processor   = DropPreProcessor((_hsc_camera.shape_frames[0]//scale_down,
                                    _hsc_camera.shape_frames[1]//scale_down),use_cuda=True)


    prev_time = time.time()
    while True:
        node_lock_n_load = True
        if node_lock_n_load:
            # global_logger.log(f"{utils.log_timestamp()} Setting camera as READY to record.")

            frame_orig  = _hsc_camera.get_frame()
            frame_orig  = cv2.resize(frame_orig,   (_hsc_camera.shape_frames[0]//scale_down,
                                                    _hsc_camera.shape_frames[1]//scale_down))

            contours    = processor.process(prev_gray, frame_orig)
            prev_gray   = frame_orig

            drop_detected = False
            for cnt in contours:
                area = cv2.contourArea(cnt)
                if area > 500:
                    x, y, w, h = cv2.boundingRect(cnt)
                    crop_x2     = x + w
                    cv2.rectangle(frame_orig, (x, y), (x + w, y + h), (0), 2)
                    drop_detected = True

            fps = _fps.incriment()
    

            current_time = time.time()
            elapsed = current_time - prev_time

            if elapsed >= 1.0:
                print(f"FPS: {fps:.2f}")
                prev_time = current_time
           

            if drop_detected:
                _timing.main(x, crop_x2,None)
            else:
                # _hsc_camera.set_statet_ready_live()
                # _timing.begin_end = False
                # _timing.restart()
                pass

            key = cv2.waitKey(1) & 0xFF
            if key == ord('q'):
                break

            elif (key == ord('s') or _timing.begin_start) and (not _timing._DO):
                

                _timing.begin_start = False

            elif key == ord('e') or _timing.begin_end:
                _hsc_camera.set_state_save(_hsc_camera.fps_list[fps_index])

                _timing.begin_end = False
                _timing.restart()

            # if crop_x2 < 100 or x < 20:
            #     x               = 1280      
            #     crop_x2         = frame_orig.shape[1]
            #     prev_gray       = frame_orig
            #     utils.clear_screen()

            Show_now += 1
            if Show_now % 1 == 0:
                cv2.imshow("Live Feed", frame_orig)
                Show_now = 0
        else:
            pass
    _hsc_camera.set_state_off()
    

if __name__ == "__main__":
    main()
