ctypedef unsigned char uchar
ctypedef unsigned short ushort
ctypedef unsigned long ulong
ctypedef unsigned long long ull
ctypedef unsigned int uint


cdef struct Point:
    ull x
    ull y
    ull z


ctypedef struct MemRecordingInfo:
    ulong n_recorded_frames
    ulong n_frames_per_trig
    ulong width
    ulong height
    ulong fps
    bint color
