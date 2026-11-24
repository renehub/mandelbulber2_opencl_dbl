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
 * mathematical algebra code for opencl
 */

#ifndef MANDELBULBER2_OPENCL_ALGEBRA_HPP_
#define MANDELBULBER2_OPENCL_ALGEBRA_HPP_

#ifndef OPENCL_KERNEL_CODE
#include "src/include_header_wrapper.hpp"
#include <QString>

#include "src/algebra.hpp"
#include "src/color_structures.hpp"
#endif

typedef struct
{
	REAL3 m1;
	REAL3 m2;
	REAL3 m3;
} matrix33;

typedef struct
{
	REAL4 r1;
	REAL4 r2;
	REAL4 r3;
	REAL4 r4;
} matrix44;

#ifndef OPENCL_KERNEL_CODE
typedef struct
{
	cl_double3 m1;
	cl_double3 m2;
	cl_double3 m3;
} matrix33D;

typedef struct
{
	cl_double4 r1;
	cl_double4 r2;
	cl_double4 r3;
	cl_double4 r4;
} matrix44D;
#endif

#ifndef OPENCL_KERNEL_CODE
inline matrix33 toClMatrix33(CRotationMatrix source)
{
	CMatrix33 matrix = source.GetMatrix();
	matrix33 m;
	m.m1 = {{cl_float(matrix.m11), cl_float(matrix.m12), cl_float(matrix.m13), cl_float(0.0)}};
	m.m2 = {{cl_float(matrix.m21), cl_float(matrix.m22), cl_float(matrix.m23), cl_float(0.0)}};
	m.m3 = {{cl_float(matrix.m31), cl_float(matrix.m32), cl_float(matrix.m33), cl_float(0.0)}};
	return m;
}
inline cl_float2 toClFloat2(CVector2<double> v)
{
	cl_float2 retVal = {{cl_float(v.x), cl_float(v.y)}};
	return retVal;
}
inline cl_float3 toClFloat3(CVector3 v)
{
	cl_float3 retVal = {{cl_float(v.x), cl_float(v.y), cl_float(v.z), cl_float(0.0)}};
	return retVal;
}
inline cl_int3 toClInt3(int x, int y, int z)
{
	cl_int3 retVal = {{cl_int(x), cl_int(y), cl_int(z), cl_int(0)}};
	return retVal;
}
inline cl_int3 toClInt3(sRGB c)
{
	cl_int3 retVal = {{cl_int(c.R), cl_int(c.G), cl_int(c.B), cl_int(1)}};
	return retVal;
}
inline cl_float3 toClFloat3(sRGBFloat c)
{
	cl_float3 retVal = {{cl_float(c.R), cl_float(c.G), cl_float(c.B), cl_float(1.0f)}};
	return retVal;
}
inline cl_float4 toClFloat4(CVector4 v)
{
	cl_float4 retVal = {{cl_float(v.x), cl_float(v.y), cl_float(v.z), cl_float(v.w)}};
	return retVal;
}
inline cl_float4 toClFloat4(sRGBAFloat v)
{
	cl_float4 retVal = {{cl_float(v.R), cl_float(v.G), cl_float(v.B), cl_float(v.A)}};
	return retVal;
}
inline cl_float2 toClFloat2(cl_float2 v)
{
	return v;
}
inline cl_float2 toClFloat2(cl_double2 v)
{
	cl_float2 retVal = {{cl_float(v.x), cl_float(v.y)}};
	return retVal;
}
inline cl_float3 toClFloat3(cl_float3 v)
{
	return v;
}
inline cl_float3 toClFloat3(cl_double3 v)
{
	cl_float3 retVal = {{cl_float(v.x), cl_float(v.y), cl_float(v.z), cl_float(0.0)}};
	return retVal;
}
inline cl_float4 toClFloat4(cl_float4 v)
{
	return v;
}
inline cl_float4 toClFloat4(cl_double4 v)
{
	cl_float4 retVal = {{cl_float(v.x), cl_float(v.y), cl_float(v.z), cl_float(v.w)}};
	return retVal;
}

inline cl_double2 toClDouble2(CVector2<double> v)
{
	cl_double2 retVal = {{cl_double(v.x), cl_double(v.y)}};
	return retVal;
}
inline cl_double3 toClDouble3(CVector3 v)
{
	cl_double3 retVal = {{cl_double(v.x), cl_double(v.y), cl_double(v.z), cl_double(0.0)}};
	return retVal;
}
inline cl_double4 toClDouble4(CVector4 v)
{
	cl_double4 retVal = {{cl_double(v.x), cl_double(v.y), cl_double(v.z), cl_double(v.w)}};
	return retVal;
}
inline cl_double3 toClDouble3(sRGBFloat c)
{
	cl_double3 retVal = {{cl_double(c.R), cl_double(c.G), cl_double(c.B), cl_double(1.0)}};
	return retVal;
}
inline cl_double4 toClDouble4(sRGBAFloat c)
{
	cl_double4 retVal = {{cl_double(c.R), cl_double(c.G), cl_double(c.B), cl_double(c.A)}};
	return retVal;
}
inline cl_double2 toClDouble2(cl_float2 v)
{
	cl_double2 retVal = {{cl_double(v.x), cl_double(v.y)}};
	return retVal;
}
inline cl_double3 toClDouble3(cl_float3 v)
{
	cl_double3 retVal = {{cl_double(v.x), cl_double(v.y), cl_double(v.z), cl_double(0.0)}};
	return retVal;
}
inline cl_double4 toClDouble4(cl_float4 v)
{
	cl_double4 retVal = {{cl_double(v.x), cl_double(v.y), cl_double(v.z), cl_double(v.w)}};
	return retVal;
}
inline matrix33D toClMatrix33D(CRotationMatrix source)
{
	CMatrix33 matrix = source.GetMatrix();
	matrix33D m;
	m.m1 = {{cl_double(matrix.m11), cl_double(matrix.m12), cl_double(matrix.m13), cl_double(0.0)}};
	m.m2 = {{cl_double(matrix.m21), cl_double(matrix.m22), cl_double(matrix.m23), cl_double(0.0)}};
	m.m3 = {{cl_double(matrix.m31), cl_double(matrix.m32), cl_double(matrix.m33), cl_double(0.0)}};
	return m;
}
inline matrix33 toClFloatMatrix33(const matrix33D &source)
{
	matrix33 m;
	m.m1 = {{cl_float(source.m1.x), cl_float(source.m1.y), cl_float(source.m1.z), cl_float(0.0)}};
	m.m2 = {{cl_float(source.m2.x), cl_float(source.m2.y), cl_float(source.m2.z), cl_float(0.0)}};
	m.m3 = {{cl_float(source.m3.x), cl_float(source.m3.y), cl_float(source.m3.z), cl_float(0.0)}};
	return m;
}
inline matrix33D toClMatrix33D(const matrix33 &source)
{
	matrix33D m;
	m.m1 = {{cl_double(source.m1.x), cl_double(source.m1.y), cl_double(source.m1.z), cl_double(0.0)}};
	m.m2 = {{cl_double(source.m2.x), cl_double(source.m2.y), cl_double(source.m2.z), cl_double(0.0)}};
	m.m3 = {{cl_double(source.m3.x), cl_double(source.m3.y), cl_double(source.m3.z), cl_double(0.0)}};
	return m;
}

inline matrix44 toClMatrix44(const CMatrix44 &source)
{
	matrix44 m;
	m.r1 = {{cl_float(source.m11), cl_float(source.m12), cl_float(source.m13),
		cl_float(source.m14)}};
	m.r2 = {{cl_float(source.m21), cl_float(source.m22), cl_float(source.m23),
		cl_float(source.m24)}};
	m.r3 = {{cl_float(source.m31), cl_float(source.m32), cl_float(source.m33),
		cl_float(source.m34)}};
	m.r4 = {{cl_float(source.m41), cl_float(source.m42), cl_float(source.m43),
		cl_float(source.m44)}};
	return m;
}

inline matrix44 toClMatrix44(const CRotationMatrix44 &source)
{
	return toClMatrix44(source.GetMatrix());
}

inline matrix44D toClMatrix44D(const CMatrix44 &source)
{
	matrix44D m;
	m.r1 = {{cl_double(source.m11), cl_double(source.m12), cl_double(source.m13),
		cl_double(source.m14)}};
	m.r2 = {{cl_double(source.m21), cl_double(source.m22), cl_double(source.m23),
		cl_double(source.m24)}};
	m.r3 = {{cl_double(source.m31), cl_double(source.m32), cl_double(source.m33),
		cl_double(source.m34)}};
	m.r4 = {{cl_double(source.m41), cl_double(source.m42), cl_double(source.m43),
		cl_double(source.m44)}};
	return m;
}

inline matrix44D toClMatrix44D(const CRotationMatrix44 &source)
{
	return toClMatrix44D(source.GetMatrix());
}

inline matrix44 toClFloatMatrix44(const matrix44D &source)
{
	matrix44 m;
	m.r1 = {{cl_float(source.r1.x), cl_float(source.r1.y), cl_float(source.r1.z),
		cl_float(source.r1.w)}};
	m.r2 = {{cl_float(source.r2.x), cl_float(source.r2.y), cl_float(source.r2.z),
		cl_float(source.r2.w)}};
	m.r3 = {{cl_float(source.r3.x), cl_float(source.r3.y), cl_float(source.r3.z),
		cl_float(source.r3.w)}};
	m.r4 = {{cl_float(source.r4.x), cl_float(source.r4.y), cl_float(source.r4.z),
		cl_float(source.r4.w)}};
	return m;
}
inline matrix44D toClMatrix44D(const matrix44 &source)
{
	matrix44D m;
	m.r1 = {{cl_double(source.r1.x), cl_double(source.r1.y), cl_double(source.r1.z),
		cl_double(source.r1.w)}};
	m.r2 = {{cl_double(source.r2.x), cl_double(source.r2.y), cl_double(source.r2.z),
		cl_double(source.r2.w)}};
	m.r3 = {{cl_double(source.r3.x), cl_double(source.r3.y), cl_double(source.r3.z),
		cl_double(source.r3.w)}};
	m.r4 = {{cl_double(source.r4.x), cl_double(source.r4.y), cl_double(source.r4.z),
		cl_double(source.r4.w)}};
	return m;
}

#endif

#ifdef OPENCL_KERNEL_CODE

inline REAL4 Matrix33MulFloat4(matrix33 matrix, REAL4 vect)
{
	REAL4 out;
	out.x = dot(vect.xyz, matrix.m1);
	out.y = dot(vect.xyz, matrix.m2);
	out.z = dot(vect.xyz, matrix.m3);
	out.w = vect.w;
	return out;
}

inline REAL3 Matrix33MulFloat3(matrix33 matrix, REAL3 vect)
{
	REAL3 out;
	out.x = dot(vect.xyz, matrix.m1);
	out.y = dot(vect.xyz, matrix.m2);
	out.z = dot(vect.xyz, matrix.m3);
	return out;
}

inline REAL3 Matrix44TransformPoint(matrix44 matrix, REAL3 point)
{
	REAL3 out;
	out.x = dot((REAL4){point.x, point.y, point.z, 1.0}, matrix.r1);
	out.y = dot((REAL4){point.x, point.y, point.z, 1.0}, matrix.r2);
	out.z = dot((REAL4){point.x, point.y, point.z, 1.0}, matrix.r3);
	return out;
}

matrix33 Matrix33MulMatrix33(matrix33 m1, matrix33 m2)
{
	matrix33 out;
	out.m1.x = m1.m1.x * m2.m1.x + m1.m1.y * m2.m2.x + m1.m1.z * m2.m3.x;
	out.m1.y = m1.m1.x * m2.m1.y + m1.m1.y * m2.m2.y + m1.m1.z * m2.m3.y;
	out.m1.z = m1.m1.x * m2.m1.z + m1.m1.y * m2.m2.z + m1.m1.z * m2.m3.z;
	out.m2.x = m1.m2.x * m2.m1.x + m1.m2.y * m2.m2.x + m1.m2.z * m2.m3.x;
	out.m2.y = m1.m2.x * m2.m1.y + m1.m2.y * m2.m2.y + m1.m2.z * m2.m3.y;
	out.m2.z = m1.m2.x * m2.m1.z + m1.m2.y * m2.m2.z + m1.m2.z * m2.m3.z;
	out.m3.x = m1.m3.x * m2.m1.x + m1.m3.y * m2.m2.x + m1.m3.z * m2.m3.x;
	out.m3.y = m1.m3.x * m2.m1.y + m1.m3.y * m2.m2.y + m1.m3.z * m2.m3.y;
	out.m3.z = m1.m3.x * m2.m1.z + m1.m3.y * m2.m2.z + m1.m3.z * m2.m3.z;
	return out;
}

matrix33 RotateX(matrix33 m, REAL angle)
{
	matrix33 out, rot;
	REAL s = sin(angle);
	REAL c = cos(angle);
	rot.m1 = (REAL3){1.0, 0.0, 0.0};
	rot.m2 = (REAL3){0.0, c, -s};
	rot.m3 = (REAL3){0.0, s, c};
	out = Matrix33MulMatrix33(m, rot);
	return out;
}

matrix33 RotateY(matrix33 m, REAL angle)
{
	matrix33 out, rot;
	REAL s = sin(angle);
	REAL c = cos(angle);
	rot.m1 = (REAL3){c, 0.0, s};
	rot.m2 = (REAL3){0.0, 1.0, 0.0};
	rot.m3 = (REAL3){-s, 0.0, c};
	out = Matrix33MulMatrix33(m, rot);
	return out;
}

matrix33 RotateZ(matrix33 m, REAL angle)
{
	matrix33 out, rot;
	REAL s = sin(angle);
	REAL c = cos(angle);
	rot.m1 = (REAL3){c, -s, 0.0};
	rot.m2 = (REAL3){s, c, 0.0};
	rot.m3 = (REAL3){0.0, 0.0, 1.0};
	out = Matrix33MulMatrix33(m, rot);
	return out;
}

REAL3 RotateAroundVectorByAngle(REAL3 origin, REAL3 axis, REAL angle)
{
	REAL3 vector = origin * cos(angle);
	vector += cross(axis, origin) * sin(angle);
	vector += axis * dot(axis, origin) * (1.0 - cos(angle));
	return vector;
}

REAL4 RotateAroundVectorByAngle4(REAL4 origin4d, REAL3 axis, REAL angle)
{
	REAL3 origin = origin4d.xyz;
	REAL3 vector = origin * cos(angle);
	vector += cross(axis, origin) * sin(angle);
	vector += axis * dot(axis, origin) * (1.0 - cos(angle));
	return (REAL4){vector.x, vector.y, vector.z, origin4d.w};
}

inline matrix33 TransposeMatrix(matrix33 m)
{
	matrix33 out;
	out.m1 = (REAL3){m.m1.x, m.m2.x, m.m3.x};
	out.m2 = (REAL3){m.m1.y, m.m2.y, m.m3.y};
	out.m3 = (REAL3){m.m1.z, m.m2.z, m.m3.z};
	return out;
}

REAL SmoothConditionAGreaterB(REAL a, REAL b, REAL sharpness)
{
#ifdef DOUBLE_FAST_RADIUS
	// Double exp is a software sequence on most GPUs. Under fast relaxed math
	// the blend factor is accurate enough in float, where native_exp is a
	// single hardware instruction.
	const float e = native_exp((float)(sharpness * (b - a)));
	return (REAL)native_recip(1.0f + e);
#else
	return native_recip(1.0 + native_exp(sharpness * (b - a)));
#endif
}

REAL SmoothConditionALessB(REAL a, REAL b, REAL sharpness)
{
#ifdef DOUBLE_FAST_RADIUS
	const float e = native_exp((float)(sharpness * (a - b)));
	return (REAL)native_recip(1.0f + e);
#else
	return native_recip(1.0 + native_exp(sharpness * (a - b)));
#endif
}

inline REAL3 wrap(REAL3 x, REAL3 a, REAL3 s)
{
	x -= s;
	REAL3 out;
	out.x = x.x - a.x * floor(x.x / a.x) + s.x;
	out.y = x.y - a.y * floor(x.y / a.y) + s.y;
	out.z = x.z - a.z * floor(x.z / a.z) + s.z;
	return out;
}

// ref https://iquilezles.org/articles/distfunctions/
inline REAL opSmoothUnion(REAL d1, REAL d2, REAL k)
{
	REAL h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
	return mix(d2, d1, h) - k * h * (1.0 - h);
}

// Fast real power for the formula kernels. In double precision OpenCL's pow()
// is an exp2/log2 software sequence on most GPUs, while formula powers are very
// often small integer values stored as REAL parameters. Use exponentiation by
// squaring for those and fall back to pow() for fractional exponents.
inline REAL PowR(REAL x, REAL y)
{
	if (y >= 0.0 && y <= 1024.0)
	{
		const int n = (int)y;
		if ((REAL)n == y)
		{
			REAL result = 1.0;
			REAL base = x;
			int e = n;
			while (e > 0)
			{
				if (e & 1) result *= base;
				e >>= 1;
				if (e) base *= base;
			}
			return result;
		}
	}
	return pow(x, y);
}

// Radius used by the fractal iteration. This is called once per fractal
// iteration and used to be written as length(z), which generates significantly
// slower code than an explicit sqrt(dot(z, z)) in the double kernels. Under
// fast-relaxed-math the sqrt itself is evaluated in float and promoted; the
// radius only scales the DE, so this changes the image at roughly the 1e-7
// relative level while the iteration itself stays double. Disable fast math to
// get the exact double sqrt.
inline REAL CalcRadius(REAL4 z)
{
	const REAL r2 = dot(z, z);
#ifdef DOUBLE_PRECISION
#ifdef DOUBLE_FAST_RADIUS
	// Fall back to the double path for values that would overflow float.
	if (r2 < 1.0e37) return convert_double(sqrt(convert_float(r2)));
	return sqrt(r2);
#else
	return sqrt(r2);
#endif
#else
	return sqrt(r2);
#endif
}

//********** Random ******************************
int RandomInt(int *randomSeed)
{
	int s = *randomSeed;
	//	int const a = 15484817;
	//	int const m = 6571759;
	//	s = ((long)(s * a)) % m;
	s = (s * 0x5DEECE66DL + 0xBL) & ((1L << 48) - 1);
	if (s < 0) s = -s;
	return *randomSeed = s;
}

uint RandomLong(ulong *randomSeed)
{
	ulong s = *randomSeed;
	s = (s * 0x5DEECE66DL + 0xBL) & ((1L << 48) - 1);
	*randomSeed = s;
	return s >> 16;
}

int Random(int max, int *randomSeed)
{
	return RandomInt(randomSeed) % (max + 1);
}

uint RandomL(uint max, ulong *randomSeed)
{
	return RandomLong(randomSeed) % (max + 1);
}

inline REAL3 vectorMod(REAL3 vector1, REAL3 vector2)
{
	return (REAL3){(vector2.x > 0.0 ? fmod(vector1.x, vector2.x) : vector1.x),
		(vector2.y > 0.0 ? fmod(vector1.y, vector2.y) : vector1.y),
		(vector2.z > 0.0 ? fmod(vector1.z, vector2.z) : vector1.z)};
}

inline REAL3 modRepeat(REAL3 vector1, REAL3 repeat)
{
	if (length(repeat) == 0.0) return vector1;
	return vectorMod((vectorMod((vector1 - repeat * 0.5), repeat) + repeat), repeat) - repeat * 0.5;
}

#ifdef ITERATION_WEIGHT
REAL4 SmoothCVector(const REAL4 v1, const REAL4 v2, REAL k)
{
	REAL4 result;
	REAL nk = 1.0 - k;

	if (k <= 0.0)
	{
		result = v1;
	}
	else if (k >= 1.0)
	{
		result = v2;
	}
	else
	{
		REAL length1 = length(v1);
		REAL length2 = length(v2);
		REAL lenInterp = length1 * nk + length2 * k;
		REAL4 vTemp = v1 * nk + v2 * k;
		REAL lengthTemp = length(vTemp);
		if (lengthTemp > 0.0)
		{
			result = (vTemp / lengthTemp) * lenInterp;
		}
		else
		{
			result = v1;
		}
	}
	return result;
}
#endif

inline REAL LengthPow(REAL2 vect, REAL p)
{
	return pow(pow(vect.x, p) + pow(vect.y, p), 1.0 / p);
}

inline REAL GetAlpha(REAL3 vect)
{
	return atan2(vect.y, vect.x);
}

inline REAL GetBeta(REAL3 vect)
{
	return atan2(vect.z, length(vect.xy));
}

#endif

#endif // MANDELBULBER2_OPENCL_ALGEBRA_HPP_
