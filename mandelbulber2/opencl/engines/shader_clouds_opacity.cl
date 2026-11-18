/**
 * Mandelbulber v2, a 3D fractal generator       ,=#MKNmMMKmmßMNWy,
 *                                             ,B" ]L,,p%%%,,,§;, "K
 * Copyright (C) 2020-22 Mandelbulber Team     §R-==%w["'~5]m%=L.=~5N
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
 * calculates opacity of clouds based on Perlin noise
 */

#ifdef CLOUDS
REAL CloudOpacity(__constant sClInConstants *consts, __global uchar *perlinNoiseSeeds,
	REAL3 point, REAL distance, REAL detailSize, REAL *distanceOut)
{
	REAL h = 1.0; // height factor
	REAL3 point2;
	REAL distToGeometry = 0.0;
	REAL opacityOut = 0.0;

	if (consts->params.cloudsPlaneShape)
	{
		point2 =
			Matrix33MulFloat3(consts->params.mRotCloudsRotation, point - consts->params.cloudsCenter);
		// h = clamp(1.0 - fabs(2.0 / consts->params.cloudsHeight * (point2.z)), 0.0, 1.0);
		h = clamp(1.0 / (pow(point2.z / consts->params.cloudsHeight * 2.0, 6.0) + 0.99) - 0.01,
			0.0, 1.0);

		distToGeometry = max(fabs(point2.z) - consts->params.cloudsHeight * 2.0, 0.0)
										 * consts->params.cloudsDEApproaching;
	}
	else
	{
		h = 1.0;
		point2 = point;
	}

	if (consts->params.cloudsDistanceMode)
	{
		//		h *= clamp(2.0
		//								 - fabs(3.0 / consts->params.cloudsDistanceLayer
		//												* (distance - consts->params.cloudsDistance)),
		//
		//			0.0, 1.0);

		h = clamp(1.0
									/ (pow((distance - consts->params.cloudsDistance)
													 / consts->params.cloudsDistanceLayer * 2.0,
											 6.0)
										 + 0.99)
								- 0.01,
			0.0, 1.0);

		distToGeometry = max(distToGeometry, fabs(distance - consts->params.cloudsDistance)
																					 - consts->params.cloudsDistanceLayer * 2.0)
										 * consts->params.cloudsDEApproaching;
	}

	REAL distToCloud = distToGeometry;
	if (h > 0.0)
	{
		REAL opacity = NormalizedOctavePerlinNoise3D_0_1(point2.x / consts->params.cloudsPeriod,
			point2.y / consts->params.cloudsPeriod, point2.z / consts->params.cloudsPeriod,
			consts->params.cloudsSpeed * consts->params.frameNo, consts->params.cloudsIterations,
			perlinNoiseSeeds);

		distToCloud = fabs(1.0 - opacity - consts->params.cloudsDensity) * 0.2
									* consts->params.cloudsPeriod * consts->params.cloudsDEMultiplier;

		opacity = clamp(opacity - 1.0 + consts->params.cloudsDensity * 2.0, 0.0, 1.0);

		if (consts->params.cloudsSharpEdges)
			opacity = 0.5 * (1.0 + tanh((opacity - 0.5) * consts->params.cloudsSharpness));

		opacity *= consts->params.cloudsOpacity;

		opacityOut = opacity * h;
	}

	//*distanceOut = max(distToGeometry, distToCloud);
	*distanceOut = max(max(distToGeometry, distToCloud),
		max(consts->params.cloudsPeriod * 0.02 / consts->params.cloudsDetailAccuracy,
			detailSize * 5.0 / consts->params.cloudsDetailAccuracy));

	return opacityOut;
}

#endif // CLOUDS
