#include <string.h>
#include <libplacebo/renderer.h>
#include <libplacebo/utils/libav.h>
#include "pl_libav_shim.h"

bool pl_map_avframe_simple(const void *gpu, void *out_frame, const AVFrame *frame, void *tex)
{
    // Use the simple wrapper to avoid version-specific struct details
    return pl_map_avframe((pl_gpu)gpu, (struct pl_frame *)out_frame, (pl_tex *)tex, frame);
}

void pl_unmap_avframe_simple(const void *gpu, void *frame)
{
    pl_unmap_avframe((pl_gpu)gpu, (struct pl_frame *)frame);
}

int pl_frame_plane_count_from_avframe(const AVFrame *frame)
{
    // libplacebo before API 360 dereferences a null pointer when asked to map
    // a pixel format it does not recognize (moonlight-stream/moonlight-qt#1409).
    // Describing the frame first is safe and reports zero planes for exactly
    // those formats, so the caller can refuse before mapping. Kept in this C
    // shim because <libplacebo/utils/libav.h> must not enter a C++ TU.
    struct pl_frame out;
    memset(&out, 0, sizeof(out));
    pl_frame_from_avframe(&out, frame);
    return out.num_planes;
}

