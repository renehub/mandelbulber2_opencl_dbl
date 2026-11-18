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
 * calculation of distance to primitive objects for opencl
 */

#ifdef USE_PRIMITIVES

#ifdef USE_PRIMITIVE_PLANE
REAL PrimitivePlane(__global sPrimitiveCl *primitive, REAL3 _point)
{
	REAL3 point = _point;
	REAL dist = point.z;
	dist = primitive->data.plane.empty ? fabs(dist) : dist;
	dist = max(dist - primitive->object.wallThickness, 0.0);
	return dist;
}
#endif

#ifdef USE_PRIMITIVE_BOX
REAL PrimitiveBox(__global sPrimitiveCl *primitive, REAL3 _point)
{
	REAL3 point = _point;

	REAL boxDist = -1e6;
	if (primitive->data.box.empty)
	{
		boxDist = max(fabs(point.x) - primitive->object.size.x * 0.5, boxDist);
		boxDist = max(fabs(point.y) - primitive->object.size.y * 0.5, boxDist);
		boxDist = max(fabs(point.z) - primitive->object.size.z * 0.5, boxDist);
		boxDist = fabs(boxDist);
	}
	else
	{
		REAL3 boxTemp;
		boxTemp.x = max(fabs(point.x) - primitive->object.size.x * 0.5, 0.0);
		boxTemp.y = max(fabs(point.y) - primitive->object.size.y * 0.5, 0.0);
		boxTemp.z = max(fabs(point.z) - primitive->object.size.z * 0.5, 0.0);
		boxDist = length(boxTemp) - primitive->data.box.rounding;
	}

	boxDist = max(boxDist - primitive->object.wallThickness, 0.0);

	if (primitive->data.box.limitsEnable)
	{
		REAL3 distanceAxial =
			max(point - primitive->data.box.limitsMax, primitive->data.box.limitsMin - point);
		REAL limitBoxDist = max(max(distanceAxial.x, distanceAxial.y), distanceAxial.z);
		boxDist = max(boxDist, limitBoxDist);
	}
	return boxDist;
}
#endif

#ifdef USE_PRIMITIVE_SPHERE
REAL PrimitiveSphere(__global sPrimitiveCl *primitive, REAL3 _point)
{
	REAL3 point = _point;
	REAL dist = length(point) - primitive->data.sphere.radius;
	dist = primitive->data.sphere.empty ? fabs(dist) : dist;
	dist = max(dist - primitive->object.wallThickness, 0.0);

	if (primitive->data.sphere.limitsEnable)
	{
		REAL3 distanceAxial =
			max(point - primitive->data.sphere.limitsMax, primitive->data.sphere.limitsMin - point);
		REAL limitBoxDist = max(max(distanceAxial.x, distanceAxial.y), distanceAxial.z);
		dist = max(dist, limitBoxDist);
	}
	return dist;
}
#endif

#ifdef USE_PRIMITIVE_RECTANGLE
REAL PrimitiveRectangle(__global sPrimitiveCl *primitive, REAL3 _point)
{
	REAL3 point = _point;
	REAL3 boxTemp;
	boxTemp.x = max(fabs(point.x) - primitive->data.rectangle.width * 0.5, 0.0);
	boxTemp.y = max(fabs(point.y) - primitive->data.rectangle.height * 0.5, 0.0);
	boxTemp.z = fabs(point.z);
	return length(boxTemp);
}
#endif

#ifdef USE_PRIMITIVE_CYLINDER
REAL PrimitiveCylinder(__global sPrimitiveCl *primitive, REAL3 _point)
{
	REAL3 point = _point;
	REAL2 cylTemp = (REAL2){point.x, point.y};
	REAL dist = length(cylTemp) - primitive->data.cylinder.radius;
	if (!primitive->data.cylinder.caps) dist = fabs(dist);
	dist = max(fabs(point.z) - primitive->data.cylinder.height * 0.5, dist);
	dist = primitive->data.cylinder.empty ? fabs(dist) : dist;
	dist = max(dist - primitive->object.wallThickness, 0.0);

	if (primitive->data.cylinder.limitsEnable)
	{
		REAL3 distanceAxial =
			max(point - primitive->data.cylinder.limitsMax, primitive->data.cylinder.limitsMin - point);
		REAL limitBoxDist = max(max(distanceAxial.x, distanceAxial.y), distanceAxial.z);
		dist = max(dist, limitBoxDist);
	}
	return dist;
}
#endif

#ifdef USE_PRIMITIVE_CIRCLE
REAL PrimitiveCircle(__global sPrimitiveCl *primitive, REAL3 _point)
{
	REAL3 point = _point;
	REAL2 circleTemp = (REAL2){point.x, point.y};
	REAL distTemp = length(circleTemp) - primitive->data.circle.radius;
	distTemp = max(fabs(point.z), distTemp);
	return distTemp;
}
#endif

#ifdef USE_PRIMITIVE_CONE
REAL PrimitiveCone(__global sPrimitiveCl *primitive, REAL3 _point)
{
	REAL3 point = _point;
	point.z -= primitive->data.cone.height;
	REAL q = sqrt(point.x * point.x + point.y * point.y);
	REAL2 vect = (REAL2){q, point.z};
	REAL dist = dot(primitive->data.cone.wallNormal, vect);
	if (!primitive->data.cone.caps) dist = fabs(dist);
	dist = max(-point.z - primitive->data.cone.height, dist);
	dist = primitive->data.cone.empty ? fabs(dist) : dist;
	dist = max(dist - primitive->object.wallThickness, 0.0);

	if (primitive->data.cone.limitsEnable)
	{
		REAL3 distanceAxial =
			max(point - primitive->data.cone.limitsMax, primitive->data.cone.limitsMin - point);
		REAL limitBoxDist = max(max(distanceAxial.x, distanceAxial.y), distanceAxial.z);
		dist = max(dist, limitBoxDist);
	}
	return dist;
}
#endif

#ifdef USE_PRIMITIVE_WATER
REAL PrimitiveWater(__global sPrimitiveCl *primitive, REAL3 _point, REAL distanceFromAnother)
{
	REAL3 point = _point;

	REAL length = primitive->data.water.length;
	if (primitive->data.water.waveFromObjectsEnable)
	{
		point.x += length * 20.0 * exp(-distanceFromAnother / length / 5.0)
							 * primitive->data.water.waveFromObjectsRelativeAmplitude;
	}

	REAL amplitude = length * primitive->data.water.relativeAmplitude;
	REAL objectWave = 0.0;

	REAL planeDistance = point.z;
	if (planeDistance < amplitude * 10.0)
	{
		REAL phase = -primitive->data.water.animSpeed * primitive->data.water.animFrame * 0.1;

		if (primitive->data.water.waveFromObjectsEnable)
		{
			objectWave = sin(distanceFromAnother / length * 5.0 - phase * 2.0)
									 * exp(-distanceFromAnother / length / 5.0)
									 * primitive->data.water.waveFromObjectsRelativeAmplitude;
		}

		REAL k = 0.23;
		REAL waveXTemp;
		REAL waveYTemp;
		REAL waveX = objectWave;
		REAL waveY = -objectWave;
		REAL p = 1.0;
		REAL p2 = 0.05;

		point.x += phase * 0.05 * (primitive->data.water.animProgressionSpeed * 3.0 - 3.0);

		for (int i = 1; i <= primitive->data.water.iterations; i++)
		{
			REAL p3 = p * p2;
			REAL shift = phase / (i / 2.697 + 1.0);
			waveXTemp = sin(i + 0.4 * (waveX)*p3 + sin(k * point.y / length * p3 + shift * 0.134 * p3)
											+ point.x / length * p3 + shift * p3)
									/ p;
			waveYTemp = cos(i + 0.4 * (waveY)*p3 + sin(point.x / length * p3 + shift * 0.0179 * p3)
											+ k * point.y / length * p3 + shift * 0.023 * p3)
									/ p;
			waveX += waveXTemp;
			waveY += waveYTemp;
			p2 = p2 + (1.0 - p2 + 0.5 * sin(shift * 0.0323)) * 0.7;
			p *= 1.872;
		}

		planeDistance += (waveX + waveY) * amplitude;
	}
	planeDistance = primitive->data.water.empty ? fabs(planeDistance) : planeDistance;
	planeDistance = max(planeDistance - primitive->object.wallThickness, 0.0);

	if (primitive->data.water.limitsEnable)
	{
		REAL3 distanceAxial =
			max(point - primitive->data.water.limitsMax, primitive->data.water.limitsMin - point);
		REAL limitBoxDist = max(max(distanceAxial.x, distanceAxial.y), distanceAxial.z);
		planeDistance = max(planeDistance, limitBoxDist);
	}
	return planeDistance;
}
#endif

#ifdef USE_PRIMITIVE_TORUS
REAL PrimitiveTorus(__global sPrimitiveCl *primitive, REAL3 _point)
{
	REAL3 point = _point;

	REAL2 pointXY = (REAL2){point.x, point.y};
	REAL d1 =
		LengthPow(pointXY, pow(2.0, primitive->data.torus.radiusLPow)) - primitive->data.torus.radius;
	REAL2 pointDZ = (REAL2){d1, point.z};

	REAL dist = LengthPow(pointDZ, pow(2.0, primitive->data.torus.tubeRadiusLPow))
							 - primitive->data.torus.tubeRadius;
	dist = primitive->data.torus.empty ? fabs(dist) : dist;
	dist = max(dist - primitive->object.wallThickness, 0.0);

	if (primitive->data.torus.limitsEnable)
	{
		REAL3 distanceAxial =
			max(point - primitive->data.torus.limitsMax, primitive->data.torus.limitsMin - point);
		REAL limitBoxDist = max(max(distanceAxial.x, distanceAxial.y), distanceAxial.z);
		dist = max(dist, limitBoxDist);
	}
	return dist;
}
#endif

#ifdef USE_PRIMITIVE_PRISM
REAL PrimitivePrism(__global sPrimitiveCl *primitive, REAL3 _point)
{
	REAL3 point = _point;

	REAL3 q = fabs(point);

	REAL prismDistance = max(q.z - primitive->data.prism.height,
		max(q.x * primitive->data.prism.normals.y + point.y * primitive->data.prism.normals.z,
			-point.y + primitive->data.prism.triangleHeight)
			- primitive->data.prism.triangleHeight);

	prismDistance = primitive->data.prism.empty ? fabs(prismDistance) : prismDistance;
	prismDistance = max(prismDistance - primitive->object.wallThickness, 0.0);

	return prismDistance;
}
#endif

#ifdef USE_PRIMITIVE_ELLIPSOID
REAL PrimitiveEllipsoid(__global sPrimitiveCl *primitive, REAL3 _point)
{
	REAL3 point = _point;

	REAL k0 = length(point / primitive->object.size);
	REAL k1 = length(point / (primitive->object.size * primitive->object.size));
	REAL dist = k0 * (k0 - 1.0) / k1;

	dist = primitive->data.ellipsoid.empty ? fabs(dist) : dist;
	dist = max(dist - primitive->object.wallThickness, 0.0);

	if (primitive->data.ellipsoid.limitsEnable)
	{
		REAL3 distanceAxial =
			max(point - primitive->data.ellipsoid.limitsMax, primitive->data.ellipsoid.limitsMin - point);
		REAL limitBoxDist = max(max(distanceAxial.x, distanceAxial.y), distanceAxial.z);
		dist = max(dist, limitBoxDist);
	}
	return dist;
}
#endif

REAL PrimitiveDistanceByType(__global sPrimitiveCl *primitive, REAL3 point, REAL distFromAnother)
{
	REAL distTemp = 0.0;
	switch (primitive->object.objectType)
	{
#ifdef USE_PRIMITIVE_PLANE
		case objPlane:
		{
			distTemp = PrimitivePlane(primitive, point);
			break;
		}
#endif

#ifdef USE_PRIMITIVE_BOX
		case objBox:
		{
			distTemp = PrimitiveBox(primitive, point);
			break;
		}
#endif

#ifdef USE_PRIMITIVE_SPHERE
		case objSphere:
		{
			distTemp = PrimitiveSphere(primitive, point);
			break;
		}
#endif

#ifdef USE_PRIMITIVE_RECTANGLE
		case objRectangle:
		{
			distTemp = PrimitiveRectangle(primitive, point);
			break;
		}
#endif

#ifdef USE_PRIMITIVE_CYLINDER
		case objCylinder:
		{
			distTemp = PrimitiveCylinder(primitive, point);
			break;
		}
#endif

#ifdef USE_PRIMITIVE_CIRCLE
		case objCircle:
		{
			distTemp = PrimitiveCircle(primitive, point);
			break;
		}
#endif

#ifdef USE_PRIMITIVE_CONE
		case objCone:
		{
			distTemp = PrimitiveCone(primitive, point);
			break;
		}
#endif

#ifdef USE_PRIMITIVE_WATER
		case objWater:
		{
			distTemp = PrimitiveWater(primitive, point, distFromAnother);
			break;
		}
#endif

#ifdef USE_PRIMITIVE_TORUS
		case objTorus:
		{
			distTemp = PrimitiveTorus(primitive, point);
			break;
		}
#endif

#ifdef USE_PRIMITIVE_PRISM
		case objPrism:
		{
			distTemp = PrimitivePrism(primitive, point);
			break;
		}
#endif

#ifdef USE_PRIMITIVE_ELLIPSOID
		case objEllipsoid:
		{
			distTemp = PrimitiveEllipsoid(primitive, point);
			break;
		}
#endif

		default: break;
	}
	return distTemp;
}

#endif // USE_PRIMITIVES
