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
	__constant sClInConstants *consts, int initRandomSeed)
{
	// get actual pixel
	// get actual pixel
	const int imageX = get_global_id(0);
	const int imageY = get_global_id(1);
	const int cl_offsetX = get_global_offset(0);
	const int cl_offsetY = get_global_offset(1);
	const int buffIndex = (imageX - cl_offsetX) + (imageY - cl_offsetY) * get_global_size(0);

	REAL2 screenPoint = (REAL2){convert_float(imageX), convert_float(imageY)};
	REAL width = convert_float(consts->params.imageWidth);
	REAL height = convert_float(consts->params.imageHeight);
	REAL resolution = 1.0 / height;

	//-------- decode data file ----------------
	int primitivesMainOffset = GetInteger(3 * sizeof(int), inBuff);
	int objectsMainOffset = GetInteger(4 * sizeof(int), inBuff);
	int nodesMainOffset = GetInteger(5 * sizeof(int), inBuff);
	int hybridSequencesMainOffset = GetInteger(6 * sizeof(int), inBuff);

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

	//	if (imageX == 0 && imageY == 0) // print only for first pixel to avoid flooding the output)
	//	{
	//		for (int i = 0; i < numberOfNodes; i++)
	//		{
	//			sNodeDataForRenderingCl node = nodesData[i];
	//
	//			//		typedef struct
	//			//		{
	//			//			cl_int id;
	//			//			enumNodeTypeCl type;
	//			//			cl_int parentId;
	//			//			cl_int userObjectId;
	//			//			cl_int internalObjectId;
	//			//			cl_int primitiveIdx;
	//			//			cl_int level;
	//			//			cl_int hybridSequenceIndex;
	//			//			REAL3 repeat;
	//			//			REAL scale;
	//			//			REAL absScale;
	//			//			cl_int material;
	//			//			matrix33 rotationMatrix;
	//			//			matrix44 inverseTransformMatrix;
	//			//		} sNodeDataForRenderingCl;
	//
	//			printf(
	//				"Node %d: id=%d, type=%d, parentId=%d, userObjectId=%d, internalObjectId=%d, "
	//				"primitiveIdx=%d, level=%d, hybridSequenceIndex=%d, repeat=(%f,%f,%f), scale=%f, "
	//				"absScale=%f, material=%d\n",
	//				i, node.id, node.type, node.parentId, node.userObjectId, node.internalObjectId,
	//				node.primitiveIdx, node.level, node.hybridSequenceIndex, node.repeat.x, node.repeat.y,
	//				node.repeat.z, node.scale, node.absScale, node.material);
	//
	//			printf("Node %d rotation matrix: m1=(%f,%f,%f), m2=(%f,%f,%f), m3=(%f,%f,%f)\n", i,
	//				node.rotationMatrix.m1.x, node.rotationMatrix.m1.y, node.rotationMatrix.m1.z,
	//				node.rotationMatrix.m2.x, node.rotationMatrix.m2.y, node.rotationMatrix.m2.z,
	//				node.rotationMatrix.m3.x, node.rotationMatrix.m3.y, node.rotationMatrix.m3.z);
	//
	//			printf(
	//				"Node %d inverse transform matrix: m1=(%f,%f,%f,%f), m2=(%f,%f,%f,%f), m3=(%f,%f,%f,%f),
	//" 				"m4=(%f,%f,%f,%f)\n", 				i, node.worldToLocalMatrix.r1.x,
	// node.worldToLocalMatrix.r1.y, 				node.worldToLocalMatrix.r1.z,
	// node.worldToLocalMatrix.r1.w, 				node.worldToLocalMatrix.r2.x,
	// node.worldToLocalMatrix.r2.y, 				node.worldToLocalMatrix.r2.z,
	// node.worldToLocalMatrix.r2.w, 				node.worldToLocalMatrix.r3.x,
	// node.worldToLocalMatrix.r3.y, 				node.worldToLocalMatrix.r3.z,
	// node.worldToLocalMatrix.r3.w, 				node.worldToLocalMatrix.r4.x,
	// node.worldToLocalMatrix.r4.y, 				node.worldToLocalMatrix.r4.z,
	// node.worldToLocalMatrix.r4.w);
	//		}
	//	}

	//	printf("constant_multiplier %f %f %f", consts->fractal[1].constantMultiplier.x,
	//		consts->fractal[1].constantMultiplier.y, consts->fractal[1].constantMultiplier.z);

	//--- Hybrid Sequences

	int numberOfHybridSequences = GetInteger(hybridSequencesMainOffset, inBuff);
	int hybridSequencesArrayOffset = GetInteger(hybridSequencesMainOffset + 1 * sizeof(int), inBuff);

	__global sHybridSequenceCl *__attribute__((aligned(16))) hybridSequences =
		(__global sHybridSequenceCl *)&inBuff[hybridSequencesArrayOffset];

	//--- Fractals ---

	int fractalsMainOffset = GetInteger(7 * sizeof(int), inBuff);
	int numberOfFractals = GetInteger(fractalsMainOffset, inBuff);
	int fractalsArrayOffset = GetInteger(fractalsMainOffset + 1 * sizeof(int), inBuff);
	__global sFractalCl *fractals = (__global sFractalCl *)&inBuff[fractalsArrayOffset];

	//--------- end of data file ----------------------------------

	sRenderData renderData;
	renderData.viewVectorNotRotated = 0;
	renderData.material = 0;
	renderData.palette = 0;
	renderData.AOVectors = 0;
	renderData.lights = 0;
	renderData.numberOfLights = 0;
	renderData.AOVectorsCount = 0;
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
	renderData.fractals = fractals;
	renderData.numberOfFractals = numberOfFractals;

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

		REAL lightAlpha = -45.0 / 180.0 * M_PI_F;
		REAL lightBeta = 45.0 / 180.0 * M_PI_F;
		REAL3 lightVector = (REAL3){cos(lightAlpha - 0.5 * M_PI_F) * cos(lightBeta),
			sin(lightAlpha - 0.5 * M_PI_F) * cos(lightBeta), sin(lightBeta)};
		lightVector = Matrix33MulFloat3(rot, lightVector);

		rot = RotateZ(rot, -consts->params.sweetSpotHAngle);
		rot = RotateX(rot, consts->params.sweetSpotVAngle);

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

		REAL3 viewVectorNotRotated = CalculateViewVector(normalizedScreenPoint, consts->params.fov);
		REAL3 viewVector = Matrix33MulFloat3(rot, viewVectorNotRotated);

#ifdef STEREOSCOPIC
#ifndef PERSP_FISH_EYE_CUT

#ifdef PERSP_EQUIRECTANGULAR // reduce of stereo effect on poles
		REAL stereoIntensity = 1.0 - pow(normalizedScreenPoint.y * 2.0, 10.0);
#else
		REAL stereoIntensity = 1.0;
#endif

		start = StereoCalcEyePosition(start, viewVector, consts->params.topVector,
			consts->params.stereoEyeDistance * stereoIntensity, eye, consts->params.stereoSwapEyes);

		matrix33 rotInv = TransposeMatrix(rot);
		StereoViewVectorCorrection(consts->params.stereoInfiniteCorrection * stereoIntensity, &rot,
			&rotInv, eye, consts->params.stereoSwapEyes, &viewVector);
#else // PERSP_FISH_EYE_CUT
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
#endif
#endif // STEREOSCOPIC

		bool found = false;
		int count;

		REAL3 point;
		REAL scan, distThresh, distance;

		scan = 1e-10;

		sClCalcParams calcParam;
		calcParam.N = consts->params.N;
		calcParam.normalCalculationMode = false;
		calcParam.iterThreshMode = consts->params.iterThreshMode;
		distThresh = 1e-6;

		formulaOut outF;
		REAL step = 0.0;

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

			if (distance < distThresh * 0.95)
			{
				found = true;
				break;
			}

			step = (distance - 0.5 * distThresh) * consts->params.DEFactor;

#ifdef ADVANCED_QUALITY
			step = clamp(step, consts->params.absMinMarchingStep, consts->params.absMaxMarchingStep);

			if (distThresh > consts->params.absMinMarchingStep)
				step = clamp(step, consts->params.relMinMarchingStep * distThresh,
					consts->params.relMaxMarchingStep * distThresh);
#endif

			scan += step / length(viewVector);
		}

		// final binary searching
		if (found)
		{
			step *= 0.5;
			for (int i = 0; i < 5; i++)
			{
				if (distance < distThresh && distance > distThresh * 0.95)
				{
					break;
				}
				else
				{
					if (distance > distThresh)
					{
						point += viewVector * step;
					}
					else if (distance < distThresh * 0.95)
					{
						point -= viewVector * step;
					}
				}
				outF = CalculateDistance(consts, point, &calcParam, &renderData);
				distance = outF.distance;
				step *= 0.5;
			}
		}
		else
		{
			scan = 1e20;
		}

		REAL3 colour = 0.7;
		REAL alpha = 0.0;
		REAL3 surfaceColour = 1.0;
		if (found)
		{
			distThresh = CalcDistThresh(point, consts);

			REAL3 normal =
				NormalVector(consts, &renderData, point, distance, distThresh, false, &calcParam);

			REAL shade = dot(lightVector, normal);
			if (shade < 0.0) shade = 0.0;

			REAL3 halfVector = lightVector - viewVector;
			halfVector = fast_normalize(halfVector);
			REAL specular = dot(normal, halfVector);
			if (specular < 0.0) specular = 0.0;
			specular = pown(specular, 30.0);
			if (specular > 15.0) specular = 15.0;

			colour = colour * (shade + specular);
			alpha = 1.0;
		}
		else
		{
#ifdef STEREOSCOPIC
			REAL grid = 0.5
									 + 0.5 * sin(10.0 * sin(atan2(viewVector.y, viewVector.x) * 10.0))
											 * sin(10.0 * sin(atan2(viewVector.z, length(viewVector.xy)) * 10.0));
			grid *= grid;
			colour = grid;
#else	 // not STEREOSCOPIC
		colour = (REAL3){0.0, 0.0, screenPoint.y / height};
		alpha = 0.0;
#endif // STEREOSCOPIC
		}

		REAL glow = count / 500.0 * consts->params.DEFactor;

#ifdef STEREO_REYCYAN
		if (eye == 0)
		{
			pixelLeftColor.s0 = colour.s2 + glow;
			pixelLeftColor.s1 = colour.s2 + glow;
			pixelLeftColor.s2 = colour.s2;
		}
		else
		{
			pixelRightColor.s0 = colour.s2 + glow;
			pixelRightColor.s1 = colour.s2 + glow;
			pixelRightColor.s2 = colour.s2 + glow;

			sClPixel pixel;
			pixel.image.s0 = pixelRightColor.s0;
			pixel.image.s1 = pixelLeftColor.s1;
			pixel.image.s2 = pixelLeftColor.s2;
			pixel.image.s3 = 0.0f;
			pixel.zBuffer = scan;
			pixel.color = 128;
			pixel.opacity = 0;
			pixel.alpha = alpha * 65535;

			out[buffIndex] = pixel;
		}
	} // next exe

#else	 // no STEREO_REYCYAN

	pixel.image.s0 = colour.s0 + glow;
	pixel.image.s1 = colour.s1 * glow * 10.0;
	pixel.image.s2 = colour.s2;
	pixel.image.s3 = 0.0f;
	pixel.zBuffer = scan;
	pixel.color = 128;
	pixel.opacity = 0;
	pixel.alpha = alpha * 65535;
	//printf("sizeof sClPixel: %d", sizeof(sClPixel));

	out[buffIndex] = pixel;
#endif // STEREO_REYCYAN
}
