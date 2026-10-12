# Vibemis keyboard mapping suite.
#
# Same shape as tests/vrr/vrr.pro and tests/overlay/overlay.pro: a subdirs
# project whose targets are each one focused file, so a test can keep the
# dependency floor of the code it covers. The remote-key map is a pure header,
# so its test needs SDL's enum headers and nothing else -- no Session, no
# window, no host.
TEMPLATE = subdirs
CONFIG += ordered

keyremotemap.file = $$PWD/keyremotemap.pro

SUBDIRS += \
    keyremotemap
