# The overlay suite holds two independent binaries, so it is a subdirs project
# in the same shape as tests/vrr/vrr.pro. Keeping each test file single-purpose
# matters here: the decoder-status test must build with no FFmpeg/SDL/Qt-GUI
# headers at all, which is the constraint that keeps decoderstatus.h a pure,
# dependency-free header.
TEMPLATE = subdirs
CONFIG += ordered

overlayplacement.file = $$PWD/overlayplacement.pro

# Vibemis (BL-2417): coverage for the debug overlay's decoder-capability line
# (active decoder, driver vendor, negotiated RFI state).
decoderstatus.file = $$PWD/decoderstatus.pro

SUBDIRS += \
    overlayplacement \
    decoderstatus
