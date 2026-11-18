/**
 * Mandelbulber v2, a 3D fractal generator       ,=#MKNmMMKmmßMNWy,
 *                                             ,B" ]L,,p%%%,,,§;, "K
 * Copyright (C) 2025 Mandelbulber Team        §R-==%w["'~5]m%=L.=~5N
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
 * OpenCL representation of node data for objects tree rendering
 * Corresponds to CPU-side cObjectsTree::sNodeDataForRendering
 */

#ifndef MANDELBULBER2_OPENCL_NODE_DATA_CL_H_
#define MANDELBULBER2_OPENCL_NODE_DATA_CL_H_

#ifndef OPENCL_KERNEL_CODE
#include "opencl_algebra.h"
#endif

typedef enum
{
	nodeTypeFractal = 1,
	nodeTypePrimitive = 2,
	nodeTypeHybrid = 10,
	nodeTypeBooleanAdd = 11,
	nodeTypeBooleanMul = 12,
	nodeTypeBooleanSub = 13,
} enumNodeTypeCl;

// Node data for rendering - corresponds to CPU cObjectsTree::sNodeDataForRendering
typedef struct ALIGN_REAL
{
	matrix33 rotationMatrix;
	matrix44 worldToLocalMatrix;
	
	REAL3 repeat;
	REAL3 julia_c;
	REAL3 fractal_constant_factor;
	
	REAL scale;
	REAL absScale;
	REAL detailLevelMultiplier;
	REAL initial_waxis;
	REAL smooth_de_combine_distance;
	
	cl_int id;
	cl_int parentId;
	cl_int userObjectId;
	cl_int internalObjectId;
	cl_int primitiveIdx;
	cl_int level;
	cl_int hybridSequenceIndex;
	cl_int material;
	cl_int enabled;

	// Common fractal parameters shared by all node types (including boolean groups)
	cl_int julia_mode;
	cl_int smooth_de_combine_enable;

	cl_int formula_maxiter;
	
		enumNodeTypeCl type;
} sNodeDataForRenderingCl;

#ifndef OPENCL_KERNEL_CODE
// BEGIN OPENCL_D_STRUCTS
typedef struct ALIGN_DOUBLE
{
	matrix33D rotationMatrix;
	matrix44D worldToLocalMatrix;
	
	cl_double3 repeat;
	cl_double3 julia_c;
	cl_double3 fractal_constant_factor;
	
	cl_double scale;
	cl_double absScale;
	cl_double detailLevelMultiplier;
	cl_double initial_waxis;
	cl_double smooth_de_combine_distance;
	
	cl_int id;
	cl_int parentId;
	cl_int userObjectId;
	cl_int internalObjectId;
	cl_int primitiveIdx;
	cl_int level;
	cl_int hybridSequenceIndex;
	cl_int material;
	cl_int enabled;

	// Common fractal parameters shared by all node types (including boolean groups)
	cl_int julia_mode;
	cl_int smooth_de_combine_enable;

	cl_int formula_maxiter;
	
		enumNodeTypeCl type;
} sNodeDataForRenderingClD;

inline sNodeDataForRenderingClD clPromoteSNodeDataForRenderingClD(const sNodeDataForRenderingCl &source)
{
	sNodeDataForRenderingClD target;
	target.rotationMatrix = toClMatrix33D(source.rotationMatrix);
	target.worldToLocalMatrix = toClMatrix44D(source.worldToLocalMatrix);
	target.repeat = toClDouble3(source.repeat);
	target.julia_c = toClDouble3(source.julia_c);
	target.fractal_constant_factor = toClDouble3(source.fractal_constant_factor);
	target.scale = source.scale;
	target.absScale = source.absScale;
	target.detailLevelMultiplier = source.detailLevelMultiplier;
	target.initial_waxis = source.initial_waxis;
	target.smooth_de_combine_distance = source.smooth_de_combine_distance;
	target.id = source.id;
	target.parentId = source.parentId;
	target.userObjectId = source.userObjectId;
	target.internalObjectId = source.internalObjectId;
	target.primitiveIdx = source.primitiveIdx;
	target.level = source.level;
	target.hybridSequenceIndex = source.hybridSequenceIndex;
	target.material = source.material;
	target.enabled = source.enabled;
	target.julia_mode = source.julia_mode;
	target.smooth_de_combine_enable = source.smooth_de_combine_enable;
	target.formula_maxiter = source.formula_maxiter;
	target.type = static_cast<enumNodeTypeCl>(source.type);
	return target;
}
// END OPENCL_D_STRUCTS
#endif /* OPENCL_KERNEL_CODE */

#endif /* MANDELBULBER2_OPENCL_NODE_DATA_CL_H_ */
