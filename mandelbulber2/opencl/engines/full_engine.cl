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
 * Full kernel for rendering opencl with missing effects
 */

// defined to force recompilation of kernels on NVidia cards with new releases
#define MANDELBULBER_VERSION 2.35
int GetInteger(int byte, __global char *array)
{
	__global int *intPointer = (__global int *)&array[byte];
	return *intPointer;
}

//------------------ MAIN RENDER FUNCTION --------------------
kernel void fractal3D(__global sClPixel *out, __global char *inBuff, __global char *inTextureBuff,
	__constant sClInConstants *consts, image2d_t image2dBackground, __global uchar *perlinNoiseSeeds,
	int initRandomSeed, REAL2 antiAliasingOffset, cl_int sequenceSize, cl_int jobWidth,
	__global cl_int *inPixelSequence, cl_int jobHeight, cl_int use2D)
{
	// Pixel mapping: a 2D NDRange for unmasked tiles, otherwise the 1D pixel
	// sequence used by monte-carlo / masked rendering.
	int imageX, imageY, buffIndex;
	const int cl_offsetX = use2D ? get_global_offset(0)
															 : get_global_offset(0) % consts->params.imageWidth;
	const int cl_offsetY = use2D ? get_global_offset(1)
															 : get_global_offset(0) / consts->params.imageWidth;
	if (use2D)
	{
		const int localX = get_global_id(0) - get_global_offset(0);
		const int localY = get_global_id(1) - get_global_offset(1);
		if (localX >= jobWidth || localY >= jobHeight) return;
		imageX = cl_offsetX + localX;
		imageY = cl_offsetY + localY;
		buffIndex = localX + localY * jobWidth;
	}
	else
	{
		const int sequenceIndex = get_global_id(0) - get_global_offset(0);
		if (sequenceIndex >= sequenceSize) return;
		imageX = inPixelSequence[sequenceIndex] % jobWidth + cl_offsetX;
		imageY = inPixelSequence[sequenceIndex] / jobWidth + cl_offsetY;
		buffIndex = (imageX - cl_offsetX) + (imageY - cl_offsetY) * jobWidth;
	}

	// randomizing random seed
	int randomSeed = imageX + imageY * consts->params.imageWidth + initRandomSeed;
	for (int i = 0; i < 10; i++)
	{
		randomSeed = RandomInt(&randomSeed);
	}

	REAL2 screenPoint = (REAL2){convert_float(imageX), convert_float(imageY)};
	REAL width = convert_float(consts->params.imageWidth);
	REAL height = convert_float(consts->params.imageHeight);
	REAL resolution = 1.0 / height;

	//-------- decode main data file ----------------
	// main offset for materials
	int materialsMainOffset = GetInteger(0, inBuff);
	int AOVectorsMainOffset = GetInteger(1 * sizeof(int), inBuff);
	int lightsMainOffset = GetInteger(2 * sizeof(int), inBuff);
	int primitivesMainOffset = GetInteger(3 * sizeof(int), inBuff);
	int objectsMainOffset = GetInteger(4 * sizeof(int), inBuff);
	int nodesMainOffset = GetInteger(5 * sizeof(int), inBuff);
	int hybridSequencesMainOffset = GetInteger(6 * sizeof(int), inBuff);

	//--- materials
	__global sMaterialCl *materials[MAT_ARRAY_SIZE];
	__global float4 *palettes[MAT_ARRAY_SIZE];

#ifdef USE_SURFACE_GRADIENT
	int paletteSurfaceOffsets[MAT_ARRAY_SIZE];
	int paletteSurfaceLengths[MAT_ARRAY_SIZE];
#endif
#ifdef USE_SPECULAR_GRADIENT
	int paletteSpecularOffsets[MAT_ARRAY_SIZE];
	int paletteSpecularLengths[MAT_ARRAY_SIZE];
#endif
#ifdef USE_DIFFUSE_GRADIENT
	int paletteDiffuseOffsets[MAT_ARRAY_SIZE];
	int paletteDiffuseLengths[MAT_ARRAY_SIZE];
#endif
#ifdef USE_LUMINOSITY_GRADIENT
	int paletteLuminosityOffsets[MAT_ARRAY_SIZE];
	int paletteLuminosityLengths[MAT_ARRAY_SIZE];
#endif
#ifdef USE_ROUGHNESS_GRADIENT
	int paletteRoughnessOffsets[MAT_ARRAY_SIZE];
	int paletteRoughnessLengths[MAT_ARRAY_SIZE];
#endif
#ifdef USE_REFLECTANCE_GRADIENT
	int paletteReflectanceOffsets[MAT_ARRAY_SIZE];
	int paletteReflectanceLengths[MAT_ARRAY_SIZE];
#endif
#ifdef USE_TRANSPARENCY_GRADIENT
	int paletteTransparencyOffsets[MAT_ARRAY_SIZE];
	int paletteTransparencyLengths[MAT_ARRAY_SIZE];
#endif

	// number of materials
	int numberOfMaterials = GetInteger(materialsMainOffset, inBuff);

	for (int i = 0; i < MAT_ARRAY_SIZE; i++)
	{
		// material offset:
		const int materialAddressOffset = materialsMainOffset + (i + 1) * sizeof(int);
		int materialOffset = GetInteger(materialAddressOffset, inBuff);

		// material header
		int materialClOffset = GetInteger(materialOffset, inBuff);
		int paletteItemsOffset = GetInteger(materialOffset + sizeof(int), inBuff);

#ifdef USE_SURFACE_GRADIENT
		paletteSurfaceOffsets[i] = GetInteger(materialOffset + sizeof(int) * 2, inBuff);
		paletteSurfaceLengths[i] = GetInteger(materialOffset + sizeof(int) * 3, inBuff);
#endif
#ifdef USE_SPECULAR_GRADIENT
		paletteSpecularOffsets[i] = GetInteger(materialOffset + sizeof(int) * 4, inBuff);
		paletteSpecularLengths[i] = GetInteger(materialOffset + sizeof(int) * 5, inBuff);
#endif
#ifdef USE_DIFFUSE_GRADIENT
		paletteDiffuseOffsets[i] = GetInteger(materialOffset + sizeof(int) * 6, inBuff);
		paletteDiffuseLengths[i] = GetInteger(materialOffset + sizeof(int) * 7, inBuff);
#endif
#ifdef USE_LUMINOSITY_GRADIENT
		paletteLuminosityOffsets[i] = GetInteger(materialOffset + sizeof(int) * 8, inBuff);
		paletteLuminosityLengths[i] = GetInteger(materialOffset + sizeof(int) * 9, inBuff);
#endif
#ifdef USE_ROUGHNESS_GRADIENT
		paletteRoughnessOffsets[i] = GetInteger(materialOffset + sizeof(int) * 10, inBuff);
		paletteRoughnessLengths[i] = GetInteger(materialOffset + sizeof(int) * 11, inBuff);
#endif
#ifdef USE_REFLECTANCE_GRADIENT
		paletteReflectanceOffsets[i] = GetInteger(materialOffset + sizeof(int) * 12, inBuff);
		paletteReflectanceLengths[i] = GetInteger(materialOffset + sizeof(int) * 13, inBuff);
#endif
#ifdef USE_TRANSPARENCY_GRADIENT
		paletteTransparencyOffsets[i] = GetInteger(materialOffset + sizeof(int) * 14, inBuff);
		paletteTransparencyLengths[i] = GetInteger(materialOffset + sizeof(int) * 15, inBuff);
#endif

		// material data
		__global sMaterialCl *materialTemp = (__global sMaterialCl *)&inBuff[materialClOffset];
		materials[i] = materialTemp;

		// palette data
		__global float4 *paletteTemp = (__global float4 *)&inBuff[paletteItemsOffset];
		palettes[i] = paletteTemp;
	}

	//--- AO vectors

	// AO vectors count
	int AOVectorsCount = GetInteger(AOVectorsMainOffset, inBuff);
	int AOVectorsOffset = GetInteger(AOVectorsMainOffset + 1 * sizeof(int), inBuff);

	__global sVectorsAroundCl *__attribute__((aligned(16))) AOVectors =
		(__global sVectorsAroundCl *)&inBuff[AOVectorsOffset];

	//--- Lights

	// AO vectors count
	int numberOfLights = GetInteger(lightsMainOffset, inBuff);
	int lightssOffset = GetInteger(lightsMainOffset + 1 * sizeof(int), inBuff);

	__global sLightCl *__attribute__((aligned(16))) lights =
		(__global sLightCl *)&inBuff[lightssOffset];

	//--- Primitives

	// primitives count
	int numberOfPrimitives = GetInteger(primitivesMainOffset, inBuff);
	int primitivesGlobalDataOffset = GetInteger(primitivesMainOffset + 1 * sizeof(int), inBuff);
	int primitivesOffset = GetInteger(primitivesMainOffset + 2 * sizeof(int), inBuff);

	// global position of primitives
	__global sPrimitiveGlobalDataCl *primitivesGlobalData =
		(__global sPrimitiveGlobalDataCl *)&inBuff[primitivesGlobalDataOffset];

	// data for primitives
	__global sPrimitiveCl *__attribute__((aligned(16))) primitives =
		(__global sPrimitiveCl *)&inBuff[primitivesOffset];

	//--- Objects

	int numberOfObjects = GetInteger(objectsMainOffset, inBuff);
	int objectsOffset = GetInteger(objectsMainOffset + 1 * sizeof(int), inBuff);

	__global sObjectDataCl *__attribute__((aligned(16))) objectsData =
		(__global sObjectDataCl *)&inBuff[objectsOffset];

	//--- Nodes

	int numberOfNodes = GetInteger(nodesMainOffset, inBuff);
	int nodesOffset = GetInteger(nodesMainOffset + 1 * sizeof(int), inBuff);

	__global sNodeDataForRenderingCl *__attribute__((aligned(16))) nodesData =
		(__global sNodeDataForRenderingCl *)&inBuff[nodesOffset];

	//--- Hybrid Sequences

	int numberOfHybridSequences = GetInteger(hybridSequencesMainOffset, inBuff);
	int hybridSequencesArrayOffset = GetInteger(hybridSequencesMainOffset + 1 * sizeof(int), inBuff);

	__global sHybridSequenceCl *__attribute__((aligned(16))) hybridSequences =
		(__global sHybridSequenceCl *)&inBuff[hybridSequencesArrayOffset];

	//--- Fractals ---

	int fractalsMainOffset = GetInteger(7 * sizeof(int), inBuff);
	int numberOfFractals = GetInteger(fractalsMainOffset, inBuff);
	int fractalsArrayOffset = GetInteger(fractalsMainOffset + 1 * sizeof(int), inBuff);

	//--------- end of data file ----------------------------------

	sClPixel pixel;

	// initialize render statistics payload (kept zeroed when a path skips
	// ray marching, e.g. the fish-eye hemisphere cut)
	pixel.statsItersSum = 0;
	pixel.statsDeCalls = 0;
	pixel.statsStepCount = 0;
	pixel.statsHitIters = 0;
	pixel.statsRaymarchings = 0;
	pixel.statsMissedDE = 0;
	pixel.statsFlags = 0;
	pixel.statsPad = 0;

	// per-pixel render statistics accumulator; declared outside the stereo eye
	// loop so it sums the work of both eyes (histogram samples keep the values
	// of the last traced eye - acceptable approximation for diagnostics)
	sPixelStatsCl pixelStats;
	pixelStats.itersSum = 0;
	pixelStats.deCalls = 0;
	pixelStats.stepCount = 0;
	pixelStats.hitIters = 0;
	pixelStats.raymarchings = 0;
	pixelStats.missedDE = 0;
	pixelStats.hasHit = false;

#ifdef STEREO_REYCYAN
	REAL3 pixelLeftColor = 0.0;
	REAL3 pixelRightColor = 0.0;

#ifdef STEREO_FORCEDEYELEFT
	int eye = 0;
#elif STEREO_FORCEDEYERIGHT
	int eye = 1;
#else
	for (int eye = 0; eye < 2; eye++)
#endif
	{
#endif

		sRenderData renderData;
		renderData.viewVectorNotRotated = 0;
		renderData.materials = materials;
		renderData.palettes = palettes;
		renderData.AOVectors = AOVectors;
		renderData.lights = lights;
#ifdef USE_SURFACE_GRADIENT
		renderData.paletteSurfaceOffsets = paletteSurfaceOffsets;
		renderData.paletteSurfaceLengths = paletteSurfaceLengths;
#endif
#ifdef USE_SPECULAR_GRADIENT
		renderData.paletteSpecularOffsets = paletteSpecularOffsets;
		renderData.paletteSpecularLengths = paletteSpecularLengths;
#endif
#ifdef USE_DIFFUSE_GRADIENT
		renderData.paletteDiffuseOffsets = paletteDiffuseOffsets;
		renderData.paletteDiffuseLengths = paletteDiffuseLengths;
#endif
#ifdef USE_LUMINOSITY_GRADIENT
		renderData.paletteLuminosityOffsets = paletteLuminosityOffsets;
		renderData.paletteLuminosityLengths = paletteLuminosityLengths;
#endif
#ifdef USE_ROUGHNESS_GRADIENT
		renderData.paletteRoughnessOffsets = paletteRoughnessOffsets;
		renderData.paletteRoughnessLengths = paletteRoughnessLengths;
#endif
#ifdef USE_REFLECTANCE_GRADIENT
		renderData.paletteReflectanceOffsets = paletteReflectanceOffsets;
		renderData.paletteReflectanceLengths = paletteReflectanceLengths;
#endif
#ifdef USE_TRANSPARENCY_GRADIENT
		renderData.paletteTransparencyOffsets = paletteTransparencyOffsets;
		renderData.paletteTransparencyLengths = paletteTransparencyLengths;
#endif
		renderData.numberOfLights = numberOfLights;
		renderData.AOVectorsCount = AOVectorsCount;
		renderData.reflectionsMax = 0;
		renderData.primitives = primitives;
		renderData.numberOfPrimitives = numberOfPrimitives;
		renderData.primitivesGlobalData = primitivesGlobalData;
		renderData.objectsData = objectsData;
		renderData.nodesData = nodesData;
		renderData.numberOfNodes = numberOfNodes;
		renderData.numberOfObjects = numberOfObjects;
		renderData.dynamicData = inBuff;
		renderData.hybridSequences = hybridSequences;
		renderData.numberOfHybridSequences = numberOfHybridSequences;
		renderData.numberOfFractals = numberOfFractals;
		renderData.fractals = (__global sFractalCl *)&inBuff[fractalsArrayOffset];

#if defined(CLOUDS) || defined(USE_PERLIN_NOISE)
		renderData.perlinNoiseSeeds = perlinNoiseSeeds;
#endif

//------------------ decode texture data -----------
#ifdef USE_TEXTURES
		__global uchar4 *textures[NUMBER_OF_TEXTURES];
		int2 textureSizes[NUMBER_OF_TEXTURES];

		for (int i = 0; i < NUMBER_OF_TEXTURES; i++)
		{
			int textureMainOffset = GetInteger(i * sizeof(int), inTextureBuff);
			int textureDataOffset = GetInteger(textureMainOffset + 0 * sizeof(int), inTextureBuff);
			int textureWidth = GetInteger(textureMainOffset + 1 * sizeof(int), inTextureBuff);
			int textureHeight = GetInteger(textureMainOffset + 2 * sizeof(int), inTextureBuff);
			textureSizes[i] = (int2){textureWidth, textureHeight};

			__global uchar4 *texture = (__global uchar4 *)&inTextureBuff[textureDataOffset];
			textures[i] = texture;
		}
		renderData.textures = textures;
		renderData.textureSizes = textureSizes;
#endif
		//------------------ end of texture data -----------

		// auxiliary vectors
		const REAL3 one = (REAL3){1.0, 0.0, 0.0};
		const REAL3 ones = 1.0;

		// main rotation matrix
		matrix33 rot;
		rot.m1 = (REAL3){1.0, 0.0, 0.0};
		rot.m2 = (REAL3){0.0, 1.0, 0.0};
		rot.m3 = (REAL3){0.0, 0.0, 1.0};

		rot = RotateZ(rot, consts->params.viewAngle.x);
		rot = RotateX(rot, consts->params.viewAngle.y);
		rot = RotateY(rot, consts->params.viewAngle.z);

		// sweet spot rotation
		rot = RotateZ(rot, -consts->params.sweetSpotHAngle);
		rot = RotateX(rot, consts->params.sweetSpotVAngle);

		matrix33 rotInv = TransposeMatrix(rot);
		renderData.mRot = rot;
		renderData.mRotInv = rotInv;

		// starting point for ray-marching
		REAL3 start = consts->params.camera;

// view vector
#ifdef PERSP_EQUIRECTANGULAR
		REAL aspectRatio = 2.0;
#else
	REAL aspectRatio = width / height;
#endif

#ifdef STEREOSCOPIC
#ifndef STEREO_REYCYAN
#ifndef PERSP_EQUIRECTANGULAR
		aspectRatio = StereoModifyAspectRatio(aspectRatio);
#endif
#endif
#endif

		REAL2 normalizedScreenPoint;
		normalizedScreenPoint.x = (screenPoint.x / width - 0.5);
		normalizedScreenPoint.y = -(screenPoint.y / height - 0.5);
		if (consts->params.legacyCoordinateSystem) normalizedScreenPoint.y *= -1.0;

#ifdef STEREOSCOPIC
#ifndef STEREO_REYCYAN
		int eye = StereoWhichEye(normalizedScreenPoint);
		normalizedScreenPoint = StereoModifyImagePoint(normalizedScreenPoint);
#endif
#endif

		normalizedScreenPoint.x *= aspectRatio;

#ifdef MONTE_CARLO_ANTI_ALIASING
		normalizedScreenPoint.x +=
			(Random(1000.0, &randomSeed) / 1000.0 - 0.5) / width * aspectRatio;
		normalizedScreenPoint.y += (Random(1000.0, &randomSeed) / 1000.0 - 0.5) / height;
#endif

#ifdef ANTIALIASING
		normalizedScreenPoint.x += antiAliasingOffset.x / width * aspectRatio;
		normalizedScreenPoint.y += antiAliasingOffset.y / height;
#endif

		REAL3 viewVectorNotRotated = CalculateViewVector(normalizedScreenPoint, consts->params.fov);
		REAL3 viewVector = Matrix33MulFloat3(rot, viewVectorNotRotated);

#ifdef MONTE_CARLO_DOF
		MonteCarloDOF(&start, &viewVector, consts, rot, &randomSeed);
#endif

#ifdef CHROMATIC_ABERRATION
		REAL hue = Random(3600, &randomSeed) / 10.0;
		renderData.hue = hue;
		REAL3 rgbFromHsv = TO_REAL3(Hsv2rgb(fmod(360.0 + hue - 60.0, 360.0), 1.0, 1.0)) * 2.0;
		REAL3 randVector =
			(REAL3){0.0, hue / 20000.0 * consts->params.DOFMonteCarloCACameraDispersion, 0.0};
		REAL3 randVectorRot = Matrix33MulFloat3(rot, randVector);
		viewVector -= randVectorRot;
		viewVector = normalize(viewVector);
#endif

#ifdef STEREOSCOPIC
#ifndef PERSP_FISH_EYE_CUT

#ifdef PERSP_EQUIRECTANGULAR // reduce of stereo effect on poles
		// x^10 by explicit multiplies: pow() is an exp2/log2 pair in double.
		REAL stereoTerm = normalizedScreenPoint.y * 2.0;
		REAL stereoTerm2 = stereoTerm * stereoTerm;
		REAL stereoTerm4 = stereoTerm2 * stereoTerm2;
		REAL stereoIntensity = 1.0 - stereoTerm4 * stereoTerm4 * stereoTerm2;
#else
		REAL stereoIntensity = 1.0;
#endif

		start = StereoCalcEyePosition(start, viewVector, consts->params.topVector,
			consts->params.stereoEyeDistance * stereoIntensity, eye, consts->params.stereoSwapEyes);

		StereoViewVectorCorrection(consts->params.stereoInfiniteCorrection * stereoIntensity, &rot,
			&rotInv, eye, consts->params.stereoSwapEyes, &viewVector);
#else	 // PERSP_FISH_EYE_CUT
		REAL3 eyePosition = 0.0;
		REAL3 sideVector = normalize(cross(viewVector, consts->params.topVector));
		REAL3 rightVector =
			normalize(cross(consts->params.target - consts->params.camera, consts->params.topVector));
		REAL eyeDistance = consts->params.stereoEyeDistance;
		if (consts->params.stereoSwapEyes) eyeDistance *= -1.0;

		if (eye == 0)
		{
			eyePosition = start + 0.5 * (rightVector * eyeDistance + sideVector * eyeDistance);
		}
		else
		{
			eyePosition = start - 0.5 * (rightVector * eyeDistance + sideVector * eyeDistance);
		}
		start = eyePosition;
#endif // PERSP_FISH_EYE_CUT
#endif // STEREOSCOPIC

#ifdef PERSP_FISH_EYE_CUT
		bool hemisphereCut = false;
		if (length(normalizedScreenPoint) > M_PI_F * 0.5 / consts->params.fov) hemisphereCut = true;
#endif

		REAL4 color4 = 0.0;
		REAL opacityOut;
		REAL3 surfaceColor = 0.0;

		REAL3 point;
		REAL depth = 0.0;

		int reflectionsMax = consts->params.reflectionsMax;
		if (!consts->params.raytracedReflections) reflectionsMax = 0;
		renderData.reflectionsMax = reflectionsMax;

		REAL4 resultShader = 0.0;
		REAL3 objectColour = 0.0;
		REAL3 normal = viewVector;
		REAL3 specularOut = 0.0;
		REAL3 shadowOut = 0.0;
		REAL3 globalIlluminationOut = 0.0;
		REAL3 worldPositionRGB = 0.0;

		REAL opacity = 0.0;

#ifdef PERSP_FISH_EYE_CUT
		if (!hemisphereCut)
		{
#endif // PERSP_FISH_EYE_CUT

			sRayRecursionIn recursionIn;

			sRayMarchingIn rayMarchingIn;
			rayMarchingIn.binaryEnable = true;
			rayMarchingIn.direction = normalize(viewVector);
			rayMarchingIn.maxScan = consts->params.viewDistanceMax;
			rayMarchingIn.minScan = 0.0;
			rayMarchingIn.start = start;
			rayMarchingIn.invertMode = false;
			recursionIn.rayMarchingIn = rayMarchingIn;
			recursionIn.calcInside = false;
			recursionIn.resultShader = resultShader;
			recursionIn.objectColour = objectColour;
			recursionIn.rayBranch = rayBranchReflection;

			sRayRecursionOut recursionOut =
				RayRecursion(recursionIn, &renderData, consts, image2dBackground, &randomSeed, &pixelStats);
			resultShader = recursionOut.resultShader;
			objectColour = recursionOut.objectColour;
			depth = recursionOut.rayMarchingOut.depth;
			if (!recursionOut.found) depth = 1e20;
			opacity = recursionOut.fogOpacity;
			normal = recursionOut.normal;
			shadowOut = recursionOut.outShadow;
			globalIlluminationOut = recursionOut.outGlobalIllumination;
			specularOut = recursionOut.specular;
			worldPositionRGB = recursionOut.rayMarchingOut.point;

			// copy the per-pixel render statistics into the output buffer payload
			pixel.statsItersSum = pixelStats.itersSum;
			pixel.statsDeCalls = pixelStats.deCalls;
			pixel.statsStepCount = pixelStats.stepCount;
			pixel.statsHitIters = pixelStats.hitIters;
			pixel.statsRaymarchings = pixelStats.raymarchings;
			pixel.statsMissedDE = pixelStats.missedDE;
			pixel.statsFlags = pixelStats.hasHit ? 1 : 0;

#ifdef PERSP_FISH_EYE_CUT
		}
#endif // PERSP_FISH_EYE_CUT

#ifdef STEREO_REYCYAN
#ifdef STEREO_FORCEDEYELEFT // if double ppass - left eye
		pixelLeftColor.s1 = resultShader.s1;
		pixelLeftColor.s2 = resultShader.s2;
#elif STEREO_FORCEDEYERIGHT // if double ppass - right eye
		pixelRightColor.s0 = resultShader.s0;
#else												// if not double pass (internal repeat loop)
		if (eye == 0)
		{
			pixelLeftColor.s0 = resultShader.s0;
			pixelLeftColor.s1 = resultShader.s1;
			pixelLeftColor.s2 = resultShader.s2;
		}
		else
#endif
		{
#if (!defined(STEREO_FORCEDEYELEFT) && !defined(STEREO_FORCEDEYERIGHT))
			pixelRightColor.s0 = resultShader.s0;
			pixelRightColor.s1 = resultShader.s1;
			pixelRightColor.s2 = resultShader.s2;
#endif

			pixel.image.s0 = pixelRightColor.s0;
			pixel.image.s1 = pixelLeftColor.s1;
			pixel.image.s2 = pixelLeftColor.s2;
			pixel.image.s3 = 0.0f;
			pixel.zBuffer = depth;
			pixel.color = convert_uchar3(objectColour * 256.0);
			pixel.opacity = opacity * 65535;
			pixel.alpha = resultShader.s3 * 65535;
			pixel.normalWorld = convert_float3(normalize(normal));

			out[buffIndex] = pixel;
		}
	} // next eye

#else // no STEREO_REYCYAN

#ifdef CHROMATIC_ABERRATION
	pixel.image = (float4)(convert_float3(resultShader.xyz * rgbFromHsv), 0.0f);
#else
	pixel.image = convert_float4(resultShader);
#endif

	pixel.zBuffer = depth;
	pixel.color = convert_uchar3(objectColour * 256.0);
	pixel.opacity = opacity * 65535;
	pixel.alpha = resultShader.s3 * 65535;
	REAL3 pixelNormalWorld = normalize(normal);
	pixel.normalWorld = convert_float3(pixelNormalWorld);

	// sClPixel is an ALIGN16 float-only struct. All double->float demotions
	// happen above; the final out[buffIndex] assignment is one aligned store.
#ifdef OPTIONAL_IMAGE_CHANNELS
	REAL3 pixelNormalRotated = Matrix33MulFloat3(rotInv, pixelNormalWorld);
	pixel.normal.s0 = (1.0 + pixelNormalRotated.x) / 2.0;
	pixel.normal.s1 = (1.0 + pixelNormalRotated.z) / 2.0;
	pixel.normal.s2 = (1.0 - pixelNormalRotated.y) / 2.0;
	pixel.specular = specularOut;
	pixel.shadows = shadowOut;
	pixel.globalIllumination = globalIlluminationOut;
	pixel.world = worldPositionRGB;
	pixel.diffuse = objectColour;
#endif

	out[buffIndex] = pixel;
#endif // STEREO_REYCYAN
}
