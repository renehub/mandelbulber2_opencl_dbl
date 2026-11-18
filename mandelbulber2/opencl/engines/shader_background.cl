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
 * calculates background
 */

__constant sampler_t sampler = CLK_NORMALIZED_COORDS_TRUE | CLK_ADDRESS_REPEAT | CLK_FILTER_LINEAR;

//-------------- background shaders ---------------

REAL3 BackgroundShader(__constant sClInConstants *consts, sRenderData *renderData,
	image2d_t image2dBackground, sShaderInputDataCl *input)
{
	REAL3 pixel;
	REAL3 viewVectorNorm = input->viewVector;
	viewVectorNorm = normalize(viewVectorNorm);

#ifdef TEXTURED_BACKGROUND

#ifdef BACKGROUND_EQUIRECTANGULAR
	REAL3 rotatedViewVector =
		Matrix33MulFloat3(consts->params.mRotBackgroundRotation, input->viewVector);

	REAL alphaTexture =
		fmod(-atan2(rotatedViewVector.y, rotatedViewVector.x) + 3.5 * M_PI_F, 2.0 * M_PI_F);
	REAL betaTexture = -atan2(rotatedViewVector.z, length(rotatedViewVector.xy));
	if (betaTexture > 0.5 * M_PI_F) betaTexture = 0.5 * M_PI_F - betaTexture;
	if (betaTexture < -0.5 * M_PI_F) betaTexture = -0.5 * M_PI_F + betaTexture;
	REAL2 texCord;
	texCord.x = alphaTexture / (2.0 * M_PI_F) / consts->params.backgroundHScale
							+ consts->params.backgroundTextureOffsetX;
	texCord.y = (betaTexture / (M_PI_F) + 0.5) / consts->params.backgroundVScale
							+ consts->params.backgroundTextureOffsetY;
	float4 pixelTex = read_imagef(image2dBackground, sampler, convert_float2(texCord));

	pixel = TO_REAL3(pixelTex.xyz);
#endif // BACKGROUND_EQUIRECTANGULAR

#ifdef BACKGROUND_FLAT
	REAL3 vect = Matrix33MulFloat3(renderData->mRotInv, input->viewVector);
	vect = Matrix33MulFloat3(consts->params.mRotBackgroundRotation, vect);

	REAL2 tex;
	if (fabs(vect.y) > 1e-10)
	{
		tex.x =
			vect.x / vect.y / consts->params.fov * consts->params.imageHeight / consts->params.imageWidth;
		tex.y = -vect.z / vect.y / consts->params.fov;
	}
	else
	{
		tex.x = vect.x > 0.0 ? 1.0 : -1.0;
		tex.y = vect.z > 0.0 ? -1.0 : 1.0;
	}

	tex.x =
		(tex.x / consts->params.backgroundHScale) + 0.5 + consts->params.backgroundTextureOffsetX;
	tex.y =
		(tex.y / consts->params.backgroundVScale) + 0.5 + consts->params.backgroundTextureOffsetY;

	float4 pixelTex = read_imagef(image2dBackground, sampler, convert_float2(tex));
	pixel = TO_REAL3(pixelTex.xyz);
#endif // BACKGROUND_FLAT

#ifdef BACKGROUND_DOUBLE_HEMISPHERE
	REAL3 rotatedViewVector =
		Matrix33MulFloat3(consts->params.mRotBackgroundRotation, input->viewVector);
	REAL alphaTexture = atan2(rotatedViewVector.y, rotatedViewVector.x);
	REAL betaTexture = atan2(rotatedViewVector.z, length(rotatedViewVector.xy));

	REAL offset = 0.0;
	if (betaTexture < 0.0)
	{
		betaTexture = -betaTexture;
		alphaTexture = M_PI_F - alphaTexture;
		offset = 0.5;
	}

	REAL2 tex;
	tex.x = 0.25 + cos(alphaTexture) * (1.0 - betaTexture / (0.5 * M_PI_F)) * 0.25 + offset;
	tex.y = 0.5 + sin(alphaTexture) * (1.0 - betaTexture / (0.5 * M_PI_F)) * 0.5;
	float4 pixelTex = read_imagef(image2dBackground, sampler, convert_float2(tex));
	pixel = TO_REAL3(pixelTex.xyz);

#endif

#else	 // TEXTURED_BACKGROUND

	if (consts->params.background3ColorsEnable)
	{
		REAL3 vector = (REAL3){0.0, 0.0, 1.0};
		vector = normalize(vector);
		REAL grad = dot(viewVectorNorm, vector) + 1.0;

		if (grad < 1.0)
		{
			REAL gradN = 1.0 - grad;
			pixel = TO_REAL3(consts->params.background_color3) * gradN
			+ TO_REAL3(consts->params.background_color2) * grad;
		}
		else
		{
			grad = grad - 1.0;
			REAL gradN = 1.0 - grad;
			pixel = TO_REAL3(consts->params.background_color2) * gradN
			+ TO_REAL3(consts->params.background_color1) * grad;
		}
	}
	else
	{
		pixel = TO_REAL3(consts->params.background_color1);
	}
#endif // TEXTURED_BACKGROUND

	pixel *= consts->params.background_brightness;
	pixel = pow(pixel, 1.0 / consts->params.background_gamma);

	for (int i = 0; i < renderData->numberOfLights; i++)
	{
		__global sLightCl *light = &renderData->lights[i];
		if (light->enabled && light->type == lightDirectional)
		{
			REAL intensity = -(dot(viewVectorNorm, light->lightDirection) - 1.0) * 360.0 / light->size;
			intensity = 1.0 / (1.0 + pow(intensity, 6.0 * light->contourSharpness)) * light->visibility
									* light->intensity;
			pixel += intensity * light->color;
		}
	}

	return pixel;
}
