/**
 * Mandelbulber v2, a 3D fractal generator       ,=#MKNmMMKmmßMNWy,
 *                                             ,B" ]L,,p%%%,,,§;, "K
 * Copyright (C) 2018-23 Mandelbulber Team     §R-==%w["'~5]m%=L.=~5N
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
 * data structures for primitive objects for OpenCL kernels
 */

#ifndef MANDELBULBER2_OPENCL_PRIMITIVES_CL_H_
#define MANDELBULBER2_OPENCL_PRIMITIVES_CL_H_

#ifndef OPENCL_KERNEL_CODE
#include "object_data_cl.h"
#include "opencl_algebra.h"
#endif

typedef enum
{
	clPrimBooleanOperatorAND = 0,
	clPrimBooleanOperatorOR = 1,
	clPrimBooleanOperatorSUB = 2,
	clPrimBooleanOperatorRevSUB = 3
} enumClPrimitiveBooleanOperator;

// primitive specified parameters
typedef struct ALIGN_REAL
{
	cl_int empty;
} sPrimitivePlaneCl;

typedef struct ALIGN_REAL
{
	REAL3 limitsMax;
	REAL3 limitsMin;
	REAL rounding;
	cl_int empty;
	cl_int limitsEnable;


} sPrimitiveBoxCl;

typedef struct ALIGN_REAL
{
	REAL3 limitsMax;
	REAL3 limitsMin;
	REAL radius;
	cl_int empty;
	cl_int limitsEnable;


} sPrimitiveSphereCl;

typedef struct ALIGN_REAL
{
	REAL3 limitsMax;
	REAL3 limitsMin;
	REAL relativeAmplitude;
	REAL animSpeed;
	REAL animProgressionSpeed;
	REAL length;
	REAL waveFromObjectsRelativeAmplitude;
	cl_int empty;
	cl_int limitsEnable;
	cl_int waveFromObjectsEnable;
	cl_int iterations;
	cl_int animFrame;

} sPrimitiveWaterCl;

typedef struct ALIGN_REAL
{
	REAL3 limitsMax;
	REAL3 limitsMin;
	REAL2 wallNormal;
	REAL radius;
	REAL height;
	cl_int empty;
	cl_int caps;
	cl_int limitsEnable;

} sPrimitiveConeCl;

typedef struct ALIGN_REAL
{
	REAL3 limitsMax;
	REAL3 limitsMin;
	REAL radius;
	REAL height;
	cl_int empty;
	cl_int caps;
	cl_int limitsEnable;
} sPrimitiveCylinderCl;

typedef struct ALIGN_REAL
{
	REAL3 limitsMax;
	REAL3 limitsMin;
	REAL radius;
	REAL radiusLPow;
	REAL tubeRadius;
	REAL tubeRadiusLPow;
	cl_int empty;
	cl_int limitsEnable;
} sPrimitiveTorusCl;

typedef struct ALIGN_REAL
{
	REAL radius;
} sPrimitiveCircleCl;

typedef struct ALIGN_REAL
{
	REAL height;
	REAL width;
} sPrimitiveRectangleCl;

typedef struct ALIGN_REAL
{
	REAL3 normals;
	REAL triangleHeight;
	REAL height;
	REAL prismAngle;
	cl_int empty;
} sPrimitivePrismCl;

typedef struct ALIGN_REAL
{
	REAL3 limitsMax;
	REAL3 limitsMin;
	cl_int empty;
	cl_int limitsEnable;
} sPrimitiveEllipsoidCl;

typedef struct ALIGN_REAL
{
	matrix33 mRotAllPrimitivesRotation;
	REAL3 allPrimitivesPosition;
	REAL3 allPrimitivesRotation;

	cl_int primitiveIndexForBasicFog;
	cl_int primitiveIndexForDistFog;
	cl_int primitiveIndexForIterFog;
	cl_int primitiveIndexForClouds;
} sPrimitiveGlobalDataCl;

// union - variable container for primitive data
typedef union ALIGN_REAL
{
	sPrimitivePlaneCl plane;
	sPrimitiveBoxCl box;
	sPrimitiveSphereCl sphere;
	sPrimitiveWaterCl water;
	sPrimitiveConeCl cone;
	sPrimitiveCylinderCl cylinder;
	sPrimitiveTorusCl torus;
	sPrimitiveCircleCl circle;
	sPrimitiveRectangleCl rectangle;
	sPrimitivePrismCl prism;
	sPrimitiveEllipsoidCl ellipsoid;
} uPrimitiveCl;

// full definition of primitive
typedef struct ALIGN_REAL
{
	sObjectDataCl object; // structure
	uPrimitiveCl data;		// union !!!
	enumClPrimitiveBooleanOperator booleanOperator;
} sPrimitiveCl;

#ifndef OPENCL_KERNEL_CODE
// BEGIN OPENCL_D_STRUCTS
typedef struct ALIGN_DOUBLE
{
	cl_int empty;
} sPrimitivePlaneClD;

inline sPrimitivePlaneClD clPromoteSPrimitivePlaneClD(const sPrimitivePlaneCl &source)
{
	sPrimitivePlaneClD target;
	target.empty = source.empty;
	return target;
}

typedef struct ALIGN_DOUBLE
{
	cl_double3 limitsMax;
	cl_double3 limitsMin;
	cl_double rounding;
	cl_int empty;
	cl_int limitsEnable;
} sPrimitiveBoxClD;

inline sPrimitiveBoxClD clPromoteSPrimitiveBoxClD(const sPrimitiveBoxCl &source)
{
	sPrimitiveBoxClD target;
	target.limitsMax = toClDouble3(source.limitsMax);
	target.limitsMin = toClDouble3(source.limitsMin);
	target.rounding = source.rounding;
	target.empty = source.empty;
	target.limitsEnable = source.limitsEnable;
	return target;
}

typedef struct ALIGN_DOUBLE
{
	cl_double3 limitsMax;
	cl_double3 limitsMin;
	cl_double radius;
	cl_int empty;
	cl_int limitsEnable;
} sPrimitiveSphereClD;

inline sPrimitiveSphereClD clPromoteSPrimitiveSphereClD(const sPrimitiveSphereCl &source)
{
	sPrimitiveSphereClD target;
	target.limitsMax = toClDouble3(source.limitsMax);
	target.limitsMin = toClDouble3(source.limitsMin);
	target.radius = source.radius;
	target.empty = source.empty;
	target.limitsEnable = source.limitsEnable;
	return target;
}

typedef struct ALIGN_DOUBLE
{
	cl_double3 limitsMax;
	cl_double3 limitsMin;
	cl_double relativeAmplitude;
	cl_double animSpeed;
	cl_double animProgressionSpeed;
	cl_double length;
	cl_double waveFromObjectsRelativeAmplitude;
	cl_int empty;
	cl_int limitsEnable;
	cl_int waveFromObjectsEnable;
	cl_int iterations;
	cl_int animFrame;
} sPrimitiveWaterClD;

inline sPrimitiveWaterClD clPromoteSPrimitiveWaterClD(const sPrimitiveWaterCl &source)
{
	sPrimitiveWaterClD target;
	target.limitsMax = toClDouble3(source.limitsMax);
	target.limitsMin = toClDouble3(source.limitsMin);
	target.relativeAmplitude = source.relativeAmplitude;
	target.animSpeed = source.animSpeed;
	target.animProgressionSpeed = source.animProgressionSpeed;
	target.length = source.length;
	target.waveFromObjectsRelativeAmplitude = source.waveFromObjectsRelativeAmplitude;
	target.empty = source.empty;
	target.limitsEnable = source.limitsEnable;
	target.waveFromObjectsEnable = source.waveFromObjectsEnable;
	target.iterations = source.iterations;
	target.animFrame = source.animFrame;
	return target;
}

typedef struct ALIGN_DOUBLE
{
	cl_double3 limitsMax;
	cl_double3 limitsMin;
	cl_double2 wallNormal;
	cl_double radius;
	cl_double height;
	cl_int empty;
	cl_int caps;
	cl_int limitsEnable;
} sPrimitiveConeClD;

inline sPrimitiveConeClD clPromoteSPrimitiveConeClD(const sPrimitiveConeCl &source)
{
	sPrimitiveConeClD target;
	target.limitsMax = toClDouble3(source.limitsMax);
	target.limitsMin = toClDouble3(source.limitsMin);
	target.wallNormal = toClDouble2(source.wallNormal);
	target.radius = source.radius;
	target.height = source.height;
	target.empty = source.empty;
	target.caps = source.caps;
	target.limitsEnable = source.limitsEnable;
	return target;
}

typedef struct ALIGN_DOUBLE
{
	cl_double3 limitsMax;
	cl_double3 limitsMin;
	cl_double radius;
	cl_double height;
	cl_int empty;
	cl_int caps;
	cl_int limitsEnable;
} sPrimitiveCylinderClD;

inline sPrimitiveCylinderClD clPromoteSPrimitiveCylinderClD(const sPrimitiveCylinderCl &source)
{
	sPrimitiveCylinderClD target;
	target.limitsMax = toClDouble3(source.limitsMax);
	target.limitsMin = toClDouble3(source.limitsMin);
	target.radius = source.radius;
	target.height = source.height;
	target.empty = source.empty;
	target.caps = source.caps;
	target.limitsEnable = source.limitsEnable;
	return target;
}

typedef struct ALIGN_DOUBLE
{
	cl_double3 limitsMax;
	cl_double3 limitsMin;
	cl_double radius;
	cl_double radiusLPow;
	cl_double tubeRadius;
	cl_double tubeRadiusLPow;
	cl_int empty;
	cl_int limitsEnable;
} sPrimitiveTorusClD;

inline sPrimitiveTorusClD clPromoteSPrimitiveTorusClD(const sPrimitiveTorusCl &source)
{
	sPrimitiveTorusClD target;
	target.limitsMax = toClDouble3(source.limitsMax);
	target.limitsMin = toClDouble3(source.limitsMin);
	target.radius = source.radius;
	target.radiusLPow = source.radiusLPow;
	target.tubeRadius = source.tubeRadius;
	target.tubeRadiusLPow = source.tubeRadiusLPow;
	target.empty = source.empty;
	target.limitsEnable = source.limitsEnable;
	return target;
}

typedef struct ALIGN_DOUBLE
{
	cl_double radius;
} sPrimitiveCircleClD;

inline sPrimitiveCircleClD clPromoteSPrimitiveCircleClD(const sPrimitiveCircleCl &source)
{
	sPrimitiveCircleClD target;
	target.radius = source.radius;
	return target;
}

typedef struct ALIGN_DOUBLE
{
	cl_double height;
	cl_double width;
} sPrimitiveRectangleClD;

inline sPrimitiveRectangleClD clPromoteSPrimitiveRectangleClD(const sPrimitiveRectangleCl &source)
{
	sPrimitiveRectangleClD target;
	target.height = source.height;
	target.width = source.width;
	return target;
}

typedef struct ALIGN_DOUBLE
{
	cl_double3 normals;
	cl_double triangleHeight;
	cl_double height;
	cl_double prismAngle;
	cl_int empty;
} sPrimitivePrismClD;

inline sPrimitivePrismClD clPromoteSPrimitivePrismClD(const sPrimitivePrismCl &source)
{
	sPrimitivePrismClD target;
	target.normals = toClDouble3(source.normals);
	target.triangleHeight = source.triangleHeight;
	target.height = source.height;
	target.prismAngle = source.prismAngle;
	target.empty = source.empty;
	return target;
}

typedef struct ALIGN_DOUBLE
{
	cl_double3 limitsMax;
	cl_double3 limitsMin;
	cl_int empty;
	cl_int limitsEnable;
} sPrimitiveEllipsoidClD;

inline sPrimitiveEllipsoidClD clPromoteSPrimitiveEllipsoidClD(const sPrimitiveEllipsoidCl &source)
{
	sPrimitiveEllipsoidClD target;
	target.limitsMax = toClDouble3(source.limitsMax);
	target.limitsMin = toClDouble3(source.limitsMin);
	target.empty = source.empty;
	target.limitsEnable = source.limitsEnable;
	return target;
}

typedef struct ALIGN_DOUBLE
{
	matrix33D mRotAllPrimitivesRotation;
	cl_double3 allPrimitivesPosition;
	cl_double3 allPrimitivesRotation;

	cl_int primitiveIndexForBasicFog;
	cl_int primitiveIndexForDistFog;
	cl_int primitiveIndexForIterFog;
	cl_int primitiveIndexForClouds;
} sPrimitiveGlobalDataClD;

inline sPrimitiveGlobalDataClD clPromoteSPrimitiveGlobalDataClD(const sPrimitiveGlobalDataCl &source)
{
	sPrimitiveGlobalDataClD target;
	target.mRotAllPrimitivesRotation = toClMatrix33D(source.mRotAllPrimitivesRotation);
	target.allPrimitivesPosition = toClDouble3(source.allPrimitivesPosition);
	target.allPrimitivesRotation = toClDouble3(source.allPrimitivesRotation);
	target.primitiveIndexForBasicFog = source.primitiveIndexForBasicFog;
	target.primitiveIndexForDistFog = source.primitiveIndexForDistFog;
	target.primitiveIndexForIterFog = source.primitiveIndexForIterFog;
	target.primitiveIndexForClouds = source.primitiveIndexForClouds;
	return target;
}

typedef union ALIGN_DOUBLE
{
	sPrimitivePlaneClD plane;
	sPrimitiveBoxClD box;
	sPrimitiveSphereClD sphere;
	sPrimitiveWaterClD water;
	sPrimitiveConeClD cone;
	sPrimitiveCylinderClD cylinder;
	sPrimitiveTorusClD torus;
	sPrimitiveCircleClD circle;
	sPrimitiveRectangleClD rectangle;
	sPrimitivePrismClD prism;
	sPrimitiveEllipsoidClD ellipsoid;
} uPrimitiveClD;

inline uPrimitiveClD clPromoteUPrimitiveClD(const uPrimitiveCl &source)
{
	uPrimitiveClD target;
	target.plane = clPromoteSPrimitivePlaneClD(source.plane);
	target.box = clPromoteSPrimitiveBoxClD(source.box);
	target.sphere = clPromoteSPrimitiveSphereClD(source.sphere);
	target.water = clPromoteSPrimitiveWaterClD(source.water);
	target.cone = clPromoteSPrimitiveConeClD(source.cone);
	target.cylinder = clPromoteSPrimitiveCylinderClD(source.cylinder);
	target.torus = clPromoteSPrimitiveTorusClD(source.torus);
	target.circle = clPromoteSPrimitiveCircleClD(source.circle);
	target.rectangle = clPromoteSPrimitiveRectangleClD(source.rectangle);
	target.prism = clPromoteSPrimitivePrismClD(source.prism);
	target.ellipsoid = clPromoteSPrimitiveEllipsoidClD(source.ellipsoid);
	return target;
}

typedef struct ALIGN_DOUBLE
{
	sObjectDataClD object; // structure
	uPrimitiveClD data;		// union !!!
	enumClPrimitiveBooleanOperator booleanOperator;
} sPrimitiveClD;

inline sPrimitiveClD clPromoteSPrimitiveClD(const sPrimitiveCl &source)
{
	sPrimitiveClD target;
	target.object = clPromoteSObjectDataClD(source.object);
	target.data = clPromoteUPrimitiveClD(source.data);
	target.booleanOperator = source.booleanOperator;
	return target;
}
// END OPENCL_D_STRUCTS
#endif /* OPENCL_KERNEL_CODE */

#endif /* MANDELBULBER2_OPENCL_PRIMITIVES_CL_H_ */
