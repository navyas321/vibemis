BUILD_CONFIG="release"

fail()
{
	echo "$1" 1>&2
	exit 1
}

BUILD_ROOT=$PWD/build
SOURCE_ROOT=$PWD
BUILD_FOLDER=$BUILD_ROOT/build-$BUILD_CONFIG
DEPLOY_FOLDER=$BUILD_ROOT/deploy-$BUILD_CONFIG
INSTALLER_FOLDER=$BUILD_ROOT/installer-$BUILD_CONFIG

LINUXDEPLOY=linuxdeploy-$(uname -m).AppImage

if [ -n "$CI_VERSION" ]; then
  VERSION=$CI_VERSION
else
  VERSION=`cat $SOURCE_ROOT/app/version.txt`
fi

command -v qmake6 >/dev/null 2>&1 || fail "Unable to find 'qmake6' in your PATH!"
command -v $LINUXDEPLOY >/dev/null 2>&1 || fail "Unable to find '$LINUXDEPLOY' in your PATH!"

echo Cleaning output directories
rm -rf $BUILD_FOLDER
rm -rf $DEPLOY_FOLDER
rm -rf $INSTALLER_FOLDER
mkdir $BUILD_ROOT
mkdir $BUILD_FOLDER
mkdir $DEPLOY_FOLDER
mkdir $INSTALLER_FOLDER

echo Configuring the project
pushd $BUILD_FOLDER
# Building with Wayland support will cause linuxdeploy to include libwayland-client.so in the AppImage.
# Since we always use the host implementation of EGL, this can cause libEGL_mesa.so to fail to load due
# to missing symbols from the host's version of libwayland-client.so that aren't present in the older
# version of libwayland-client.so from our AppImage build environment. When this happens, EGL fails to
# work even in X11. To avoid this, we will disable Wayland support for the AppImage.
#
# We disable DRM support because linuxdeploy doesn't bundle the appropriate libraries for Qt EGLFS.
# We disable CUDA because the AppImage targets a portable install set and we lean on VAAPI/VDPAU at runtime.
# Vibemis: project file is artemis.pro (renamed from moonlight-qt.pro upstream).
qmake6 $SOURCE_ROOT/artemis.pro CONFIG+=disable-wayland CONFIG+=disable-libdrm CONFIG+=disable-cuda PREFIX=$DEPLOY_FOLDER/usr DEFINES+=APP_IMAGE || fail "Qmake failed!"
popd

echo Compiling Artemis in $BUILD_CONFIG configuration
pushd $BUILD_FOLDER
make -j$(nproc) $(echo "$BUILD_CONFIG" | tr '[:upper:]' '[:lower:]') || fail "Make failed!"
popd

echo Deploying to staging directory
pushd $BUILD_FOLDER
make install || fail "Make install failed!"
popd

# Vibemis: drop AppRun init hooks so the bundled libVA loader finds the HOST's
# VAAPI/VDPAU drivers — AND uses the HOST's libva.so.2 itself when one is
# available. We do both because, while LIBVA_DRIVERS_PATH points the loader
# at where to find drivers like radeonsi_drv_video.so, the BUNDLED libva.so.2
# may not be ABI-compatible with the host's drivers.
#
# Concrete example we hit on the Legion Go S Z2 (SteamOS 3.8.5):
#   - linuxdeploy bundled libva.so.2 v1.20.0 alongside the binary.
#   - Mesa 25.3 / SteamOS ships radeonsi_drv_video.so that only exports
#     __vaDriverInit_1_22 (built against libva 1.22).
#   - libva 1.20 walks down from __vaDriverInit_1_20, never finds
#     __vaDriverInit_1_22, returns VA_STATUS_ERROR_UNKNOWN, hardware decode
#     dies. User sees "No functioning hardware accelerated video decoder".
#
# Diagnosis credit: in-repo diagnostic agent on the Legion Go S Z2, see
# DIAGNOSTIC_REPORT_test3.md (in PR #6) §9. The agent recommended dropping
# the bundled libva entirely; the hook below is the lower-risk option
# (LD_LIBRARY_PATH prefer system) that preserves bundling for hosts that
# lack a system libva while letting modern hosts use their own.
#
# linuxdeploy's AppRun sources every $APPDIR/apprun-hooks/*.sh before exec'ing
# the binary, so env vars set here propagate to the binary.
mkdir -p $DEPLOY_FOLDER/apprun-hooks
cat > $DEPLOY_FOLDER/apprun-hooks/01-libva-driver-paths.sh <<'HOOK'
# Vibemis AppImage runtime hook — point bundled libVA at the host's drivers,
# AND prefer the host's libva.so.2 over our bundled one so ABI matches the
# host's mesa-va drivers (radeonsi, iHD, etc.).
# Only set when not already overridden so power users keep full control.

# (1) Point libva at the host's DRI driver dir.
if [ -z "$LIBVA_DRIVERS_PATH" ]; then
    _vibemis_libva_dri_candidates=(
        # Most Linux distros (Debian/Ubuntu multi-arch)
        "/usr/lib/x86_64-linux-gnu/dri"
        # Fedora / RHEL / OpenSUSE / SteamOS (Arch-based)
        "/usr/lib64/dri"
        # Arch generic / older SteamOS layouts
        "/usr/lib/dri"
    )
    _vibemis_libva_found=""
    for _vibemis_d in "${_vibemis_libva_dri_candidates[@]}"; do
        if [ -d "$_vibemis_d" ]; then
            if [ -z "$_vibemis_libva_found" ]; then
                _vibemis_libva_found="$_vibemis_d"
            else
                _vibemis_libva_found="$_vibemis_libva_found:$_vibemis_d"
            fi
        fi
    done
    if [ -n "$_vibemis_libva_found" ]; then
        export LIBVA_DRIVERS_PATH="$_vibemis_libva_found"
    fi
    unset _vibemis_libva_dri_candidates _vibemis_libva_found
fi

# (2) Prefer the HOST's libva.so.2 over our bundled one — load order matters.
# We only prepend the host's lib dir to LD_LIBRARY_PATH if a host libva.so.2
# is actually present. The first matching dir wins. Be surgical: a single
# preferred dir, not the whole system library set.
if [ -z "$VIBEMIS_SKIP_HOST_LIBVA" ]; then
    for _vibemis_d in /usr/lib64 /usr/lib/x86_64-linux-gnu /usr/lib; do
        if [ -e "$_vibemis_d/libva.so.2" ]; then
            export LD_LIBRARY_PATH="$_vibemis_d${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            # Diagnostic — visible in run logs to confirm the hook chose host libva
            echo "[vibemis-apprun-hook] preferring host libva.so.2 from $_vibemis_d" 1>&2
            break
        fi
    done
fi
unset _vibemis_d

# (3) Same trick for VDPAU drivers.
if [ -z "$VDPAU_DRIVER_PATH" ]; then
    for _vibemis_d in /usr/lib/x86_64-linux-gnu/vdpau /usr/lib64/vdpau /usr/lib/vdpau; do
        if [ -d "$_vibemis_d" ]; then
            export VDPAU_DRIVER_PATH="$_vibemis_d"
            break
        fi
    done
    unset _vibemis_d
fi
HOOK
chmod +x $DEPLOY_FOLDER/apprun-hooks/01-libva-driver-paths.sh

export QML_SOURCES_PATHS=$SOURCE_ROOT/app/gui
export QMAKE=qmake6

echo Creating AppImage
pushd $INSTALLER_FOLDER
# Vibemis: take upstream's modern linuxdeploy approach (linuxdeployqt is broken on glibc >= 2.36).
VERSION=$VERSION $LINUXDEPLOY --appdir $DEPLOY_FOLDER \
  --library=/usr/local/lib/libSDL3.so.0 \
  --plugin qt --output appimage || fail "linuxdeploy failed!"
popd

echo Build successful