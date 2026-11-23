/**
 * Mandelbulber v2, a 3D fractal generator       ,=#MKNmMMKmmßMNWy,
 *                                             ,B" ]L,,p%%%,,,§;, "K
 * Copyright (C) 2017-19 Mandelbulber Team     §R-==%w["'~5]m%=L.=~5N
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
 * Normal vector calculation for opencl
 */

REAL3 NormalVector(__constant sClInConstants *consts, sRenderData *renderData, REAL3 point,
	REAL mainDistance, REAL distThresh, REAL invertMode, sClCalcParams *calcParam)
{
#ifndef SLOW_SHADING
	REAL delta = distThresh * consts->params.smoothness;
#ifdef INTERIOR_MODE
	delta = calcParam->distThresh * 0.2 * consts->params.smoothness;
#endif

	calcParam->distThresh = distThresh;
	calcParam->detailSize = distThresh;
	calcParam->normalCalculationMode = true;

	// Tetrahedral normal estimator: four diagonal distance samples instead of
	// six axis-aligned central differences. Same O(h^2) gradient accuracy with
	// two fewer DE calls per normal.
	const REAL3 k = (REAL3){1.0, -1.0, -1.0};
	const REAL s0 =
		CalculateDistance(consts, point + k.xyy * delta, calcParam, renderData).distance;
	const REAL s1 =
		CalculateDistance(consts, point + k.yyx * delta, calcParam, renderData).distance;
	const REAL s2 =
		CalculateDistance(consts, point + k.yxy * delta, calcParam, renderData).distance;
	const REAL s3 =
		CalculateDistance(consts, point + k.xxx * delta, calcParam, renderData).distance;

	REAL3 normal = k.xyy * s0 + k.yyx * s1 + k.yxy * s2 + k.xxx * s3;
	normal = normalize(normal);
	calcParam->normalCalculationMode = false;

	if (invertMode) normal *= -1.0;

	return normal;
#else

	// calculating normal vector based on average value of binary central difference

	REAL3 point2;
	REAL3 point3;

	REAL delta = calcParam->detailSize * consts->params.smoothness;
#ifdef INTERIOR_MODE
	delta = calcParam->distThresh * 0.2 * consts->params.smoothness;
#endif

	formulaOut out;
	out.z = (REAL4)(0.0, 0.0, 0.0, 0.0);
	out.iters = 0;
	out.distance = 0.0;
	out.colorIndex = 0.0;
	out.orbitTrapR = 0.0;
	out.maxiter = false;
	out.objectId = 0;

	REAL3 normal = 0.0;
	for (point2.x = -1.0; point2.x <= 1.0; point2.x += 0.2) //+0.2
	{
		for (point2.y = -1.0; point2.y <= 1.0; point2.y += 0.2)
		{
			for (point2.z = -1.0; point2.z <= 1.0; point2.z += 0.2)
			{
				point3 = point + point2 * delta;

				out = Fractal(
					consts, point3, calcParam, calcModeNormal, NULL, -1, renderData, 0, point3, false);
				REAL pseudoDistance = 1.0 + consts->params.N - out.iters;
				normal += point2 * pseudoDistance;
			}
		}
	}
	normal = normalize(normal);

	if (invertMode) normal *= -1.0;

	return normal;
#endif
}
