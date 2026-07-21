# Keep the platform-neutral timing test separate from the Qt policy test: the
# former deliberately has no Qt event-loop/runtime dependency.
TEMPLATE = subdirs
CONFIG += ordered

timingcontroller.file = $$PWD/timingcontroller.pro
ratepolicy.file = $$PWD/ratepolicy.pro
pacingworker.file = $$PWD/pacingworker.pro

# Vibemis (BL-2230): also build the repo's pre-existing standalone
# VrrRatePolicy checker (app/test_vrrratepolicy.cpp, from the BL-2212 wave)
# alongside the vendored Nonary QtTest suite. The two overlap but the
# standalone covers extra edge cases; keeping both keeps the vendored files
# byte-identical to Nonary for cheap future merges.
ratepolicy_standalone.file = $$PWD/ratepolicy_standalone.pro

# Vibemis (BL-2296): standalone checker for the same-display
# refresh-mode-switch guard predicates (StreamUtils, ported from the Nonary
# v6.1.0-vrr9.1 refreshMayHaveChanged guard).
refreshguard_standalone.file = $$PWD/refreshguard_standalone.pro

SUBDIRS += \
    timingcontroller \
    ratepolicy \
    ratepolicy_standalone \
    refreshguard_standalone \
    pacingworker
