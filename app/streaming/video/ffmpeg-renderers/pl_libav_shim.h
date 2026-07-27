#ifndef PL_LIBAV_SHIM_H
#define PL_LIBAV_SHIM_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <libavutil/frame.h>

// Avoid pulling libplacebo headers into C++ TU; use opaque pointers here.
// They are cast to the correct libplacebo types in the C implementation.
bool pl_map_avframe_simple(const void *gpu, void *out_frame, const AVFrame *frame, void *tex);
void pl_unmap_avframe_simple(const void *gpu, void *frame);

// Number of planes libplacebo derives from this frame; 0 means it does not
// recognize the pixel format. Used to refuse a frame before mapping it on
// libplacebo builds that would otherwise crash.
int pl_frame_plane_count_from_avframe(const AVFrame *frame);

#ifdef __cplusplus
}
#endif

#endif // PL_LIBAV_SHIM_H

