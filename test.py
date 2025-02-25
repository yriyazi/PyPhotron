# import subprocess

# ip_address = "192.168.0.10"
# response = subprocess.run(["ping", "-n", "1", ip_address], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

# if response.returncode == 0:
#     print(f"Device {ip_address} is reachable")
# else:
#     print(f"Device {ip_address} is not reachable")

from pyphotron.pyphotron_pdclib import test,test_live_CV2
# test()
test_live_CV2()