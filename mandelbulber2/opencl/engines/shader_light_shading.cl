/**
 * Mandelbulber v2, a 3D fractal generator       ,=#MKNmMMKmmßMNWy,
 *                                             ,B" ]L,,p%%%,,,§;, "K
 * Copyright (C) 2018-22 Mandelbulber Team     §R-==%w["'~5]m%=L.=~5N
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
 * calculation of auxiliary light sources
 */

#ifdef AUX_LIGHTS

REAL3 CalculateBeam(__global sLightCl *light, REAL3 point1, REAL3 point2, int *randomSeed)
{
	if (light->type == lightBeam)
	{
		REAL3 direction = point2 - point1;
		return point1 + direction * Random(10000, randomSeed) / 10000.0;
	}
	else
	{
		return point1;
	}
}

REAL3 CalculateLightVector(__global sLightCl *light, REAL3 point, REAL delta, REAL resolution,
	REAL viewDistanceMax, REAL *outDistance, int *randomSeed)
{
	REAL3 lightVector;
	if (light->type == lightDirectional)
	{
		lightVector = light->lightDirection;
		if (light->penetrating)
		{
			*outDistance = delta / resolution;
		}
		else
		{
			*outDistance = viewDistanceMax;
		}
	}
	else
	{
		REAL3 d = CalculateBeam(light, light->position, light->target, randomSeed) - point;
		lightVector = normalize(d);
		*outDistance = length(d);
	}
	return lightVector;
}

REAL LightDecay(REAL dist, enumLightDecayFunctionCl decayFunction)
{
	return pown(dist, (int)decayFunction + 1);
}

REAL CalculateLightCone(__global sLightCl *light, sRenderData *renderData, REAL3 point,
	REAL3 lightVector, REAL3 *outColor)
{
	REAL3 color = 1.0;
	REAL intensity = 1.0;

	if (light->type == lightConical)
	{
#ifdef LIGHT_CONICAL
		if (dot(point - light->position, light->lightDirection) > 0.0)
		{
			intensity = 0.0;
		}
		else
		{
			REAL tipSize = light->size * 0.5;
			REAL distanceToAxis = length(cross(point - light->position, light->lightDirection));
			REAL cone = length(point - light->position);
			REAL cone1 = cone * light->coneRatio;
			REAL cone2 = cone * light->coneSoftRatio;
			if (distanceToAxis < tipSize + cone1)
			{
				intensity = 1.0;
			}
			else if (distanceToAxis < tipSize + cone2)
			{
				intensity = (tipSize + cone2 - distanceToAxis) / (cone2 - cone1);
			}
			else
			{
				intensity = 0.0;
			}

			intensity = intensity * (tipSize * tipSize) / ((tipSize + cone1) * (tipSize + cone1));
		}
#endif // LIGHT_CONICAL
	}
	else if (light->type == lightProjection)
	{
#ifdef USE_LIGHT_TEXTURE
		if (light->colorTextureIndex >= 0)
		{
			REAL axiality = dot(lightVector, light->lightDirection);
			if (axiality > 0.0 && light->projectionHorizontalRatio > 0.0
					&& light->projectionVerticalRatio > 0.0)
			{
				REAL texX =
					dot(light->lightRightVector, lightVector) / light->projectionHorizontalRatio / axiality
					+ 0.5;
				REAL texY =
					dot(light->lightTopVector, lightVector) / light->projectionVerticalRatio / axiality
					+ 0.5;

				if (light->repeatTexture || (texX > 0.0 && texX < 1.0 && texY > 0.0 && texY < 1.0))
				{
					REAL2 texturePoint = (REAL2){texX, texY};

					int2 textureSize = renderData->textureSizes[light->colorTextureIndex];
					__global uchar4 *texture = renderData->textures[light->colorTextureIndex];

					REAL3 texOut = TO_REAL3(BicubicInterpolation(
						texturePoint.x, texturePoint.y, texture, textureSize.x, textureSize.y));

					color = texOut;
					intensity = 1.0;
				}
				else
				{
					color = 0.0;
					intensity = 0.0;
				}
			}
			else
			{
				color = 0.0;
				intensity = 0.0;
			}
		}
#endif // USE_LIGHT_TEXTURE
	}

	*outColor = color;
	return intensity;
}

REAL3 LightShading(__constant sClInConstants *consts, sRenderData *renderData,
	sShaderInputDataCl *input, sClCalcParams *calcParam, REAL3 surfaceColor,
	__global sLightCl *light, sClGradientsCollection *gradients, REAL3 *outSpecular,
	REAL3 *outShadow, bool allowShadows)
{
	REAL3 shading = 0.0;

	REAL dist = 0.0;

	REAL3 lightVector = CalculateLightVector(light, input->point, input->delta,
		consts->params.resolution, consts->params.viewDistanceMax, &dist, &input->randomSeed);

	REAL intensity = 0.0;
	if (light->type == lightDirectional)
	{
		intensity = light->intensity;
	}
	else if (light->type == lightConical)
	{
		intensity = 10.0 * light->intensity;
	}
	else
	{
		intensity = 100.0 * light->intensity / LightDecay(dist, light->decayFunction) / 6.0;
	}

	REAL3 textureColor;
	intensity *= CalculateLightCone(light, renderData, input->point, lightVector, &textureColor);

	REAL shade = dot(input->normal, lightVector);
	if (shade < 0.0) shade = 0.0;
	shade = 1.0 - input->material->shading + shade * input->material->shading;

	shade = shade * intensity;
	if (shade > 500.0) shade = 500.0;

	// specular
	REAL3 specular =
		SpecularHighlightCombined(input, calcParam, lightVector, surfaceColor, gradients) * intensity;

#ifdef USE_SPECULAR_GRADIENT
	if (input->material->useColorsFromPalette && input->material->specularGradientEnable)
	{
		specular *= gradients->specular;
	}
#endif

	REAL specularMax = max(max(specular.s0, specular.s1), specular.s2);

	// calculate shadow

	REAL3 auxShadow = 1.0;
#ifdef SHADOWS
	if (allowShadows && light->castShadows)
	{
		if (shade > SHADOW_CONTRIBUTION_MIN || specularMax > SHADOW_CONTRIBUTION_MIN)
		{
			auxShadow =
				AuxShadow(consts, renderData, input, light, dist, lightVector, calcParam, light->intensity);
			specular *= auxShadow;
		}
		else
		{
			auxShadow = 0.0;
			specular = 0.0;
		}
	}
#endif // SHADOWS

	shading = shade * light->color * auxShadow * textureColor;
	*outSpecular = specular * light->color * textureColor;

	*outShadow = auxShadow;

	return shading;
}
#endif // AUX_LIGHTS
