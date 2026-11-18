/**
 * Mandelbulber v2, a 3D fractal generator       ,=#MKNmMMKmmßMNWy,
 *                                             ,B" ]L,,p%%%,,,§;, "K
 * Copyright (C) 2019 Mandelbulber Team        §R-==%w["'~5]m%=L.=~5N
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
 * calculation of distance from orbit trap for "fake lights"
 */

#ifdef FAKE_LIGHTS

REAL OrbitTrapShapeDistance(REAL4 z4, __constant sClInConstants *consts)
{
	REAL dist = 0.0;
	REAL3 z = z4.xyz;
	REAL3 delta = z - consts->params.common.fakeLightsOrbitTrap;

#ifdef FAKE_LIGHTS_POINT
	dist = length(delta);
#endif

#ifdef FAKE_LIGHTS_LINE
	delta = Matrix33MulFloat3(consts->params.common.mRotFakeLightsRotation, delta);
	dist = length(delta.yz);
#endif

#ifdef FAKE_LIGHTS_CIRCLE
	delta = Matrix33MulFloat3(consts->params.common.mRotFakeLightsRotation, delta);
	REAL lengthYZ = length(delta.yz) - consts->params.common.fakeLightsOrbitTrapSize;
	dist = length((REAL2){lengthYZ, delta.x});
#endif

#ifdef FAKE_LIGHTS_SQUARE
	delta = Matrix33MulFloat3(consts->params.common.mRotFakeLightsRotation, delta);
	REAL size = consts->params.common.fakeLightsOrbitTrapSize;

	REAL dy = max(fabs(fabs(delta.y) - size), fabs(delta.z) - size);
	REAL dz = max(fabs(fabs(delta.z) - size), fabs(delta.y) - size);
	REAL deltaRect = min(dy, dz);
	dist = length((REAL2){deltaRect, delta.x});
#endif

#ifdef FAKE_LIGHTS_SPHERE
	delta = Matrix33MulFloat3(consts->params.common.mRotFakeLightsRotation, delta);
	REAL lengthYZ = length(delta.yz) - consts->params.common.fakeLightsOrbitTrapSize;
	REAL distYZ = length((REAL2){lengthYZ, delta.x});

	REAL lengthXZ = length(delta.xz) - consts->params.common.fakeLightsOrbitTrapSize;
	REAL distXZ = length((REAL2){lengthXZ, delta.y});

	REAL lengthXY = length(delta.xy) - consts->params.common.fakeLightsOrbitTrapSize;
	REAL distXY = length((REAL2){lengthXY, delta.z});

	dist = min(min(distYZ, distXZ), distXY);
#endif

#ifdef FAKE_LIGHTS_CUBE
	delta = Matrix33MulFloat3(consts->params.common.mRotFakeLightsRotation, delta);
	REAL size = consts->params.common.fakeLightsOrbitTrapSize;

	REAL dy_x = max(fabs(fabs(delta.y) - size), fabs(delta.z) - size);
	REAL dz_x = max(fabs(fabs(delta.z) - size), fabs(delta.y) - size);
	REAL dx_z = max(fabs(fabs(delta.y) - size), fabs(delta.x) - size);
	REAL deltaRectYZ = min(dy_x, dz_x);
	REAL distYZ = length((REAL2){deltaRectYZ, fabs(fabs(delta.x) - size)});
	REAL distXZ = length((REAL2){dx_z, fabs(fabs(z.z) - size)});

	dist = min(distYZ, distXZ);
#endif

	return dist / consts->params.common.fakeLightsThickness;
}

#endif // FAKE_LIGHTS
