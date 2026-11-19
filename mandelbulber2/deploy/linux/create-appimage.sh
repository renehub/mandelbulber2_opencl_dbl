#!/bin/bash
#
# Mandelbulber v2 - build a self-contained AppImage
#
# The script installs the qmake build into a temporary AppDir, lets
# linuxdeploy bundle Qt and the other shared libraries, and finally packages
# the AppDir with appimagetool. The AppImage uses the standard
# AppDir layout (usr/bin/mandelbulber2, usr/share/mandelbulber2), so the
# binary finds its data through its normal "share next to the executable"
# lookup; no special SHARED_DIR build definition is required.
#
# Usage: ./create-appimage.sh [options]
#
# Options:
#   --build-dir DIR  Directory containing the qmake Makefile
#                    (default: <source>/qmake or <package>/makefiles)
#   --appdir DIR     Temporary AppDir (default: <build-dir>/appdir)
#   --out-dir DIR    Directory for Mandelbulber_v2-<arch>.AppImage
#                    (default: current directory)
#   --tools-dir DIR  Cache for linuxdeploy/appimagetool
#                    (default: ~/.cache/mandelbulber2-appimage)
#   --jobs N         Parallel make jobs (default: number of CPUs)
#   --keep-appdir    Keep the AppDir after packaging
#   -h, --help       Show this help
#
# Requirements: Qt 6 development tools (qmake6), make, wget, mksquashfs,
# and FUSE or APPIMAGE_EXTRACT_AND_RUN support. The linuxdeploy plugin,
# linuxdeploy and appimagetool are downloaded when not already cached.
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect the source-tree or release-package layout.
if [ -d "$SCRIPT_DIR/makefiles" ] || [ -d "$SCRIPT_DIR/qmake" ]; then
	PROJECT_ROOT="$SCRIPT_DIR"
else
	PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
fi

if [ -d "$PROJECT_ROOT/qmake" ]; then
	PRO_DIR="qmake"
elif [ -d "$PROJECT_ROOT/makefiles" ]; then
	PRO_DIR="makefiles"
else
	echo "Error: cannot find qmake/ or makefiles/ in $PROJECT_ROOT" >&2
	exit 1
fi

BUILD_DIR=""
APPDIR=""
OUT_DIR="$PWD"
TOOLS_DIR="${APPIMAGE_TOOLS_DIR:-$HOME/.cache/mandelbulber2-appimage}"
JOBS="$(nproc 2>/dev/null || echo 4)"
KEEP_APPDIR=0

LINUXDEPLOY_URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
LINUXDEPLOY_QT_URL="https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage"
APPIMAGETOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"

usage() {
	sed -n '3,28p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
	echo "Error: $*" >&2
	exit 1
}

info() {
	echo "==> $*"
}

while [ $# -gt 0 ]; do
	case "$1" in
		--build-dir)   [ $# -ge 2 ] || die "--build-dir requires a directory"; BUILD_DIR="$2"; shift ;;
		--build-dir=*) BUILD_DIR="${1#*=}" ;;
		--appdir)      [ $# -ge 2 ] || die "--appdir requires a directory"; APPDIR="$2"; shift ;;
		--appdir=*)    APPDIR="${1#*=}" ;;
		--out-dir)     [ $# -ge 2 ] || die "--out-dir requires a directory"; OUT_DIR="$2"; shift ;;
		--out-dir=*)   OUT_DIR="${1#*=}" ;;
		--tools-dir)   [ $# -ge 2 ] || die "--tools-dir requires a directory"; TOOLS_DIR="$2"; shift ;;
		--tools-dir=*) TOOLS_DIR="${1#*=}" ;;
		--jobs)        [ $# -ge 2 ] || die "--jobs requires a number"; JOBS="$2"; shift ;;
		--jobs=*)      JOBS="${1#*=}" ;;
		--keep-appdir) KEEP_APPDIR=1 ;;
		-h|--help)     usage; exit 0 ;;
		*)             die "unknown option '$1' (see --help)" ;;
	esac
	shift
done

[ -n "$BUILD_DIR" ] || BUILD_DIR="$PROJECT_ROOT/$PRO_DIR"
BUILD_DIR="$(cd "$BUILD_DIR" 2>/dev/null && pwd)" || die "build directory does not exist"
[ -n "$APPDIR" ] || APPDIR="$BUILD_DIR/appdir"
case "$APPDIR" in
	/*) : ;;
	*) APPDIR="$(pwd)/$APPDIR" ;;
esac
OUT_DIR="$(cd "$OUT_DIR" 2>/dev/null && pwd)" || die "output directory does not exist"
mkdir -p "$TOOLS_DIR" || die "cannot create tools directory '$TOOLS_DIR'"

case "$JOBS" in
	''|*[!0-9]*) die "--jobs must be a positive integer (got: '$JOBS')" ;;
esac

MAKE="$BUILD_DIR/Makefile"
[ -f "$MAKE" ] || die "no Makefile in '$BUILD_DIR' (run qmake in that directory first)"

# --------------------------------------------------------------------------
# Qt selection
# --------------------------------------------------------------------------
if [ -n "${QMAKE:-}" ]; then
	:
elif command -v qmake6 >/dev/null 2>&1; then
	QMAKE="$(command -v qmake6)"
elif command -v qmake >/dev/null 2>&1; then
	QMAKE="$(command -v qmake)"
else
	die "Qt's qmake/qmake6 was not found"
fi

QT_VERSION="$("$QMAKE" -query QT_VERSION 2>/dev/null || true)"
case "$QT_VERSION" in
	6.*) : ;;
	*) die "Qt 6 is required for the AppImage (found: '${QT_VERSION:-unknown}')" ;;
esac

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
download() {
	local url="$1" path="$2"
	[ -s "$path" ] && return 0
	info "Downloading $(basename "$path")"
	if command -v wget >/dev/null 2>&1; then
		wget -q -c -nv "$url" -O "$path" || return 1
	elif command -v curl >/dev/null 2>&1; then
		curl -L --fail --silent --show-error "$url" -o "$path" || return 1
	else
		die "wget or curl is required to download the AppImage tools"
	fi
	chmod a+x "$path"
}

require_tool() {
	local path="$1"
	[ -x "$path" ] || die "required tool is not executable: $path"
}

# Remove the AppDir safely. Refuse obviously dangerous paths.
clean_appdir() {
	case "$APPDIR" in
		""|/|/home|/home/*/|/tmp|/tmp/)
			die "refusing to remove suspicious AppDir path '$APPDIR'"
			;;
	esac
	if [ "${#APPDIR}" -lt 5 ]; then
		die "refusing to remove short AppDir path '$APPDIR'"
	fi
	rm -rf "$APPDIR"
}

# --------------------------------------------------------------------------
# Tools
# --------------------------------------------------------------------------
LINUXDEPLOY="$TOOLS_DIR/linuxdeploy-x86_64.AppImage"
LINUXDEPLOY_QT="$TOOLS_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"
APPIMAGETOOL="$TOOLS_DIR/appimagetool-x86_64.AppImage"
download "$LINUXDEPLOY_URL" "$LINUXDEPLOY" || die "cannot download linuxdeploy"
download "$LINUXDEPLOY_QT_URL" "$LINUXDEPLOY_QT" || die "cannot download linuxdeploy-plugin-qt"
download "$APPIMAGETOOL_URL" "$APPIMAGETOOL" || die "cannot download appimagetool"
require_tool "$LINUXDEPLOY"
require_tool "$LINUXDEPLOY_QT"
require_tool "$APPIMAGETOOL"

command -v make >/dev/null 2>&1 || die "make was not found"
command -v mksquashfs >/dev/null 2>&1 || die "mksquashfs was not found"

# --------------------------------------------------------------------------
# Build and install into the AppDir
# --------------------------------------------------------------------------
clean_appdir
info "Installing application into AppDir: $APPDIR"
make -C "$BUILD_DIR" -j"$JOBS" INSTALL_ROOT="$APPDIR" install || die "make install failed"

BINARY="$APPDIR/usr/bin/mandelbulber2"
[ -x "$BINARY" ] || die "application binary is missing from the AppDir"

DESKTOP_FILE="$APPDIR/usr/share/applications/mandelbulber2.desktop"
[ -f "$DESKTOP_FILE" ] || die "desktop file is missing from the AppDir"

ICON_FILE="$APPDIR/usr/share/icons/hicolor/256x256/apps/mandelbulber.png"
if [ ! -f "$ICON_FILE" ]; then
	ICON_FILE="$PROJECT_ROOT/deploy/share/mandelbulber2/icons/mandelbulber.png"
fi
[ -f "$ICON_FILE" ] || die "icon is missing from the AppDir and deploy/share"

# --------------------------------------------------------------------------
# Deploy Qt and the other libraries, then write the AppImage root metadata
# --------------------------------------------------------------------------
info "Deploying libraries with linuxdeploy (Qt $QT_VERSION)"
unset QTDIR QT_PLUGIN_PATH LD_LIBRARY_PATH
APPIMAGE_EXTRACT_AND_RUN=1 ARCH="$(uname -m)" PATH="$TOOLS_DIR:$PATH" \
	QMAKE="$QMAKE" \
	"$LINUXDEPLOY" --appimage-extract-and-run \
	--appdir "$APPDIR" \
	--plugin qt \
	--desktop-file "$DESKTOP_FILE" \
	--icon-file "$ICON_FILE" \
	--icon-filename mandelbulber2 ||
	die "linuxdeploy failed"

# --------------------------------------------------------------------------
# Package
# --------------------------------------------------------------------------
ARCH="$(uname -m)"
case "$ARCH" in
	x86_64|aarch64) : ;;
	*) die "unsupported architecture for AppImage naming: $ARCH" ;;
esac
OUTPUT="$OUT_DIR/Mandelbulber_v2-$ARCH.AppImage"
rm -f "$OUTPUT"
info "Packaging $OUTPUT"
APPIMAGE_EXTRACT_AND_RUN=1 ARCH="$ARCH" "$APPIMAGETOOL" "$APPDIR" "$OUTPUT" ||
	die "appimagetool failed"

if [ "$KEEP_APPDIR" -eq 0 ]; then
	clean_appdir
fi

info "AppImage created: $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
