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
 * OpenCL structures for hybrid fractal sequences
 * derived from src/hybrid_fractal_sequences.h
 */

#ifndef MANDELBULBER2_OPENCL_HYBRID_SEQUENCE_CL_H_
#define MANDELBULBER2_OPENCL_HYBRID_SEQUENCE_CL_H_

#ifndef OPENCL_KERNEL_CODE
#include "fractal_cl.h"
#include "fractal_sequence_cl.h"
#endif

// OpenCL version of cHybridFractalSequences::sFractalData
// Note: fractalFormulaObject pointer is not transferred to OpenCL
typedef struct ALIGN_REAL
{
	sFractalCl fractalParameters;
	REAL formulaWeight;
	REAL bailout;
	cl_int formulaIterations;
	cl_int formulaStartIteration;
	cl_int formulaStopIteration;
	cl_int addCConstant;
	cl_int checkForBailout;
	cl_int useAdditionalBailoutCond;
} sHybridFractalDataCl;

// OpenCL version of cHybridFractalSequences::sSequence
// The variable-length arrays (seqence and fractData) are stored separately in dynamic data
typedef struct ALIGN_REAL
{
	REAL3 juliaConstant;
	REAL3 constantMultiplier;

	REAL initialWAxis;

	cl_int length;
	cl_int tableLength; // number of entries in the sequence array (formulaMaxiter * 5)
	cl_int numberOfFractalsInTheSequence;
	cl_int internalObjectId;

	cl_int isHybrid;
	cl_int juliaEnabled;
	cl_int formulaMaxiter;

	cl_int sequenceArrayOffset;	 // offset to sequence array (cl_int[]) in dynamic data
	cl_int fractDataArrayOffset; // offset to fractData array (sHybridFractalDataCl[]) in dynamic data
	cl_int formulaBaseIndex; // global index of first formula in consts->fractal[] for this sequence

	enumDEFunctionTypeCl DEFunctionType;
	enumDETypeCl DEType;
	enumDEAnalyticFunctionCl DEAnalyticFunction;
	enumColoringFunctionCl coloringFunction;
} sHybridSequenceCl;

#ifndef OPENCL_KERNEL_CODE
// BEGIN OPENCL_D_STRUCTS
typedef struct ALIGN_DOUBLE
{
	sFractalClD fractalParameters;
	cl_double formulaWeight;
	cl_double bailout;
	cl_int formulaIterations;
	cl_int formulaStartIteration;
	cl_int formulaStopIteration;
	cl_int addCConstant;
	cl_int checkForBailout;
	cl_int useAdditionalBailoutCond;
} sHybridFractalDataClD;

inline sHybridFractalDataClD clPromoteSHybridFractalDataClD(const sHybridFractalDataCl &source)
{
	sHybridFractalDataClD target;
	target.fractalParameters = clPromoteSFractalClD(source.fractalParameters);
	target.formulaWeight = source.formulaWeight;
	target.bailout = source.bailout;
	target.formulaIterations = source.formulaIterations;
	target.formulaStartIteration = source.formulaStartIteration;
	target.formulaStopIteration = source.formulaStopIteration;
	target.addCConstant = source.addCConstant;
	target.checkForBailout = source.checkForBailout;
	target.useAdditionalBailoutCond = source.useAdditionalBailoutCond;
	return target;
}

typedef struct ALIGN_DOUBLE
{
	cl_double3 juliaConstant;
	cl_double3 constantMultiplier;

	cl_double initialWAxis;

	cl_int length;
	cl_int tableLength; // number of entries in the sequence array (formulaMaxiter * 5)
	cl_int numberOfFractalsInTheSequence;
	cl_int internalObjectId;

	cl_int isHybrid;
	cl_int juliaEnabled;
	cl_int formulaMaxiter;

	cl_int sequenceArrayOffset;	 // offset to sequence array (cl_int[]) in dynamic data
	cl_int fractDataArrayOffset; // offset to fractData array (sHybridFractalDataClD[]) in dynamic data
	cl_int formulaBaseIndex; // global index of first formula in consts->fractal[] for this sequence

	enumDEFunctionTypeCl DEFunctionType;
	enumDETypeCl DEType;
	enumDEAnalyticFunctionCl DEAnalyticFunction;
	enumColoringFunctionCl coloringFunction;
} sHybridSequenceClD;

inline sHybridSequenceClD clPromoteSHybridSequenceClD(const sHybridSequenceCl &source)
{
	sHybridSequenceClD target;
	target.juliaConstant = toClDouble3(source.juliaConstant);
	target.constantMultiplier = toClDouble3(source.constantMultiplier);
	target.initialWAxis = source.initialWAxis;
	target.length = source.length;
	target.tableLength = source.tableLength;
	target.numberOfFractalsInTheSequence = source.numberOfFractalsInTheSequence;
	target.internalObjectId = source.internalObjectId;
	target.isHybrid = source.isHybrid;
	target.juliaEnabled = source.juliaEnabled;
	target.formulaMaxiter = source.formulaMaxiter;
	target.sequenceArrayOffset = source.sequenceArrayOffset;
	target.fractDataArrayOffset = source.fractDataArrayOffset;
	target.formulaBaseIndex = source.formulaBaseIndex;
	target.DEFunctionType = static_cast<enumDEFunctionTypeCl>(source.DEFunctionType);
	target.DEType = static_cast<enumDETypeCl>(source.DEType);
	target.DEAnalyticFunction = static_cast<enumDEAnalyticFunctionCl>(source.DEAnalyticFunction);
	target.coloringFunction = static_cast<enumColoringFunctionCl>(source.coloringFunction);
	return target;
}
// END OPENCL_D_STRUCTS
#endif /* OPENCL_KERNEL_CODE */

#endif /* MANDELBULBER2_OPENCL_HYBRID_SEQUENCE_CL_H_ */
