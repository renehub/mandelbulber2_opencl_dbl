/**
 * Mandelbulber v2, a 3D fractal generator       ,=#MKNmMMKmmßMNWy,
 *                                             ,B" ]L,,p%%%,,,§;, "K
 * Copyright (C) 2018-24 Mandelbulber Team     §R-==%w["'~5]m%=L.=~5N
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
 * calculation of MC Global Illumination effect
 */

#if defined(MONTE_CARLO_DOF_GLOBAL_ILLUMINATION) && defined(FULL_ENGINE)
REAL3 GlobalIlumination(__constant sClInConstants *consts, sRenderData *renderData,
	sShaderInputDataCl *input, sClCalcParams *calcParam, image2d_t image2dBackground,
	REAL3 objectColor, bool volumetricMode)
{
	REAL3 out = 0.0;
	sShaderInputDataCl inputCopy = *input;
	REAL3 objectColorTemp = objectColor;
	REAL totalOpacity = 0.0;

	bool finished = false;
	// GI depth is capped independently of reflectionsMax (which can be 1000).
	int maxDepth = (volumetricMode) ? 2 : min((int)consts->params.reflectionsMax, GI_MAX_DEPTH);

	REAL lastReflectance = 0.0;
	REAL3 lastReflectanceColor = 0.0;
	REAL3 lastDirection = 0.0;

	for (int rayDepth = 0; rayDepth < maxDepth; rayDepth++)
	{
		if (totalOpacity > 1.0) break;

		REAL3 reflectedDirection = inputCopy.normal;
		REAL randomX = (Random(20000, &calcParam->randomSeed) - 10000) / 10000.0;
		REAL randomY = (Random(20000, &calcParam->randomSeed) - 10000) / 10000.0;
		REAL randomZ = (Random(20000, &calcParam->randomSeed) - 10000) / 10000.0;
		REAL3 randomVector = (REAL3){randomX * 1.2, randomY * 1.2, randomZ * 1.2};

		REAL3 randomizedDirection;
		if (volumetricMode && rayDepth == 0)
		{
			randomizedDirection = normalize(randomVector);
		}
		else
		{
#if defined(USE_REFLECTANCE) && defined(MC_GI_USE_REFLECTANCE)
			if (lastReflectance > 0.0)
			{
				if (Random(1000, &calcParam->randomSeed) / 1000.0 < lastReflectance)
				{
					randomizedDirection =
						lastDirection - 2.0 * dot(lastDirection, inputCopy.normal) * inputCopy.normal;
				}
				else
				{
					randomizedDirection = normalize(reflectedDirection + randomVector);
				}
			}
			else
#endif
			{
				randomizedDirection = normalize(reflectedDirection + randomVector);
			}
		}
		inputCopy.viewVector = randomizedDirection;

		REAL dist = 0.0;
		bool found = false;
		int objectId = 0;

		REAL4 resultShader = 0.0;
		REAL3 newColor = objectColor;

		int giSteps = 0;
		for (REAL scan = inputCopy.distThresh; scan < consts->params.viewDistanceMax;
			scan += dist * consts->params.DEFactor)
		{
			// Hard budget: protects deep-zoom GI rays with a tiny DE.
			if (giSteps >= MAX_GI_STEPS) break;
			giSteps++;

			REAL3 point = inputCopy.point + scan * randomizedDirection;

			REAL distThresh = CalcDistThresh(point, consts);
			inputCopy.distThresh = distThresh;

			calcParam->distThresh = distThresh;
			formulaOut outF;
			outF = CalculateDistance(consts, point, calcParam, renderData);
			dist = outF.distance;
			objectId = outF.objectId;

			// Apply per-object detailLevelMultiplier to distThresh dynamically
			if (outF.objectId >= 0 && outF.objectId < renderData->numberOfObjects)
			{
				distThresh *= renderData->objectsData[outF.objectId].detailLevelMultiplier;
			}

			if (dist < distThresh)
			{
				if (scan < distThresh * 2.0)
				{
					return out;
				}
				inputCopy.point = point;
				inputCopy.sequenceIndex = outF.sequenceIndex;
				inputCopy.transformedPoint = outF.transformedPoint;
				inputCopy.hasTransformedPoint = outF.hasTransformedPoint;
				inputCopy.objectId = objectId;

				REAL3 normal = NormalVector(consts, renderData, inputCopy.point, inputCopy.lastDist,
					inputCopy.distThresh, inputCopy.invertMode, calcParam);
				inputCopy.normal = normal;
				inputCopy.depth = scan;

				found = true;
				break;
			}

			// No progress: a step much smaller than the local threshold would
			// otherwise burn the whole budget without reaching the surface.
			if (dist * consts->params.DEFactor < GI_NO_PROGRESS_EPSILON * distThresh) break;
		}

		if (found)
		{
			REAL3 objectColor;
			REAL3 specular;
			REAL3 iridescence;

			__global sObjectDataCl *objectData = &renderData->objectsData[inputCopy.objectId];
			inputCopy.material = renderData->materials[objectData->materialId];
			inputCopy.palette = renderData->palettes[objectData->materialId];

#ifdef USE_SURFACE_GRADIENT
			inputCopy.paletteSurfaceOffset = renderData->paletteSurfaceOffsets[objectData->materialId];
			inputCopy.paletteSurfaceLength = renderData->paletteSurfaceLengths[objectData->materialId];
#endif
#ifdef USE_SPECULAR_GRADIENT
			inputCopy.paletteSpecularOffset = renderData->paletteSpecularOffsets[objectData->materialId];
			inputCopy.paletteSpecularLength = renderData->paletteSpecularLengths[objectData->materialId];
#endif
#ifdef USE_DIFFUSE_GRADIENT
			inputCopy.paletteDiffuseOffset = renderData->paletteDiffuseOffsets[objectData->materialId];
			inputCopy.paletteDiffuseLength = renderData->paletteDiffuseLengths[objectData->materialId];
#endif
#ifdef USE_LUMINOSITY_GRADIENT
			inputCopy.paletteLuminosityOffset =
				renderData->paletteLuminosityOffsets[objectData->materialId];
			inputCopy.paletteLuminosityLength =
				renderData->paletteLuminosityLengths[objectData->materialId];
#endif
#ifdef USE_ROUGHNESS_GRADIENT
			inputCopy.paletteRoughnessOffset =
				renderData->paletteRoughnessOffsets[objectData->materialId];
			inputCopy.paletteRoughnessLength =
				renderData->paletteRoughnessLengths[objectData->materialId];
#endif
#ifdef USE_REFLECTANCE_GRADIENT
			inputCopy.paletteReflectanceOffset =
				renderData->paletteReflectanceOffsets[objectData->materialId];
			inputCopy.paletteReflectanceLength =
				renderData->paletteReflectanceLengths[objectData->materialId];
#endif
#ifdef USE_TRANSPARENCY_GRADIENT
			inputCopy.paletteTransparencyOffset =
				renderData->paletteTransparencyOffsets[objectData->materialId];
			inputCopy.paletteTransparencyLength =
				renderData->paletteTransparencyLengths[objectData->materialId];
#endif

#if USE_TEXTURES
#ifdef USE_COLOR_TEXTURE
			inputCopy.texColor = TO_CL_FLOAT3(TextureShader(consts, calcParam, &inputCopy, renderData, objectData,
				inputCopy.material->colorTextureIndex, 1.0));
#endif

#ifdef USE_DIFFUSION_TEXTURE
			inputCopy.texDiffuse = TO_CL_FLOAT3(TextureShader(consts, calcParam, &inputCopy, renderData, objectData,
				inputCopy.material->diffusionTextureIndex, 1.0));
#endif

#ifdef USE_LUMINOSITY_TEXTURE
			inputCopy.texLuminosity = TO_CL_FLOAT3(TextureShader(consts, calcParam, &inputCopy, renderData, objectData,
				inputCopy.material->luminosityTextureIndex, 0.0));
#endif
#endif

#if defined(USE_PERLIN_NOISE) \
	&& (defined(USE_PERLIN_NOISE_COLOR) || defined(USE_PERLIN_NOISE_LUMINOSITY))
			PerlinNoiseForShaders(consts, calcParam, &inputCopy, renderData, inputCopy.point);
#endif

			sClGradientsCollection gradients;
			REAL alpha = 1.0;
			REAL3 outShadow;
			REAL3 outLuminosityEmissive = 0.0;

			REAL3 objectShader = ObjectShader(consts, renderData, &inputCopy, calcParam, &objectColor,
				&specular, &iridescence, &outShadow, &outLuminosityEmissive, &alpha, &gradients,
				consts->params.indirectShadingQuality);

			newColor = objectColor;
			resultShader.xyz = objectShader + outLuminosityEmissive;

#if defined(USE_REFLECTANCE) && defined(MC_GI_USE_REFLECTANCE)
			lastReflectance = inputCopy.material->reflectance;
			lastReflectanceColor = inputCopy.material->reflectionsColor;
			lastDirection = randomizedDirection;
#endif
		}
		else
		{
			inputCopy.point = inputCopy.point + consts->params.viewDistanceMax * randomizedDirection;
			inputCopy.depth = consts->params.viewDistanceMax;

			REAL3 backgroundShader = BackgroundShader(consts, renderData, image2dBackground, &inputCopy);
			resultShader.xyz = backgroundShader;
			finished = true;
		}

		REAL opacityOut = 0.0;

#if defined(MC_GI_VOLUMETRIC) && !defined(MC_GI_FOG_ILLUMINATION)
		resultShader = VolumetricShader(
			consts, renderData, &inputCopy, calcParam, image2dBackground, resultShader, &opacityOut);
#endif

		REAL influence = clamp(1.0 - totalOpacity, 0.0, 1.0);
		resultShader = clamp(resultShader, 0.0, consts->params.monteCarloGIRadianceLimit);
		out +=
			resultShader.xyz * (objectColorTemp + lastReflectance * lastReflectanceColor) * influence;

		totalOpacity += opacityOut;
		objectColorTemp = newColor;

		if (finished || totalOpacity > 1.0) break;
	}
	return out;
}
#endif // MONTE_CARLO_DOF_GLOBAL_ILLUMINATION
