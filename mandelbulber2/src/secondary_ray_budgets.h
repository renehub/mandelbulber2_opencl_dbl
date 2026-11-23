/**
 * Mandelbulber v2, a 3D fractal generator
 *
 * Hard budgets for secondary ray loops (MC GI, AO, auxiliary-light shadows).
 * GPU defines are generated from these same values in
 * opencl_engine_render_fractal.cpp.
 */

#ifndef MANDELBULBER2_SRC_SECONDARY_RAY_BUDGETS_H_
#define MANDELBULBER2_SRC_SECONDARY_RAY_BUDGETS_H_

// Maximum distance-estimation steps for one MC GI bounce. 128-512 is the
// intended range; 256 keeps worst-case deep-zoom frames bounded without
// affecting normal frames, which stop much earlier.
#define MAX_GI_STEPS 256

// Maximum number of GI bounces. reflectionsMax may be as high as 1000; GI does
// not need that depth and the cost grows multiplicatively.
#define GI_MAX_DEPTH 3

// Maximum distance-estimation steps for one multiple-ray AO sample.
#define MAX_AO_STEPS 48

// Maximum distance-estimation steps for one auxiliary-light shadow ray.
// This is deliberately lower than MAX_RAYMARCHING (10000).
#define MAX_SHADOW_STEPS 192

// A GI step smaller than this fraction of distThresh is considered no progress.
#define GI_NO_PROGRESS_EPSILON 1e-4

// AO stops when the remaining shadow contribution is below this value or the
// unvisited fraction of the AO ray is below AO_MIN_REMAINING.
#define AO_MIN_SHADOW 1e-3
#define AO_MIN_REMAINING 1e-3

// Shadow rays stop early once the accumulated shadow is effectively black.
#define SHADOW_MIN 1e-3

// Do not start a shadow ray when the direct+specular contribution is below
// this value; the shade/specular terms already include light intensity.
#define SHADOW_CONTRIBUTION_MIN 5e-3

#endif /* MANDELBULBER2_SRC_SECONDARY_RAY_BUDGETS_H_ */
