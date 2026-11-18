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
 * Authors: Krzysztof Marczak (buddhi1980@gmail.com)
 *
 * main fractal function for opencl
 */

#ifndef MANDELBULBER2_OPENCL_ENGINES_COMPUTE_FRACTAL_CL_
#define MANDELBULBER2_OPENCL_ENGINES_COMPUTE_FRACTAL_CL_

typedef struct
{
	REAL4 z;
	REAL iters;
	REAL distance;
	REAL colorIndex;
	REAL orbitTrapR;
	int objectId;
	int sequenceIndex;
	bool maxiter;
	REAL3 transformedPoint;
	bool hasTransformedPoint;
	REAL detailLevelMultiplier;
} formulaOut;

typedef enum
{
	calcModeNormal = 0,
	calcModeColouring = 1,
	calcModeFake_AO = 2,
	calcModeDeltaDE1 = 3,
	calcModeDeltaDE2 = 4,
	calcModeOrbitTrap = 5,
	calcModeCubeOrbitTrap = 6
} enumCalculationModeCl;

REAL4 DummyIteration(REAL4 z, __global sFractalCl *fractal, sExtendedAuxCl *aux)
{
	aux->r = -1.0; // signal for main loop to break;
	return 0.0;
}

formulaOut Fractal(__constant sClInConstants *consts, REAL3 point, sClCalcParams *calcParam,
	enumCalculationModeCl mode, __global sMaterialCl *material, int forcedFormulaIndex,
	sRenderData *renderData, int hybridSequenceIndex, REAL3 pointTransformed,
	bool hasTransformedPoint)
{
	// begin
	REAL dist = 0.0;

	// get hybrid sequence data from renderData
	int seqIdx = (hybridSequenceIndex >= 0) ? hybridSequenceIndex : 0;
	if (seqIdx < 0 || seqIdx >= renderData->numberOfHybridSequences)
	{
		seqIdx = 0;
	}
	__global sHybridSequenceCl *seq = &renderData->hybridSequences[seqIdx];
	__global int *seqArray = (__global int *)&renderData->dynamicData[seq->sequenceArrayOffset];
	__global sHybridFractalDataCl *fractDataArray =
		(__global sHybridFractalDataCl *)&renderData->dynamicData[seq->fractDataArrayOffset];

	// the sequence table covers formulaMaxiter * 5 iterations (see sHybridSequenceCl),
	// the clamp is only a safety net; tail entries repeat the last active formula
	int seqTableLength = seq->tableLength;
	if (seqTableLength <= 0)
	{
		seqTableLength = 1;
	}

	REAL4 point4D = (REAL4){point.x, point.y, point.z, 0.0};

	REAL4 z;
	z.x = point.x;
	z.y = point.y;
	z.z = point.z;

	z.w = seq->initialWAxis;

	int maxN = seq->formulaMaxiter;

	if (calcParam->normalCalculationMode && calcParam->iterThreshMode) maxN *= 5;
	if (mode == calcModeColouring) maxN *= 4;

	REAL initialWAxisColor = z.w;

	REAL4 c = z;
	int i;

	formulaOut out;
	out.maxiter = true;
	out.orbitTrapR = 0.0;
	out.colorIndex = 0.0;

	REAL colorMin = 1000.0;
	REAL orbitTrapTotal = 0.0;

	// fractalIndex is the local index of the first formula in this sequence
	// - used only for defaultFractal and initialScale, not updated per iteration
	int fractalIndex = seqArray[0];
	// globalFractalIndex is used to index fractalsArray (global across all sequences)
	int globalFractalIndex = fractalIndex + seq->formulaBaseIndex;

	// formula init
	sExtendedAuxCl aux;

	aux.c = c;
	aux.const_c = c;
	aux.old_z = z;
	aux.pos_neg = 1.0;
	aux.r = length(z);
	aux.DE = 1.0;
	aux.DE0 = 0.0;
	aux.dist = 1000.0;
	aux.pseudoKleinianDE = 1.0;
	aux.actualScale = fractDataArray[fractalIndex].fractalParameters.mandelbox.scale;
	aux.actualScaleA = 0.0;
	aux.color = 1.0;
	aux.colorHybrid = 0.0;
	aux.temp1000 = 1000.0;

	int sequence = 0;
	int globalSequence = 0;
	__global sFractalCl *fractal;

	__global sFractalCl *defaultFractal = &renderData->fractals[globalFractalIndex];

	__global sFractalColoringCl *fractalColoring = (material) ? &material->fractalColoring : NULL;

	REAL4 lastZ = 0.0;
	REAL4 lastLastZ = 0.0;

#ifdef FAKE_LIGHTS
	// orbit trap lights initialization
	int fakeLightsMinIter = consts->params.common.fakeLightsMinIter;
	int fakeLightsMaxIter = consts->params.common.fakeLightsMaxIter;

	if (mode == calcModeOrbitTrap)
	{
		if (calcParam->orbitTrapIndex == 0)
		{
			if (consts->params.common.fakeLightsColor2Enabled) fakeLightsMaxIter = fakeLightsMinIter;
		}
		else if (calcParam->orbitTrapIndex == 1)
		{
			fakeLightsMinIter = consts->params.common.fakeLightsMinIter + 1;
			fakeLightsMaxIter = max(fakeLightsMinIter, consts->params.common.fakeLightsMaxIter);
			if (consts->params.common.fakeLightsColor3Enabled) fakeLightsMaxIter = fakeLightsMinIter;
		}
		else if (calcParam->orbitTrapIndex == 2)
		{
			fakeLightsMinIter = consts->params.common.fakeLightsMinIter + 2;
			fakeLightsMaxIter = max(fakeLightsMinIter, consts->params.common.fakeLightsMaxIter);
		}
	}
#endif // FAKE_LIGHTS

	// loop
	for (i = 0; i < maxN; i++)
	{
#if defined(IS_HYBRID) || defined(BOOLEAN_OPERATORS)
		sequence = seqArray[min(i, seqTableLength - 1)];
		if (sequence < 0)
		{
			// old cNineFractals 'none' slot in the sequence table: terminate the orbit
			// like the DummyIteration fallback (maxiter stays true -> ray marcher
			// treats the point as a hit, identical to the old CPU and OpenCL behavior)
			REAL high = fractDataArray[0].bailout * 10.0;
			z = high;
			out.distance = 10.0;
			out.iters = 1;
			out.z = z;
			out.colorIndex = 0.0;
			return out;
		}
		globalSequence = sequence + seq->formulaBaseIndex;
#else
		sequence = 0;
		globalSequence = seq->formulaBaseIndex;
#endif

		fractal = &renderData->fractals[globalSequence];

		aux.i = i;

		lastLastZ = lastZ;
		lastZ = z;

#ifdef BOX_FOLDING
		z = BoxFolding(z, &consts->params.common.foldings, &aux);
		aux.r = length(z);
#endif

#ifdef SPHERICAL_FOLDING
		z = SphericalFolding(z, &consts->params.common.foldings, &aux);
		aux.r = length(z);
#endif

		// temporary vector for weight function
		REAL4 tempZ = z;
		REAL tempAuxDE = aux.DE;
		REAL tempAuxColor = aux.color;

#ifdef ITERATION_WEIGHT
		if (fractDataArray[sequence].formulaWeight > 0)
		{
#endif

			// PLACEHOLDER_FOR_FORMULA_ITER

#ifdef ITERATION_WEIGHT
		}
#endif

		if (aux.r < 0.0) // if was run DummyIteration
		{
			REAL high = fractDataArray[sequence].bailout * 10.0;
			z = high;
			aux.r = length(z);
			out.distance = 10.0;
			out.iters = 1;
			out.z = z;
			out.colorIndex = 0.0;
			return out;
		}

		if (fractDataArray[sequence].addCConstant)
		{
			switch (fractal->formula)
			{
				case 64: // aboxMod1
				case 73: // amazingSurf
				{
					if (seq->juliaEnabled)
					{
						REAL4 juliaC =
							(REAL4){seq->juliaConstant.x, seq->juliaConstant.y, seq->juliaConstant.z, 0.0}
							* (REAL4){seq->constantMultiplier.x, seq->constantMultiplier.y,
								seq->constantMultiplier.z, 0.0};
						z += (REAL4){juliaC.y, juliaC.x, juliaC.z, juliaC.w};
					}
					else
					{
						z += (REAL4){aux.const_c.y, aux.const_c.x, aux.const_c.z, aux.const_c.w}
								 * (REAL4){seq->constantMultiplier.x, seq->constantMultiplier.y,
									 seq->constantMultiplier.z, 0.0};
					}
					break;
				}

				default:
				{
					if (seq->juliaEnabled)
					{
						z += (REAL4){seq->juliaConstant.x, seq->juliaConstant.y, seq->juliaConstant.z, 0.0}
								 * (REAL4){seq->constantMultiplier.x, seq->constantMultiplier.y,
									 seq->constantMultiplier.z, 0.0};
					}
					else
					{
						z += aux.const_c
								 * (REAL4){seq->constantMultiplier.x, seq->constantMultiplier.y,
									 seq->constantMultiplier.z, 1.0};
					}
				}
			}
		}

#ifdef ITERATION_WEIGHT
		if (seq->isHybrid)
		{
			REAL k = fractDataArray[sequence].formulaWeight;
			if (k < 1.0)
			{
				z = SmoothCVector(tempZ, z, k);
				REAL kn = 1.0 - k;
				aux.DE = aux.DE * k + tempAuxDE * kn;
				aux.color = aux.color * k + tempAuxColor * kn;
			}
		}
#endif

		// calculate r

		aux.r = length(z);

		// escape conditions
		if (fractDataArray[sequence].checkForBailout)
		{
			// mode normal or deltaDE center point
			if (mode == calcModeNormal || mode == calcModeDeltaDE1)
			{
				if (aux.r > fractDataArray[sequence].bailout)
				{
					out.maxiter = false;
					break;
				}

				if (fractDataArray[sequence].useAdditionalBailoutCond)
				{
					out.maxiter = false;
					if (length(z - lastZ) / aux.r < 0.1 / fractDataArray[sequence].bailout) break;
					if (length(z - lastLastZ) / aux.r < 0.1 / fractDataArray[sequence].bailout) break;
				}
			}
			else if (mode == calcModeDeltaDE2)
			{
				if (i == calcParam->deltaDEMaxN) break;
			}
			else if (mode == calcModeColouring)
			{
				REAL len = 0.0;
				REAL4 colorZ = z;
				if (!fractalColoring->color4dEnabledFalse) colorZ.w = 0.0;
#ifdef USE_COLORING_MODES
				switch (fractalColoring->coloringAlgorithm)
				{
					case fractalColoringCl_Standard:
					{
						len = length(colorZ);
						break;
					}
					case fractalColoringCl_ZDotPoint:
					{
						len = fabs(dot((REAL4){point4D.x, point4D.y, point4D.z, initialWAxisColor}, colorZ));
						break;
					}
					case fractalColoringCl_Sphere:
					{
						len = fabs(length(colorZ - (REAL4){point4D.x, point4D.y, point4D.z, initialWAxisColor})
											 - fractalColoring->sphereRadius);
						break;
					}
					case fractalColoringCl_Cross:
					{
						len = min(min(fabs(colorZ.x), fabs(colorZ.y)), fabs(colorZ.z));
						if (fractalColoring->color4dEnabledFalse) len = min(len, fabs(colorZ.w));
						break;
					}
					case fractalColoringCl_Line:
					{
						len = fabs(dot(fractalColoring->lineDirection, colorZ));
						break;
					}
					case fractalColoringCl_None:
					{
						len = aux.r;
						break;
					}
				}
#else
				len = length(colorZ);
#endif // USE_COLORING_MODES
				if (!fractalColoring->colorPreV215False)
				{
					if (fractal->formula != 8)
					{
						if (len < colorMin) colorMin = len;
						if (aux.r > fractDataArray[sequence].bailout) break;
						if (fractDataArray[sequence].useAdditionalBailoutCond
								&& length(z - lastZ) / aux.r < 1e-15)
							break;
					}
					else // for Mandelbox. Note in Normal Mode (abox_color) colorMin = 0, else has a value
					{
						if (fractalColoring->coloringAlgorithm == fractalColoringCl_Standard)
						{
							if (aux.r > 1e15 || length(z - lastZ) / aux.r < 1e-15) break;
						}
						else
						{
							if (len < colorMin) colorMin = len; // colorMin for hybrid mode ??
							if (aux.r > fractDataArray[sequence].bailout || length(z - lastZ) / aux.r < 1e-15)
								break;
						}
					}
				}
				else // pre-2.15
				{
					if (fractal->formula != 8) // if not mandelbox
					{
						if (len < colorMin) colorMin = len;
						if (aux.r > 1e15 || length(z - lastZ) / aux.r < 1e-15) break;
					}
					else
					{
						if (aux.r > 1e15 || length(z - lastZ) / aux.r < 1e-15) break;
					}
					// if (aux.r > 1e15) break; // old
				}
			}
#ifdef FAKE_LIGHTS
			else if (mode == calcModeOrbitTrap)
			{
				REAL distance = (consts->params.common.fakeLightsRelativeCenter)
													 ? OrbitTrapShapeDistance(z - aux.const_c, consts)
													 : OrbitTrapShapeDistance(z, consts);

				if (i >= fakeLightsMinIter && i <= fakeLightsMaxIter)
					orbitTrapTotal += (1.0 / (distance * distance));
				if (distance > fractDataArray[sequence].bailout)
				{
					out.orbitTrapR = orbitTrapTotal;
					break;
				}
			}
#endif // FAKE_LIGHTS
#ifdef FRACTALIZE_TEXTURE
			else if (mode == calcModeCubeOrbitTrap)
			{
				if (i >= material->textureFractalizeStartIteration)
				{
					REAL size = material->textureFractalizeCubeSize;
					REAL3 zz = z.xyz - (hasTransformedPoint ? pointTransformed : point);
					if (zz.x > -size && zz.x < size && zz.y > -size && zz.y < size && zz.z > -size
							&& zz.z < size)
					{
						out.colorIndex = (fabs(z.x - size) + fabs(z.y - size) + fabs(z.z - size)) * 100.0;
						out.iters = i + 1;
						out.z = z;
						return out;
					}
				}
				if (aux.r > material->textureFractalizeCubeSize * 100.0)
				{
					out.colorIndex = 0.0;
					out.iters = i + 1;
					out.z = z / length(z);
					return out;
				}
			}
#endif // FRACTALIZE_TEXTURE
		}
	}

	// calculate estimated distance

	if (mode == calcModeNormal)
	{
		if (aux.DE > 0.0)
		{
			if (seq->isHybrid)
			{
#ifdef HYBRID_NODES
				if (seq->DEFunctionType == logarithmicDEFunction)
				{
					if (aux.r > 1.0)
						dist = 0.5 * aux.r * native_log(aux.r) / fabs(aux.DE);
					else
						dist = 0.0;
				}
				else if (seq->DEFunctionType == linearDEFunction)
				{
					dist = (aux.r - consts->params.common.linearDEOffset) / fabs(aux.DE);
				}
				else if (seq->DEFunctionType == pseudoKleinianDEFunction)
				{
					REAL rxy = length(z.xy);
					dist = max(rxy - aux.pseudoKleinianDE, fabs(rxy * z.z) / aux.r) / fabs(aux.DE);
				}
				else if (seq->DEFunctionType == josKleinianDEFunction)
				{
					if (fractDataArray[sequence].fractalParameters.transformCommon.spheresEnabled)
						z.y = min(
							z.y, fractDataArray[sequence].fractalParameters.transformCommon.foldingValue - z.y);
					dist = min(z.y, fractDataArray[sequence].fractalParameters.analyticDE.tweak005)
								 / max(fabs(aux.DE), fractDataArray[sequence].fractalParameters.analyticDE.offset1);
				}
				else if (seq->DEFunctionType == customDEFunction)
				{
					dist = aux.dist;
				}
				else if (seq->DEFunctionType == maxAxisDEFunction)
				{
					REAL4 absZ = fabs(z);
					REAL rd = max(absZ.x, max(absZ.y, absZ.z));
					dist = rd / fabs(aux.DE);
				}
#endif // HYBRID_NODES
			}
			else
			{
				switch (seq->DEAnalyticFunction)
				{
					case clAnalyticFunctionLogarithmic:
					{
						if (aux.r > 1.0)
							dist = 0.5 * aux.r * native_log(aux.r) / aux.DE;
						else
							dist = 0.0;
						break;
					}
					case clAnalyticFunctionLinear:
					{
						dist = aux.r / aux.DE;
						break;
					}
					case clAnalyticFunctionIFS:
					{
						dist = (aux.r - 2.0) / aux.DE;
						break;
					}
					case clAnalyticFunctionPseudoKleinian:
					{
						REAL rxy = length(z.xy);
						dist = max(rxy - aux.pseudoKleinianDE, fabs(rxy * z.z) / aux.r) / aux.DE;
						break;
					}
					case clAnalyticFunctionJosKleinian:
					{
						if (fractDataArray[sequence].fractalParameters.transformCommon.spheresEnabled)
							z.y = min(
								z.y, fractDataArray[sequence].fractalParameters.transformCommon.foldingValue - z.y);
						dist = min(z.y, fractDataArray[sequence].fractalParameters.analyticDE.tweak005)
									 / max(aux.DE, fractDataArray[sequence].fractalParameters.analyticDE.offset1);
						break;
					}
					case clAnalyticFunctionCustomDE:
					{
						dist = aux.dist;
						break;
					}
					case clAnalyticFunctionMaxAxis:
					{
						REAL4 absZ = fabs(z);
						REAL rd = max(absZ.x, max(absZ.y, absZ.z));
						dist = rd / aux.DE;
						break;
					}
					case clAnalyticFunctionNone: dist = -1.0; break;
					case clAnalyticFunctionUndefined: dist = aux.r; break;
				}
			}
		}
		else
			dist = aux.r;
	}

#ifdef USE_FRACTAL_COLORING
	else if (mode == calcModeColouring)
	{
		enumColoringFunctionCl coloringFunction = seq->coloringFunction;
		out.colorIndex = CalculateColorIndex(
			seq->isHybrid, aux.r, z, colorMin, &aux, fractalColoring, coloringFunction, defaultFractal);
	}
#endif
	else
	{
		dist = 0.0;

		// needed for JosKleinian fractal to calculate spheres in deltaDE mode
		if (seq->DEFunctionType == josKleinianDEFunction)
		{
			if (fractDataArray[sequence].fractalParameters.transformCommon.spheresEnabled)
				z.y =
					min(z.y, fractDataArray[sequence].fractalParameters.transformCommon.foldingValue - z.y);
		}
	}

	// end
	if (dist < 0.0) dist = 0.0;
	out.distance = dist;
	out.iters = i + 1;
	out.z = z;

	return out;
}

#endif /* MANDELBULBER2_OPENCL_ENGINES_COMPUTE_FRACTAL_CL_ */
