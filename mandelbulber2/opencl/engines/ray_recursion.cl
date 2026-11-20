/**
 * Mandelbulber v2, a 3D fractal generator       ,=#MKNmMMKmmßMNWy,
 *                                             ,B" ]L,,p%%%,,,§;, "K
 * Copyright (C) 2017-24 Mandelbulber Team     §R-==%w["'~5]m%=L.=~5N
 *                                        ,=mm=§M ]=4 yJKA"/-Nsaj  "Bw,==,,
 * This file is part of Mandelbulber.    §R.r= jw",M  Km .mM  FW ",§=ß., ,TN
 *                                     ,4R =%["w[N=7]J '"5=],""]]M,w,-; T=]M
 * Mandelbulber is free software:     §R.ß~-Q/M=,=5"v"]=Qf,'§"M= =,M.§ Rz]M"Kw
 * you can redistribute it and/or     §w "xDY.J ' -"m=====WeC=\ ""%""y=%"]"" §
 * modify it under the terms of the    "§M=M =D=4"N #"%==A%p M§ M6  R' #"=~.4M
 * GNU General Public License as        §W =, ][T"]C  §  § '§ e===~ U  !§[Z ]N
 * published by the                    4M",,Jm=,"=e~  §  §  j]]""N  BmM"py=ßM
 * Free Software Foundation,          ]§ T,M=& 'YmMMpM9MMM%=w=,,=MT]M m§;'§,
 * either version 3 of the License,    TWw [.j"5=~N[=§%=%W,T ]R,"=="Y[LFT ]N
 * or (at your option)                   TW=,-#"%=;[  =Q:["V""  ],,M.m == ]N
 * any later version.                      J§"mr"] ,=,," =="""J]= M"M"]==ß"
 *                                          §= "=C=4 §"eM "=B:m|4"]#F,§~
 * Mandelbulber is distributed in            "9w=,,]w em%wJ '"~" ,=,,ß"
 * the hope that it will be useful,                 . "K=  ,=RMMMßM"""
 * but WITHOUT ANY WARRANTY;                            .'''
 * without even the implied warranty
 * of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * See the GNU General Public License for more details.
 * You should have received a copy of the GNU General Public License
 * along with Mandelbulber. If not, see <http://www.gnu.org/licenses/>.
 *
 * ###########################################################################
 *
 * Authors: Krzysztof Marczak (buddhi1980@gmail.com)
 *
 * contains the RayMarching function and the ray iteration function
 * used in the full_engine_cl
 */

typedef struct
{
	REAL3 start;
	REAL3 direction;
	REAL minScan;
	REAL maxScan;
	bool binaryEnable;
	bool invertMode;
} sRayMarchingIn;

typedef struct
{
	REAL3 point;
	REAL lastDist;
	REAL depth;
	REAL distThresh;
	int objectId;
	int sequenceIndex;
	bool found;
	int count;
	REAL3 transformedPoint;
	bool hasTransformedPoint;
	REAL detailLevelMultiplier;
} sRayMarchingOut;

typedef enum
{
	rayBranchReflection = 0,
	rayBranchRefraction = 1,
	rayBranchDone = 2,
} enumRayBranch;

typedef struct
{
	sRayMarchingIn rayMarchingIn;
	REAL4 resultShader;
	REAL3 objectColour;
	enumRayBranch rayBranch;
	bool calcInside;
} sRayRecursionIn;

typedef struct
{
	sRayMarchingOut rayMarchingOut;
	REAL3 point;
	REAL4 resultShader;
	REAL3 objectColour;
	REAL3 normal;
	REAL3 specular;
	REAL3 outShadow;
	REAL3 outGlobalIllumination;
	REAL fogOpacity;
	bool found;
} sRayRecursionOut;

typedef struct
{
	sRayRecursionIn in;
	sRayRecursionOut out;
#ifdef USE_REFLECTANCE
	REAL4 reflectShader;
#endif
#ifdef USE_REFRACTION
	REAL4 transparentShader;
#endif
	enumRayBranch rayBranch;
	bool goDeeper;
} sRayStack;

#if defined(USE_REFRACTION) || defined(USE_REFLECTANCE)
REAL3 ReflectionVector(const REAL3 normal, const REAL3 incident)
{
	return incident - normal * dot(incident, normal) * 2.0;
}
#endif

// Statistics of a single RayMarching call. Only scalar values are produced
// inside RayMarching (no per-pixel arrays / global atomics), the final
// aggregation into histograms is done on the CPU after reading sClPixel back.
// Shadows, AO and volumetric effects are intentionally not covered.
typedef struct
{
	uint deCalls;	 // number of CalculateDistance calls in this raymarch
	uint itersSum; // sum of iterations over all those calls
	uint hitIters; // iterations at the step where the surface was hit
	ushort steps;	 // main loop steps + binary search iterations
	bool hit;			 // surface was found
	bool missedDE; // hit with distance < 0.1 * distThresh (bad DE estimate)
} sRaymarchStatsCl;

// Per-pixel statistics accumulated across all RayMarching calls of a pixel
// (primary ray + reflection/refraction bounces). Histogram samples
// (stepCount, hitIters) are taken from the primary ray only.
typedef struct
{
	uint itersSum;			// total iterations of all raymarchings of the pixel
	uint deCalls;				// total CalculateDistance calls of all raymarchings
	ushort stepCount;		// steps of the primary raymarch
	ushort hitIters;		// iterations at the hit point of the primary ray
	uchar raymarchings; // number of RayMarching calls (saturated at 255)
	uchar missedDE;			// number of missed DE events (saturated at 255)
	bool hasHit;				// primary ray hit a surface -> histogram samples are valid
} sPixelStatsCl;

void RayMarching(sRayMarchingIn in, sRayMarchingOut *out, __constant sClInConstants *consts,
	sRenderData *renderData, int *randomSeed, __private sRaymarchStatsCl *rmStats)
{
	bool found = false;
	int count;
	int bsIterations = 0; // binary search iterations (counted into step stats)

	REAL3 point;
	REAL scan, distance;

	scan = in.minScan;
	const REAL invDirectionLength = 1.0 / length(in.direction);

	sClCalcParams calcParam;
	calcParam.N = consts->params.N;
	calcParam.normalCalculationMode = false;
	calcParam.iterThreshMode = consts->params.iterThreshMode;
	REAL distThresh = 1e-6;

	formulaOut outF;
	REAL step = 0.0;

	REAL searchAccuracy = 0.001 * consts->params.detailLevel;
	REAL searchLimit = 1.0 - searchAccuracy;

	// ray-marching
	for (count = 0; count < MAX_RAYMARCHING && scan < in.maxScan; count++)
	{
		point = in.start + in.direction * scan;
		distThresh = CalcDistThresh(point, consts);
		calcParam.distThresh = distThresh;
		calcParam.detailSize = distThresh;
		outF = CalculateDistance(consts, point, &calcParam, renderData);
		distance = outF.distance;

		// statistics: one sample per distance estimation call
		rmStats->deCalls++;
		rmStats->itersSum += (uint)outF.iters;

		out->objectId = outF.objectId;
		out->sequenceIndex = outF.sequenceIndex;
		out->transformedPoint = outF.transformedPoint;
		out->hasTransformedPoint = outF.hasTransformedPoint;
		out->detailLevelMultiplier = 1.0;
		if (outF.objectId >= 0 && outF.objectId < renderData->numberOfObjects)
		{
			out->detailLevelMultiplier = renderData->objectsData[outF.objectId].detailLevelMultiplier;
		}

		// Apply per-object detailLevelMultiplier to distThresh dynamically
		if (out->detailLevelMultiplier > 0.0)
		{
			distThresh *= out->detailLevelMultiplier;
		}

#ifdef USE_REFRACTION
		if (in.invertMode)
		{
			distance = distThresh * 1.99 - distance;
			if (distance < 0.0) distance = 0.0;
		}
#endif

		if (distance < distThresh)
		{
			// statistics: record the iteration count at the surface hit point;
			// a hit far below the threshold means a bad distance estimation
			rmStats->hit = true;
			rmStats->hitIters = (uint)outF.iters;
			if (distance < 0.1 * distThresh) rmStats->missedDE = true;
			found = true;
			break;
		}

#ifdef INTERIOR_MODE
		step = (distance - 0.8 * distThresh) * consts->params.DEFactor;
#else
		step = (distance - 0.5 * distThresh) * consts->params.DEFactor;
#endif

		// No random step jitter. See the matching comment in
		// src/render_worker.cpp: random jitter amplified the small numerical
		// differences between the CPU and OpenCL distance estimators and made
		// the two renderers produce visibly different surfaces.

#ifdef ADVANCED_QUALITY
		step = clamp(step, consts->params.absMinMarchingStep, consts->params.absMaxMarchingStep);

		if (distThresh > consts->params.absMinMarchingStep)
			step = clamp(step, consts->params.relMinMarchingStep * distThresh,
				consts->params.relMaxMarchingStep * distThresh);
#endif

		scan += step * invDirectionLength;
	}

	point = in.start + in.direction * scan;

	// final binary searching
	if (found)
	{
		step *= 0.5;
		for (int i = 0; i < 30; i++)
		{
			bsIterations++;
			if (distance < distThresh && distance > distThresh * searchLimit)
			{
				break;
			}
			else
			{
				if (distance > distThresh)
				{
					scan += step;
					point = in.start + in.direction * scan;
				}
				else if (distance < distThresh * searchLimit)
				{
					scan -= step;
					point = in.start + in.direction * scan;
				}
			}
			outF = CalculateDistance(consts, point, &calcParam, renderData);
			distance = outF.distance;

			// statistics: binary search performs additional distance estimations too
			rmStats->deCalls++;
			rmStats->itersSum += (uint)outF.iters;

			out->objectId = outF.objectId;
			out->sequenceIndex = outF.sequenceIndex;
			out->transformedPoint = outF.transformedPoint;
			out->hasTransformedPoint = outF.hasTransformedPoint;

			// #ifdef USE_REFRACTION
			if (in.invertMode)
			{
				distance = distThresh * 1.99 - distance;
				if (distance < 0.0) distance = 0.0;
			}
			// #endif

			step *= 0.5;
		}
	}

	out->found = found;
	out->lastDist = distance;
	out->depth = scan;
	out->distThresh = distThresh;
	out->point = point;
	out->count = count;
	rmStats->steps = (ushort)(count + bsIterations);
}

sRayRecursionOut RayRecursion(sRayRecursionIn in, sRenderData *renderData,
	__constant sClInConstants *consts, image2d_t image2dBackground, int *randomSeed,
	__private sPixelStatsCl *pixelStats)
{
	int rayIndex = 0; // level of recursion

	sRayStack rayStack[REFLECTIONS_MAX + 2];

	rayStack[rayIndex].in = in;
	rayStack[rayIndex].rayBranch = rayBranchReflection;
	rayStack[rayIndex].goDeeper = true;

	for (int i = 0; i < renderData->reflectionsMax + 1; i++)
	{
		rayStack[i].rayBranch = rayBranchReflection;

#ifdef USE_REFLECTANCE
		rayStack[i].reflectShader = 0.0;
#endif
#ifdef USE_REFRACTION
		rayStack[i].transparentShader = 0.0;
#endif
		rayStack[i].in.objectColour = 0.0;
		rayStack[i].in.resultShader = 0.0;
	}

	do
	{
		if (rayStack[rayIndex].goDeeper)
		{

			// statistics: prepare per-raymarch storage
			sRaymarchStatsCl rmStats;
			rmStats.deCalls = 0;
			rmStats.itersSum = 0;
			rmStats.hitIters = 0;
			rmStats.steps = 0;
			rmStats.hit = false;
			rmStats.missedDE = false;

			sRayMarchingOut rayMarchingOut;
			RayMarching(rayStack[rayIndex].in.rayMarchingIn, &rayMarchingOut, consts, renderData,
				randomSeed, &rmStats);

			// statistics: accumulate across all bounces; histogram samples are taken
			// from the primary ray only (rayIndex == 0) to keep the payload minimal
			pixelStats->itersSum += rmStats.itersSum;
			pixelStats->deCalls += rmStats.deCalls;
			if (rmStats.missedDE && pixelStats->missedDE < 255) pixelStats->missedDE++;
			if (pixelStats->raymarchings < 255) pixelStats->raymarchings++;
			if (rayIndex == 0)
			{
				pixelStats->stepCount = rmStats.steps;
				if (rmStats.hit)
				{
					pixelStats->hitIters =
						(rmStats.hitIters > 65535u) ? (ushort)65535 : (ushort)rmStats.hitIters;
					pixelStats->hasHit = true;
				}
			}

			REAL3 point = rayMarchingOut.point;

			bool found = rayMarchingOut.found;
			REAL depth = rayMarchingOut.depth;

			REAL distThresh = CalcDistThresh(point, consts);

			sClCalcParams calcParam;
			calcParam.N = consts->params.N;
			calcParam.normalCalculationMode = false;
			calcParam.iterThreshMode = consts->params.iterThreshMode;

			sShaderInputDataCl shaderInputData;
			shaderInputData.distThresh = distThresh;
			shaderInputData.delta = CalcDelta(point, consts);
			shaderInputData.point = point;
			shaderInputData.viewVector = rayStack[rayIndex].in.rayMarchingIn.direction;
			shaderInputData.viewVectorNotRotated = renderData->viewVectorNotRotated;
			shaderInputData.normal = shaderInputData.viewVector; // initial value
			shaderInputData.lastDist = rayMarchingOut.lastDist;
			shaderInputData.depth = rayMarchingOut.depth;
			shaderInputData.invertMode = rayStack[rayIndex].in.calcInside;

			shaderInputData.objectId = rayMarchingOut.objectId;
			shaderInputData.sequenceIndex = rayMarchingOut.sequenceIndex;
			shaderInputData.transformedPoint = rayMarchingOut.transformedPoint;
			shaderInputData.hasTransformedPoint = rayMarchingOut.hasTransformedPoint;

			__global sObjectDataCl *objectData = &renderData->objectsData[shaderInputData.objectId];
			shaderInputData.material = renderData->materials[objectData->materialId];
			shaderInputData.palette = renderData->palettes[objectData->materialId];
#ifdef USE_SURFACE_GRADIENT
			shaderInputData.paletteSurfaceOffset =
				renderData->paletteSurfaceOffsets[objectData->materialId];
			shaderInputData.paletteSurfaceLength =
				renderData->paletteSurfaceLengths[objectData->materialId];
#endif
#ifdef USE_SPECULAR_GRADIENT
			shaderInputData.paletteSpecularOffset =
				renderData->paletteSpecularOffsets[objectData->materialId];
			shaderInputData.paletteSpecularLength =
				renderData->paletteSpecularLengths[objectData->materialId];
#endif
#ifdef USE_DIFFUSE_GRADIENT
			shaderInputData.paletteDiffuseOffset =
				renderData->paletteDiffuseOffsets[objectData->materialId];
			shaderInputData.paletteDiffuseLength =
				renderData->paletteDiffuseLengths[objectData->materialId];
#endif
#ifdef USE_LUMINOSITY_GRADIENT
			shaderInputData.paletteLuminosityOffset =
				renderData->paletteLuminosityOffsets[objectData->materialId];
			shaderInputData.paletteLuminosityLength =
				renderData->paletteLuminosityLengths[objectData->materialId];
#endif
#ifdef USE_ROUGHNESS_GRADIENT
			shaderInputData.paletteRoughnessOffset =
				renderData->paletteRoughnessOffsets[objectData->materialId];
			shaderInputData.paletteRoughnessLength =
				renderData->paletteRoughnessLengths[objectData->materialId];
#endif
#ifdef USE_REFLECTANCE_GRADIENT
			shaderInputData.paletteReflectanceOffset =
				renderData->paletteReflectanceOffsets[objectData->materialId];
			shaderInputData.paletteReflectanceLength =
				renderData->paletteReflectanceLengths[objectData->materialId];
#endif
#ifdef USE_TRANSPARENCY_GRADIENT
			shaderInputData.paletteTransparencyOffset =
				renderData->paletteTransparencyOffsets[objectData->materialId];
			shaderInputData.paletteTransparencyLength =
				renderData->paletteTransparencyLengths[objectData->materialId];
#endif

			shaderInputData.stepCount = rayMarchingOut.count;
			shaderInputData.randomSeed = *randomSeed;

			REAL reflect = shaderInputData.material->reflectance;
			REAL transparent = shaderInputData.material->transparencyOfSurface;

			rayStack[rayIndex].out.rayMarchingOut = rayMarchingOut;

			// if found any object
			if (found)
			{
				sClCalcParams calcParam;
				calcParam.N = consts->params.N;
				calcParam.normalCalculationMode = false;
				calcParam.iterThreshMode = consts->params.iterThreshMode;
				calcParam.distThresh = shaderInputData.distThresh;
				calcParam.detailSize = shaderInputData.delta;

				REAL3 normal =
					NormalVector(consts, renderData, shaderInputData.point, shaderInputData.lastDist,
						shaderInputData.distThresh, shaderInputData.invertMode, &calcParam);
				shaderInputData.normal = normal;

#ifdef USE_ROUGH_SURFACE
				REAL roughnessGradient = 1.0;

#ifdef USE_ROUGHNESS_GRADIENT
				if (shaderInputData.material->useColorsFromPalette
						&& shaderInputData.material->roughnessGradientEnable)
				{
					sClGradientsCollection gradients;
					SurfaceColor(consts, renderData, &shaderInputData, &calcParam, &gradients);
					roughnessGradient = gradients.roughness.s0;
				}
#endif // USE_ROUGHNESS_GRADIENT

				REAL roughnesTexture = 1.0;
#ifdef USE_TEXTURES
#ifdef USE_ROUGHNESS_TEXTURE
				roughnesTexture = RoughnessTexture(&shaderInputData, renderData, objectData,
					shaderInputData.material->roughnessTextureIndex);
#endif // USE_ROUGHNESS_TEXTURE
#endif // USE_TEXTURES

				if (shaderInputData.material->roughSurface)
				{
					REAL roughness = shaderInputData.material->surfaceRoughness;
					// every axis is calculated twice because of simple Random() function (increase
					// randomness)
					REAL totalRoughness = roughnesTexture * roughnessGradient * roughness;
					normal.x += totalRoughness * (Random(20000, randomSeed) / 10000.0 - 1.0);
					normal.x += totalRoughness * (Random(20000, randomSeed) / 10000.0 - 1.0);
					normal.y += totalRoughness * (Random(20000, randomSeed) / 10000.0 - 1.0);
					normal.y += totalRoughness * (Random(20000, randomSeed) / 10000.0 - 1.0);
					normal.z += totalRoughness * (Random(20000, randomSeed) / 10000.0 - 1.0);
					normal.z += totalRoughness * (Random(20000, randomSeed) / 10000.0 - 1.0);
					shaderInputData.normal = normal = normalize(normal);
				}
#endif // USE_ROUGH_SURFACE

#ifdef USE_TEXTURES
#ifdef USE_NORMAL_MAP_TEXTURE
				{
					REAL3 normalMapResult = NormalMapShader(&shaderInputData, renderData, objectData,
						shaderInputData.material->normalMapTextureIndex);
					REAL normalMapLength = length(normalMapResult);
					bool valid = normalMapLength > 1e-5 && normalMapLength < 1e5;

					if (valid)
					{
						normal = normalMapResult;
						shaderInputData.normal = normal;
					}
				}
#endif
#endif

				rayStack[rayIndex].out.normal = normal;

#if defined(USE_REFRACTION) || defined(USE_REFLECTANCE)
				// prepare refraction values
				REAL n1, n2;

#ifdef CHROMATIC_ABERRATION
				REAL aberrationStrength = consts->params.DOFMonteCarloCADispersionGain * 0.01;
				REAL hueEffect = 1.0 - aberrationStrength + aberrationStrength * renderData->hue / 180.0;
#else
				REAL hueEffect = 1.0;
#endif

				if (rayStack[rayIndex].in.calcInside) // if trace is inside the object
				{
					n1 = shaderInputData.material->transparencyIndexOfRefraction
							 / hueEffect; // reverse refractive indices
					n2 = 1.0;
				}
				else
				{
					n1 = 1.0;
					n2 = shaderInputData.material->transparencyIndexOfRefraction / hueEffect;
				}

				if (rayIndex < renderData->reflectionsMax)
				{

					enumRayBranch rayBranch = rayStack[rayIndex].rayBranch;
					if (rayStack[rayIndex].rayBranch == rayBranchReflection)
					{
						// qDebug() << "Reflection" << rayIndex;
						rayStack[rayIndex].rayBranch = rayBranchRefraction;

#ifdef USE_REFLECTANCE
						// calculate reflection
						if (reflect > 0.0)
						{
							rayIndex++; // increase recursion level

							sRayRecursionIn recursionIn;
							sRayMarchingIn rayMarchingIn;

							// calculate new direction of reflection
							REAL3 newDirection =
								ReflectionVector(normal, rayStack[rayIndex - 1].in.rayMarchingIn.direction);
							REAL3 newPoint = point + newDirection * shaderInputData.distThresh;

							// prepare for new recursion
							rayMarchingIn.binaryEnable = true;
							rayMarchingIn.direction = newDirection;
							rayMarchingIn.maxScan = consts->params.viewDistanceMax;
							rayMarchingIn.minScan = 0.0;
							rayMarchingIn.start = newPoint;
							rayMarchingIn.invertMode = false;
							recursionIn.rayMarchingIn = rayMarchingIn;
							recursionIn.calcInside = false;
							recursionIn.resultShader = rayStack[rayIndex - 1].in.resultShader;
							recursionIn.objectColour = rayStack[rayIndex - 1].in.objectColour;
							recursionIn.rayBranch = rayBranchReflection;

							// recursion for reflection
							rayStack[rayIndex].in = recursionIn;
							rayStack[rayIndex].goDeeper = true;
							rayStack[rayIndex].rayBranch = rayBranchReflection;

							continue;
						}
#endif
					}

					if (rayStack[rayIndex].rayBranch == rayBranchRefraction)
					{
						rayStack[rayIndex].rayBranch = rayBranchDone;

#ifdef USE_REFRACTION
						// calculate refraction (transparency)
						if (transparent > 0.0)
						{
							rayIndex++; // increase recursion level

							sRayRecursionIn recursionIn;
							sRayMarchingIn rayMarchingIn;

							// calculate direction of refracted light
							REAL3 newDirection =
								RefractVector(normal, rayStack[rayIndex - 1].in.rayMarchingIn.direction, n1, n2);

							// move starting point a little
							REAL3 newPoint = point
																+ rayStack[rayIndex - 1].in.rayMarchingIn.direction
																		* shaderInputData.distThresh * 1.0;

							// if is total internal reflection the use reflection instead of refraction
							bool internalReflection = false;
							if (length(newDirection) == 0.0)
							{
								newDirection =
									ReflectionVector(normal, rayStack[rayIndex - 1].in.rayMarchingIn.direction);
								newPoint = point
													 + rayStack[rayIndex - 1].in.rayMarchingIn.direction
															 * shaderInputData.distThresh * 1.0;
								internalReflection = true;
							}

							// preparation for new recursion
							rayMarchingIn.binaryEnable = true;
							rayMarchingIn.direction = newDirection;
							rayMarchingIn.maxScan = consts->params.viewDistanceMax;
							rayMarchingIn.minScan = 0.0;
							rayMarchingIn.start = newPoint;
							rayMarchingIn.invertMode =
								!rayStack[rayIndex - 1].in.calcInside || internalReflection;
							recursionIn.rayMarchingIn = rayMarchingIn;
							recursionIn.calcInside = !rayStack[rayIndex - 1].in.calcInside || internalReflection;
							recursionIn.resultShader = rayStack[rayIndex - 1].in.resultShader;
							recursionIn.objectColour = rayStack[rayIndex - 1].in.objectColour;
							recursionIn.rayBranch = rayBranchRefraction;

							// recursion for refraction
							rayStack[rayIndex].in = recursionIn;
							rayStack[rayIndex].goDeeper = true;
							rayStack[rayIndex].rayBranch = rayBranchReflection;

							continue;
						}
#endif
					}

					if (rayStack[rayIndex].rayBranch == rayBranchDone)
					{
						rayStack[rayIndex].goDeeper = false;
					}
				} // reflectionsMax

				else
				{
					rayStack[rayIndex].goDeeper = false;
				}
#else // defined(USE_REFRACTION) || defined(USE_REFLECTANCE)
				rayStack[rayIndex].goDeeper = false;
#endif
			} // found
			else
			{
				rayStack[rayIndex].goDeeper = false;
			}
		} // goDeeper

		if (!rayStack[rayIndex].goDeeper)
		{
			sRayRecursionOut recursionOut;

			recursionOut = rayStack[rayIndex].out;
			recursionOut.specular = 0.0;
			recursionOut.outShadow = 0.0;

			sRayMarchingOut rayMarchingOut = recursionOut.rayMarchingOut;

			REAL3 point = rayMarchingOut.point;

#ifdef USE_REFLECTANCE
			REAL4 reflectShader = rayStack[rayIndex].reflectShader;
#endif
#ifdef USE_REFRACTION
			REAL4 transparentShader = rayStack[rayIndex].transparentShader;
#endif

			REAL distThresh = CalcDistThresh(point, consts);

			sShaderInputDataCl shaderInputData;
			shaderInputData.distThresh = distThresh;
			shaderInputData.delta = CalcDelta(point, consts);
			shaderInputData.point = point;
			shaderInputData.viewVector = rayStack[rayIndex].in.rayMarchingIn.direction;
			shaderInputData.viewVectorNotRotated = renderData->viewVectorNotRotated;
			shaderInputData.normal = shaderInputData.viewVector; // initial value
			shaderInputData.lastDist = rayMarchingOut.lastDist;
			shaderInputData.depth = rayMarchingOut.depth;
			shaderInputData.invertMode = rayStack[rayIndex].in.calcInside;
			shaderInputData.objectId = rayMarchingOut.objectId;
			shaderInputData.sequenceIndex = rayMarchingOut.sequenceIndex;
			shaderInputData.transformedPoint = rayMarchingOut.transformedPoint;
			shaderInputData.hasTransformedPoint = rayMarchingOut.hasTransformedPoint;
			__global sObjectDataCl *objectData = &renderData->objectsData[shaderInputData.objectId];
			shaderInputData.material = renderData->materials[objectData->materialId];
			shaderInputData.palette = renderData->palettes[objectData->materialId];
#ifdef USE_SURFACE_GRADIENT
			shaderInputData.paletteSurfaceOffset =
				renderData->paletteSurfaceOffsets[objectData->materialId];
			shaderInputData.paletteSurfaceLength =
				renderData->paletteSurfaceLengths[objectData->materialId];
#endif
#ifdef USE_SPECULAR_GRADIENT
			shaderInputData.paletteSpecularOffset =
				renderData->paletteSpecularOffsets[objectData->materialId];
			shaderInputData.paletteSpecularLength =
				renderData->paletteSpecularLengths[objectData->materialId];
#endif
#ifdef USE_DIFFUSE_GRADIENT
			shaderInputData.paletteDiffuseOffset =
				renderData->paletteDiffuseOffsets[objectData->materialId];
			shaderInputData.paletteDiffuseLength =
				renderData->paletteDiffuseLengths[objectData->materialId];
#endif
#ifdef USE_LUMINOSITY_GRADIENT
			shaderInputData.paletteLuminosityOffset =
				renderData->paletteLuminosityOffsets[objectData->materialId];
			shaderInputData.paletteLuminosityLength =
				renderData->paletteLuminosityLengths[objectData->materialId];
#endif
#ifdef USE_ROUGHNESS_GRADIENT
			shaderInputData.paletteRoughnessOffset =
				renderData->paletteRoughnessOffsets[objectData->materialId];
			shaderInputData.paletteRoughnessLength =
				renderData->paletteRoughnessLengths[objectData->materialId];
#endif
#ifdef USE_REFLECTANCE_GRADIENT
			shaderInputData.paletteReflectanceOffset =
				renderData->paletteReflectanceOffsets[objectData->materialId];
			shaderInputData.paletteReflectanceLength =
				renderData->paletteReflectanceLengths[objectData->materialId];
#endif
#ifdef USE_TRANSPARENCY_GRADIENT
			shaderInputData.paletteTransparencyOffset =
				renderData->paletteTransparencyOffsets[objectData->materialId];
			shaderInputData.paletteTransparencyLength =
				renderData->paletteTransparencyLengths[objectData->materialId];
#endif

			shaderInputData.stepCount = rayMarchingOut.count;
			shaderInputData.randomSeed = *randomSeed;

			sClCalcParams calcParam;
			calcParam.N = consts->params.N;
			calcParam.normalCalculationMode = false;
			calcParam.iterThreshMode = consts->params.iterThreshMode;
			calcParam.distThresh = shaderInputData.distThresh;
			calcParam.detailSize = shaderInputData.delta;
			calcParam.randomSeed = *randomSeed;

#ifdef USE_REFLECTANCE
			REAL reflect = shaderInputData.material->reflectance;
#endif
#ifdef USE_REFRACTION
			REAL transparent = shaderInputData.material->transparencyOfSurface;
#endif

			REAL4 resultShader = rayStack[rayIndex].in.resultShader;
			REAL3 objectColour = rayStack[rayIndex].in.objectColour;

#ifdef USE_REFRACTION
			REAL4 transparentColor = (REAL4){shaderInputData.material->transparencyInteriorColor.s0,
				shaderInputData.material->transparencyInteriorColor.s1,
				shaderInputData.material->transparencyInteriorColor.s2, 0.0};
			resultShader = transparentColor;
#endif

			REAL3 objectShader;
			REAL3 backgroundShader;
			REAL3 volumetricShader;
			REAL3 specular;
			REAL3 iridescence;

			shaderInputData.normal = recursionOut.normal;

			if (rayMarchingOut.found)
			{

// color texture
#ifdef USE_TEXTURES
#ifdef USE_COLOR_TEXTURE
				shaderInputData.texColor = TO_CL_FLOAT3(
					TextureShader(consts, &calcParam, &shaderInputData, renderData, objectData,
						shaderInputData.material->colorTextureIndex, 1.0));
#endif

#ifdef USE_DIFFUSION_TEXTURE
				shaderInputData.texDiffuse = TO_CL_FLOAT3(
					TextureShader(consts, &calcParam, &shaderInputData, renderData, objectData,
						shaderInputData.material->diffusionTextureIndex, 1.0));
#endif

#ifdef USE_LUMINOSITY_TEXTURE
				shaderInputData.texLuminosity = TO_CL_FLOAT3(
					TextureShader(consts, &calcParam, &shaderInputData, renderData, objectData,
						shaderInputData.material->luminosityTextureIndex, 0.0));
#endif

#ifdef USE_REFLECTANCE_TEXTURE
				shaderInputData.texReflectance = TO_CL_FLOAT3(
					TextureShader(consts, &calcParam, &shaderInputData, renderData, objectData,
						shaderInputData.material->reflectanceTextureIndex, 1.0));
#endif

#ifdef USE_TRANSPARENCY_TEXTURE
				shaderInputData.texTransparency = TO_CL_FLOAT3(
					TextureShader(consts, &calcParam, &shaderInputData, renderData, objectData,
						shaderInputData.material->transparencyTextureIndex, 1.0));
#endif

#ifdef USE_TRANSPARENCY_ALPHA_TEXTURE
				shaderInputData.texTransparencyAlpha = TO_CL_FLOAT3(
					TextureShader(consts, &calcParam, &shaderInputData, renderData, objectData,
						shaderInputData.material->transparencyAlphaTextureIndex, 1.0));
#endif
#endif

#if defined(USE_PERLIN_NOISE)                                                 \
	&& (defined(USE_PERLIN_NOISE_COLOR) || defined(USE_PERLIN_NOISE_LUMINOSITY) \
			|| defined(USE_PERLIN_NOISE_TRANSPARENCY_COLOR)                         \
			|| defined(USE_PERLIN_NOISE_TRANSPARENCY_ALPHA) || defined(USE_PERLIN_NOISE_REFLECTANCE))
				PerlinNoiseForShaders(consts, &calcParam, &shaderInputData, renderData, point);
#endif

				sClGradientsCollection gradients;

				specular = 0.0;
				REAL alpha = 1.0;
				REAL3 outLuminosityEmissive = 0.0;
				objectShader =
					ObjectShader(consts, renderData, &shaderInputData, &calcParam, &objectColour, &specular,
						&iridescence, &recursionOut.outShadow, &outLuminosityEmissive, &alpha, &gradients);
				recursionOut.specular = specular;

#ifdef MONTE_CARLO_DOF_GLOBAL_ILLUMINATION
				REAL3 globalIllumination = GlobalIlumination(
					consts, renderData, &shaderInputData, &calcParam, image2dBackground, objectColour, false);
				objectShader += globalIllumination;
				recursionOut.outGlobalIllumination = globalIllumination;
#endif // MONTE_CARLO_DOF_GLOBAL_ILLUMINATION

				// calculate reflectance according to Fresnel equations

#if defined(USE_REFRACTION) || defined(USE_REFLECTANCE)
				// prepare refraction values
				REAL n1, n2;
				if (rayStack[rayIndex].in.calcInside) // if trace is inside the object
				{
					n1 =
						shaderInputData.material->transparencyIndexOfRefraction; // reverse refractive indices
					n2 = 1.0;
				}
				else
				{
					n1 = 1.0;
					n2 = shaderInputData.material->transparencyIndexOfRefraction;
				}

				REAL reflectance = 1.0;
				REAL reflectanceN = 1.0; // TODO to check if 1.0 is correct value

				if (shaderInputData.material->fresnelReflectance)
				{
					reflectance = Reflectance(
						shaderInputData.normal, rayStack[rayIndex].in.rayMarchingIn.direction, n1, n2);
					if (reflectance < 0.0) reflectance = 0.0;
					if (reflectance > 1.0) reflectance = 1.0;
					reflectanceN = 1.0 - reflectance;
				}

				if (rayIndex == renderData->reflectionsMax)
				{
					reflectance = 0.0;
					reflectanceN = 1.0;
				}
#endif

				// combine all results
				resultShader.xyz = (objectShader);

#ifdef USE_REFRACTION
#ifdef USE_TRANSPARENCY_GRADIENT
				if (shaderInputData.material->useColorsFromPalette
						&& shaderInputData.material->transparencyGradientEnable
						&& !shaderInputData.material->perlinNoiseTransparencyColorEnable)
					transparentShader *= (REAL4){
						gradients.transparency.s0, gradients.transparency.s1, gradients.transparency.s2, 1.0};
				else
#endif // USE_TRANSPARENCY_GRADIENT
					transparentShader *= (REAL4){shaderInputData.material->transparencyColor.s0,
						shaderInputData.material->transparencyColor.s1,
						shaderInputData.material->transparencyColor.s2, 1.0};

#ifdef USE_TRANSPARENCY_TEXTURE
				if (shaderInputData.material->useTransparencyTexture)
				{
					REAL texTransInt = shaderInputData.material->transparencyTextureIntensity;
					REAL texTransIntN = 1.0 - shaderInputData.material->transparencyTextureIntensity;
					REAL3 texTransparencyIntens = TO_REAL3(shaderInputData.texTransparency) * texTransInt
													 + texTransIntN;
					transparentShader *= (REAL4){texTransparencyIntens.s0, texTransparencyIntens.s1,
						texTransparencyIntens.s2, transparentShader.s3};
				}
#endif // USE_TRANSPARENCY_TEXTURE

#if defined(USE_PERLIN_NOISE) && defined(USE_PERLIN_NOISE_TRANSPARENCY_COLOR)
				// transparency perlin noise
				if (shaderInputData.material->perlinNoiseEnable
						&& shaderInputData.material->perlinNoiseTransparencyColorEnable)
				{
					transparentShader.xyz =
						PerlinNoiseForTransparency(&shaderInputData, transparentShader.xyz, false);
				}
#endif // USE_PERLIN_NOISE

#endif // USE_REFRACTION

#if defined(USE_REFRACTION) || defined(USE_REFLECTANCE)
				if (renderData->reflectionsMax > 0)
				{
#if (defined(USE_DIFFUSION_TEXTURE) || defined(USE_DIFFUSE_GRADIENT)) && defined(USE_REFLECTANCE)
					REAL3 reflectDiffused = reflect;

#ifdef USE_DIFFUSION_TEXTURE
					REAL diffusionIntensity = shaderInputData.material->diffusionTextureIntensity;
					REAL diffusionIntensityN = 1.0 - diffusionIntensity;

					reflectDiffused = reflect * shaderInputData.texDiffuse * diffusionIntensity
														+ reflect * diffusionIntensityN;
#endif // USE_DIFFUSION_TEXTURE

#ifdef USE_DIFFUSE_GRADIENT
					if (shaderInputData.material->useColorsFromPalette
							&& shaderInputData.material->diffuseGradientEnable)
					{
						reflectDiffused *= gradients.diffuse;
					}
#endif // USE_DIFFUSE_GRADIENT

#else // not USE_DIFFUSION_TEXTURE or USE_DIFFUSE_GRADIENT
#ifdef USE_REFLECTANCE
					REAL3 reflectDiffused = reflect;
#else
					REAL3 reflectDiffused = 0.0;
#endif // USE_REFLECTANCE
#endif // USE_DIFFUSION_TEXTURE

					reflectDiffused *= iridescence;

#ifdef USE_REFLECTANCE_GRADIENT
					if (shaderInputData.material->useColorsFromPalette
							&& shaderInputData.material->reflectanceGradientEnable
							&& !shaderInputData.material->perlinNoiseReflectanceEnable)
						reflectDiffused *= gradients.reflectance;
					else
#endif // USE_REFLECTANCE_GRADIENT
						reflectDiffused *= shaderInputData.material->reflectionsColor;

#ifdef USE_REFRACTION
#ifdef USE_TRANSPARENCY_ALPHA_TEXTURE
					if (shaderInputData.material->useTransparencyAlphaTexture)
					{
						transparent = transparent
													* (1.0
														 - shaderInputData.texTransparencyAlpha.s0
																 * shaderInputData.material->transparencyAlphaTextureIntensity);
					}

#endif // USE_TRANSPARENCY_ALPHA_TEXTURE

#if defined(USE_PERLIN_NOISE) && defined(USE_PERLIN_NOISE_TRANSPARENCY_ALPHA)
					if (shaderInputData.material->perlinNoiseEnable
							&& shaderInputData.material->perlinNoiseTransparencyAlphaEnable)
					{
						REAL alpha = (shaderInputData.material->perlinNoiseTransparencyAlphaInvert)
														? 1.0 - shaderInputData.perlinNoise
														: shaderInputData.perlinNoise;
						alpha = clamp(
							alpha * shaderInputData.material->perlinNoiseTransparencyAlphaIntensity, 0.0, 1.0);
						transparent = transparent * (1.0 - alpha);
					}
#endif

					resultShader = transparentShader * transparent * reflectanceN
												 + (1.0 - transparent * reflectanceN) * resultShader;
#endif // USE_REFRACTION

#ifdef USE_REFLECTANCE
#ifdef USE_REFLECTANCE_TEXTURE
					if (shaderInputData.material->useReflectanceTexture)
					{
						REAL texReflInt = shaderInputData.material->reflectanceTextureIntensity;
						REAL texReflIntN = 1.0 - shaderInputData.material->reflectanceTextureIntensity;
						reflectDiffused *=
							TO_REAL3(shaderInputData.texReflectance) * texReflInt + texReflIntN;
					}
#endif // USE_REFLECTANCE_TEXTURE

#if defined(USE_PERLIN_NOISE) && defined(USE_PERLIN_NOISE_REFLECTANCE)
					// reflectance perlin noise
					if (shaderInputData.material->perlinNoiseEnable
							&& shaderInputData.material->perlinNoiseReflectanceEnable)
					{
						reflectDiffused = PerlinNoiseForReflectance(&shaderInputData, reflectDiffused);
					}
#endif // USE_PERLIN_NOISE

					REAL reflectDiffusedAvg =
						(reflectDiffused.s0 + reflectDiffused.s1 + reflectDiffused.s2) / 3.0;

					REAL4 reflectDiffused4 =
						(REAL4){reflectDiffused.s0, reflectDiffused.s1, reflectDiffused.s2, 1.0};
					resultShader = reflectShader * reflectDiffused4 * reflectance
												 + (1.0 - reflectDiffusedAvg * reflectance) * resultShader;
#endif // USE_REFLECTANCE
				}
#endif // USE_REFRACTION || USE_REFLECTANCE
				resultShader = max(resultShader, 0.0);
				resultShader.w = alpha;
			}
			else
			{
				backgroundShader =
					BackgroundShader(consts, renderData, image2dBackground, &shaderInputData);
				resultShader.xyz = backgroundShader;
				resultShader.w = 0.0;
				rayMarchingOut.depth = 1e20;
				shaderInputData.normal = shaderInputData.viewVector;
				recursionOut.outShadow = 1.0;
				recursionOut.outGlobalIllumination = 0.0;
				// vn = mRot.RotateVector(CVector3(0.0, -1.0, 0.0));
			}

			REAL opacityOut = 0.0;

#ifdef USE_REFRACTION

			if (rayStack[rayIndex].in.calcInside) // if the object interior is traced, then the absorption
																						// of light has to be calculated
			{
				sShaderInputDataCl input2 = shaderInputData;

				REAL delta = CalcDistThresh(shaderInputData.point, consts);
				REAL depth = min(rayMarchingOut.depth, consts->params.viewDistanceMax);
				REAL startStep = min(max(depth / 10.0, delta), delta * 100);
				REAL endStep = shaderInputData.material->transparencyOfInterior * delta;
				REAL step = startStep;

				REAL scan = 0.0;

				for (int i = 0; i < MAX_RAYMARCHING; i++)
				{
					if (scan >= depth) break;

					REAL4 transparentColor = (REAL4){shaderInputData.material->transparencyInteriorColor.s0,
						shaderInputData.material->transparencyInteriorColor.s1,
						shaderInputData.material->transparencyInteriorColor.s2, 0.0};

					REAL3 insidePoint = shaderInputData.point - shaderInputData.viewVector * scan;
					input2.point = insidePoint;
					REAL opacityGradient = 1.0;

#ifdef USE_INNER_COLORING
					if (shaderInputData.material->insideColoringEnable)
					{
						sClGradientsCollection gradients;
						transparentColor.xyz *=
							SurfaceColor(consts, renderData, &input2, &calcParam, &gradients);

#ifdef USE_DIFFUSE_GRADIENT
						if (shaderInputData.material->diffuseGradientEnable)
						{
							opacityGradient = gradients.diffuse.s0;
						}
#endif
					}
#endif // USE_INNER_COLORING

#ifdef USE_TRANSPARENCY_TEXTURE
					if (shaderInputData.material->useTransparencyTexture)
					{
						REAL3 tex = TextureShader(consts, &calcParam, &input2, renderData, objectData,
							shaderInputData.material->transparencyTextureIndex, 1.0);
						REAL intensN = 1.0 - shaderInputData.material->transparencyTextureIntensityVol;
						transparentColor.xyz *=
							tex * shaderInputData.material->transparencyTextureIntensityVol + intensN;
					}
#endif

					REAL texOpacity = 0.0;
#ifdef USE_TRANSPARENCY_ALPHA_TEXTURE
					if (shaderInputData.material->useTransparencyAlphaTexture)
					{
						REAL3 tex = TextureShader(consts, &calcParam, &input2, renderData, objectData,
							shaderInputData.material->transparencyAlphaTextureIndex, 1.0);
						texOpacity =
							(1.0 - tex.s0) * shaderInputData.material->transparencyAlphaTextureIntensityVol
							+ 1e-6;
					}
#endif

#if defined(USE_PERLIN_NOISE)                      \
	&& (defined(USE_PERLIN_NOISE_TRANSPARENCY_COLOR) \
			|| defined(USE_PERLIN_NOISE_TRANSPARENCY_ALPHA))
					PerlinNoiseForShaders(consts, &calcParam, &input2, renderData, insidePoint);
#endif

#if defined(USE_PERLIN_NOISE) && defined(USE_PERLIN_NOISE_TRANSPARENCY_COLOR)
					// transparency perlin noise
					if (shaderInputData.material->perlinNoiseEnable
							&& shaderInputData.material->perlinNoiseTransparencyColorEnable)
					{
						transparentColor.xyz = PerlinNoiseForTransparency(&input2, transparentColor.xyz, true);
					}
#endif // USE_PERLIN_NOISE

					REAL opacityCollected =
						shaderInputData.material->transparencyOfInterior * opacityGradient * (1.0 - texOpacity)
						+ texOpacity;

#if defined(USE_PERLIN_NOISE) && defined(USE_PERLIN_NOISE_TRANSPARENCY_ALPHA)
					if (shaderInputData.material->perlinNoiseEnable
							&& shaderInputData.material->perlinNoiseTransparencyAlphaEnable)
					{
						REAL alpha = (shaderInputData.material->perlinNoiseTransparencyColorInvert)
														? 1.0 - shaderInputData.perlinNoise
														: input2.perlinNoise;
						alpha =
							clamp(alpha * shaderInputData.material->perlinNoiseTransparencyAlphaIntensityVol,
								0.0, 1.0);
						alpha = 1.0 - alpha;
						opacityCollected = opacityCollected * (1.0 - alpha) + alpha + 1e-6;
					}
#endif

					REAL opacity = (-1.0 + 1.0 / opacityCollected) * step;
					if (opacity > 1.0) opacity = 1.0;

					REAL4 lightColor = 0.0;

#ifdef USE_SUBSURFACE_SCATTERING
					if (shaderInputData.material->subsurfaceScattering)
					{
#ifdef AUX_LIGHTS
						input2.invertMode = false;
						int numberOfLights = renderData->numberOfLights;
						for (int i = 0; i < numberOfLights; i++)
						{
							__global sLightCl *light = &renderData->lights[i];
							if (light->enabled)
							{
								REAL distanceLight = 0.0;

								REAL3 lightVectorTemp =
									CalculateLightVector(light, input2.point, input2.delta, consts->params.resolution,
										consts->params.viewDistanceMax, &distanceLight, &input2.randomSeed);

								REAL intensity = 0.0;
								if (light->type == lightDirectional)
									intensity = light->intensity;
								else if (light->type == lightConical)
									intensity = 10.0 * light->intensity;
								else
									intensity = 100.0 * light->intensity
															/ LightDecay(distanceLight, light->decayFunction) / 6.0;

								REAL3 textureColor;
								intensity *= CalculateLightCone(
									light, renderData, input2.point, lightVectorTemp, &textureColor);

								REAL3 lightShadow = 1.0;
#ifdef SHADOWS
								if (consts->params.iterFogShadows && light->castShadows && intensity > 1e-3)
								{
									calcParam.distThresh = input2.distThresh;
									calcParam.detailSize = input2.distThresh;
									lightShadow = AuxShadow(consts, renderData, &input2, light, distanceLight,
										lightVectorTemp, &calcParam, light->intensity);
								}
#endif

								lightColor.xyz += lightShadow * light->color * intensity * textureColor;
							}
						}
#endif // AUX_LIGHTS
					}
					else
#endif // USE_SUBSURFACE_SCATTERING
					{
						lightColor = 1.0;
					}

					resultShader = opacity * lightColor * transparentColor + (1.0 - opacity) * resultShader;

					endStep = opacityCollected * CalcDistThresh(shaderInputData.point, consts);

					step = max((endStep - startStep) * (scan / depth) + startStep, max(depth / 1000.0, 1e-6));
#ifdef MONTE_CARLO
					step *= (1.0 - Random(1000, &shaderInputData.randomSeed) / 4000.0);
#endif

					scan += step;
				}
			}
			else
#endif
			{
				resultShader = VolumetricShader(consts, renderData, &shaderInputData, &calcParam,
					image2dBackground, resultShader, &opacityOut);
			}

			recursionOut.point = point;
			recursionOut.rayMarchingOut = rayMarchingOut;
			recursionOut.objectColour = objectColour;
			recursionOut.resultShader = resultShader;
			recursionOut.found = rayMarchingOut.found;
			recursionOut.fogOpacity = opacityOut;
			recursionOut.normal = shaderInputData.normal;

			rayStack[rayIndex].out = recursionOut;

#if defined(USE_REFRACTION) || defined(USE_REFLECTANCE)
			if (rayIndex > 0)
			{
				if (rayStack[rayIndex].in.rayBranch == rayBranchReflection)
				{
#ifdef USE_REFLECTANCE
					rayStack[rayIndex - 1].reflectShader = resultShader;
#endif
				}
				else
				{
#ifdef USE_REFRACTION
					rayStack[rayIndex - 1].transparentShader = resultShader;
#endif
				}
				rayStack[rayIndex - 1].in.resultShader = resultShader;
				rayStack[rayIndex - 1].in.objectColour = objectColour;
			}
#endif

			rayIndex--;
		}
		// prepare final result
	} while (rayIndex >= 0);

	sRayRecursionOut out = rayStack[0].out;

	return out;
}
