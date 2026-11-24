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
 * calculation of all volumetric shaders
 */

#ifdef FULL_ENGINE

#ifdef RAYLEIGH_SCATTERING
void RayleighScattering(__constant sClInConstants *consts, REAL3 lightVectorTemp,
	sShaderInputDataCl *input, REAL3 *raleighScatteringRGB, REAL3 *mieScatteringRGB)
{
	if (consts->params.rayleighScatteringBlue > 0.0)
	{
		REAL raleighScattering = (1.0 + pow(dot(lightVectorTemp, input->viewVector), 2.0))
															* consts->params.rayleighScatteringBlue;
		raleighScatteringRGB->s0 = 1.0;
		raleighScatteringRGB->s1 = (1.0 + 0.2 * raleighScattering);
		raleighScatteringRGB->s2 = (1.0 + 2.0 * raleighScattering);
	}
	if (consts->params.rayleighScatteringRed > 0.0)
	{
		REAL mieScatteringR = pow(dot(lightVectorTemp, input->viewVector) * 0.5 + 0.5, 15.0)
													 * consts->params.rayleighScatteringRed;
		REAL mieScatteringG = pow(dot(lightVectorTemp, input->viewVector) * 0.5 + 0.5, 10.0)
													 * consts->params.rayleighScatteringRed;
		mieScatteringRGB->s0 = (1.0 + 5.0 * mieScatteringR);
		mieScatteringRGB->s1 = (1.0 + mieScatteringG);
		mieScatteringRGB->s2 = 1.0;
	}
}
#endif // RAYLEIGH_SCATTERING

//------------ Volumetric shader ----------------
REAL4 VolumetricShader(__constant sClInConstants *consts, sRenderData *renderData,
	sShaderInputDataCl *input, sClCalcParams *calcParam, image2d_t image2dBackground, REAL4 oldPixel,
	REAL *opacityOut)
{
	REAL4 out4 = oldPixel;
	REAL3 output = oldPixel.xyz;
	REAL totalOpacity = 0.0;

	// visible lights init
	int numberOfLights = renderData->numberOfLights;

#ifdef GLOW
	// glow init
	REAL glow = input->stepCount * consts->params.glowIntensity / 512.0 * consts->params.DEFactor;
	REAL glowN = 1.0 - glow;
	if (glowN < 0.0) glowN = 0.0;

	REAL3 glowColor;

	glowColor = (glowN * TO_REAL3(consts->params.glowColor1)
								 + TO_REAL3(consts->params.glowColor2) * glow);

#endif // GLOW

#ifdef SIMPLE_GLOW // only simple glow, no another shaders
#ifdef GLOW
	glow *= 0.7;
	REAL glowOpacity = 1.0 * glow;
	if (glowOpacity > 1.0) glowOpacity = 1.0;
	output = glow * glowColor + (1.0 - glowOpacity) * output;
	out4.s3 += glowOpacity;
#endif // GLOW

#else // not SIMPLE_GLOW
	REAL totalStep = 0.0;
	REAL scan = CalcDistThresh(input->point, consts);
	REAL lastCloudDistance = consts->params.cloudsPeriod;

	sShaderInputDataCl input2 = *input;

	for (int i = 0; i < MAX_RAYMARCHING; i++)
	{
		REAL3 point = input->point - input->viewVector * scan;

		input2.point = point;
		const REAL cameraDistance = length(consts->params.camera - point);
		input2.distThresh = CalcDistThreshFromCameraDistance(cameraDistance, consts);
		input2.delta = CalcDeltaFromCameraDistance(cameraDistance, consts);

		calcParam->distThresh = input2.distThresh;
		calcParam->detailSize = input2.distThresh;

		formulaOut outF;
		outF = CalculateDistance(consts, point, calcParam, renderData);
		REAL distance = outF.distance;

		// Apply per-object detailLevelMultiplier to input2.distThresh dynamically
		if (outF.objectId >= 0 && outF.objectId < renderData->numberOfObjects)
		{
			input2.distThresh *= renderData->objectsData[outF.objectId].detailLevelMultiplier;
		}

		REAL step = (min(distance, lastCloudDistance) - 0.5 * input2.distThresh)
								 * consts->params.DEFactor * consts->params.volumetricLightDEFactor;

#ifdef MONTE_CARLO
		step *= (1.0 - Random(1000, &input->randomSeed) / 4000.0);
#else
		step *= (1.0 - Random(1000, &input->randomSeed) / 10000.0);
#endif

#ifdef ADVANCED_QUALITY
		step = clamp(step, consts->params.absMinMarchingStep, consts->params.absMaxMarchingStep);

		if (input2.distThresh > consts->params.absMinMarchingStep)
			step = clamp(step, consts->params.relMinMarchingStep * input2.distThresh,
				consts->params.relMaxMarchingStep * input2.distThresh);
#endif

		step = max(step, input2.distThresh);

		bool end = false;
		if (step > input->depth - scan)
		{
			step = input->depth - scan;
			end = true;
		}
		scan += step;

//------------------- glow
#ifdef GLOW
		{
			if (input->stepCount > 0)
			{
				REAL glowOpacity = glow / input->stepCount * consts->params.volumetricLightDEFactor;
				if (glowOpacity > 1.0) glowOpacity = 1.0;

				output = glowOpacity * glowColor + (1.0 - glowOpacity) * output;
				out4.s3 += glowOpacity;
			}
		}
#endif // GLOW

#ifdef BASIC_FOG
		REAL basicFogOpacity = 0.0;
		{
			basicFogOpacity = step / consts->params.fogVisibility;

			// FIXME: it needs to be rewritten to work with ObjectsTree
			// #if (defined(USE_PRIMITIVES) && defined(BASIC_FOG_SHAPE_FROM_PRIMITIVE))
			//			if (renderData->primitivesGlobalData->primitiveIndexForBasicFog >= 0)
			//			{
			//				int closestId = -1;
			//
			//				if (TotalDistanceToPrimitives(consts, renderData, point, distance, input2.delta,
			//false, 							&closestId, renderData->primitivesGlobalData->primitiveIndexForBasicFog) 						>
			//input2.delta) 					basicFogOpacity = 0.0;
			//			}
			// #endif // USE_PRIMITIVES
		}
#endif // BASIC_FOG

#ifdef ITER_FOG
		REAL iterFogOpacity = 0.0;
		REAL3 iterFogCol = 0.0;

		{
			int L = outF.iters;
			iterFogOpacity = IterOpacity(step, L, consts->params.N, consts->params.iterFogOpacityTrim,
				consts->params.iterFogOpacityTrimHigh, consts->params.iterFogOpacity);

			// FIXME: it needs to be rewritten to work with ObjectsTree
			// #if (defined(USE_PRIMITIVES) && defined(ITER_FOG_SHAPE_FROM_PRIMITIVE))
			//			if (iterFogOpacity > 0.0 &&
			//renderData->primitivesGlobalData->primitiveIndexForIterFog >= 0)
			//			{
			//				int closestId = -1;
			//
			//				if (TotalDistanceToPrimitives(consts, renderData, point, distance, input2.delta,
			//false, 							&closestId, renderData->primitivesGlobalData->primitiveIndexForIterFog) 						>
			//input2.delta) 					iterFogOpacity = 0.0;
			//			}
			// #endif // USE_PRIMITIVES

			if (iterFogOpacity > 0.0)
			{
				// fog colour
				REAL iterFactor1 =
					(L - consts->params.iterFogOpacityTrim)
					/ (consts->params.iterFogColor1Maxiter - consts->params.iterFogOpacityTrim);
				REAL k = iterFactor1;
				if (k > 1.0) k = 1.0;
				if (k < 0.0) k = 0.0;
				REAL kn = 1.0 - k;
				iterFogCol = TO_REAL3(consts->params.iterFogColour1) * kn
				+ TO_REAL3(consts->params.iterFogColour2) * k;

				REAL iterFactor2 =
					(L - consts->params.iterFogColor1Maxiter)
					/ (consts->params.iterFogColor2Maxiter - consts->params.iterFogColor1Maxiter);
				REAL k2 = iterFactor2;
				if (k2 < 0.0) k2 = 0.0;
				if (k2 > 1.0) k2 = 1.0;
				kn = 1.0 - k2;
				iterFogCol = iterFogCol * kn + TO_REAL3(consts->params.iterFogColour3) * k2;
				//----
			}
		}
#endif // ITER_FOG

		//--------- clouds --------
#ifdef CLOUDS
		REAL cloudsOpacity = 0.0;
		REAL cloudDensity = 0.0;
		REAL3 deltaCloud = 0.0;

		{
			// perlin noise clouds
			REAL distanceToClouds = 0.0;
			bool calculateClouds = true;

			// FIXME: it needs to be rewritten to work with ObjectsTree
			// #if (defined(USE_PRIMITIVES) && defined(CLOUDS_SHAPE_FROM_PRIMITIVE))
			//			if (renderData->primitivesGlobalData->primitiveIndexForClouds >= 0)
			//			{
			//				int closestId = -1;
			//
			//				if (TotalDistanceToPrimitives(consts, renderData, point, distance, input2.delta,
			//false, 							&closestId, renderData->primitivesGlobalData->primitiveIndexForClouds) 						>
			//input2.delta)
			//				{
			//					cloudDensity = 0.0;
			//					calculateClouds = false;
			//				}
			//			}
			// #endif // USE_PRIMITIVES

			if (calculateClouds)
			{
				cloudDensity = CloudOpacity(
					consts, renderData->perlinNoiseSeeds, point, distance, input2.delta, &distanceToClouds);
			}
			else
			{
				distanceToClouds = distance;
			}

#ifndef CLOUDSSHADOWS
			if (cloudDensity > 0.0)
			{
				REAL delta =
					consts->params.cloudsPeriod / pown(2.0, consts->params.cloudsIterations) * 5.0;
				REAL distanceToCloudsDummy = 0.0;

				deltaCloud.x =
					CloudOpacity(consts, renderData->perlinNoiseSeeds, point + (REAL3){delta, 0.0, 0.0},
						distance, input2.delta, &distanceToCloudsDummy)
					- cloudDensity;

				deltaCloud.y =
					CloudOpacity(consts, renderData->perlinNoiseSeeds, point + (REAL3){0.0, delta, 0.0},
						distance, input2.delta, &distanceToCloudsDummy)
					- cloudDensity;

				deltaCloud.z =
					CloudOpacity(consts, renderData->perlinNoiseSeeds, point + (REAL3){0.0, 0.0, delta},
						distance, input2.delta, &distanceToCloudsDummy)
					- cloudDensity;

				if (length(deltaCloud) > 0.0)
				{
					deltaCloud = normalize(deltaCloud);
				}
			}
#endif // CLOUDSSHADOWS

			cloudsOpacity = cloudDensity * step;

			lastCloudDistance = distanceToClouds;
		}
#endif // CLOUDS

//-------------------- volumetric fog
#ifdef VOLUMETRIC_FOG
		REAL distFogOpacity = 0.0;
		REAL3 distFogColor = 0.0;

		{
			REAL distanceShifted;
			distFogOpacity = DistanceFogOpacity(step, distance, consts->params.volFogDistanceFromSurface,
				consts->params.volFogDistanceFactor, consts->params.volFogDensity, &distanceShifted);

			// FIXME: it needs to be rewritten to work with ObjectsTree
			// #if (defined(USE_PRIMITIVES) && defined(DIST_FOG_SHAPE_FROM_PRIMITIVE))
			//			if (distFogOpacity > 0.0 &&
			//renderData->primitivesGlobalData->primitiveIndexForDistFog >= 0)
			//			{
			//				int closestId = -1;
			//
			//				if (TotalDistanceToPrimitives(consts, renderData, point, distance, input2.delta,
			//false, 							&closestId, renderData->primitivesGlobalData->primitiveIndexForDistFog) 						>
			//input2.delta) 					distFogOpacity = 0.0;
			//			}
			// #endif // USE_PRIMITIVES

			REAL k = distanceShifted / consts->params.volFogColour1Distance;
			if (k > 1.0) k = 1.0;
			REAL kn = 1.0 - k;
			REAL3 fogTemp;
			fogTemp = TO_REAL3(consts->params.volFogColour1) * kn
				+ TO_REAL3(consts->params.volFogColour2) * k;

			REAL k2 = distanceShifted / consts->params.volFogColour2Distance * k;
			if (k2 > 1.0) k2 = 1.0;
			kn = 1.0 - k2;
			distFogColor = fogTemp * kn + TO_REAL3(consts->params.volFogColour3) * k2;
		}
#endif // VOLUMETRIC_FOG

		REAL3 totalLightsWithShadows = 0.0;
		REAL3 totalLights = 0.0;
		REAL3 totalLightsClouds = 0.0;

// loop for proceessing all lights and volumetric effects
#ifdef AUX_LIGHTS
#if (defined(VOLUMETRIC_LIGHTS) || defined(ITER_FOG) || defined(DIST_FOG_SHADOWS) \
		 || defined(CLOUDS) || defined(BASIC_FOG))
		for (int i = 0; i < numberOfLights; i++)
		{
			__global sLightCl *light = &renderData->lights[i];

			if (light->enabled)
			{
				bool shadowNeeded = false;
				bool lightNeeded = false;

#ifdef VOLUMETRIC_LIGHTS
				if (light->volumetric)
				{
					shadowNeeded = true;
					lightNeeded = true;
				}
#endif

#ifdef ITER_FOG
				if (iterFogOpacity > 0.0)
				{
					lightNeeded = true;
					if (consts->params.iterFogShadows) shadowNeeded = true;
				}
#endif

#ifdef CLOUDS
				if (cloudsOpacity > 0.0)
				{
					lightNeeded = true;
					if (consts->params.cloudsCastShadows) shadowNeeded = true;
				}
#endif

#ifdef VOLUMETRIC_FOG
				if (consts->params.distanceFogShadows && distFogOpacity > 0.0)
				{
					lightNeeded = true;
					shadowNeeded = true;
				}
#endif

#ifdef BASIC_FOG
				if (consts->params.fogCastShadows && basicFogOpacity > 0.0)
				{
					lightNeeded = true;
					shadowNeeded = true;
				}
#endif

				if (!light->castShadows) shadowNeeded = false;

				if (lightNeeded)
				{
					REAL distanceLight = 0.0;

					REAL3 lightVectorTemp =
						CalculateLightVector(light, point, input2.delta, consts->params.resolution,
							consts->params.viewDistanceMax, &distanceLight, &input->randomSeed);

					REAL lightIntensity = 0.0;
					if (light->type == lightDirectional)
						lightIntensity = light->intensity;
					else if (light->type == lightConical)
						lightIntensity = light->intensity * 10.0;
					else
						lightIntensity =
							light->intensity / LightDecay(distanceLight, light->decayFunction) * 4.0;

					REAL3 textureColor;
					lightIntensity *=
						CalculateLightCone(light, renderData, point, lightVectorTemp, &textureColor);

					REAL3 lightShadow = 1.0;

#ifdef SHADOWS
					if (shadowNeeded)
					{
						if (lightIntensity > 1e-3)
							lightShadow = AuxShadow(consts, renderData, &input2, light, distanceLight,
								lightVectorTemp, calcParam, light->intensity);
						else
							lightShadow = 0.0;
					}
#endif

					REAL3 raleighScatteringRGB = 1.0;
					REAL3 mieScatteringRGB = 1.0;

#ifdef RAYLEIGH_SCATTERING
					RayleighScattering(
						consts, lightVectorTemp, input, &raleighScatteringRGB, &mieScatteringRGB);
#endif

					REAL3 calculatedLight =
						light->color * lightIntensity * textureColor * raleighScatteringRGB * mieScatteringRGB;
					totalLightsWithShadows += calculatedLight * lightShadow;
					totalLights += calculatedLight;

#ifdef CLOUDS
					REAL shadeClouds = clamp(-dot(lightVectorTemp, deltaCloud), 0.0, 1.0);
					totalLightsClouds += calculatedLight * shadeClouds;
#endif

					if (light->volumetric)
					{
						output += calculatedLight * light->volumetricVisibility * lightShadow * step;
						out4.s3 += lightShadow.s0 * step * lightIntensity * light->volumetricVisibility;
					}
				} // if light needed
			} // if light enabled
		}

#endif // VOLUMETRIC_LIGHTS
#endif // AUX_LIGHTS

#if !defined(MC_GI_VOLUMETRIC) && defined(MC_GI_FOG_ILLUMINATION) \
	&& defined(MONTE_CARLO_DOF_GLOBAL_ILLUMINATION)
		{
			REAL3 gi =
				GlobalIlumination(consts, renderData, &input2, calcParam, image2dBackground, 1.0, true);
			totalLights += gi;
			totalLightsWithShadows += gi;
		}
#endif

		REAL3 AO = 0.0;
		bool aoNeeded = false;
#ifdef ITER_FOG
		if (iterFogOpacity > 0.0) aoNeeded = true;
#endif
		// #ifdef VOLUMETRIC_FOG
		//		if (distFogOpacity > 0.0) aoNeeded = true;
		// #endif

#ifdef AO_MODE_MULTIPLE_RAYS
		if (aoNeeded)
		{
			AO =
				AmbientOcclusion(consts, renderData, &input2, calcParam) * consts->params.ambientOcclusion;
		}
#endif // AO_MODE_MULTIPLE_RAYS

#ifdef ITER_FOG
		if (iterFogOpacity > 0.0)
		{
			REAL3 light = (consts->params.iterFogShadows) ? totalLightsWithShadows : totalLights;

			if (iterFogOpacity > 1.0) iterFogOpacity = 1.0;

			output = output * (1.0 - iterFogOpacity)
							 + (light * consts->params.iterFogBrightnessBoost + AO) * iterFogOpacity * iterFogCol;

			totalOpacity = iterFogOpacity + (1.0 - iterFogOpacity) * totalOpacity;
			out4.s3 = iterFogOpacity + (1.0 - iterFogOpacity) * out4.s3;
		}

#endif // ITER_FOG

#ifdef CLOUDS
		if (cloudsOpacity > 0.0)
		{
			REAL3 light =
				(consts->params.cloudsCastShadows) ? totalLightsWithShadows : totalLightsClouds;

			REAL ambient = consts->params.cloudsAmbientLight;
			REAL nAmbient = 1.0 - consts->params.cloudsAmbientLight;

			light = ambient * totalLights + nAmbient * light;

			if (cloudsOpacity > 1.0) cloudsOpacity = 1.0;

			output =
				output * (1.0 - cloudsOpacity)
					+ (light + AO) * cloudsOpacity * TO_REAL3(consts->params.cloudsColor);

			totalOpacity = cloudsOpacity + (1.0 - cloudsOpacity) * totalOpacity;
			out4.s3 = cloudsOpacity + (1.0 - cloudsOpacity) * out4.s3;
		}
#endif // CLOUDS

#ifdef VOLUMETRIC_FOG
		if (distFogOpacity > 0.0)
		{
			REAL3 light = (consts->params.distanceFogShadows) ? totalLightsWithShadows : 1.0;

			if (distFogOpacity > 1.0) distFogOpacity = 1.0;

			output = distFogOpacity * distFogColor * (light + AO) + (1.0 - distFogOpacity) * output;

			totalOpacity = distFogOpacity + (1.0 - distFogOpacity) * totalOpacity;
			out4.s3 = distFogOpacity + (1.0 - distFogOpacity) * out4.s3;
		}
#endif

//----------------------- basic fog
#ifdef BASIC_FOG
		if (basicFogOpacity > 0)
		{
			REAL3 light = (consts->params.fogCastShadows) ? totalLightsWithShadows : 1.0;

			if (basicFogOpacity > 1.0) basicFogOpacity = 1.0;

			output = basicFogOpacity * TO_REAL3(consts->params.fogColor) * (light + AO)
							 + (1.0 - basicFogOpacity) * output;

			totalOpacity = basicFogOpacity + (1.0 - basicFogOpacity) * totalOpacity;
			out4.s3 = basicFogOpacity + (1.0 - basicFogOpacity) * out4.s3;
		}
#endif // BASIC_FOG

#ifdef VISIBLE_AUX_LIGHTS
		//------------------ visible light
		{
			for (int i = 0; i < numberOfLights; ++i)
			{
				__global sLightCl *light = &renderData->lights[i];
				if (light->enabled && light->intensity > 0.0 && light->visibility > 0.0
						&& light->type != lightDirectional)
				{
					REAL lastMiniSteps = -1.0;
					REAL miniStep = 0.0;

					REAL3 lightPosition =
						CalculateBeam(light, light->position, light->target, &input->randomSeed);

					for (REAL miniSteps = 0.0; miniSteps < step; miniSteps += miniStep)
					{
						REAL3 lightDistVect = point - input->viewVector * miniSteps - lightPosition;
						REAL lightDist = fast_length(lightDistVect);
						REAL lightSize = native_sqrt(light->intensity) * light->size;

						REAL distToLightSurface = lightDist - lightSize;
						distToLightSurface = max(distToLightSurface, 0.0);

						miniStep = 0.1 * (distToLightSurface + 0.1 * distToLightSurface);
						miniStep = clamp(miniStep, step * 0.01, step - miniSteps);
						miniStep = max(miniStep, 1e-6);

						REAL r2 = lightDist / lightSize;
						REAL bellFunction;
						if (light->type == lightConical)
						{
							bellFunction = 1.0;
						}
						else
						{
							bellFunction = 1.0 / (1.0 + pown(r2, ((int)light->decayFunction + 1) * 2));
						}

						REAL3 lightDirection = normalize(lightDistVect);

						REAL3 textureColor;
						bellFunction *=
							CalculateLightCone(light, renderData, point, (-1.0) * lightDirection, &textureColor);

						REAL lightDensity = miniStep * bellFunction * light->visibility / lightSize;

#ifdef CLOUDS
						lightDensity *= 1.0 + consts->params.cloudsLightsBoost * cloudsOpacity;
#endif

						output += lightDensity * light->color * textureColor;
						out4.s3 += lightDensity;

						if (miniSteps == lastMiniSteps)
						{
							// Dead computation
							break;
						}
						lastMiniSteps = miniSteps;
					}
				}
			}
		}
#endif

#ifdef FAKE_LIGHTS
		// fake lights (orbit trap)
		{
			int fakeLightMaxLoop = 1;
			if (consts->params.common.fakeLightsColor2Enabled) fakeLightMaxLoop = 2;
			if (consts->params.common.fakeLightsColor3Enabled) fakeLightMaxLoop = 3;

			for (int fakeLightLoop = 0; fakeLightLoop < fakeLightMaxLoop; fakeLightLoop++)
			{
				calcParam->orbitTrapIndex = fakeLightLoop;
				formulaOut outF;
				outF = Fractal(consts, input2.point, calcParam, calcModeOrbitTrap, NULL, -1, renderData, 0,
					input2.transformedPoint, input2.hasTransformedPoint);
				REAL r = outF.orbitTrapR;
				r = sqrt(1.0 / (r + 1.0e-20));
				REAL fakeLight = 1.0
													/ (pow(r, 10.0 / consts->params.fakeLightsVisibilitySize)
															 * pow(10.0, 10.0 / consts->params.fakeLightsVisibilitySize)
														 + 0.1);
				REAL3 light = fakeLight * step * consts->params.fakeLightsVisibility;
#ifdef CLOUDS
				light *= 1.0 + consts->params.cloudsLightsBoost * cloudDensity;
#endif

				REAL3 color;
				switch (fakeLightLoop)
				{
					case 0: color = TO_REAL3(consts->params.fakeLightsColor); break;
					case 1: color = TO_REAL3(consts->params.fakeLightsColor2); break;
					case 2: color = TO_REAL3(consts->params.fakeLightsColor3); break;
					default: color = TO_REAL3(consts->params.fakeLightsColor); break;
				}

				output += light * color;
				out4.s3 += fakeLight * step * consts->params.fakeLightsVisibility;
			}
		}
#endif // FAKE_LIGHTS

		if (totalOpacity > 1.0) totalOpacity = 1.0;
		if (out4.s3 > 1.0) out4.s3 = 1.0; // alpha channel

		*opacityOut = totalOpacity;

		if (end) break;
	}
#endif // not SIMPLE_GLOW

	out4.xyz = output;
	return out4;
}
#endif // FULL_ENGINE