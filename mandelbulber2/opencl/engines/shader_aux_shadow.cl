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
 * calculation of shadows from auxiliary light sources
 */

#ifdef AUX_LIGHTS
#if defined(SHADOWS) || defined(VOLUMETRIC_LIGHTS)
REAL3 AuxShadow(constant sClInConstants *consts, sRenderData *renderData,
	sShaderInputDataCl *input, __global sLightCl *light, REAL distance, REAL3 lightVector,
	sClCalcParams *calcParam, REAL intensity)
{
	REAL3 lightShaded = 1.0;
	REAL totalOpacity = 0.0;
	REAL shadowTemp = 1.0;

	bool cloudMode = consts->params.cloudsEnable;

	REAL DEFactor = consts->params.DEFactor;
	if (consts->params.iterFogEnabled || consts->params.distanceFogShadows || light->volumetric)
		DEFactor = 1.0;
#ifdef CLOUDS
	DEFactor = consts->params.DEFactor * consts->params.volumetricLightDEFactor;
#endif

	REAL start = input->distThresh;

#ifdef MC_SOFT_SHADOWS
	REAL softRange;
	if (light->type == lightDirectional)
	{
		softRange = tan(light->softShadowCone);
	}
	else
	{
		REAL lightSize = sqrt(intensity) * light->size;
		softRange = lightSize / distance;
	}
#else
	REAL softRange = tan(light->softShadowCone);
#endif

	bool goThrough = input->material->subsurfaceScattering;

#if defined(USE_SUBSURFACE_SCATTERING)                                       \
	&& (defined(USE_INNER_COLORING) || defined(USE_TRANSPARENCY_ALPHA_TEXTURE) \
			|| defined(USE_PERLIN_NOISE_TRANSPARENCY_ALPHA))
	sShaderInputDataCl input2 = *input;
#endif

	REAL maxSoft = 0.0;

	const bool bSoft = !goThrough && !cloudMode && !consts->params.iterFogEnabled
										 && !consts->params.distanceFogShadows && !consts->params.fogCastShadows
										 && !consts->params.common.iterThreshMode && !consts->params.interiorMode
										 && softRange > 0.0
										 && !(consts->params.monteCarloSoftShadows && consts->params.DOFMonteCarlo);

#ifdef MC_SOFT_SHADOWS
	REAL3 randomVector;
	randomVector.x = Random(10000, &input->randomSeed) / 5000.0 - 1.0;
	randomVector.y = Random(10000, &input->randomSeed) / 5000.0 - 1.0;
	randomVector.z = Random(10000, &input->randomSeed) / 5000.0 - 1.0;
	REAL randomSphereRadius = pow(Random(10000, &input->randomSeed) / 10000.0, 1.0 / 3.0);
	REAL3 randomSphere = randomVector * (softRange * randomSphereRadius / length(randomVector));
	lightVector += randomSphere;
	lightVector = fast_normalize(lightVector);
#endif // MC_SOFT_SHADOWS

#if defined(USE_SUBSURFACE_SCATTERING) && defined(FULL_ENGINE)
	REAL3 lightVectorUnmodified = lightVector;
	bool wentThrough = false;
#endif

	REAL lastDistanceToClouds = 1e6;
	int count = 0;
	REAL step = 0.0;

	REAL3 point2 = input->point + start * lightVector;

	for (REAL i = start; i < distance; i += step)
	{
		// REAL3 point2 = input->point + lightVector * i;
		point2 += lightVector * step;

		REAL dist_thresh;
		if (consts->params.iterFogEnabled || consts->params.distanceFogShadows || light->volumetric
				|| cloudMode || goThrough)
		{
			dist_thresh = CalcDistThresh(point2, consts);
		}
		else
			dist_thresh = input->distThresh;

		calcParam->distThresh = dist_thresh;
		// detailSize must follow the shadow ray threshold (like in the primary
		// RayMarching and in the CPU AuxShadow). The boolean subtraction clamps
		// the distance inside the cut-out zone to 1.5*detailSize; if detailSize
		// kept the caller value (delta = distThresh*detailLevel), that clamped
		// distance could fall below dist_thresh for detailLevel < 2/3 and the
		// invisible cutter object would cast a false shadow.
		calcParam->detailSize = dist_thresh;
		formulaOut outF;

		outF = CalculateDistance(consts, point2, calcParam, renderData);
		REAL dist = outF.distance;

		// Apply per-object detailLevelMultiplier to dist_thresh dynamically
		if (outF.objectId >= 0 && outF.objectId < renderData->numberOfObjects)
		{
			dist_thresh *= renderData->objectsData[outF.objectId].detailLevelMultiplier;
		}

#ifdef USE_SUBSURFACE_SCATTERING
#ifdef FULL_ENGINE
		__global sObjectDataCl *objectData = &renderData->objectsData[outF.objectId];
		__global sMaterialCl *material = renderData->materials[objectData->materialId];
		goThrough = material->subsurfaceScattering;
#endif
#endif

		bool limitsAcheved = false;
#ifdef LIMITS_ENABLED
		limitsAcheved = any(isless(point2, consts->params.limitMin))
										|| any(isgreater(point2, consts->params.limitMax));
#endif // LIMITS_ENABLED

		if (bSoft && !limitsAcheved)
		{
			REAL angle = (dist - dist_thresh) / i;
			if (angle < 0.0) angle = 0.0;
			if (dist < dist_thresh) angle = 0.0;
			REAL softShadow = 1.0 - angle / softRange;
			if (light->penetrating) softShadow *= (distance - i) / distance;
			if (softShadow < 0.0) softShadow = 0.0;
			if (softShadow > maxSoft) maxSoft = softShadow;
		}

#ifdef ITER_FOG
		{
			REAL opacity =
				IterOpacity(step, outF.iters, consts->params.N, consts->params.iterFogOpacityTrim,
					consts->params.iterFogOpacityTrimHigh, consts->params.iterFogOpacity);

			// FIXME: it needs to be rewritten to work with ObjectsTree
			// #if (defined(USE_PRIMITIVES) && defined(ITER_FOG_SHAPE_FROM_PRIMITIVE))
			//			if (opacity > 0.0 && renderData->primitivesGlobalData->primitiveIndexForIterFog >= 0)
			//			{
			//				int closestId = -1;
			//
			//				if (TotalDistanceToPrimitives(consts, renderData, point2, distance, dist_thresh,
			// false, 							&closestId,
			// renderData->primitivesGlobalData->primitiveIndexForIterFog) 						> dist_thresh)
			// opacity = 0.0;
			//			}
			// #endif // USE_PRIMITIVES

			opacity *= (distance - i) / distance;
			opacity = min(opacity, 1.0);
			totalOpacity = opacity + (1.0 - opacity) * totalOpacity;
		}
#endif // ITER_FOG

#if (defined(VOLUMETRIC_FOG) && defined(DIST_FOG_SHADOWS))
		if (consts->params.distanceFogShadows)
		{
			REAL distanceShifted;
			REAL opacity = DistanceFogOpacity(step, dist, consts->params.volFogDistanceFromSurface,
				consts->params.volFogDistanceFactor, consts->params.volFogDensity, &distanceShifted);

			// FIXME: it needs to be rewritten to work with ObjectsTree
			// #if (defined(USE_PRIMITIVES) && defined(DIST_FOG_SHAPE_FROM_PRIMITIVE))
			//			if (opacity > 0.0 && renderData->primitivesGlobalData->primitiveIndexForDistFog >= 0)
			//			{
			//				int closestId = -1;
			//
			//				if (TotalDistanceToPrimitives(consts, renderData, point2, distance, dist_thresh,
			// false, 							&closestId,
			// renderData->primitivesGlobalData->primitiveIndexForDistFog) 						> dist_thresh)
			// opacity = 0.0;
			//			}
			// #endif // USE_PRIMITIVES

			opacity *= (distance - i) / distance;
			opacity = min(opacity, 1.0);
			totalOpacity = opacity + (1.0 - opacity) * totalOpacity;
		}
#endif // VOL_OFG

#if (defined(BASIC_FOG) && defined(BASIC_FOG_CAST_SHADOWS))
		if (consts->params.fogCastShadows)
		{
			REAL opacity = step / consts->params.fogVisibility;

			// FIXME: it needs to be rewritten to work with ObjectsTree
			// #if (defined(USE_PRIMITIVES) && defined(BASIC_FOG_SHAPE_FROM_PRIMITIVE))
			//			if (renderData->primitivesGlobalData->primitiveIndexForBasicFog >= 0)
			//			{
			//				int closestId = -1;
			//
			//				if (TotalDistanceToPrimitives(consts, renderData, point2, distance, dist_thresh,
			// false, 							&closestId,
			// renderData->primitivesGlobalData->primitiveIndexForBasicFog) 						> dist_thresh)
			// opacity = 0.0;
			//			}
			// #endif // USE_PRIMITIVES

			opacity *= (distance - i) / distance;
			opacity = min(opacity, 1.0);
			totalOpacity = opacity + (1.0 - opacity) * totalOpacity;
		}
#endif // BASIC_FOG

#ifdef CLOUDS
		{
			REAL distanceToClouds = 0.0;
			bool calculateClouds = true;
			REAL opacity = 0.0;

			// FIXME: it needs to be rewritten to work with ObjectsTree
			// #if (defined(USE_PRIMITIVES) && defined(CLOUDS_SHAPE_FROM_PRIMITIVE))
			//			if (renderData->primitivesGlobalData->primitiveIndexForClouds >= 0)
			//			{
			//				int closestId = -1;
			//
			//				if (TotalDistanceToPrimitives(consts, renderData, point2, distance, dist_thresh,
			// false, 							&closestId, renderData->primitivesGlobalData->primitiveIndexForClouds)
			// > dist_thresh)
			//				{
			//					opacity = 0.0;
			//					calculateClouds = false;
			//				}
			//			}
			// #endif // USE_PRIMITIVES

			if (calculateClouds)
			{
				opacity = CloudOpacity(consts, renderData->perlinNoiseSeeds, point2, dist, dist_thresh,
										&distanceToClouds)
									* step;
			}
			else
			{
				distanceToClouds = dist;
			}

			lastDistanceToClouds = distanceToClouds;
			opacity *= (distance - i) / distance;
			opacity = min(opacity, 1.0);
			totalOpacity = opacity + (1.0 - opacity) * totalOpacity;
		}
#endif // CLOUS

#if defined(USE_SUBSURFACE_SCATTERING) && defined(FULL_ENGINE)
		if (goThrough && dist < dist_thresh)
		{
#ifdef MC_SOFT_SHADOWS
			if (!wentThrough)
			{
				wentThrough = true;
				REAL3 randomVector;
				randomVector.x = Random(10000, &input->randomSeed) / 5000.0 - 1.0;
				randomVector.y = Random(10000, &input->randomSeed) / 5000.0 - 1.0;
				randomVector.z = Random(10000, &input->randomSeed) / 5000.0 - 1.0;
				REAL randomSphereRadius = pow(Random(10000, &input->randomSeed) / 10000.0, 1.0 / 3.0);
				REAL3 randomSphere = randomVector * (0.95 * randomSphereRadius / length(randomVector));
				lightVector = lightVectorUnmodified + randomSphere;
				lightVector = fast_normalize(lightVector);
			}

			REAL opacityFactor = dot(lightVector, lightVectorUnmodified);
#endif // MC_SOFT_SHADOWS

			REAL opacityCollected = 1.0;
#if defined(USE_INNER_COLORING) && defined(USE_DIFFUSE_GRADIENT)
			if (material->insideColoringEnable && material->diffuseGradientEnable)
			{
				sClGradientsCollection gradients;
				input2.objectId = outF.objectId;
				input2.point = point2;
				SurfaceColor(consts, renderData, &input2, calcParam, &gradients);
				opacityCollected = gradients.diffuse.s0;
			}
#endif // USE_INNER_COLORING && USE_DIFFUSE_GRADIENT

			REAL texOpacity = 0.0;
#ifdef USE_TRANSPARENCY_ALPHA_TEXTURE
			if (input->material->useTransparencyAlphaTexture)
			{
				REAL3 tex = TextureShader(consts, calcParam, &input2, renderData, objectData,
					input2.material->transparencyAlphaTextureIndex, 1.0);
				texOpacity =
					(1.0 - tex.s0) * input2.material->transparencyAlphaTextureIntensityVol + 1e-6;
				opacityCollected = opacityCollected * (1.0 - texOpacity) + texOpacity;
			}
#endif // USE_TRANSPARENCY_ALPHA_TEXTURE

#if defined(USE_PERLIN_NOISE) && defined(USE_PERLIN_NOISE_TRANSPARENCY_ALPHA)
			if (input->material->perlinNoiseEnable && input->material->perlinNoiseTransparencyAlphaEnable)
			{
				PerlinNoiseForShaders(consts, calcParam, &input2, renderData, point2);
				REAL alpha = (input->material->perlinNoiseTransparencyColorInvert)
												? 1.0 - input2.perlinNoise
												: input2.perlinNoise;
				alpha =
					clamp(alpha * input->material->perlinNoiseTransparencyAlphaIntensityVol, 0.0, 1.0);
				alpha = 1.0 - alpha;
				opacityCollected = opacityCollected * (1.0 - alpha) + alpha + 1e-6;
			}
#endif

			REAL opacity =
				(-1.0 + 1.0 / (opacityCollected * input->material->transparencyOfInterior)) * step;

#ifdef MC_SOFT_SHADOWS
			opacity *= opacityFactor;
#endif

			opacity *= (distance - i) / distance;
			opacity = min(opacity, 1.0);
			totalOpacity = opacity + (1.0 - opacity) * totalOpacity;
			dist = CalcDelta(point2, consts);
		}
		else
		{
			lightVector = lightVectorUnmodified;
			wentThrough = false;
		}
#endif // USE_SUBSURFACE_SCATTERING

		shadowTemp = 1.0 - totalOpacity;

		if ((!goThrough && (dist < dist_thresh || shadowTemp < 0.0))
				|| (goThrough && shadowTemp < 0.0001))
		{
			if (light->penetrating)
			{
				shadowTemp -= (distance - i) / distance;
				if (shadowTemp < 0.0) shadowTemp = 0.0;
			}
			else
			{
				shadowTemp = 0.0;
			}
			break;
		}
		step = min(dist, lastDistanceToClouds) * DEFactor;
		step = max(step, 1e-6);

		count++;
		if (count > MAX_RAYMARCHING) break;
	}

	if (!bSoft)
	{
		lightShaded = shadowTemp;
	}
	else
	{
		lightShaded = 1.0 - maxSoft;
	}

	return lightShaded;
}
#endif // SHADOWS
#endif // AUX_LIGHTS
