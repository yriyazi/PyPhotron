# import subprocess

# ip_address = "192.168.0.10"
# response = subprocess.run(["ping", "-n", "1", ip_address], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

# if response.returncode == 0:
#     print(f"Device {ip_address} is reachable")
# else:
#     print(f"Device {ip_address} is not reachable")

from pyphotron.pyphotron_pdclib import test,test_live_CV2
# test()
test_live_CV2(fps_index=2, shutter_index=0, resolution_index=5)





"""
fps_list = [50,     125,    250,    500,    1000,
            2000,   3200,   4000,   5000,   6250,
            6400,   8000,   8192,   10000,  10240,
            12500,  16000,  20000,  25000,  32000,
            40000,  50000,  64000,  80000,  100000,
            160000, 200000, 256000, 512000, 800000]

Shutter speeds:  [  125,    250,    500,    640,    800,
                    1000,   1250,   1600,   2000,   2500,
                    3125,   3200,   4000,   5000,   5120, 
                    6250,   6400,   8000,   8192,   10000, 
                    10240,  12500,  12800,  16000,  20000, 
                    20480,  25000,  25600,  32000,  32768, 
                    40000,  40960,  50000,  51200,  64000, 
                    80000,  81920,  100000, 102400, 128000, 
                    160000, 163840, 200000, 204800, 256000] 
 
 Available resolutions:  [  '1280x1024',    '1280x1000',    '1280x800', '1280x720',     '1280x616', 
                            '1280x512',     '1280x480',     '1280x400', '1280x312',     '1280x248', 
                            '1280x200',     '1280x152',     '1280x120', '1280x96',      '1280x72', 
                            '1280x56',      '1280x32',      '1280x24',  '1280x16',      '1024x1024', 
                            '1024x576',     '896x896',      '896x720',  '896x488',      '768x768', 
                            '768x512',      '640x480',      '640x320',  '640x8']

"""