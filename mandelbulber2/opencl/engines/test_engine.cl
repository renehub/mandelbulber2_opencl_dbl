/**
 * Mandelbulber v2, a 3D fractal generator       ,=#MKNmMMKmmßMNWy,
 *                                             ,B" ]L,,p%%%,,,§;, "K
 * Copyright (C) 2017-20 Mandelbulber Team     §R-==%w["'~5]m%=L.=~5N
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
 * Test kernel for rendering opencl with minimal footprint
 */

#define MAX_RAYMARCHING 5000

REAL3 NormalVector(__constant sClInConstants *consts, REAL3 point, REAL mainDistance,
	REAL distThresh, sClCalcParams *calcParam, sRenderData *renderData)
{
	REAL delta = distThresh;
	REAL s1 = CalculateDistance(consts, point + (REAL3){delta, 0.0, 0.0}, calcParam, renderData).distance;
	REAL s2 = CalculateDistance(consts, point + (REAL3){0.0, delta, 0.0}, calcParam, renderData).distance;
	REAL s3 = CalculateDistance(consts, point + (REAL3){0.0, 0.0, delta}, calcParam, renderData).distance;
	REAL3 normal = (REAL3){s1 - mainDistance, s2 - mainDistance, s3 - mainDistance};
	normal = normalize(normal);
	return normal;
}

//------------------ MAIN RENDER FUNCTION --------------------
kernel void fractal3D(__global sClPixel *out, __global sClInBuff *inBuff,
	__constant sClInConstants *consts, int Gcl_offset)
{
	int cl_offset = Gcl_offset;

	// get actual pixel
	const int id = get_global_id(0) + cl_offset;
	const int imageX = id % consts->params.imageWidth;
	const int imageYTemp = id / consts->params.imageWidth;
	const int buffIndex = (id - cl_offset);

	const int imageY = clamp(imageYTemp, 0, consts->params.imageHeight - 1);

	REAL2 screenPoint = (REAL2){convert_float(imageX), convert_float(imageY)};
	REAL width = convert_float(consts->params.imageWidth);
	REAL height = convert_float(consts->params.imageHeight);
	REAL resolution = 1.0 / width;

	// auxiliary vectors
	const REAL3 one = (REAL3){1.0, 0.0, 0.0};
	const REAL3 ones = 1.0;

	// main rotation matrix
	matrix33 rot;
	rot.m1 = (REAL3){1.0, 0.0, 0.0};
	rot.m2 = (REAL3){0.0, 1.0, 0.0};
	rot.m3 = (REAL3){0.0, 0.0, 1.0};

	rot = RotateZ(rot, consts->params.viewAngle.x);
	rot = RotateX(rot, consts->params.viewAngle.y);
	rot = RotateY(rot, consts->params.viewAngle.z);

	// starting point for ray-marching
	REAL3 start = consts->params.camera;

	// view vector
	REAL aspectRatio = width / height;
	REAL x2, z2;
	x2 = (screenPoint.x / width - 0.5) * aspectRatio;
	z2 = -(screenPoint.y / height - 0.5);
	REAL3 viewVector = (REAL3){x2 * consts->params.fov, 1.0, z2 * consts->params.fov};
	viewVector = Matrix33MulFloat3(rot, viewVector);

	bool found = false;
	int count;

	REAL3 point;
	REAL scan, distThresh, distance;

	scan = 1e-10;

	sClCalcParams calcParam;
	calcParam.N = consts->params.N;
	distThresh = 1e-6;

	sRenderData renderData;
	renderData.nodesData = 0;
	renderData.numberOfNodes = 0;
	renderData.numberOfPrimitives = 0;
	renderData.primitives = 0;
	renderData.primitivesGlobalData = 0;
	renderData.objectsData = 0;
	renderData.numberOfObjects = 0;
	renderData.dynamicData = 0;
	renderData.hybridSequences = 0;
	renderData.numberOfHybridSequences = 0;

	formulaOut outF;
	REAL step = 0.0;

	// ray-marching
	for (count = 0; count < MAX_RAYMARCHING && scan < consts->params.viewDistanceMax; count++)
	{
		point = start + viewVector * scan;
		calcParam.distThresh = distThresh;
		outF = CalculateDistance(consts, point, &calcParam, &renderData);
		distance = outF.distance;
		distThresh = scan * resolution * consts->params.fov;

		if (distance < distThresh)
		{
			found = true;
			break;
		}

		step = (distance - 0.5 * distThresh) * consts->params.DEFactor;
		scan += step;
	}

	// final binary searching
	if (found)
	{
		step *= 0.5;
		for (int i = 0; i < 5; i++)
		{
			if (distance < distThresh && distance > distThresh * 0.95)
			{
				break;
			}
			else
			{
				if (distance > distThresh)
				{
					point += viewVector * step;
				}
				else if (distance < distThresh * 0.95)
				{
					point -= viewVector * step;
				}
			}
			outF = CalculateDistance(consts, point, &calcParam, &renderData);
			distance = outF.distance;
			step *= 0.5;
		}
	}

	REAL3 colour = 0.7;
	REAL3 surfaceColour = 1.0;
	if (found)
	{
		REAL3 normal = NormalVector(consts, point, distance, distThresh, &calcParam, &renderData);

		REAL3 lightVector = (REAL3){
			cos(consts->params.mainLightAlpha - 0.5 * M_PI_F) * cos(-consts->params.mainLightBeta),
			sin(consts->params.mainLightAlpha - 0.5 * M_PI_F) * cos(-consts->params.mainLightBeta),
			sin(-consts->params.mainLightBeta)};
		lightVector = Matrix33MulFloat3(rot, lightVector);
		REAL shade = dot(lightVector, normal);
		if (shade < 0.0) shade = 0.0;

		REAL3 halfVector = lightVector - viewVector;
		halfVector = fast_normalize(halfVector);
		REAL specular = dot(normal, halfVector);
		if (specular < 0.0) specular = 0.0;
		specular = pown(specular, 30.0);
		if (specular > 15.0) specular = 15.0;

		colour = colour * (shade + specular);
	}
	else
	{
		colour = 0.0;
	}

	sClPixel pixel;

	REAL glow = count / 100.0 * consts->params.DEFactor;

	pixel.R = colour.s0 + glow;
	pixel.G = colour.s1 * glow * 10.0;
	pixel.B = colour.s2;
	pixel.zBuffer = scan;
	pixel.colR = 0.0;
	pixel.colG = 0.0;
	pixel.colB = 0.0;
	pixel.opacity = 0;
	pixel.alpha = 65535;

	out[buffIndex] = pixel;
}
