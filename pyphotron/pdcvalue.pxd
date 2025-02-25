from pyphotron.typedefs cimport ulong


cdef extern from "PDCLIB.h":
    ulong PDC_COLORTYPE_COLOR
    ulong PDC_MRAW_BITDEPTH_8

    ulong PDC_DETECT_AUTO
    ulong PDC_DETECT_NORMAL

    ulong PDC_STATUS_REC
    ulong PDC_STATUS_RECREADY

    ulong PDC_STATUS_LIVE
    ulong PDC_STATUS_PLAYBACK
    ulong PDC_STATUS_PAUSE

    ulong PDC_EXT_IN_TYPE_INPUT2
    ulong PDC_EXT_OUT_RECORD_POSI
    ulong PDC_EXT_OUT_READY_POSI
    ulong PDC_TRIGGER_START
    ulong PDC_TRIGGER_RANDOM

    ulong PDC_PARTITIONINC_MODE1  # maintains current partition after recording
    ulong PDC_PARTITIONINC_MODE2  # Switches current partition after recording
    ulong PDC_PARTITIONINC_MODE3

    ulong PDC_EXIST_PARTITIONINC  # Partition increment function available on device

    ulong PDC_EXIST_SUPPORTED
    ulong PDC_EXIST_NOTSUPPORTED