/**
 * Mandelbulber v2, a 3D fractal generator       ,=#MKNmMMKmmßMNWy,
 *                                             ,B" ]L,,p%%%,,,§;, "K
 * Copyright (C) 2021-22 Mandelbulber Team     §R-==%w["'~5]m%=L.=~5N
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
 * TODO: description
 */

#ifndef MANDELBULBER2_OPENCL_LIGHT_CL_H_
#define MANDELBULBER2_OPENCL_LIGHT_CL_H_

#ifndef OPENCL_KERNEL_CODE
#include "opencl_algebra.h"
#endif /* OPENCL_KERNEL_CODE */

typedef enum
{
	lightDirectional = 0,
	lightPoint = 1,
	lightConical = 2,
	lightProjection = 3,
	lightBeam = 4
} enumLightTypeCl;

typedef enum
{
	lightDecay1R = 0,
	lightDecay1R2 = 1,
	lightDecay1R3 = 2,
} enumLightDecayFunctionCl;

typedef struct ALIGN_REAL
{
	REAL3 color;
	
	REAL3 position;
	REAL3 rotation;
	REAL3 target;
	REAL3 lightDirection;
	REAL3 lightTopVector;
	REAL3 lightRightVector;
		
	matrix33 rotMatrix;

	REAL coneSoftAngle;
	REAL intensity;
	REAL visibility;
	REAL volumetricVisibility;
	REAL size;
	REAL softShadowCone;
	REAL contourSharpness;
	
	REAL coneRatio;
	REAL coneSoftRatio;
	
	REAL projectionHorizontalRatio;
	REAL projectionVerticalRatio;
	
	REAL coneAngle;
	
	// booleans
	cl_int enabled;
	cl_int castShadows;
	cl_int penetrating;
	cl_int relativePosition;
	cl_int repeatTexture;
	cl_int volumetric;
	
	cl_int colorTextureIndex;

	// enums
	enumLightTypeCl type;
	enumLightDecayFunctionCl decayFunction;

} sLightCl;

#ifndef OPENCL_KERNEL_CODE
// BEGIN OPENCL_D_STRUCTS
typedef struct ALIGN_DOUBLE
{
	cl_double3 color;
	
	cl_double3 position;
	cl_double3 rotation;
	cl_double3 target;
	cl_double3 lightDirection;
	cl_double3 lightTopVector;
	cl_double3 lightRightVector;
		
	matrix33D rotMatrix;

	cl_double coneSoftAngle;
	cl_double intensity;
	cl_double visibility;
	cl_double volumetricVisibility;
	cl_double size;
	cl_double softShadowCone;
	cl_double contourSharpness;
	
	cl_double coneRatio;
	cl_double coneSoftRatio;
	
	cl_double projectionHorizontalRatio;
	cl_double projectionVerticalRatio;
	
	cl_double coneAngle;
	
	// booleans
	cl_int enabled;
	cl_int castShadows;
	cl_int penetrating;
	cl_int relativePosition;
	cl_int repeatTexture;
	cl_int volumetric;
	
	cl_int colorTextureIndex;

	// enums
	enumLightTypeCl type;
	enumLightDecayFunctionCl decayFunction;
} sLightClD;

inline sLightClD clPromoteSLightClD(const sLightCl &source)
{
	sLightClD target;
	target.color = toClDouble3(source.color);
	target.position = toClDouble3(source.position);
	target.rotation = toClDouble3(source.rotation);
	target.target = toClDouble3(source.target);
	target.lightDirection = toClDouble3(source.lightDirection);
	target.lightTopVector = toClDouble3(source.lightTopVector);
	target.lightRightVector = toClDouble3(source.lightRightVector);
	target.rotMatrix = toClMatrix33D(source.rotMatrix);
	target.coneSoftAngle = source.coneSoftAngle;
	target.intensity = source.intensity;
	target.visibility = source.visibility;
	target.volumetricVisibility = source.volumetricVisibility;
	target.size = source.size;
	target.softShadowCone = source.softShadowCone;
	target.contourSharpness = source.contourSharpness;
	target.coneRatio = source.coneRatio;
	target.coneSoftRatio = source.coneSoftRatio;
	target.projectionHorizontalRatio = source.projectionHorizontalRatio;
	target.projectionVerticalRatio = source.projectionVerticalRatio;
	target.coneAngle = source.coneAngle;
	target.enabled = source.enabled;
	target.castShadows = source.castShadows;
	target.penetrating = source.penetrating;
	target.relativePosition = source.relativePosition;
	target.repeatTexture = source.repeatTexture;
	target.volumetric = source.volumetric;
	target.colorTextureIndex = source.colorTextureIndex;
	target.type = static_cast<enumLightTypeCl>(source.type);
	target.decayFunction = static_cast<enumLightDecayFunctionCl>(source.decayFunction);
	return target;
}
// END OPENCL_D_STRUCTS
#endif /* OPENCL_KERNEL_CODE */

#endif /* MANDELBULBER2_OPENCL_LIGHT_CL_H_ */
