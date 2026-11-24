/**
 * Mandelbulber v2, a 3D fractal generator       ,=#MKNmMMKmmßMNWy,
 *                                             ,B" ]L,,p%%%,,,§;, "K
 * Copyright (C) 2017-24 Mandelbulber Team     §R-==%w["'~5]m%=L.=~5N
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
 * Authors: Krzysztof Marczak (buddhi1980@gmail.com), Sebastian Jennen (jenzebas@gmail.com)
 *
 * global structs for copying data to opencl and back
 */

#ifndef OPENCL_KERNEL_CODE
#include "fractal_cl.h"
#include "hybrid_sequence_cl.h"
#include "fractparams_cl.hpp"
#include "node_data_cl.h"
#endif

#ifndef INPUT_DATA_STRUCTURES
#define INPUT_DATA_STRUCTURES

typedef struct ALIGN16
{
	// float4 keeps the main color a single 16-byte vector store; .w is unused
	// by the host but preserves the 16-byte layout of the former float3.
	cl_float4 image;
	cl_float3 normal;
	cl_float3 normalWorld;
	cl_float3 specular;
	cl_float3 diffuse;
	cl_float3 world;
	cl_float3 shadows;
	cl_float3 globalIllumination;
	cl_uchar3 color;
	cl_float zBuffer;
	cl_ushort opacity;
	cl_ushort alpha;
	// per-pixel render statistics collected inside RayMarching (full engine only);
	// final aggregation of these values is done on the CPU side
	cl_uint statsItersSum;			// sum of iterations over all CalculateDistance calls
	cl_uint statsDeCalls;				// number of CalculateDistance calls
	cl_ushort statsStepCount;		// raymarching steps of the primary ray (with binary search)
	cl_ushort statsHitIters;		// iterations at the surface hit point of the primary ray
	cl_uchar statsRaymarchings; // number of RayMarching calls (primary + bounces, saturated)
	cl_uchar statsMissedDE;			// number of missed distance estimation events (saturated)
	cl_uchar statsFlags;				// bit0: primary ray hit a surface (histogram samples valid)
	cl_uchar statsPad;					// explicit padding to keep the struct 16-byte aligned
} sClPixel;

typedef struct
{
	sParamRenderCl params;
} sClInConstants;

typedef struct
{
	cl_int dummy[256];
} sClInBuff;

typedef struct
{
	cl_uint N;
	cl_uint deltaDEMaxN;
	cl_int randomSeed;
	cl_int iterThreshMode;
	cl_int normalCalculationMode;
	cl_int orbitTrapIndex;
	REAL3 orbitTrap;
	REAL distThresh;
	REAL detailSize;
} sClCalcParams;

// ambient occlusion data
typedef struct
{
	REAL3 v;
	REAL3 color;
} sVectorsAroundCl;

#ifndef OPENCL_KERNEL_CODE
// BEGIN OPENCL_D_STRUCTS
typedef struct ALIGN_DOUBLE
{
	sParamRenderClD params;
} sClInConstantsD;

inline sClInConstantsD clPromoteSClInConstantsD(const sClInConstants &source)
{
	sClInConstantsD target;
	target.params = clPromoteSParamRenderClD(source.params);
	return target;
}

typedef struct ALIGN_DOUBLE
{
	cl_int dummy[256];
} sClInBuffD;

inline sClInBuffD clPromoteSClInBuffD(const sClInBuff &source)
{
	sClInBuffD target;
	for(int i = 0; i < 256; i++){target.dummy[i] = source.dummy[i];}
	return target;
}

typedef struct ALIGN_DOUBLE
{
	cl_uint N;
	cl_uint deltaDEMaxN;
	cl_int randomSeed;
	cl_int iterThreshMode;
	cl_int normalCalculationMode;
	cl_int orbitTrapIndex;
	cl_double3 orbitTrap;
	cl_double distThresh;
	cl_double detailSize;
} sClCalcParamsD;

inline sClCalcParamsD clPromoteSClCalcParamsD(const sClCalcParams &source)
{
	sClCalcParamsD target;
	target.N = source.N;
	target.deltaDEMaxN = source.deltaDEMaxN;
	target.randomSeed = source.randomSeed;
	target.iterThreshMode = source.iterThreshMode;
	target.normalCalculationMode = source.normalCalculationMode;
	target.orbitTrapIndex = source.orbitTrapIndex;
	target.orbitTrap = toClDouble3(source.orbitTrap);
	target.distThresh = source.distThresh;
	target.detailSize = source.detailSize;
	return target;
}

typedef struct ALIGN_DOUBLE
{
	cl_double3 v;
	cl_double3 color;
} sVectorsAroundClD;

inline sVectorsAroundClD clPromoteSVectorsAroundClD(const sVectorsAroundCl &source)
{
	sVectorsAroundClD target;
	target.v = toClDouble3(source.v);
	target.color = toClDouble3(source.color);
	return target;
}
// END OPENCL_D_STRUCTS
#endif /* OPENCL_KERNEL_CODE */

#endif // INPUT_DATA_STRUCTURES
