from pyphotron.typedefs cimport ulong

from pyphotron.pdcstr cimport PDC_FRAME_INFO, PDC_DETECT_INFO, PDC_DETECT_NUM_INFO
from pyphotron.pdcvalue cimport *

DEF PDC_MAX_DEVICE = 64
DEF PDC_MAX_LIST_NUMBER = 256
DEF PDC_MAX_STRING_LENGTH = 256


cdef extern from "PDCLIB.h":
    # ctypedef wchar_t * LPCTSTR
    # ctypedef TCHAR * LPCTSTR
    ctypedef char * LPCTSTR

    ulong PDC_FAILED
    ulong PDC_SUCCEEDED

    ulong PDC_ERROR_NOERROR


    ulong PDC_INTTYPE_G_ETHER

    ulong PDC_Init(ulong *pErrorCode)
    ulong PDC_IsFunction(ulong nDeviceNo, ulong nChildNo, ulong nFunction, char *pFlag, ulong *pErrorCode)  # FIXME: implement
    ulong PDC_DetectDevice(ulong nInterfaceCode, ulong *pDetectNo, ulong nDetectNum, ulong nDetectParam,
                           PDC_DETECT_NUM_INFO *pDetectNumInfo, ulong *pErrorCode)
    ulong PDC_DetectDeviceLV(ulong nInterfaceCode, ulong *pDetectNo, ulong nDetectNum, ulong nDetectParam,
                             ulong *pDeviceNum, ulong *pDeviceCode, ulong *pTmpDeviceNo, ulong *pInterfaceCode,
                             ulong *pErrorCode)

    ulong PDC_OpenDevice(PDC_DETECT_INFO *pDetectInfo, ulong *pDeviceNo, ulong *pErrorCode)
    ulong PDC_OpenDeviceLV(ulong nDeviceCode, ulong nTmpDeviceNb, ulong nInterfaceCode, ulong *pDeviceNo, ulong *pErrorCode)
    ulong PDC_CloseDevice(ulong nDeviceNo, ulong *pErrorCode)

    ulong PDC_TriggerIn(ulong nDeviceNo, ulong *pErrorCode)

    # ulong PDC_GetDeviceName(ulong nDeviceNo, ulong nChildNo, wchar_t *pStrName, ulong *pErrorCode)  # TODO: check if LPCTSTR
    ulong PDC_GetDeviceName(ulong nDeviceNo, ulong nChildNo, char *pStrName, ulong *pErrorCode)  # TODO: check if LPCTSTR

    ulong PDC_GetStatus(ulong nDeviceNo, ulong *Status, ulong *pErrorCode)

    ulong PDC_GetResolution(ulong nDeviceNo, ulong nChildNo, ulong *pWidth,ulong *pHeight, ulong *pErrorCode)
    ulong PDC_GetColorType(ulong nDeviceNo, ulong nChildNo, char *pMode, ulong *pErrorCode)

    # list getting functions
    ulong PDC_GetExistChildDeviceList(ulong nDeviceNo, ulong *pSize, ulong *pList, ulong *pErrorCode)  # TODO: check signature seems different
    ulong PDC_GetRecordRateList(ulong nDeviceNo, ulong nChildNo, ulong *pSize, ulong *pList, ulong *pErrorCode)
    ulong PDC_GetResolutionList(ulong nDeviceNo, ulong nChildNo, ulong *pSize, ulong *pList, ulong *pErrorCode)
    ulong PDC_GetShutterSpeedFpsList(ulong nDeviceNo, ulong nChildNo, ulong *pSize, ulong *pList, ulong *pErrorCode)

    # status getting functions
    ulong PDC_GetMemResolution(ulong nDeviceNo, ulong nChildNo, ulong *pWidth, ulong *pHeight, ulong *pErrorCode)
    ulong PDC_GetMemRecordRate(ulong nDevceNo, ulong nChildNo, ulong *pRate, ulong *pErrorCode)  # FIXME: implement
    ulong PDC_GetMemFrameInfo(ulong nDeviceNo, ulong nChildNo, PDC_FRAME_INFO *pFrame, ulong *pErrorCode)

    # data getting functions
    ulong PDC_GetLiveImageData(ulong nDeviceNo, ulong nChildNo, ulong nBitDepth, void *pData, ulong *pErrorCode)
    ulong PDC_GetMemImageData(ulong nDeviceNo, ulong nChildNo, long nFrameNo, ulong nBitDepth, void *pData, ulong *pErrorCode)

    # status setting functions
    ulong PDC_SetStatus(ulong nDeviceNo, ulong nMode, ulong *nErrorCode)
    ulong PDC_SetRecReady(ulong nDeviceNo, ulong *pErrorCode)
    ulong PDC_SetEndless(ulong nDeviceNo, ulong *pErrorCode)
    ulong PDC_TriggerIn(ulong nDeviceNo, ulong *pErrorCode)  # Unused but useful for debug
    ulong PDC_SetRecordRate(ulong nDeviceNo, ulong nChildNo, ulong nRate, ulong *pErrorCode)
    ulong PDC_SetResolution(ulong nDeviceNo, ulong nChildNo, ulong nWidth, ulong nHeight, ulong *pErrorCode)
    ulong PDC_SetShutterSpeedFps(ulong nDeviceNo, ulong nChildNo, ulong nFps, ulong *pErrorCode)
    ulong PDC_SetTriggerMode(ulong nDeviceNo, ulong nMode, ulong nAFrames, ulong nRFrames, ulong nRCount, ulong *pErrorCode)
    ulong PDC_SetColorType(ulong nDeviceNo, ulong nChildNo, ulong nMode, ulong *pErrorCode)  # Could be used
    ulong PDC_SetExternalInMode(ulong nDeviceNo, ulong nPort, ulong nMode, ulong *pErrorCode)  # Could be used
    ulong PDC_SetExternalOutMode(ulong nDeviceNo, ulong nPort, ulong nMode, ulong *pErrorCode)

    ulong PDC_MRAWFileSaveOpen(ulong nDeviceNo, ulong nChildNo, LPCTSTR lpszFileName,
                               ulong nMRawBitDepth, long nMaxFrameNum, ulong *pErrorCode)
    ulong PDC_MRAWFileSave(ulong nDeviceNo, ulong nChildNo, long nFrameNo, ulong *pErrorCode)
    ulong PDC_MRAWFileSaveClose(ulong nDeviceNo, ulong nChildNo, ulong *pErrorCode)

    # Partitionning
    ulong PDC_GetMaxPartition(ulong nDeviceNo, ulong nChildNo, ulong *pCount, ulong *pBlock, ulong *pErrorCode)
    ulong PDC_GetMaxFrames(ulong nDeviceNo, ulong nChildNo, ulong *pFrames, ulong *pBlocks, ulong *pErrorCode)
    ulong PDC_GetCurrentPartition(ulong nDeviceNo, ulong nChildNo, ulong *pNo, ulong *pErrorCode)
    ulong PDC_SetCurrentPartition(ulong nDeviceNo, ulong nChildNo, ulong nNo, ulong *pErrorCode)

    ulong PDC_SetMemoryModePartition(ulong nDeviceNo, ulong nChildNo, ulong nNo, ulong *pErrorCode)
    ulong PDC_GetMemoryModePartition(ulong nDeviceNo, ulong nChildNo, ulong *pNo, ulong *pErrorCode)

    ulong PDC_GetPartitionIncMode(ulong nDeviceNo, ulong *pMode, ulong *pErrorCode)
    ulong PDC_SetPartitionIncMode(ulong nDeviceNo, ulong nMode, ulong *pErrorCode)

    ulong PDC_SetPartitionList(ulong nDeviceNo, ulong nChildNo, ulong nCount, ulong *pBlocks, ulong *pErrorCode)
    ulong PDC_GetPartitionList(ulong nDeviceNo, ulong nChildNo, ulong *pCount, ulong *pFrames, ulong *pBlocks, ulong *pErrorCode)
