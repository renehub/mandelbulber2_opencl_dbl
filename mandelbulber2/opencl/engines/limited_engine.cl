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
 * Fast kernel for rendering opencl with missing effects
 */

// defined to force recompilation of kernels on NVidia cards with new releases
#define MANDELBULBER_VERSION 2.35

int GetInteger(int byte, __global char *array)
{
	__global int *intPointer = (__global int *)&array[byte];
	return *intPointer;
}

//------------------ MAIN RENDER FUNCTION --------------------
kernel void fractal3D(__global sClPixel *out, __global char *inBuff,
	__constant sClInConstants *consts, image2d_t image2dBackground, __global uchar *perlinNoiseSeeds,
	int initRandomSeed)
{
	// get actual pixel
	const int imageX = get_global_id(0);
	const int imageY = get_global_id(1);
	const int cl_offsetX = get_global_offset(0);
	const int cl_offsetY = get_global_offset(1);
	const int buffIndex = (imageX - cl_offsetX) + (imageY - cl_offsetY) * get_global_size(0);

	// randomizing random seed
	int randomSeed = imageX + imageY * consts->params.imageWidth + initRandomSeed;
	for (int i = 0; i < 3; i++)
	{
		randomSeed = RandomInt(&randomSeed);
	}

	REAL2 screenPoint = (REAL2){convert_float(imageX), convert_float(imageY)};
	REAL width = convert_float(consts->params.imageWidth);
	REAL height = convert_float(consts->params.imageHeight);
	REAL resolution = 1.0 / height;

	//-------- decode data file ----------------
	// main offset for materials
	int materialsMainOffset = GetInteger(0, inBuff);
	int AOVectorsMainOffset = GetInteger(1 * sizeof(int), inBuff);
	int lightsMainOffset = GetInteger(2 * sizeof(int), inBuff);
	int primitivesMainOffset = GetInteger(3 * sizeof(int), inBuff);
	int objectsMainOffset = GetInteger(4 * sizeof(int), inBuff);
	int nodesMainOffset = GetInteger(5 * sizeof(int), inBuff);
	int hybridSequencesMainOffset = GetInteger(6 * sizeof(int), inBuff);

	//--- main material

#ifdef USE_SURFACE_GRADIENT
	int paletteSurfaceOffset;
	int paletteSurfaceLength;
#endif
#ifdef USE_SPECULAR_GRADIENT
	int paletteSpecularOffset;
	int paletteSpecularLength;
#endif
#ifdef USE_DIFFUSE_GRADIENT
	int paletteDiffuseOffset;
	int paletteDiffuseLength;
#endif
#ifdef USE_LUMINOSITY_GRADIENT
	int paletteLuminosityOffset;
	int paletteLuminosityLength;
#endif
#ifdef USE_ROUGHNESS_GRADIENT
	int paletteRoughnessOffset;
	int paletteRoughnessLength;
#endif
#ifdef USE_REFLECTANCE_GRADIENT
	int paletteReflectanceOffset;
	int paletteReflectanceLength;
#endif
#ifdef USE_TRANSPARENCY_GRADIENT
	int paletteTransparencyOffset;
	int paletteTransparencyLength;
#endif

	// number of materials
	int numberOfMaterials = GetInteger(materialsMainOffset, inBuff);

	// materials 1 offset:
	const int materialAddressOffset = materialsMainOffset + 2 * sizeof(int);
	int material0Offset = GetInteger(materialAddressOffset, inBuff);

	// material header
	int materialClOffset = GetInteger(material0Offset, inBuff);
	int paletteItemsOffset = GetInteger(material0Offset + sizeof(int), inBuff);

#ifdef USE_SURFACE_GRADIENT
	paletteSurfaceOffset = GetInteger(material0Offset + sizeof(int) * 2, inBuff);
	paletteSurfaceLength = GetInteger(material0Offset + sizeof(int) * 3, inBuff);
#endif
#ifdef USE_SPECULAR_GRADIENT
	paletteSpecularOffset = GetInteger(material0Offset + sizeof(int) * 4, inBuff);
	paletteSpecularLength = GetInteger(material0Offset + sizeof(int) * 5, inBuff);
#endif
#ifdef USE_DIFFUSE_GRADIENT
	paletteDiffuseOffset = GetInteger(material0Offset + sizeof(int) * 6, inBuff);
	paletteDiffuseLength = GetInteger(material0Offset + sizeof(int) * 7, inBuff);
#endif
#ifdef USE_LUMINOSITY_GRADIENT
	paletteLuminosityOffset = GetInteger(material0Offset + sizeof(int) * 8, inBuff);
	paletteLuminosityLength = GetInteger(material0Offset + sizeof(int) * 9, inBuff);
#endif
#ifdef USE_ROUGHNESS_GRADIENT
	paletteRoughnessOffset = GetInteger(material0Offset + sizeof(int) * 10, inBuff);
	paletteRoughnessLength = GetInteger(material0Offset + sizeof(int) * 11, inBuff);
#endif
#ifdef USE_REFLECTANCE_GRADIENT
	paletteReflectanceOffset = GetInteger(material0Offset + sizeof(int) * 12, inBuff);
	paletteReflectanceLength = GetInteger(material0Offset + sizeof(int) * 13, inBuff);
#endif
#ifdef USE_TRANSPARENCY_GRADIENT
	paletteTransparencyOffset = GetInteger(material0Offset + sizeof(int) * 14, inBuff);
	paletteTransparencyLength = GetInteger(material0Offset + sizeof(int) * 15, inBuff);
#endif

	// material data
	__global sMaterialCl *material = (__global sMaterialCl *)&inBuff[materialClOffset];

	// palette data
	__global float4 *palette = (__global float4 *)&inBuff[paletteItemsOffset];

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

	sRenderData renderData;
	renderData.viewVectorNotRotated = 0;
	renderData.material = material;
	renderData.palette = palette;
	renderData.AOVectors = AOVectors;
	renderData.lights = lights;
	renderData.numberOfLights = numberOfLights;
#ifdef USE_SURFACE_GRADIENT
	renderData.paletteSurfaceOffset = paletteSurfaceOffset;
	renderData.paletteSurfaceLength = paletteSurfaceLength;
#endif
#ifdef USE_SPECULAR_GRADIENT
	renderData.paletteSpecularOffset = paletteSpecularOffset;
	renderData.paletteSpecularLength = paletteSpecularLength;
#endif
#ifdef USE_DIFFUSE_GRADIENT
	renderData.paletteDiffuseOffset = paletteDiffuseOffset;
	renderData.paletteDiffuseLength = paletteDiffuseLength;
#endif
#ifdef USE_LUMINOSITY_GRADIENT
	renderData.paletteLuminosityOffset = paletteLuminosityOffset;
	renderData.paletteLuminosityLength = paletteLuminosityLength;
#endif
#ifdef USE_ROUGHNESS_GRADIENT
	renderData.paletteRoughnessOffset = paletteRoughnessOffset;
	renderData.paletteRoughnessLength = paletteRoughnessLength;
#endif
#ifdef USE_REFLECTANCE_GRADIENT
	renderData.paletteReflectanceOffset = paletteReflectanceOffset;
	renderData.paletteReflectanceLength = paletteReflectanceLength;
#endif
#ifdef USE_TRANSPARENCY_GRADIENT
	renderData.paletteTransparencyOffset = paletteTransparencyOffset;
	renderData.paletteTransparencyLength = paletteTransparencyLength;
#endif
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

	sClPixel pixel;

#ifdef STEREO_REYCYAN
	REAL3 pixelLeftColor = 0.0;
	REAL3 pixelRightColor = 0.0;
	for (int eye = 0; eye < 2; eye++)
	{
#endif

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

		REAL3 viewVectorNotRotated = CalculateViewVector(normalizedScreenPoint, consts->params.fov);
		REAL3 viewVector = Matrix33MulFloat3(rot, viewVectorNotRotated);

#ifdef MONTE_CARLO_DOF
		MonteCarloDOF(&start, &viewVector, consts, rot, &randomSeed);
#endif

#ifdef STEREOSCOPIC
#ifndef PERSP_FISH_EYE_CUT

#ifdef PERSP_EQUIRECTANGULAR // reduce of stereo effect on poles
		REAL stereoIntensity = 1.0 - pow(normalizedScreenPoint.y * 2.0, 10.0);
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
		REAL opacityOut = 0.0;
		REAL3 surfaceColor = 0.0;
		REAL3 iridescence = 0.0;

		bool found = false;
		int count = 0;

		REAL3 point;
		REAL scan, distThresh, distance;

		scan = 1e-10;

#ifdef PERSP_FISH_EYE_CUT
		if (!hemisphereCut)
		{
#endif // PERSP_FISH_EYE_CUT

			sClCalcParams calcParam;
			calcParam.N = consts->params.N;
			calcParam.normalCalculationMode = false;
			calcParam.iterThreshMode = consts->params.iterThreshMode;
			distThresh = 1e-6;

			renderData.mRot = rot;
			renderData.mRotInv = rotInv;

			formulaOut outF;
			REAL step = 0.0;

			REAL searchAccuracy = 0.001 * consts->params.detailLevel;
			REAL searchLimit = 1.0 - searchAccuracy;

			// ray-marching
			for (count = 0; count < MAX_RAYMARCHING && scan < consts->params.viewDistanceMax; count++)
			{
				point = start + viewVector * scan;
				distThresh = CalcDistThresh(point, consts);
				calcParam.distThresh = distThresh;
				calcParam.detailSize = distThresh;
				outF = CalculateDistance(consts, point, &calcParam, &renderData);
				distance = outF.distance;

				// Apply per-object detailLevelMultiplier to distThresh dynamically
				if (outF.objectId >= 0 && outF.objectId < renderData.numberOfObjects)
				{
					distThresh *= renderData.objectsData[outF.objectId].detailLevelMultiplier;
				}

				if (distance < distThresh)
				{
					found = true;
					break;
				}

#ifdef INTERIOR_MODE
				step = (distance - 0.8 * distThresh) * consts->params.DEFactor;
#else
		step = (distance - 0.5 * distThresh) * consts->params.DEFactor;
#endif

				// No random step jitter; see the comment in ray_recursion.cl.

#ifdef ADVANCED_QUALITY
				step = clamp(step, consts->params.absMinMarchingStep, consts->params.absMaxMarchingStep);

				if (distThresh > consts->params.absMinMarchingStep)
					step = clamp(step, consts->params.relMinMarchingStep * distThresh,
						consts->params.relMaxMarchingStep * distThresh);
#endif

				scan += step / length(viewVector);
			}

			point = start + viewVector * scan;

			// final binary searching
			if (found)
			{
				step *= 0.5;
				for (int i = 0; i < 30; i++)
				{
					if (distance < distThresh && distance > distThresh * searchLimit)
					{
						break;
					}
					else
					{
						if (distance > distThresh)
						{
							scan += step;
							point = start + viewVector * scan;
						}
						else if (distance < distThresh * searchLimit)
						{
							scan -= step;
							point = start + viewVector * scan;
						}
					}
					outF = CalculateDistance(consts, point, &calcParam, &renderData);
					distance = outF.distance;
					step *= 0.5;
				}
			}

			// shaders
			REAL3 color = 0.0;
			REAL alpha = 0.0;

			distThresh = CalcDistThresh(point, consts);

			sShaderInputDataCl shaderInputData;
			shaderInputData.point = point;
			shaderInputData.viewVector = viewVector;
			shaderInputData.viewVectorNotRotated = viewVectorNotRotated;
			shaderInputData.distThresh = distThresh;
			shaderInputData.lastDist = distance;
			shaderInputData.delta = calcParam.detailSize;
			shaderInputData.depth = scan;
			shaderInputData.invertMode = false;
			shaderInputData.material = material;
			shaderInputData.palette = palette;
#ifdef USE_SURFACE_GRADIENT
			shaderInputData.paletteSurfaceOffset = renderData.paletteSurfaceOffset;
			shaderInputData.paletteSurfaceLength = renderData.paletteSurfaceLength;
#endif
#ifdef USE_SPECULAR_GRADIENT
			shaderInputData.paletteSpecularOffset = renderData.paletteSpecularOffset;
			shaderInputData.paletteSpecularLength = renderData.paletteSpecularLength;
#endif
#ifdef USE_DIFFUSE_GRADIENT
			shaderInputData.paletteDiffuseOffset = renderData.paletteDiffuseOffset;
			shaderInputData.paletteDiffuseLength = renderData.paletteDiffuseLength;
#endif
#ifdef USE_LUMINOSITY_GRADIENT
			shaderInputData.paletteLuminosityOffset = renderData.paletteLuminosityOffset;
			shaderInputData.paletteLuminosityLength = renderData.paletteLuminosityLength;
#endif
#ifdef USE_ROUGHNESS_GRADIENT
			shaderInputData.paletteRoughnessOffset = renderData.paletteRoughnessOffset;
			shaderInputData.paletteRoughnessLength = renderData.paletteRoughnessLength;
#endif
#ifdef USE_REFLECTANCE_GRADIENT
			shaderInputData.paletteReflectanceOffset = renderData.paletteReflectanceOffset;
			shaderInputData.paletteReflectanceLength = renderData.paletteReflectanceLength;
#endif
#ifdef USE_TRANSPARENCY_GRADIENT
			shaderInputData.paletteTransparencyOffset = renderData.paletteTransparencyOffset;
			shaderInputData.paletteTransparencyLength = renderData.paletteTransparencyLength;
#endif
			shaderInputData.stepCount = count;
			shaderInputData.randomSeed = randomSeed;

			REAL3 normal =
				NormalVector(consts, &renderData, point, distance, distThresh, false, &calcParam);
			shaderInputData.normal = normal;

			REAL3 specular = 0.0;

			sClGradientsCollection gradients;

			if (found)
			{
				REAL3 shadowOutDummy;
				REAL3 outLuminosityEmissive;
				color = ObjectShader(consts, &renderData, &shaderInputData, &calcParam, &surfaceColor,
					&specular, &iridescence, &shadowOutDummy, &outLuminosityEmissive, &alpha, &gradients);
			}
			else
			{
				color = BackgroundShader(consts, &renderData, image2dBackground, &shaderInputData);
				scan = 1e20;
				alpha = 0.0;
			}

#ifdef GLOW
			// glow init
			REAL glow = count * consts->params.glowIntensity / 512.0 * consts->params.DEFactor;
			REAL glowN = 1.0 - glow;
			if (glowN < 0.0) glowN = 0.0;

			REAL3 glowColor;

			glowColor = (glowN * TO_REAL3(consts->params.glowColor1)
									 + TO_REAL3(consts->params.glowColor2) * glow);

			glow *= 0.7;
			REAL glowOpacity = 1.0 * glow;
			if (glowOpacity > 1.0) glowOpacity = 1.0;
			color = glow * glowColor + (1.0 - glowOpacity) * color;
			alpha += glowOpacity;
#endif // GLOW

			color4 = (REAL4){color.s0, color.s1, color.s2, alpha};

#ifdef PERSP_FISH_EYE_CUT
		}
#endif // PERSP_FISH_EYE_CUT

#ifdef STEREO_REYCYAN
		if (eye == 0)
		{
			pixelLeftColor.s0 = color4.s0;
			pixelLeftColor.s1 = color4.s1;
			pixelLeftColor.s2 = color4.s2;
		}
		else
		{
			pixelRightColor.s0 = color4.s0;
			pixelRightColor.s1 = color4.s1;
			pixelRightColor.s2 = color4.s2;

			pixel.image.s0 = pixelRightColor.s0;
			pixel.image.s1 = pixelLeftColor.s1;
			pixel.image.s2 = pixelLeftColor.s2;
			pixel.zBuffer = scan;
			pixel.color = convert_uchar3(objectColour * 256.0);
			pixel.opacity = opacityOut * 65535;
			pixel.alpha = color4.s3 * 65535;

			out[buffIndex] = pixel;
		}
	} // next exe

#else	 // no STEREO_REYCYAN

	pixel.image = convert_float3(color4.xyz);
	pixel.zBuffer = scan;
	pixel.color = convert_uchar3(surfaceColor * 256.0);
	pixel.opacity = opacityOut * 65535;
	pixel.alpha = color4.s3 * 65535;

	out[buffIndex] = pixel;
#endif // STEREO_REYCYAN
}
