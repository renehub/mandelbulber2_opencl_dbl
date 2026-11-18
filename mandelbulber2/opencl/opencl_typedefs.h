/**
 * Mandelbulber v2, a 3D fractal generator       ,=#MKNmMMKmmßMNWy,
 *                                             ,B" ]L,,p%%%,,,§;, "K
 * Copyright (C) 2017-22 Mandelbulber Team     §R-==%w["'~5]m%=L.=~5N
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
 * type definitions for binding the opencl c++ API types to the cl pendants
 */

#ifndef MANDELBULBER2_OPENCL_OPENCL_TYPEDEFS_H_
#define MANDELBULBER2_OPENCL_OPENCL_TYPEDEFS_H_

typedef float4 cl_float4;
typedef float3 cl_float3;
typedef float2 cl_float2;
typedef float cl_float;
typedef int3 cl_int3;
typedef int cl_int;
typedef unsigned int cl_uint;
typedef unsigned short cl_ushort;
typedef uchar cl_uchar;
typedef uchar3 cl_uchar3;
typedef uchar4 cl_uchar4;

#ifndef DOUBLE_PRECISION
#define REAL float
#define REAL2 float2
#define REAL3 float3
#define REAL4 float4
#else
#define REAL double
#define REAL2 double2
#define REAL3 double3
#define REAL4 double4
#endif

/* Convert single-precision data (textures, palettes, image2d_t pixels) to the
 * current REAL vector type. In single mode the conversion is a no-op. */
#ifdef DOUBLE_PRECISION
#define TO_REAL2(v) convert_double2(v)
#define TO_REAL3(v) convert_double3(v)
#define TO_REAL4(v) convert_double4(v)
/* Convert REAL shading results back to the single-precision storage used by
 * textures, palettes and image pixels. */
#define TO_CL_FLOAT2(v) convert_float2(v)
#define TO_CL_FLOAT3(v) convert_float3(v)
#define TO_CL_FLOAT4(v) convert_float4(v)
#else
#define TO_REAL2(v) (v)
#define TO_REAL3(v) (v)
#define TO_REAL4(v) (v)
#define TO_CL_FLOAT2(v) (v)
#define TO_CL_FLOAT3(v) (v)
#define TO_CL_FLOAT4(v) (v)
#endif

#ifdef DOUBLE_PRECISION
/* Native math functions are float-only in OpenCL. In double precision mode
 * map them to the standard functions so formula and engine code stays valid
 * and does not silently fall back to single precision. */
#define native_exp(x) exp(x)
#define native_log(x) log(x)
#define native_sqrt(x) sqrt(x)
#define native_rsqrt(x) rsqrt(x)
#define native_sin(x) sin(x)
#define native_cos(x) cos(x)
#define native_recip(x) (1.0 / (x))
#define native_divide(a, b) ((a) / (b))
#define native_powr(a, b) powr(a, b)
#define fast_length(x) length(x)
#define fast_normalize(x) normalize(x)
#endif

#ifndef NULL
#define NULL 0
#endif

#endif /* MANDELBULBER2_OPENCL_OPENCL_TYPEDEFS_H_ */
