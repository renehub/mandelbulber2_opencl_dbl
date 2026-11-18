/**
 * Mandelbulber v2, a 3D fractal generator       ,=#MKNmMMKmmßMNWy,
 *                                             ,B" ]L,,p%%%,,,§;, "K
 * Copyright (C) 2024 Mandelbulber Team        §R-==%w["'~5]m%=L.=~5N
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
 * calculation of perlin noise for shaders
 *
 */

#if defined(USE_PERLIN_NOISE)                                                 \
	&& (defined(USE_PERLIN_NOISE_COLOR) || defined(USE_PERLIN_NOISE_LUMINOSITY) \
			|| defined(USE_PERLIN_NOISE_TRANSPARENCY_COLOR)                         \
			|| defined(USE_PERLIN_NOISE_TRANSPARENCY_ALPHA) || defined(USE_PERLIN_NOISE_REFLECTANCE))
void PerlinNoiseForShaders(__constant sClInConstants *consts, sClCalcParams *calcParam,
	sShaderInputDataCl *shaderInputData, sRenderData *renderData, REAL3 point)
{
	if (shaderInputData->material->perlinNoiseEnable)
	{
		REAL3 pointModified = point;

#ifdef FRACTALIZE_TEXTURE
		// texture fractalize requires a valid fractal sequence; primitives (sequenceIndex < 0)
		// have no fractal iteration, so the option is silently ignored for them
		if (shaderInputData->material->textureFractalize && shaderInputData->sequenceIndex >= 0)
		{
			formulaOut outF;
			outF =
				Fractal(consts, pointModified, calcParam, calcModeCubeOrbitTrap, shaderInputData->material,
					-1, renderData, shaderInputData->sequenceIndex, pointModified, false);
			pointModified = outF.z.xyz;
		}
#endif

		pointModified =
			Matrix33MulFloat3(shaderInputData->material->rotMatrixPerlinNoise, pointModified);

		REAL perlin = NormalizedOctavePerlinNoise3D_0_1(
			pointModified.x / shaderInputData->material->perlinNoisePeriod.x,
			pointModified.y / shaderInputData->material->perlinNoisePeriod.y,
			pointModified.z / shaderInputData->material->perlinNoisePeriod.z,
			shaderInputData->material->perlinNoisePositionOffset,
			shaderInputData->material->perlinNoiseIterations, renderData->perlinNoiseSeeds);

		perlin += shaderInputData->material->perlinNoiseValueOffset;

		if (shaderInputData->material->perlinNoiseAbs) perlin = fabs(perlin - 0.5) * 2.0;
		perlin = clamp(perlin, 0.0, 1.0);
		shaderInputData->perlinNoise = perlin;
	}
	else
	{
		shaderInputData->perlinNoise = 0.0;
	}
}
#endif // USE_PERLIN_NOISE

#if defined(USE_PERLIN_NOISE) && defined(USE_PERLIN_NOISE_REFLECTANCE)
REAL3 PerlinNoiseForReflectance(sShaderInputDataCl *shaderInputData, REAL3 reflectance)
{
	REAL perlin = (shaderInputData->material->perlinNoiseReflectanceInvert)
									 ? 1.0 - shaderInputData->perlinNoise
									 : shaderInputData->perlinNoise;
	REAL3 reflectancePerlin = 1.0;

#ifdef USE_REFLECTANCE_GRADIENT
	if (shaderInputData->material->reflectanceGradientEnable)
	{
		REAL colorPosition = fmod(
			perlin * shaderInputData->material->coloring_speed + shaderInputData->material->paletteOffset,
			1.0);

		REAL3 gradientColor =
			GetColorFromGradient(colorPosition, false, shaderInputData->paletteReflectanceLength,
				shaderInputData->palette + shaderInputData->paletteReflectanceOffset);

		reflectancePerlin = gradientColor;
	}
	else
#endif // USE_REFLECTANCE_GRADIENT
	{
		REAL perlinCol = perlin;
		reflectancePerlin = perlinCol;
	}
	REAL perlinRefInt = shaderInputData->material->perlinNoiseReflectanceIntensity;
	REAL perlinRefIntN = 1.0 - shaderInputData->material->perlinNoiseReflectanceIntensity;
	reflectance *= reflectancePerlin * perlinRefInt + perlinRefIntN;

	return reflectance;
}
#endif // USE_PERLIN_NOISE_REFLECTANCE

#if defined(USE_PERLIN_NOISE)                      \
	&& (defined(USE_PERLIN_NOISE_TRANSPARENCY_COLOR) \
			|| defined(USE_PERLIN_NOISE_TRANSPARENCY_ALPHA))
REAL3 PerlinNoiseForTransparency(
	sShaderInputDataCl *shaderInputData, REAL3 transparency, bool volumeMode)
{
	REAL perlin = (shaderInputData->material->perlinNoiseTransparencyColorInvert)
									 ? 1.0 - shaderInputData->perlinNoise
									 : shaderInputData->perlinNoise;
	REAL3 transparencyPerlin = 1.0;

#ifdef USE_TRANSPARENCY_GRADIENT
	if (shaderInputData->material->transparencyGradientEnable)
	{
		REAL colorPosition = fmod(
			perlin * shaderInputData->material->coloring_speed + shaderInputData->material->paletteOffset,
			1.0);

		REAL3 gradientColor =
			GetColorFromGradient(colorPosition, false, shaderInputData->paletteTransparencyLength,
				shaderInputData->palette + shaderInputData->paletteTransparencyOffset);

		transparencyPerlin = gradientColor;
	}
	else
#endif // USE_TRANSPARENCY_GRADIENT
	{
		REAL perlinCol = perlin;
		transparencyPerlin = perlinCol;
	}

	REAL intensity = (volumeMode)
											? shaderInputData->material->perlinNoiseTransparencyColorIntensityVol
											: shaderInputData->material->perlinNoiseTransparencyColorIntensity;

	REAL perlinRefInt = intensity;
	REAL perlinRefIntN = 1.0 - intensity;
	transparency *= transparencyPerlin * perlinRefInt + perlinRefIntN;

	return transparency;
}
#endif // USE_PERLIN_NOISE_TRANSPARENCY_COLOR or USE_PERLIN_NOISE_TRANSPARENCY_ALPHA

#if defined(USE_PERLIN_NOISE) && defined(USE_PERLIN_NOISE_DISPLACEMENT)
REAL PerlinNoiseDisplacement(REAL distance, REAL3 point, sRenderData *renderData, int objectId)
{
	__global sObjectDataCl *objectData = &renderData->objectsData[objectId];
	__global sMaterialCl *mat = renderData->materials[objectData->materialId];

	if (mat->perlinNoiseEnable && mat->perlinNoiseDisplacementEnable)
	{
		REAL3 pointModified = Matrix33MulFloat3(mat->rotMatrixPerlinNoise, point);

		REAL perlin = NormalizedOctavePerlinNoise3D_0_1(pointModified.x / mat->perlinNoisePeriod.x,
			pointModified.y / mat->perlinNoisePeriod.y, pointModified.z / mat->perlinNoisePeriod.z,
			mat->perlinNoisePositionOffset, mat->perlinNoiseIterations, renderData->perlinNoiseSeeds);

		perlin += mat->perlinNoiseValueOffset;

		if (mat->perlinNoiseAbs) perlin = fabs(perlin - 0.5) * 2.0;
		if (mat->perlinNoiseDisplacementInvert) perlin = 1.0 - perlin;
		perlin = clamp(perlin, 0.0, 1.0);

		distance -= perlin * mat->perlinNoiseDisplacementIntensity;
	}
	return distance;
}
#endif // USE_PERLIN_NOISE_DISPLACEMENT
