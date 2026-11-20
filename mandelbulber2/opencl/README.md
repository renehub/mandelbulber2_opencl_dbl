# OpenCL precision model

Mandelbulber's OpenCL renderer can run the fractal geometry in either single or
double precision. The precision is selected at runtime with the
`opencl_precision` setting, so a single build can produce both fast single
renders and accurate double renders.

The default remains `single`. Existing scenes and GPU drivers keep their
previous behavior.

## Running from a build tree

Mandelbulber resolves its program data relative to the executable
(`../share/mandelbulber2`). A raw qmake build has no `share` directory there, so
the program falls back to `/usr/share/mandelbulber2`. If that directory contains
a different Mandelbulber version, the OpenCL headers and kernels do not match
the binary and renders can be badly wrong even though the build succeeded.

Either install the build, or stage the source tree's data next to the binary:

```sh
cd mandelbulber2
ln -s deploy/share share
ln -s ../../../opencl deploy/share/mandelbulber2/opencl
ln -s ../../../formula deploy/share/mandelbulber2/formula
ln -s ../../../language deploy/share/mandelbulber2/language
```

Keep this staging in mind when comparing CPU and OpenCL renders: the fallback
system data can silently replace the kernels this document describes.

## Runtime selection

`opencl_precision` is an enumeration with two values:

| Value    | Kernel type | Host constant buffer      |
|----------|-------------|---------------------------|
| `single` | `float`     | `sClInConstants`          |
| `double` | `double`    | `sClInConstantsD`         |

The value is resolved by name, not by truthiness:

```cpp
QString precision =
    paramContainer->GetAsOneParameter("opencl_precision").GetValueByEnumeration();
bool doublePrecisionMode = (precision == "double");
```

The setting is exposed in Preferences as **OpenCL precision**. The combo box is
enabled only when every selected OpenCL device supports FP64. If FP64 is not
available, the UI shows a warning and resets the selection to `single`. The gate
is recomputed when the dialog is shown and whenever the device selection
changes. Temporarily disabling OpenCL only disables the combo box; it does not
discard the saved precision, so re-enabling OpenCL restores the double option.

## FP64 device gating

FP64 support is detected from the `CL_DEVICE_EXTENSIONS` string. A device is
considered FP64-capable when it advertises `cl_khr_fp64` or the legacy
`cl_amd_fp64` extension. `CL_DEVICE_DOUBLE_FP_CONFIG` is logged for diagnostics
but is not used as the gate, because drivers report it inconsistently.

The check is applied per enabled device; double precision requires **all**
enabled devices to support FP64.

If a settings file requests `double` on a device without FP64, the renderer:

1. logs a clear diagnostic,
2. falls back to a single-precision kernel,
3. builds and uploads the single-precision host layouts,
4. renders normally, without compiling a double kernel or sending mismatched
   constant/dynamic buffers to the device.

The kernel source is generated from the **effective** precision rather than the
raw parameter, so the fallback is safe even when the saved setting says
`double`.

## Precision boundaries

Double precision is used for every value that affects geometry:

- camera rays, view vectors and camera matrices,
- distance estimation and ray marching,
- fractal state and iteration results,
- normal vectors,
- ray intersection, hard shadows, ambient occlusion and GI ray geometry,
- object/material transforms and mesh distances,
- light positions/directions and volumetric ray geometry.

Single precision is kept for image/display pipelines where it does not affect
geometry:

- RGB and alpha channels, `sClPixel`, display buffers,
- textures and `image2d_t` samples,
- palettes and gradient color tables,
- DOF, SSAO, chromatic aberration, HDR blur and post filters,
- background textures and the Nebula renderer.

Boundary conversions are explicit macros in `opencl/opencl_typedefs.h`:

```c
#define TO_REAL2(v) convert_double2(v)
#define TO_REAL3(v) convert_double3(v)
#define TO_REAL4(v) convert_double4(v)
#define TO_CL_FLOAT2(v) convert_float2(v)
#define TO_CL_FLOAT3(v) convert_float3(v)
#define TO_CL_FLOAT4(v) convert_float4(v)
```

In single mode these macros are no-ops. In double mode they promote a sampled
float texture/palette value to `double`, or demote a double shading result before
it is stored in a float channel.

Material/light colors that participate in double-precision shading are
promoted with `TO_REAL3` at the boundary. Texture and palette colors stay
`cl_float3` and are wrapped only when consumed.

The Nebula renderer always compiles without `DOUBLE_PRECISION`, even when the
fractal renderer is in double mode.

## Distance threshold floor

The original single-precision engine stops ray marching at a small distance
floor in `calculate_distance.cl`:

```c
distThresh = max(distThresh, 1e-6f);   // CalcDistThresh
delta = max(delta, 1e-6f);             // CalcDelta
```

That floor is a single-precision safeguard: below roughly float resolution the
distance estimator can stall and produce unstable hit points. It must not apply
to double mode. In deep zooms the CPU threshold is often far below `1e-6`, so
keeping the floor made the OpenCL ray marcher stop much earlier than the CPU and
produce different hit points, palette color indices and surface detail.

Both floors are now compiled only when `DOUBLE_PRECISION` is not defined. The
single-precision path keeps the original clamp and behavior unchanged; double
mode uses the per-point threshold computed from the camera distance, resolution
and field of view, matching the CPU ray marcher.

## Host and kernel data layouts

Generated headers contain two layouts:

- kernel-side structs (`sMaterialCl`, `sLightCl`, ...): numeric fields use
  `REAL`, `REAL2`, `REAL3`, `REAL4` and `matrix33`/`matrix44`; alignment is
  selected by `ALIGN_REAL`.
- host-side single layouts (`sMaterialCl`, ...): existing `cl_float` fields and
  16-byte alignment.
- host-side double layouts (`sMaterialClD`, `sLightClD`, ...): fields use
  `cl_double`, `cl_double2/3/4` and `matrix33D`/`matrix44D`; alignment is
  `ALIGN_DOUBLE` (32 bytes).

`ALIGN_REAL` is 16 bytes in single mode and 32 bytes in double mode. The host
uses 32-byte alignment for all `*D` structures so that array elements stay
correctly aligned when uploaded to the device.

Measured host layouts (GCC x86_64):

| Structure             | Single layout | Double layout |
|-----------------------|---------------|---------------|
| `sClInConstants`      | 1552 B / 16 B | 2336 B / 32 B (`sClInConstantsD`) |
| `sParamRenderCl`      | 1552 B / 16 B | 2336 B / 32 B (`sParamRenderClD`) |
| `sClCalcParams`       | 64 B / 16 B   | 96 B / 32 B (`sClCalcParamsD`) |
| `sClMeshExport`       | 96 B / 16 B   | 128 B / 32 B (`sClMeshExportD`) |

The host builds double dynamic data directly from CPU double structures with
`DynamicDoublePolicy` in `src/opencl_dynamic_data.cpp`; no float intermediate
is used for geometry. `DynamicSinglePolicy` keeps the existing single layout for
single mode.

`src/opencl_engine_render_fractal.cpp` selects the matching buffers, sizes and
readback types based on the effective precision:

- constant buffer: `sClInConstants` / `sClInConstantsD`,
- mesh export buffer: `sClMeshExport` / `sClMeshExportD`,
- `pointToCalculateDistance`: `cl_float3` / `cl_double3`,
- `CalculateDistance()` returns `double`,
- mesh/distance readback uses the matching array element type.

## Deterministic seeding and step jitter

The OpenCL kernels used to receive their per-pixel random seed from
`std::rand()`. That value depended on unrelated `rand()` calls made earlier in
the process (for example during kernel compilation), so repeated renders and
the single/double kernels could start from different seeds. The seed is now
derived from the frame number, and the kernel mixes in the pixel coordinates:

```c
int randomSeed = imageX + imageY * imageWidth + frameNo;
```

The CPU renderer uses the same formula, the same 48-bit LCG
(`opencl/opencl_algebra.h`) and the same ten-step warm-up, seeded once per
pixel. The generator state is `thread_local`, so parallel CPU workers do not
share it. As a result OpenCL renders are deterministic for a given scene and
frame, and the CPU render is deterministic too.

Random step-size jitter was removed from both ray marchers. The CPU and OpenCL
distance estimators differ by a few ulps; random jitter amplified those tiny
differences into visibly different hit points and speckled edges. Removing it
was the largest single improvement in CPU/OpenCL parity:

| Scene (`mandelbulb_power_2`, 400x225, default shading) | Before | After |
|--------------------------------------------------------|--------|-------|
| CPU to single                                          | 0.0254 | 0.0127 |
| CPU to double                                          | 0.0263 | 0.0125 |
| single to double                                       | 0.0272 | 0.00235 |

The remaining CPU/OpenCL difference comes from shading and Monte Carlo sampling
paths, not from the step jitter.

## Kernel cache and build flags

The precision is part of both cache keys:

- the generated source contains the `DOUBLE_PRECISION` define, so the source
  hash changes with precision,
- an explicit precision marker (`-DDOUBLE_PRECISION` or `-DOPENCL_SINGLE`) is
  added to the program/cache filename hash and to the build-parameter hash.

A cache entry from a single-precision build can therefore never be reused for a
double-precision build, and vice versa. The compiler flags themselves are also
part of the hash now, so toggling `-cl-fast-relaxed-math` (or any future flag)
cannot reuse a binary built with different options.

In single mode the build still uses `-cl-single-precision-constant`. In double
mode that flag is **not** added, because it would silently truncate every double
literal to float. `-cl-mad-enable`, `-cl-denorms-are-zero` and the optional
`-cl-fast-relaxed-math` setting are otherwise unchanged.

Double mode with fast-relaxed-math enabled also defines `DOUBLE_FAST_RADIUS`,
which selects the float-sqrt radius path described above. It is part of the
define hash, so changing fast math cannot mix kernel variants.

## Generated headers

The generated OpenCL headers are reproducible from the Python generators:

```sh
cd mandelbulber2
python3 tools/populateOpenCL.py            # dry run
python3 tools/populateOpenCL.py nondry     # write generated layout headers
python3 tools/generateOpenCLPrecisionHeaders.py            # dry run
python3 tools/generateOpenCLPrecisionHeaders.py nondry     # write +D layouts and helpers
```

`populateOpenCL.py` is the Python port of `populateOpenCL.php`. It generates the
kernel layout from the C++ structures and the host-side single layout.
`generateOpenCLPrecisionHeaders.py` adds the kernel-side `REAL` types and the
host-side `*D` structures/helpers. Both scripts are idempotent: repeated runs
produce no changes.

Do not edit generated headers by hand; change the generators or the source
structures instead.

## Precision compatibility macros

OpenCL's `native_*` and `fast_*` functions are float-only. In double mode
`opencl_typedefs.h` maps them to standard double-capable functions:

```c
native_exp -> exp
native_log -> log
native_sqrt -> sqrt
native_rsqrt -> rsqrt
native_sin -> sin
native_cos -> cos
native_recip -> 1.0/x
native_divide -> a/b
native_powr -> powr
fast_length -> length
fast_normalize -> normalize
```

This keeps formulas and engines valid in both modes without silently evaluating
geometry in single precision.

## Usage and performance

Double mode requires an FP64-capable OpenCL device. On NVIDIA GPUs with
`cl_khr_fp64` it builds and renders correctly; PoCL's CPU device also supports
FP64.

Observed performance (GTX 1050 Ti, 320x180 deep-zoom scene, render time):

| Precision | Render time | Relative |
|-----------|-------------|----------|
| single    | 6.8 s  | 1.0x |
| double    | 15.6 s | 2.3x |
| CPU       | 7.1 s  | 1.0x |

These are warm measurements after compilation. Double kernels use double
arithmetic and larger constant/dynamic buffers, so the slowdown is expected.
Compilation is also more expensive: a complex full-engine scene such as
`difs_tree` needed about 109 s wall time in double (including compilation),
while the kernel build cache makes subsequent runs much faster.

In the geometry-only deep-zoom variant (320x180), double rendered in 1.0 s
against 0.2 s for single; the CPU took 1.3 s. Double was closer to the CPU
result than single precision.

### Double-precision hot loop

The inner fractal iteration used `length(z)` to update the iteration radius.
In the double kernels the OpenCL built-in generated much slower code than an
explicit `sqrt(dot(z, z))`. The radius is needed once per iteration by every
formula, so this was the dominant cost of double rendering. `CalcRadius()` in
`opencl/opencl_algebra.h` now uses the explicit form. Under the default
fast-relaxed-math setting the sqrt is evaluated in float and promoted; the
radius only scales the distance estimate, so this changes the image by about
1e-7 relative while the iteration itself remains double. Disable
`opencl_use_fast_relaxed_math` to get the exact double sqrt.

Measured on the user's deep-zoom Mandelbox scene (`pt1.fract`, 360x240,
full engine, GTX 1050 Ti):

| Renderer | Before | After |
|----------|--------|-------|
| CPU      | 12.3 s | 12.3 s |
| single   |  3.4 s |  3.3 s |
| double   | 10.6 s |  6.0 s |

The double render is now about twice as fast as the CPU render instead of
barely faster. Absolute times vary with GPU clock throttling; the relative
improvement is stable across repeated runs. The double image changes by only
RMSE 0.00022 versus the pre-optimization render, and CPU-to-double RMSE is
unchanged (0.02738).

## Validation evidence

Deep-zoom scene `msltoe_donut_001` (camera-to-target distance `0.000377`),
320x180, full shading path with AO, reflections and fog, refreshed after the
threshold-floor fix:

| Comparison        | RMSE    |
|-------------------|---------|
| CPU to double     | 0.02982 |
| CPU to single     | 0.06091 |
| double to single  | 0.05938 |

The `gputest` mandelbox scene (`mandelbox_scale -1.1`,
`mandelbox_main_rotation_enabled true`) at 180x120 is a deeper zoom where the
ray-march threshold falls well below `1e-6`. It shows the effect of the floor
fix directly:

| Comparison        | Before fix | After fix |
|-------------------|------------|-----------|
| CPU to double     | 0.261815   | 0.06797   |
| CPU to single     | 0.261571   | 0.26150   |
| single to double  | 0.118661   | 0.25605   |

CPU and double now render the same green palette colors and surface detail;
before the fix the double image retained the clamped single-precision look
(magenta/brown) while the CPU used the unclamped threshold and stayed green.
CPU to single is unchanged, confirming single-precision behavior is preserved.
The single-to-double increase is expected: double moved to match the CPU, so it
is now farther from the clamped single image.

Earlier variants measured before the floor fix showed the same ordering, with
double closer to CPU than single: geometry-only (AO, reflections and fog off)
scored 0.03099/0.03352/0.03187 and a deeper camera (`1e-5`, 160x90) scored
0.02710/0.02899/0.02602 for CPU-to-double/CPU-to-single/double-to-single. Those
numbers predate the threshold fix and are useful mainly as relative comparisons.

CPU and GPU renders are now deterministic for a given scene and frame. Even in
double mode they are not pixel-identical because the renderers still differ in
shading and Monte Carlo sampling details. Deep-zoom precision alone does not
eliminate those differences.

Additional smoke coverage:

- 153 example scenes rendered in double at 48x27 with zero compile diagnostics.
  Three heavy scenes (`difs_tree`, `monte carlo global illumination - cube
  scene`, `stereoscopic 001`) exceeded the sweep's 60 s timeout but completed
  cleanly with extended timeouts (61-109 s wall time).
- All 153 example scenes rendered in single at 48x27 with zero compile
  diagnostics and zero failures. This includes heavy full-engine and Monte
  Carlo scenes; the later rerun pass used a 300 s per-scene timeout.
- 7 representative scenes rendered in single at 128x72 with zero compile
  diagnostics (`aexion002`, `clouds 001`, `difs_tree`, `hybrid008 - collatz`,
  `mandelbox_menger_with_textures`, `monte carlo global illumination`,
  `transparency reflectance roughness textures`).
- DOF (Monte Carlo DOF plus the DOF phases), SSAO, HDR blur and chromatic
  aberration ran in both single and double mode at 128x72 with zero
  diagnostics.
- Mesh export (PLY) tested in single and double mode, including 16x16 voxel
  grids; both complete and produce valid PLY files. A fresh run produced
  744-vertex PLY files in both modes, byte-identical in size but different in
  content.
- The Nebula renderer ran in both modes; it remains float-only by design.
- PoCL's CPU device compiled and rendered both single and double kernels at
  48x27 with zero diagnostics, confirming the double path is not NVIDIA-only.
- Deep-zoom CPU/single/double images were compared with ImageMagick `compare`.

## Known limitations

- Double precision requires FP64 support on every selected device. Without it,
  the request is downgraded to single with a warning rather than failing.
- Double mode is slower, compiles more slowly, and uses larger
  constant/dynamic buffers. The kernel build cache is especially useful for
  large full-engine scenes.
- Display, texture, palette, DOF/SSAO/post-filter and Nebula pipelines stay
  single precision by design; these values do not affect fractal geometry.
- CPU and GPU renders can still differ in deep zooms due to shading and
  sampling differences unrelated to float/double precision; exact pixel
  identity is not attainable.
- The `1e-6` distance floor is intentionally single-precision only. Removing it
  from double mode is what aligns deep-zoom hit points with the CPU.
- There is no PHP or `clang-format` in this environment; the Python generators
  replace the PHP generator for reproducibility.
