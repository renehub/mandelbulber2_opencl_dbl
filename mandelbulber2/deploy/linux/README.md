# Linux build and packaging

## Installer

`install` builds and installs Mandelbulber v2 into `/usr` (or a prefix given
on the command line). It can also install the build dependencies. `uninstall`
removes an installation made by `install`. Both scripts and the desktop file
and AppStream metadata in this directory are reused by the AppImage packaging
step.

## AppImage

`create-appimage.sh` creates a self-contained, portable AppImage from the
qmake build:

```sh
./create-appimage.sh --out-dir "$PWD"
```

The script:

1. installs the compiled qmake build into a temporary AppDir with
   `make INSTALL_ROOT=<appdir> install`;
2. uses linuxdeploy and its Qt plugin to bundle the Qt 6 runtime, Qt plugins,
   and the other shared libraries;
3. packages the AppDir with appimagetool.

The AppImage uses the normal AppDir layout `usr/bin/mandelbulber2` and
`usr/share/mandelbulber2`. The binary finds its data through its standard
"share next to the executable" lookup, so AppImage builds do not need the
`SHARED_DIR_IS_APP_DIR` definition used by macOS bundles.

Requirements are Qt 6 development tools (including `qmake6`), `make`,
`mksquashfs`, and wget or curl. linuxdeploy, its Qt plugin and appimagetool are
downloaded into `~/.cache/mandelbulber2-appimage` on first use; use
`--tools-dir` to cache them elsewhere.

Options:

| Option | Meaning |
| --- | --- |
| `--build-dir DIR` | Directory containing the qmake Makefile (default: `<source>/qmake`) |
| `--appdir DIR` | Temporary AppDir (default: `<build-dir>/appdir`) |
| `--out-dir DIR` | Where `Mandelbulber_v2-<arch>.AppImage` is written (default: current directory) |
| `--tools-dir DIR` | Cache directory for linuxdeploy and appimagetool |
| `--jobs N` | Parallel make jobs |
| `--keep-appdir` | Keep the staged AppDir for inspection |

A quick smoke test with an OpenCL-enabled settings file (`opencl_mode` > 0)
renders a small image without the GUI:

```sh
./Mandelbulber_v2-x86_64.AppImage --help
./Mandelbulber_v2-x86_64.AppImage -n -f png -r 320x180 -o out.png \
    /path/to/settings.fract
```

The AppImage bundles the generic OpenCL ICD loader, but not the OpenCL
platform or device drivers. OpenCL rendering therefore still requires the
host's driver/ICD files (for example the NVIDIA driver or PoCL), exactly like
a normal installation.

The AppImage is a build artifact and is not committed to the repository.
