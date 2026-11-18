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
 * Bump Map displacement by adding effect to existing distance
 */

#ifdef USE_TEXTURES
#ifdef USE_DISPLACEMENT_TEXTURE

REAL DisplacementMap(
	REAL oldDistance, REAL3 point, int objectId, sRenderData *renderData, REAL reduce)
{
	REAL distance = oldDistance;

	__global sObjectDataCl *objectData = &renderData->objectsData[objectId];
	__global sMaterialCl *mat = renderData->materials[objectData->materialId];
	int textureIndex = mat->displacementTextureIndex;

	if (textureIndex >= 0)
	{
		REAL2 texturePoint = TextureMapping(point, (REAL3){0.0, 0.0, 1.0}, objectData, mat, 0, 0);

		texturePoint += (REAL2){0.5, 0.5};

		if (!isfinite(texturePoint.x) || !isfinite(texturePoint.y))
		{
			return distance;
		}

		int2 textureSize = renderData->textureSizes[textureIndex];
		__global uchar4 *texture = renderData->textures[textureIndex];

		// Texture sampling stays single precision; only the resulting displacement
		// contribution is promoted to REAL for distance calculations.
		REAL pixel = BicubicInterpolationGrey16(
			(float)texturePoint.x, (float)texturePoint.y, texture, textureSize.x, textureSize.y);

		REAL bump = pixel;
		distance -= bump * mat->displacementTextureHeight / reduce;
		if (distance < 0.0) distance = 0.0;
	}

	return distance;
}
#endif // USE_DISPLACEMENT_TEXTURE
#endif // USE_TEXTURES

#ifdef FRACTALIZE_TEXTURE
REAL3 FractalizeTexture(REAL3 point, __constant sClInConstants *consts, sClCalcParams *calcParams,
	sRenderData *renderData, int objectId, int sequenceIndex, REAL *reduceDisplacement)
{
	int forcedFormulaIndex = objectId;
	if (objectId < 0) objectId = 0;

	__global sObjectDataCl *objectData = &renderData->objectsData[objectId];
	__global sMaterialCl *mat = renderData->materials[objectData->materialId];

	REAL3 pointFractalized = point;

	// texture fractalize requires a valid fractal sequence; primitives (sequenceIndex < 0)
	// have no fractal iteration, so the option is silently ignored for them
	if (mat->textureFractalize && sequenceIndex >= 0)
	{
		formulaOut outF;
		outF = Fractal(consts, point, calcParams, calcModeCubeOrbitTrap, mat, -1, renderData,
			sequenceIndex, point, false);
		pointFractalized = outF.z.xyz;
		*reduceDisplacement = pow(2.0, outF.iters);
	}

	return pointFractalized;
}
#endif // FRACTALIZE_TEXTURE
