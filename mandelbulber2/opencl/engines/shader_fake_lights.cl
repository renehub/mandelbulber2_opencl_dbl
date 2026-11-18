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
 * calculation light sources based on fractal orbit traps
 */

#ifdef FAKE_LIGHTS
REAL3 FakeLightsShader(__constant sClInConstants *consts, sShaderInputDataCl *input,
	sClCalcParams *calcParams, REAL3 surfaceColor, sClGradientsCollection *gradients,
	REAL3 *specularOut, sRenderData *renderData)
{
	REAL3 fakeLights = 0.0;

	int fakeLightMaxLoop = 1;
	if (consts->params.common.fakeLightsColor2Enabled) fakeLightMaxLoop = 2;
	if (consts->params.common.fakeLightsColor3Enabled) fakeLightMaxLoop = 3;

	// The orbit trap is evaluated in the object local space (the space in which the
	// distance calculation iterates the fractal orbit). Using the world space point
	// makes the light ignore the object tree transform: the light stays in place when
	// the object is moved or rotated and only the primary copy of a repeated object
	// gets lit.
	REAL3 lightPoint = GetFractalPoint(input);

	// Finite differences for the light normal are taken along the local axes, so the
	// shading normal has to be rotated into the same space (same convention as texture
	// mapping). The step is also converted to local units by the object scale.
	REAL delta = input->distThresh * consts->params.smoothness;
	REAL3 shadingNormal = input->normal;
	if (input->hasTransformedPoint && input->objectId >= 0
			&& input->objectId < renderData->numberOfObjects)
	{
		__global sObjectDataCl *objectData = &renderData->objectsData[input->objectId];
		if (objectData->absScale > 0.0) delta /= objectData->absScale;
		shadingNormal = Matrix33MulFloat3(TransposeMatrix(objectData->rotationMatrix), input->normal);
	}

	for (int fakeLightLoop = 0; fakeLightLoop < fakeLightMaxLoop; fakeLightLoop++)
	{
		calcParams->orbitTrapIndex = fakeLightLoop;
		formulaOut outF;
		outF = Fractal(consts, lightPoint, calcParams, calcModeOrbitTrap, NULL, -1, renderData, 0,
			input->transformedPoint, input->hasTransformedPoint);
		REAL rr = outF.orbitTrapR;
		REAL r = 1.0 / (rr + 1e-20);

		REAL fakeLight = consts->params.fakeLightsIntensity / r;

		REAL3 out;
		calcParams->distThresh = input->distThresh;
		calcParams->detailSize = input->delta;

		outF =
			Fractal(consts, lightPoint + (REAL3){delta, 0.0, 0.0}, calcParams, calcModeOrbitTrap,
				NULL, -1, renderData, 0, input->transformedPoint, input->hasTransformedPoint);
		REAL rx = 1.0 / (outF.orbitTrapR + 1e-30);

		outF =
			Fractal(consts, lightPoint + (REAL3){0.0, delta, 0.0}, calcParams, calcModeOrbitTrap,
				NULL, -1, renderData, 0, input->transformedPoint, input->hasTransformedPoint);
		REAL ry = 1.0 / (outF.orbitTrapR + 1e-30);

		outF =
			Fractal(consts, lightPoint + (REAL3){0.0, 0.0, delta}, calcParams, calcModeOrbitTrap,
				NULL, -1, renderData, 0, input->transformedPoint, input->hasTransformedPoint);
		REAL rz = 1.0 / (outF.orbitTrapR + 1e-30);

		REAL3 fakeLightNormal;
		fakeLightNormal.x = r - rx;
		fakeLightNormal.y = r - ry;
		fakeLightNormal.z = r - rz;

		fakeLightNormal = normalize(fakeLightNormal);

		REAL fakeLight2 = fakeLight * dot(shadingNormal, fakeLightNormal);
		if (fakeLight2 < 0.0) fakeLight2 = 0.0;

		REAL3 color;
		switch (fakeLightLoop)
		{
			case 0: color = TO_REAL3(consts->params.fakeLightsColor); break;
			case 1: color = TO_REAL3(consts->params.fakeLightsColor2); break;
			case 2: color = TO_REAL3(consts->params.fakeLightsColor3); break;
			default: color = TO_REAL3(consts->params.fakeLightsColor); break;
		}

		fakeLights += fakeLight2 * color;

		//	REAL3 fakeSpec =
		//		SpecularHighlightCombined(input, calcParams, fakeLightNormal, surfaceColor, gradients);
		//	fakeSpec = fakeSpec * consts->params.fakeLightsColor / r;
	}
	REAL3 fakeSpec = 0.0; // TODO to check why in CPU code it's zero
	*specularOut = fakeSpec;
	return fakeLights;
}
#endif // FAKE_LIGTS
