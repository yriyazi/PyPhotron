"""
Python bindings for the Photron PDCLIB camera library

__author__  = ['crousseau','Yassin Riyazi']
__version__ = '0.1.1'
__licence__ = 'MIT'
"""

import  datetime
import  os
import  cv2
import  numpy                       as np
cimport numpy                       as np
np.import_array()
from    time                        import      time, sleep
from    pyphotron.codes             import      ERROR_CODES
from    pyphotron.typedefs          cimport     ulong, uint, MemRecordingInfo
from    pyphotron.pyphotron_pdclib  cimport     *

DEF PDC_MAX_DEVICE          = 64  # FIXME: check why needs to be redefined in pyx in addition to pxd
DEF PDC_MAX_LIST_NUMBER     = 256
DEF PDC_MAX_STRING_LENGTH   = 256

cdef ulong pdc_failed       = <int> PDC_FAILED
cdef ulong pdc_succeeded    = <int> PDC_SUCCEEDED
cdef ulong pdc_undefined    = 50000  # Custom for debugging

class PyPhotronException(Exception):
    pass

cpdef check_pdc_failed(ulong success, ulong error_code):
    # print('Failed ? {}'.format(not success))
    if success == pdc_failed:
        raise PyPhotronException('PDC command failed with error "{}" (code: "{}").'.
                                 format(ERROR_CODES[error_code], error_code))
    return success


cpdef init_pdc_lib():
    '''
    PDCLIB must be initialized before using various functions of PDCLIB.

    PDCLIB is initialized using a PDC_Init function.

    A PDC_Init function is performed only once in a process. 
    It is not necessary to perform this function multiple times.

    It is not necessary to explicitly perform termination. 
    In PDCLIB, all termination operations are automatically performed when a process is terminated. 
    '''
    print('Initialising')
    cdef:
        ulong success = pdc_failed
        ulong error_code = pdc_failed
    success = PDC_Init(&error_code)
    return check_pdc_failed(success, error_code)


cpdef is_function(ulong device_nb, ulong child_nb, ulong n_function):
    """This function retrieves the status of various functions of the specified device/child device."""
    cdef:
        ulong success = pdc_failed
        ulong error_code = pdc_failed
        char flag
    success = PDC_IsFunction(device_nb, child_nb, n_function, &flag, &error_code)
    check_pdc_failed(success, error_code)
    return flag == PDC_EXIST_SUPPORTED


cpdef _detect_devices(subnet=(192, 168, 0, 0)):
    """
    To control a high-speed camera in PDCLIB, the high-speed camera to be controlled must first be located using a PDC_DetectDevice function. 
    (When the development language is C#, please use PDC_DetectDeviceLV function.)
    """

    cdef:
        ulong ip_list[PDC_MAX_DEVICE]
        PDC_DETECT_NUM_INFO detect_info
        ulong n_max_devices = 2
        size_t i = 0  # TODO: check Py_ssize_t
        int b
        ulong success = pdc_failed
        ulong error_code = pdc_failed

    ip_list[0] = int.from_bytes(subnet, 'big')  # (i.e. 255.255.0.0 netmask)
    success = PDC_DetectDevice(PDC_INTTYPE_G_ETHER, ip_list, n_max_devices, PDC_DETECT_AUTO, &detect_info, &error_code)
    check_pdc_failed(success, error_code)
    if detect_info.m_nDeviceNum == 0:
        subnet_str = '.'.join([str(e) for e in subnet])
        raise PyPhotronException('No devices detected at address range {}'.format(subnet_str))
    else:
        info = detect_info.m_DetectInfo[0]
        for i in range(detect_info.m_nDeviceNum):
            print('Detected camera code {} at address {} with interface code {}'.format(
                hex(info.m_nDeviceCode),
                '.'.join([str(int(b)) for b in int(info.m_nTmpDeviceNo).to_bytes(length=4, byteorder='big')]),
                hex(info.m_nInterfaceCode)))
    return detect_info


cpdef _detect_devices_lv(subnet=(192, 168, 0, 0)):
    """
    This function searches for devices that can be opened and retrieves the number of those devices.
    This function is the same as PDC_DetectDevice except a different way of parameter passing.
    Please use it when the development language is C#.

    CHECK: Also, for some reason the previous developer have used the C# implementation. Ofcourse as long as it works I have to complaint.
    """
    cdef:
        ulong n_interface_code = PDC_INTTYPE_G_ETHER, n_detect_num = PDC_MAX_DEVICE, n_detect_param = PDC_DETECT_AUTO
        ulong p_device_num = 0, p_device_code = 0, p_tmp_device_no = 0, p_interface_code = 0
        ulong p_detect_no = 0xC0A80000  # int.from_bytes(subnet, 'big')
        ulong success = pdc_failed
        ulong error_code = pdc_failed

    success = PDC_DetectDeviceLV(n_interface_code, &p_detect_no, n_detect_num, n_detect_param,
                                 &p_device_num, &p_device_code, &p_tmp_device_no, &p_interface_code, &error_code)
    check_pdc_failed(success, error_code)
    if p_device_num == 0:
        subnet_str = '.'.join([str(e) for e in subnet])
        raise PyPhotronException('No devices detected at address range {}'.format(subnet_str))
    elif p_device_num > 1:
        raise NotImplementedError('Several devices not implemented ATM')  # TODO: transform to lists of correct size
    return p_device_code, p_tmp_device_no, p_interface_code


cpdef _open_cam(PDC_DETECT_NUM_INFO detect_num_info):
    cdef:
        ulong device_nb
        ulong success = pdc_failed
        ulong error_code = pdc_failed
    cdef PDC_DETECT_INFO info = detect_num_info.m_DetectInfo[0]
    success = PDC_OpenDevice(&info, &device_nb, &error_code)
    check_pdc_failed(success, error_code)
    return device_nb


cpdef _open_cam_lv(ulong device_code, ulong tmp_device_no, ulong interface_code):
    cdef:
        ulong device_nb = pdc_undefined
        ulong success = pdc_failed
        ulong error_code = pdc_failed
    success = PDC_OpenDeviceLV(device_code, tmp_device_no, interface_code, &device_nb, &error_code)
    check_pdc_failed(success, error_code)
    return device_nb


cpdef _get_child_device_list(ulong device_nb):
    cdef:
        ulong child_nbs[PDC_MAX_DEVICE]
        ulong length
        ulong success = pdc_failed
        ulong error_code = pdc_failed
    success = PDC_GetExistChildDeviceList(device_nb, &length, child_nbs, &error_code)
    check_pdc_failed(success, error_code)
    return child_nbs


cpdef _get_record_rate_list(ulong device_nb, ulong child_nb):
    """This function retrieves the list of recording speeds that can be set in the specified child device."""

    cdef:
        ulong rates[PDC_MAX_LIST_NUMBER]
        ulong i, rate, length
        ulong success = pdc_failed
        ulong error_code = pdc_failed
    success = PDC_GetRecordRateList(device_nb, child_nb, &length, rates, &error_code)
    check_pdc_failed(success, error_code)
    return [rate for i, rate in zip(range(length), rates)]


cpdef _set_record_rate(ulong device_nb, ulong child_nb, ulong frame_rate):
    cdef:
        ulong success = pdc_failed
        ulong error_code = pdc_failed
    success = PDC_SetRecordRate(device_nb, child_nb, frame_rate, &error_code)
    check_pdc_failed(success, error_code)


cpdef close_cam(ulong dev_num):
    """
    Because this function is automatically called upon when the process using PDCLIB is terminated,
    it does not necessarily need to be used.
    """

    cdef:
        ulong success = pdc_failed
        ulong error_code = pdc_failed
    success = PDC_CloseDevice(dev_num, &error_code)
    return check_pdc_failed(success, error_code)


cpdef get_device_name(device_nb, child_nb):
    cdef:
        char c_string[50]
        ulong success = pdc_failed
        ulong error_code = pdc_failed
    success = PDC_GetDeviceName(device_nb, child_nb, c_string, &error_code)
    check_pdc_failed(success, error_code)
    return str(c_string)


cpdef _get_shutter_speeds(ulong device_nb, ulong child_nb):
    """ This function retrieves the list of shutter speeds that can currently be set in the specified child device.
        The actual shutter speed is 1/2000 seconds when the retrieved value is 2000.
    """
    cdef:
        ulong shutter_speeds[PDC_MAX_LIST_NUMBER]
        ulong i, spd, length
        ulong success = pdc_failed
        ulong error_code = pdc_failed
    success = PDC_GetShutterSpeedFpsList(device_nb, child_nb, &length, shutter_speeds, &error_code)
    check_pdc_failed(success, error_code)
    return [spd for i, spd in zip(range(length), shutter_speeds)]


cpdef _set_shutter_fps(ulong device_nb, ulong child_nb, ulong shutter_speed):
    """
    The actual shutter speed is 1/2000 seconds when the setting value is 2000.
    Values other than those that are retrieved using PDC_GetShutterSpeedFps cannot be used.
    """
    cdef:
        ulong success = pdc_failed
        ulong error_code = pdc_failed
    success = PDC_SetShutterSpeedFps(device_nb, child_nb, shutter_speed, &error_code)
    check_pdc_failed(success, error_code)


cpdef get_shape(ulong resolution):
    cdef:
        ulong width, height
    width = resolution & 0xffff0000
    width = width >> 16
    height = resolution & 0x0000ffff
    return width, height


cpdef shape_to_res(ulong width, ulong height):
    return width << 16 | height


cpdef _get_resolutions_list(ulong device_nb, ulong child_nb):
    cdef:
        ulong resolutions[PDC_MAX_LIST_NUMBER]
        ulong i, res, length
        ulong success = pdc_failed
        ulong error_code = pdc_failed
    success = PDC_GetResolutionList(device_nb, child_nb, &length, resolutions, &error_code)
    check_pdc_failed(success, error_code)
    return [res for i, res in zip(range(length), resolutions)]


cpdef _set_resolution(ulong device_nb, ulong child_nb, ulong resolution):
    cdef:
        ulong width, height
        ulong success = pdc_failed
        ulong error_code = pdc_failed
    width, height = get_shape(resolution)
    success = PDC_SetResolution(device_nb, child_nb, width, height, &error_code)
    check_pdc_failed(success, error_code)
    return width, height


cpdef _set_trigger_mode(ulong device_nb, ulong n_frames_per_trig):
    cdef:
        ulong success = pdc_failed
        ulong error_code = pdc_failed
    success = PDC_SetTriggerMode(device_nb, PDC_TRIGGER_RANDOM, 0, n_frames_per_trig, 0, &error_code)
    check_pdc_failed(success, error_code)


cpdef _set_external_trigger(ulong device_nb):
    cdef:
        ulong success = pdc_failed
        ulong error_code = pdc_failed
    success = PDC_SetExternalOutMode(device_nb, 2, PDC_EXT_OUT_RECORD_POSI, &error_code)
    # success = PDC_SetExternalOutMode(device_nb, 2, PDC_EXT_OUT_READY_POSI, &error_code)
    check_pdc_failed(success, error_code)


def update_params(ulong device_nb, ulong child_nb, ulong n_frames_per_trig=5000):  # TODO: cpdef
    """

    """
    speeds = _get_shutter_speeds(device_nb, child_nb)
    print('Shutter speeds: ', speeds)
    _set_shutter_fps(device_nb, child_nb, speeds[0])
    resolutions = _get_resolutions_list(device_nb, child_nb)
    print('Available resolutions: ', ['{}x{}'.format(*get_shape(res)) for res in resolutions])
    _set_resolution(device_nb, child_nb, resolutions[0])
    print('Setting trigger mode')
    _set_trigger_mode(device_nb, n_frames_per_trig)
    _set_external_trigger(device_nb)


cpdef _get_color_type(ulong device_nb, ulong child_nb):
    cdef:
        char mode
        ulong success = pdc_failed
        ulong error_code = pdc_failed
    success = PDC_GetColorType(device_nb, child_nb, &mode, &error_code)
    check_pdc_failed(success, error_code)
    return mode


cpdef is_color(ulong device_nb, ulong child_nb):
    mode = _get_color_type(device_nb, child_nb)
    return mode == PDC_COLORTYPE_COLOR


cpdef _get_resolution(ulong device_nb, ulong child_nb):
    cdef:
        ulong width, height
        ulong success = pdc_failed
        ulong error_code = pdc_failed
    success = PDC_GetResolution(device_nb, child_nb, &width, &height, &error_code)
    check_pdc_failed(success, error_code)
    return width, height

cpdef is_rec_ready(ulong device_nb):
    return get_status(device_nb) in (PDC_STATUS_RECREADY, PDC_STATUS_REC)


cpdef is_recording(ulong device_nb):
    return get_status(device_nb) == PDC_STATUS_REC


cpdef record(ulong device_nb):
    cdef:
        ulong success = PDC_FAILED
        ulong error_code = PDC_FAILED
    # TODO: check if live ?
    success = set_rec_ready(device_nb)
    if not success:
        return
    success = PDC_SetEndless(device_nb, &error_code)
    check_pdc_failed(success, error_code)
    success = wait_till_recording(device_nb)
    # check_pdc_failed(success, error_code)


cpdef set_rec_ready(ulong device_nb):
    cdef:
        ulong success = PDC_FAILED
        ulong error_code = PDC_FAILED
    success = PDC_SetRecReady(device_nb, &error_code)
    check_pdc_failed(success, error_code)
    success = wait_till_rec_ready(device_nb)
    return success


cpdef wait_till_rec_ready(ulong device_nb):
    waited = time()
    while True:
        if is_rec_ready(device_nb):
            return PDC_ERROR_NOERROR


cpdef wait_till_recording(ulong device_nb):
    waited = time()

    while True:
        if is_recording(device_nb):
            return PDC_ERROR_NOERROR
        # if time() - waited > TIMEOUT:
        # print("cannot start recording")
        # return PDC_FAILED


cpdef get_status(ulong device_nb):
    cdef:
        ulong error_code = pdc_failed
        ulong status
    success = PDC_GetStatus(device_nb, &status, &error_code)
    check_pdc_failed(success, error_code)
    return status

#######################################################################################
#####################################Set status##########################################
#######################################################################################

cpdef _set_status(ulong device_nb, ulong status):
    cdef:
        ulong error_code = pdc_failed
    while True:
        success = PDC_SetStatus(device_nb, status, &error_code)  # FIXME: infinite loop while not in status
        check_pdc_failed(success, error_code)
        if get_status(device_nb) == status:
            break
        else:
            sleep(0.1)

cpdef set_playback(ulong device_nb):
    """
    It is necessary to enter the memory playback mode for retrieving recording conditions. 
    Therefore, switch the device to the memory playback mode first using the PDC_SetStatus function.
    The following is performed in live mode :
        Setting and retrieving recording conditions
        Retrieving image data (live image) in current recording conditions
        Execution of recording

    The following is performed in playback mode :
        Retrieving recording conditions for recording result
        Retrieving image data for recording image
    """
    _set_status(device_nb, status=PDC_STATUS_PLAYBACK)


cpdef set_live(ulong device_nb):
    """
    In principle, Photron's high-speed camera is used by switching between two operating modes, 
    they are the live mode and the memory playback mode.
    
    The following is performed in live mode :
        Setting and retrieving recording conditions
        Retrieving image data (live image) in current recording conditions
        Execution of recording

    The following is performed in playback mode :
        Retrieving recording conditions for recording result
        Retrieving image data for recording image
    """
    _set_status(device_nb, status=PDC_STATUS_LIVE)

cpdef stop_recording(ulong device_nb, ulong child_nb):
    """
    No Documantiatio
    """
    _set_status(device_nb, PDC_STATUS_PAUSE)





cpdef get_n_chunks(ulong n_recorded_frames, ulong n_frames_per_trig):
    cdef ulong n_chunks = n_recorded_frames // n_frames_per_trig
    if n_recorded_frames % n_frames_per_trig:
        n_chunks += 1
    return n_chunks


cpdef save(ulong device_nb, ulong child_nb, str folder, str base_name, bint prepend_date, ulong vid_idx,
           ulong n_frames_per_trig=5000, codec='MRAW'):
    cdef:
        ulong error_code = pdc_failed
        ulong n_recorded_frames
        char mode
        MemRecordingInfo rec_info

    rec_info.n_recorded_frames, _, _ = _get_recorded_frame_info(device_nb, child_nb)
    if rec_info.n_recorded_frames <= 0:
        return

    set_playback(device_nb)

    # create folder to save videos
    if prepend_date:
        dt = datetime.date.today()
        f_name = '{date}_{basename}'.format(date=dt.strftime('%y%m%d'), basename=base_name)
    else:
        f_name = base_name
    dest_path = os.path.join(folder, f_name)
    if not os.path.exists(dest_path):
        os.mkdir(dest_path)

    # //////////////// RECORDING PARAMETERS /////////
    rec_info.width, rec_info.height = _get_mem_resolution(device_nb, child_nb)
    rec_info.color = is_color(device_nb, child_nb)
    rec_info.fps = _get_mem_record_rate(device_nb, child_nb)
    rec_info.n_frames_per_trig = n_frames_per_trig

    # //////////////// FILE SAVE ///////////////////
    status = get_status(device_nb)  # TODO: check if required
    set_playback(device_nb)

    cdef:
        ulong n_chunks = get_n_chunks(rec_info.n_recorded_frames, n_frames_per_trig)
        ulong i = 0
    for i in range(n_chunks):
        if codec.lower() == 'mraw':
            save_m_raw(device_nb, child_nb, dest_path, i, vid_idx + i, base_name, rec_info)
        elif codec.lower() == 'h264':
            save_h264(device_nb, child_nb, dest_path, i, vid_idx + i, base_name, rec_info)


cpdef save_m_raw(ulong device_nb, ulong child_nb, str dest_path, uint idx, ulong vid_idx,
                 str base_name, MemRecordingInfo rec_info):
    cdef:
        ulong success
        ulong error_code = pdc_failed

    file_name = '{base_name}_{vid_idx}.raw'.format(base_name=base_name, vid_idx=str(vid_idx).zfill(4))
    file_path = os.path.join(dest_path, file_name)

    # Open the destination MRAW file
    # cdef char tmp_file_path_char[PDC_MAX_STRING_LENGTH]  # Required to have a local value
    cdef:
        size_t j = 0
        char c = 0
        char c_string [PDC_MAX_STRING_LENGTH]
    for j, c in enumerate(file_path.encode('ascii')):
        c_string[j] = c
    c_string[j + 1] = 0
    # tmp_file_path_char = string_to_c_string(file_path)
    cdef LPCTSTR file_path_c = c_string
    success = PDC_MRAWFileSaveOpen(device_nb, child_nb, file_path_c, PDC_MRAW_BITDEPTH_8, 0, &error_code)
    check_pdc_failed(success, error_code)

    # Save each frame
    cdef ulong start_frame_idx, end_frame_idx
    start_frame_idx = idx * rec_info.n_frames_per_trig
    end_frame_idx = min(start_frame_idx + rec_info.n_frames_per_trig, rec_info.n_recorded_frames)  # For last chunk
    cdef ulong i = 0
    for i in range(start_frame_idx, end_frame_idx):
        success = PDC_MRAWFileSave(device_nb, child_nb, i, &error_code)  #  TODO: check if should enable burst transfer
        if not success:
            break

    # Close the MRAW file
    success = PDC_MRAWFileSaveClose(device_nb, child_nb, &error_code)
    check_pdc_failed(success, error_code)


cpdef save_h264(ulong device_nb, ulong child_nb, str dest_path, uint idx, ulong vid_idx,
                str base_name, MemRecordingInfo rec_info):
    cdef:
        ulong success, error_code

    # Open the destination H264 file
    file_name = '{base_name}_{vid_idx}.mp4'.format(base_name=base_name, vid_idx=str(vid_idx).zfill(4))
    file_path = os.path.join(dest_path, file_name)

    # Open the destination file
    if os.path.exists(file_path):
        pass  # FIXME:
    #video = cv2.VideoWriter(file_path, cv2.VideoWriter_fourcc('H', '2', '6', '4'),
    #                        float(rec_info.fps), (int(rec_info.width), int(rec_info.height)), rec_info.color)
    video = cv2.VideoWriter(file_path, cv2.VideoWriter_fourcc(*'mp4v'),
                            float(rec_info.fps), (int(rec_info.width), int(rec_info.height)), rec_info.color)

    if not video.isOpened():
        video.release()
        print("Could not start recording of video {}".format(file_path))
        return

    # //////////////// SAVE EACH FRAME //////////////////
    cdef:
        ulong start_frame_idx, endFrameIdx
    start_frame_idx = idx * rec_info.n_frames_per_trig
    end_frame_idx = min(start_frame_idx + rec_info.n_frames_per_trig, rec_info.n_recorded_frames)  #  For last chunk

    cdef np.ndarray[np.uint8_t, ndim=1] color_img = np.empty(rec_info.width * rec_info.height * 3, dtype=np.uint8)
    cdef np.ndarray[np.uint8_t, ndim=1] bw_img = np.empty(rec_info.width * rec_info.height, dtype=np.uint8)
    cdef ulong frame_idx = 0, bit_depth = 8
    for frame_idx in range(start_frame_idx, end_frame_idx):
        # print("Processing frame {}".format(frame_idx))
        if rec_info.color:
            success = PDC_GetMemImageData(device_nb, child_nb, frame_idx, bit_depth, &color_img[0], &error_code)
        else:
            success = PDC_GetMemImageData(device_nb, child_nb, frame_idx, bit_depth, &bw_img[0], &error_code)
        check_pdc_failed(success, error_code)
        if rec_info.color:
            video.write(color_img.reshape((rec_info.height, rec_info.width, 3)))  # FIXME: check deinterlace for RGB
        else:
            video.write(bw_img.reshape((rec_info.height, rec_info.width)))

    video.release()


cpdef string_to_c_string(python_string):
    cdef:
        size_t j = 0
        char c = 0
        char c_string [PDC_MAX_STRING_LENGTH]
    for j, c in enumerate(python_string.encode('ascii')):
        c_string[j] = c
    c_string[j + 1] = 0
    return c_string


cpdef auto_open_cam():
    cdef PDC_DETECT_NUM_INFO detect_info = _detect_devices()
    device_nb = _open_cam(detect_info)
    child_nb = _get_child_device_list(device_nb)[0]


cpdef auto_open_cam_lv():
    cdef ulong p_device_code, p_tmp_device_no, p_interface_code
    p_device_code, p_tmp_device_no, p_interface_code = _detect_devices_lv()
    cdef ulong device_nb = _open_cam_lv(p_device_code, p_tmp_device_no, p_interface_code)
    return device_nb



def clear_recording(ulong device_nb):
    """
    This is the bit that is oddly required to not be shifted by 1 session

    :param int device_nb:
    :return:
    """
    set_live(device_nb)
    set_rec_ready(device_nb)
    set_playback(device_nb)

cpdef test_live_CV2():
    init_pdc_lib()
    cdef ulong device_nb    = auto_open_cam_lv()
    child_list              = _get_child_device_list(device_nb)
    child_nb                = child_list[0]
    fps_list                = _get_record_rate_list(device_nb, child_nb)
    fps                     = fps_list[1]
    print(fps)
    _set_record_rate(device_nb, child_nb, fps)

    speeds = _get_shutter_speeds(device_nb, child_nb)
    print('Shutter speeds: ', speeds, '\n', speeds[10])
    _set_shutter_fps(device_nb, child_nb, speeds[10])

    set_live(device_nb)
    
    while True:
        frame = read_live_frame(device_nb, child_nb, 1280,1024, 0)
        #cv2.imshow("Live Feed", frame)
        sleep(.05)

        frame = process_frame(frame)
        cv2.imshow('Edges', frame)

        # Exit when 'q' is pressed
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    close_cam(device_nb)
    print('Done')


cpdef test():
    init_pdc_lib()

    cdef ulong device_nb = auto_open_cam_lv()
    print("Device number: ", device_nb)
    child_list = _get_child_device_list(device_nb)
    print('Device names: ', get_device_name(device_nb, 0))
    child_nb = child_list[0]
    print('Child number: ', child_nb)
    fps_list = _get_record_rate_list(device_nb, child_nb)
    print('Record rates: ', fps_list)
    fps = fps_list[3]
    _set_record_rate(device_nb, child_nb, fps)
    update_params(device_nb, child_nb, n_frames_per_trig=10000)
    print('Resolution: ', '{}x{}'.format(*_get_resolution(device_nb, child_nb)))
    print('Is recording ready ?', bool(is_rec_ready(device_nb)))
    print('Is recording ?', bool(is_recording(device_nb)))
    print('shutter speed',_get_shutter_speeds(device_nb, child_nb))
    print('Color type: ', _get_color_type(device_nb, child_nb))
    print('Memory resolution: ', '{}x{}'.format(*_get_mem_resolution(device_nb, child_nb)))

    set_live(device_nb)
    set_rec_ready(device_nb)
    print('Starting recording state')
    #while is_rec_ready(device_nb):  # wait for triggers (ready or recording)
    #    sleep(1)


    print("record(device_nb)")
    record(device_nb)
    print("sleep(10)")
    sleep(10)

    set_playback(device_nb)
    print('Recording done')
    print('Memory resolution: ', '{}x{}'.format(*_get_mem_resolution(device_nb, child_nb)))
    test_folder = os.path.normpath(os.path.expanduser('C:/Users/YSN-F/Desktop/pyphotron-master/Saves'))
    basename = f'test_{fps=}_{_get_mem_resolution(device_nb, child_nb)}_{save_time()}'
    # print('Saving mRaw')
    # save(device_nb, child_nb, test_folder, basename)
    print('Saving H264')
    save(device_nb, child_nb, test_folder, basename, 1,
                 vid_idx=0, n_frames_per_trig=10000, codec='h264')

    # FIXME: If still recording stop recording
    close_cam(device_nb)
    print('Done')


cpdef read_memory_frame(ulong device_nb, ulong child_nb, ulong width, ulong height, ulong frame_idx, bint is_color):
    cdef:
        ulong success = pdc_undefined
        ulong error_code = pdc_undefined

    img = make_numpy_img_buffer(device_nb, child_nb, width, height, is_color)  # FIXME: very inefficient to initialise on each call

    # get the recorded image
    success = PDC_GetMemImageData(device_nb, child_nb, frame_idx, 8, <char *>img.data, &error_code)
    check_pdc_failed(success, error_code)

    return img


cpdef read_live_frame(ulong device_nb, ulong child_nb, ulong width, ulong height, bint is_color):

    cdef:
        ulong success = pdc_undefined
        ulong error_code = pdc_undefined
        size_t i, j

    # img = make_numpy_img_buffer(device_nb, child_nb, width, height, is_color)

    cdef np.ndarray[np.uint8_t, ndim=1] color_img = np.empty(width * height * 3, dtype=np.uint8)
    cdef np.ndarray[np.uint8_t, ndim=1] bw_img = np.empty(width * height, dtype=np.uint8)

    # get a live image
    if is_color:
        success = PDC_GetLiveImageData(device_nb, child_nb, 8, &color_img[0], &error_code)
    else:
        success = PDC_GetLiveImageData(device_nb, child_nb, 8, &bw_img[0], &error_code)
    check_pdc_failed(success, error_code)

    if is_color:
        return color_img.reshape((height, width, 3))  # FIXME: check deinterlace
    else:
        return bw_img.reshape((height, width))


# cpdef read_live_frame_to_np_ptr_2d(ulong device_nb, ulong child_nb,
#                                 ulong width, ulong height, unsigned int[:,::view.contiguous] np_array):
#     cdef:
#         ulong success = pdc_undefined
#         ulong error_code = pdc_undefined
#     success = PDC_GetLiveImageData(device_nb, child_nb, 8, &np_array[0, 0], &error_code)
#     check_pdc_failed(success, error_code)
#
#
# cpdef read_live_frame_to_np_ptr_3d(ulong device_nb, ulong child_nb,
#                                 ulong width, ulong height, unsigned int[:,:,::view.contiguous] np_array):
#     cdef:
#         ulong success = pdc_undefined
#         ulong error_code = pdc_undefined
#     success = PDC_GetLiveImageData(device_nb, child_nb, 8, &np_array[0, 0], &error_code)
#     check_pdc_failed(success, error_code)


cdef make_numpy_img_buffer(ulong device_nb, ulong child_nb, ulong width, ulong height, bint is_color):
    cdef np.ndarray[np.uint8_t, ndim=1] color_img = np.empty([width, height, 3], dtype=np.uint8)
    cdef np.ndarray[np.uint8_t, ndim=1] bw_img = np.empty([width, height], dtype=np.uint8)
    if is_color:
        return color_img
    else:
        return bw_img

cpdef trig(ulong device_nb, ulong child_nb):
    cdef:
        ulong success = pdc_undefined
        ulong error_code = pdc_undefined
    success = PDC_TriggerIn(device_nb, &error_code)
    check_pdc_failed(success, error_code)









####################
# Yassin Added


def save_time():
    from datetime import datetime

    timestamp = datetime.now().strftime(r"%d--%H-%M-%S")#.strftime("%y%m%d-%H%M%S")
    return timestamp

def process_frame(gray):
    #gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)  # Convert to grayscale
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)  # Apply Gaussian blur to reduce noise
    edges = cv2.Canny(blurred, 50, 150)  # Apply Canny edge detection
    return edges


####################
# Memory

cpdef _get_mem_resolution(ulong device_nb, ulong child_nb):
    """This function retrieves the resolution recorded in the current partition of the specified child device."""
    cdef:
        ulong width, height
        ulong success = pdc_failed
        ulong error_code = pdc_failed
    success = PDC_GetMemResolution(device_nb, child_nb, &width, &height, &error_code)
    check_pdc_failed(success, error_code)
    return width, height

cpdef _get_mem_record_rate(ulong device_nb, ulong child_nb):
    cdef:
        ulong rate = pdc_undefined
        ulong success = pdc_failed
        ulong error_code = pdc_failed
    success = PDC_GetMemRecordRate(device_nb, child_nb, &rate, &error_code)
    check_pdc_failed(success, error_code)
    return rate

cpdef _get_recorded_frame_info(ulong device_nb, ulong child_nb):

    """Unlike retrieving a live image, it's necessary to specify the frame number when retrieving a recording image.
    For a frame number, the information for a recording frame can be obtained using the PDC_GetMemFrameInfofunction. Specify a number between the top frame number and last frame number.
    The size of the transferred image data is determined by the image resolution, color/monochrome, and bit depth that is obtained by retrieving the recording conditions of the device.
    A PDC_GetMemImageData function is used to transfer a recording image.
    For a monochromatic camera, the retrieved recording image data is binary data with its origin in the upper-left position of the image.
    """
    cdef:
        ulong success = pdc_undefined
        ulong error_code = pdc_failed
        PDC_FRAME_INFO info
        ulong n_recorded_frames, start_frame, end_frame
    success = PDC_GetMemFrameInfo(device_nb, child_nb, &info, &error_code)
    check_pdc_failed(success, error_code)
    n_recorded_frames = info.m_nRecordedFrames
    start_frame = info.m_nStart
    end_frame = info.m_nEnd
    return n_recorded_frames, start_frame, end_frame



##################################################################
# Partitioning

cpdef get_max_partition(ulong device_nb, ulong child_nb):
    """
    In the FASTCAM series, some devices can divide a recording memory area and store multiple recording data items.

    Using the PDC_GetMaxPartition function, confirm whether the device has the partition division function.

    The partition division function can be used when the maximum number of divisions retrieved using this function is 
    two or greater.

    part_count == 1 if no partition support
    n_blocks = 0 if not setable (then = sizes)
    
    :param device_nb: 
    :param child_nb: 
    :return: 
    """
    cdef:
        ulong part_count = 0
        ulong n_blocks = 0
        ulong error_code = pdc_failed
        ulong success = pdc_undefined
    success = PDC_GetMaxPartition(device_nb, child_nb, &part_count, &n_blocks, &error_code)
    check_pdc_failed(success, error_code)
    return part_count, n_blocks

cpdef get_max_frames(ulong device_nb, ulong child_nb):
    """
    This function retrieves the total number of current partition frames in the specified child devices.

    Gets total nb of frames in current partition 
    :param device_nb: 
    :param child_nb: 
    :return: 
    """
    cdef:
        ulong n_frames = 0, n_blocks = 0
        ulong error_code = pdc_failed
        ulong success = pdc_undefined
    success = PDC_GetMaxFrames(device_nb, child_nb, &n_frames, &n_blocks, &error_code)
    check_pdc_failed(success, error_code)
    return n_frames

cpdef get_current_partition(ulong device_nb, ulong child_nb):
    """This function retrieves the current partition number of the specified child device."""
    cdef:
        ulong partition_id = 0
        ulong error_code = pdc_failed
        ulong success = pdc_undefined
    success = PDC_GetCurrentPartition(device_nb, child_nb, &partition_id, &error_code)
    check_pdc_failed(success, error_code)
    return partition_id

cpdef set_current_partition(ulong device_nb, ulong child_nb, ulong partition_id):
    # Divides the current partition into two  # FIXME: how
    # nRet = PDC_SetCurrentPartition(nDeviceNo, nChildNo, 2, &nErrorCode)
    cdef:
        ulong error_code = pdc_failed
        ulong success = pdc_undefined
    success = PDC_SetCurrentPartition(device_nb, child_nb, partition_id, &error_code)
    check_pdc_failed(success, error_code)

cpdef set_memory_mode_partition(ulong device_nb, ulong child_nb, ulong partition_id):
    """
    Set partition ID for mem playback 
    
    .. warning:
            To use this function, first set mode to PDC_PARTITIONNING_MODE3
            
    :param device_nb: 
    :param child_nb: 
    :param partition_id: 
    :return: 
    """
    cdef:
        ulong error_code = pdc_failed
        ulong success = pdc_undefined
    success = PDC_SetMemoryModePartition(device_nb, child_nb, partition_id, &error_code)
    check_pdc_failed(success, error_code)


cpdef get_memory_mode_partition(ulong device_nb, ulong child_nb):
    """
    retrives partition id for memory playback mode  
    
    .. warning:
        To use this function, mode must be set to PDC_PARTITIONNING_MODE3
        
    :param device_nb: 
    :param child_nb: 
    :return: 
    """
    cdef:
        ulong partition_id = pdc_undefined
        ulong error_code = pdc_failed
        ulong success = pdc_undefined
    success = PDC_GetMemoryModePartition(device_nb, child_nb, &partition_id, &error_code)
    check_pdc_failed(success, error_code)
    return partition_id

cpdef get_partition_inc_mode(ulong device_nb):
    cdef:
        ulong mode = pdc_undefined
        ulong error_code = pdc_failed
        ulong success = pdc_undefined
    success = PDC_GetPartitionIncMode(device_nb, &mode, &error_code)
    check_pdc_failed(success, error_code)
    return mode

cpdef set_partition_inc_mode(ulong device_nb, ulong mode):
    cdef:
        ulong error_code = pdc_failed
        ulong success = pdc_undefined
    success = PDC_SetPartitionIncMode(device_nb, mode, &error_code)


cpdef set_partition_list(ulong device_nb, ulong child_nb, ulong n_partitions):  # FIXME: add support for blocks
    cdef:
        ulong error_code = pdc_failed
        ulong success = pdc_undefined
        # ulong blocks = 0
    success = PDC_SetPartitionList(device_nb, child_nb, n_partitions, NULL, &error_code) # FIXME: add support for blocks
    check_pdc_failed(success, error_code)

cpdef get_partition_list(ulong device_nb, ulong child_nb):
    cdef:
        ulong error_code = pdc_failed
        ulong success = pdc_undefined
        ulong n_partitions = pdc_undefined
        ulong n_frames = pdc_undefined
        ulong blocks
    success = PDC_GetPartitionList(device_nb, child_nb, &n_partitions, &n_frames, &blocks, &error_code)
    return n_partitions, n_frames, blocks
##################################################################