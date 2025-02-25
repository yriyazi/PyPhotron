from pyphotron.typedefs cimport ulong

DEF PDC_MAX_DEVICE = 64

cdef extern from "PDCLIB.h":
    ctypedef struct PDC_FRAME_INFO:
        long m_nStart, m_nEnd, m_nTrigger
        long m_nTwoStageLowToHigh, m_nTwoStageHighToLow
        unsigned long   m_nTwoStageTiming
        long    m_nEvent[10]
        unsigned long   m_nEventCount, m_nRecordedFrames

    ctypedef struct PDC_DETECT_INFO:
        ulong   m_nDeviceCode, m_nTmpDeviceNo, m_nInterfaceCode

    ctypedef struct PDC_DETECT_NUM_INFO:
        ulong   m_nDeviceNum
        PDC_DETECT_INFO m_DetectInfo[PDC_MAX_DEVICE]