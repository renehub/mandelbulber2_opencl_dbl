/**
 * Mandelbulber v2, a 3D fractal generator       ,=#MKNmMMKmmßMNWy,
 *                                             ,B" ]L,,p%%%,,,§;, "K
 * Copyright (C) 2017-23 Mandelbulber Team     §R-==%w["'~5]m%=L.=~5N
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
 * opencl dynamic data for transferring to the worker device
 */

#include "opencl_dynamic_data.hpp"

#include <algorithm>
#include <cstddef>
#include <cstring>
#include <map>
#include <vector>

#include "color_gradient.h"
#include "fractparams.hpp"
#include "hybrid_fractal_sequences.h"
#include "light.h"
#include "lights.hpp"
#include "material.h"
#include "opencl_textures_data.h"
#include "primitives.h"
#include "render_worker.hpp"

// custom includes
#ifdef USE_OPENCL
#include "opencl/material_cl.h"
#include "opencl/input_data_structures.h"
#include "opencl/hybrid_sequence_cl.h"
#include "opencl/nebula_sequence_cl.h"
#include "opencl/node_data_cl.h"
#include "opencl/primitives_cl.h"
#include "opencl/light_cl.h"
#endif

#ifdef USE_OPENCL

// The dynamic data structures are built directly for the precision selected on
// the device. The kernel-side structures (REAL/REAL3/...) are controlled by
// DOUBLE_PRECISION, so the host has to upload the *D structures and use the
// corresponding 32-byte alignment.
namespace {

struct DynamicSinglePolicy
{
	static const int alignment = 16;

	using MaterialCl = sMaterialCl;
	using VectorsAroundCl = sVectorsAroundCl;
	using LightCl = sLightCl;
	using PrimitiveCl = sPrimitiveCl;
	using PrimitiveGlobalCl = sPrimitiveGlobalDataCl;
	using ObjectDataCl = sObjectDataCl;
	using NodeDataCl = sNodeDataForRenderingCl;
	using HybridSequenceCl = sHybridSequenceCl;
	using HybridFractalDataCl = sHybridFractalDataCl;
	using FractalCl = sFractalCl;

	static cl_float3 vec3(const CVector3 &v) { return toClFloat3(v); }
	static cl_float3 vec3(const sRGBFloat &v) { return toClFloat3(v); }
	static cl_float2 vec2(const CVector2<double> &v) { return toClFloat2(v); }
	static matrix33 mat33(const CRotationMatrix &m) { return toClMatrix33(m); }
	static matrix44 mat44(const CMatrix44 &m) { return toClMatrix44(m); }
	static sMaterialCl material(const cMaterial &m) { return clCopySMaterialCl(m); }
	static sFractalCl fractal(const sFractal &f) { return clCopySFractalCl(f); }
};

struct DynamicDoublePolicy
{
	static const int alignment = 32;

	using MaterialCl = sMaterialClD;
	using VectorsAroundCl = sVectorsAroundClD;
	using LightCl = sLightClD;
	using PrimitiveCl = sPrimitiveClD;
	using PrimitiveGlobalCl = sPrimitiveGlobalDataClD;
	using ObjectDataCl = sObjectDataClD;
	using NodeDataCl = sNodeDataForRenderingClD;
	using HybridSequenceCl = sHybridSequenceClD;
	using HybridFractalDataCl = sHybridFractalDataClD;
	using FractalCl = sFractalClD;

	static cl_double3 vec3(const CVector3 &v) { return toClDouble3(v); }
	static cl_double3 vec3(const sRGBFloat &v) { return toClDouble3(v); }
	static cl_double2 vec2(const CVector2<double> &v) { return toClDouble2(v); }
	static matrix33D mat33(const CRotationMatrix &m) { return toClMatrix33D(m); }
	static matrix44D mat44(const CMatrix44 &m) { return toClMatrix44D(m); }
	static sMaterialClD material(const cMaterial &m) { return clCopySMaterialClD(m); }
	static sFractalClD fractal(const sFractal &f) { return clCopySFractalClD(f); }
};

} // namespace

cOpenClDynamicData::cOpenClDynamicData(int numberOfItems)
		: cOpenClAbstractDynamicData(numberOfItems) // this container has 5
																								// items
{
}

cOpenClDynamicData::~cOpenClDynamicData() = default;

int cOpenClDynamicData::BuildMaterialsData(
	const std::vector<cMaterial> &materials, const QMap<QString, int> &textureIndexes)
{
	return doublePrecision
		? BuildMaterialsDataImpl<DynamicDoublePolicy>(materials, textureIndexes)
		: BuildMaterialsDataImpl<DynamicSinglePolicy>(materials, textureIndexes);
}

template <typename Policy>
int cOpenClDynamicData::BuildMaterialsDataImpl(
	const std::vector<cMaterial> &materials, const QMap<QString, int> &textureIndexes)
{
	/* material dynamic data structure

	header:
	cl_int numberOfMaterials

	materials offsets:
	cl_int material[0] offset
	cl_int material[1] offset
	...
	cl_int material[numberOfMaterials] offset

	---- material 0 ---
	+0	cl_int materialClOffset (offset for material data)
	+4	cl_int paletteItemsOffset
	+8	cl_int palette_offset_surface
	+12	cl_int paletteLengthSurface (number of surface color palette items)
	+16 cl_int palette offset specular
	+20 cl_int paletteLengthSpecular (number of specular color palette items)

	+24	sMaterialCl material

		palette items:
			cl_float3 color[0]
			cl_float3 color[1]
			...
			cl_float3 color[paletteLength]
	-------------------

	*/

	const int alignment = Policy::alignment;
	totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);
	itemOffsets[materialsItemIndex].itemOffset = totalDataOffset;

	cl_int numberOfMaterials = static_cast<cl_int>(materials.size());

	// numberOfMaterials
	data.append(reinterpret_cast<char *>(&numberOfMaterials), sizeof(numberOfMaterials));
	int headerSize = sizeof(numberOfMaterials);
	totalDataOffset += headerSize;

	// reserve bytes for material offsets
	std::vector<cl_int> materialOffsets(numberOfMaterials);
	int materialOffsetsSize = sizeof(cl_int) * numberOfMaterials;
	std::fill(materialOffsets.begin(), materialOffsets.end(), 0);

	int materialOffsetsAddress = totalDataOffset;
	data.append(reinterpret_cast<char *>(materialOffsets.data()), materialOffsetsSize);
	totalDataOffset += materialOffsetsSize;

	// add dummy bytes for alignment
	totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);

	for (int materialIndex = 0; materialIndex < numberOfMaterials; materialIndex++)
	{
		typename Policy::MaterialCl materialCl;
		std::vector<cl_float4> paletteCl;

		int totalSizeOfGradients = 0;
		cl_int paletteOffsetSurface;
		cl_int paletteSizeSurface;
		cl_int paletteOffsetSpecular;
		cl_int paletteSizeSpecular;
		cl_int paletteOffsetDiffuse;
		cl_int paletteSizeDiffuse;
		cl_int paletteOffsetLuminosity;
		cl_int paletteSizeLuminosity;
		cl_int paletteOffsetRoughness;
		cl_int paletteSizeRoughness;
		cl_int paletteOffsetReflectance;
		cl_int paletteSizeReflectance;
		cl_int paletteOffsetTransparency;
		cl_int paletteSizeTransparency;

		if (materialIndex < numberOfMaterials)
		{
			const cMaterial &material = materials[materialIndex];
			materialCl = Policy::material(material);

			QString textureName;

			textureName = material.colorTexture.GetFileName();
			materialCl.colorTextureIndex =
				textureIndexes.contains(textureName) ? textureIndexes[textureName] : -1;

			textureName = material.diffusionTexture.GetFileName();
			materialCl.diffusionTextureIndex =
				textureIndexes.contains(textureName) ? textureIndexes[textureName] : -1;

			textureName = material.luminosityTexture.GetFileName();
			materialCl.luminosityTextureIndex =
				textureIndexes.contains(textureName) ? textureIndexes[textureName] : -1;

			textureName = material.displacementTexture.GetFileName() + "grey16bit";
			materialCl.displacementTextureIndex =
				textureIndexes.contains(textureName) ? textureIndexes[textureName] : -1;

			textureName = material.normalMapTexture.GetFileName();
			materialCl.normalMapTextureIndex =
				textureIndexes.contains(textureName) ? textureIndexes[textureName] : -1;

			textureName = material.reflectanceTexture.GetFileName();
			materialCl.reflectanceTextureIndex =
				textureIndexes.contains(textureName) ? textureIndexes[textureName] : -1;

			textureName = material.transparencyTexture.GetFileName();
			materialCl.transparencyTextureIndex =
				textureIndexes.contains(textureName) ? textureIndexes[textureName] : -1;

			textureName = material.transparencyAlphaTexture.GetFileName();
			materialCl.transparencyAlphaTextureIndex =
				textureIndexes.contains(textureName) ? textureIndexes[textureName] : -1;

			textureName = material.roughnessTexture.GetFileName();
			materialCl.roughnessTextureIndex =
				textureIndexes.contains(textureName) ? textureIndexes[textureName] : -1;

			// gradients
			QList<cColorGradient::sColor> gradientSurface =
				material.gradientSurface.GetListOfSortedColors();
			QList<cColorGradient::sColor> gradientSpecular =
				material.gradientSpecular.GetListOfSortedColors();
			QList<cColorGradient::sColor> gradientDiffuse =
				material.gradientDiffuse.GetListOfSortedColors();
			QList<cColorGradient::sColor> gradientLuminosity =
				material.gradientLuminosity.GetListOfSortedColors();
			QList<cColorGradient::sColor> gradientRoughness =
				material.gradientRoughness.GetListOfSortedColors();
			QList<cColorGradient::sColor> gradientReflectance =
				material.gradientReflectance.GetListOfSortedColors();
			QList<cColorGradient::sColor> gradientTransparency =
				material.gradientTransparency.GetListOfSortedColors();

			paletteOffsetSurface = 0;
			paletteSizeSurface = gradientSurface.size();
			totalSizeOfGradients += paletteSizeSurface;

			paletteOffsetSpecular = paletteOffsetSurface + paletteSizeSurface;
			paletteSizeSpecular = gradientSpecular.size();
			totalSizeOfGradients += paletteSizeSpecular;

			paletteOffsetDiffuse = paletteOffsetSpecular + paletteSizeSpecular;
			paletteSizeDiffuse = gradientDiffuse.size();
			totalSizeOfGradients += paletteSizeDiffuse;

			paletteOffsetLuminosity = paletteOffsetDiffuse + paletteSizeDiffuse;
			paletteSizeLuminosity = gradientLuminosity.size();
			totalSizeOfGradients += paletteSizeLuminosity;

			paletteOffsetRoughness = paletteOffsetLuminosity + paletteSizeLuminosity;
			paletteSizeRoughness = gradientRoughness.size();
			totalSizeOfGradients += paletteSizeRoughness;

			paletteOffsetReflectance = paletteOffsetRoughness + paletteSizeRoughness;
			paletteSizeReflectance = gradientReflectance.size();
			totalSizeOfGradients += paletteSizeReflectance;

			paletteOffsetTransparency = paletteOffsetReflectance + paletteSizeReflectance;
			paletteSizeTransparency = gradientTransparency.size();
			totalSizeOfGradients += paletteSizeTransparency;

			paletteCl.resize(totalSizeOfGradients);

			for (int i = 0; i < paletteSizeSurface; i++)
			{
				paletteCl[i + paletteOffsetSurface] = toClFloat4(
					CVector4(gradientSurface[i].color.R / 256.0, gradientSurface[i].color.G / 256.0,
						gradientSurface[i].color.B / 256.0, gradientSurface[i].position));
			}

			for (int i = 0; i < paletteSizeSpecular; i++)
			{
				paletteCl[i + paletteOffsetSpecular] = toClFloat4(
					CVector4(gradientSpecular[i].color.R / 256.0, gradientSpecular[i].color.G / 256.0,
						gradientSpecular[i].color.B / 256.0, gradientSpecular[i].position));
			}

			for (int i = 0; i < paletteSizeDiffuse; i++)
			{
				paletteCl[i + paletteOffsetDiffuse] = toClFloat4(
					CVector4(gradientDiffuse[i].color.R / 256.0, gradientDiffuse[i].color.G / 256.0,
						gradientDiffuse[i].color.B / 256.0, gradientDiffuse[i].position));
			}

			for (int i = 0; i < paletteSizeLuminosity; i++)
			{
				paletteCl[i + paletteOffsetLuminosity] = toClFloat4(
					CVector4(gradientLuminosity[i].color.R / 256.0, gradientLuminosity[i].color.G / 256.0,
						gradientLuminosity[i].color.B / 256.0, gradientLuminosity[i].position));
			}

			for (int i = 0; i < paletteSizeRoughness; i++)
			{
				paletteCl[i + paletteOffsetRoughness] = toClFloat4(
					CVector4(gradientRoughness[i].color.R / 256.0, gradientRoughness[i].color.G / 256.0,
						gradientRoughness[i].color.B / 256.0, gradientRoughness[i].position));
			}

			for (int i = 0; i < paletteSizeReflectance; i++)
			{
				paletteCl[i + paletteOffsetReflectance] = toClFloat4(
					CVector4(gradientReflectance[i].color.R / 256.0, gradientReflectance[i].color.G / 256.0,
						gradientReflectance[i].color.B / 256.0, gradientReflectance[i].position));
			}

			for (int i = 0; i < paletteSizeTransparency; i++)
			{
				paletteCl[i + paletteOffsetTransparency] = toClFloat4(
					CVector4(gradientTransparency[i].color.R / 256.0, gradientTransparency[i].color.G / 256.0,
						gradientTransparency[i].color.B / 256.0, gradientTransparency[i].position));
			}
		}
		else
		{
			// fill not used material with dummy
			memset(&materialCl, 0, sizeof(materialCl));
			paletteOffsetSurface = 0;
			paletteSizeSurface = 2;
			paletteOffsetSpecular = 2;
			paletteSizeSpecular = 2;
			paletteOffsetDiffuse = 4;
			paletteSizeDiffuse = 2;
			paletteOffsetLuminosity = 6;
			paletteSizeLuminosity = 2;
			paletteOffsetRoughness = 8;
			paletteSizeRoughness = 2;
			paletteOffsetReflectance = 10;
			paletteSizeReflectance = 2;
			paletteOffsetTransparency = 12;
			paletteSizeTransparency = 2;
			paletteCl.resize(14);
			for (int i = 0; i < 14; i++)
			{
				paletteCl[i] = toClFloat4(CVector4());
			}
		}

		materialOffsets[materialIndex] = totalDataOffset;

		cl_int materialClOffset = 0;
		cl_int paletteItemsOffset = 0;

		// reserve bytes for cl_int materialClOffset
		int materialClOffsetAddress = totalDataOffset;
		data.append(reinterpret_cast<char *>(&materialClOffset), sizeof(materialClOffset));
		totalDataOffset += sizeof(materialClOffset);

		// reserve bytes cl_int paletteItemsOffset
		int paletteItemsOffsetAddress = totalDataOffset;
		data.append(reinterpret_cast<char *>(&paletteItemsOffset), sizeof(paletteItemsOffset));
		totalDataOffset += sizeof(paletteItemsOffset);

		// cl_int paletteOffsetSurface
		data.append(reinterpret_cast<char *>(&paletteOffsetSurface), sizeof(paletteOffsetSurface));
		totalDataOffset += sizeof(paletteOffsetSurface);

		// cl_int paletteSizeSurface
		data.append(reinterpret_cast<char *>(&paletteSizeSurface), sizeof(paletteSizeSurface));
		totalDataOffset += sizeof(paletteSizeSurface);

		// cl_int paletteOffsetSpecular
		data.append(reinterpret_cast<char *>(&paletteOffsetSpecular), sizeof(paletteOffsetSpecular));
		totalDataOffset += sizeof(paletteOffsetSpecular);

		// cl_int paletteSizeSpecular
		data.append(reinterpret_cast<char *>(&paletteSizeSpecular), sizeof(paletteSizeSpecular));
		totalDataOffset += sizeof(paletteSizeSpecular);

		// cl_int paletteOffsetDiffuse
		data.append(reinterpret_cast<char *>(&paletteOffsetDiffuse), sizeof(paletteOffsetDiffuse));
		totalDataOffset += sizeof(paletteOffsetDiffuse);

		// cl_int paletteSizeDiffuse
		data.append(reinterpret_cast<char *>(&paletteSizeDiffuse), sizeof(paletteSizeDiffuse));
		totalDataOffset += sizeof(paletteSizeDiffuse);

		// cl_int paletteOffsetLuminosity
		data.append(
			reinterpret_cast<char *>(&paletteOffsetLuminosity), sizeof(paletteOffsetLuminosity));
		totalDataOffset += sizeof(paletteOffsetLuminosity);

		// cl_int paletteSizeLuminosity
		data.append(reinterpret_cast<char *>(&paletteSizeLuminosity), sizeof(paletteSizeLuminosity));
		totalDataOffset += sizeof(paletteSizeLuminosity);

		// cl_int paletteOffsetRoughness
		data.append(reinterpret_cast<char *>(&paletteOffsetRoughness), sizeof(paletteOffsetRoughness));
		totalDataOffset += sizeof(paletteOffsetRoughness);

		// cl_int paletteSizeRoughness
		data.append(reinterpret_cast<char *>(&paletteSizeRoughness), sizeof(paletteSizeRoughness));
		totalDataOffset += sizeof(paletteSizeRoughness);

		// cl_int paletteOffsetReflectance
		data.append(
			reinterpret_cast<char *>(&paletteOffsetReflectance), sizeof(paletteOffsetReflectance));
		totalDataOffset += sizeof(paletteOffsetReflectance);

		// cl_int paletteSizeReflectance
		data.append(reinterpret_cast<char *>(&paletteSizeReflectance), sizeof(paletteSizeReflectance));
		totalDataOffset += sizeof(paletteSizeReflectance);

		// cl_int paletteOffsetTransparency
		data.append(
			reinterpret_cast<char *>(&paletteOffsetTransparency), sizeof(paletteOffsetTransparency));
		totalDataOffset += sizeof(paletteOffsetTransparency);

		// cl_int paletteSizeTransparency
		data.append(
			reinterpret_cast<char *>(&paletteSizeTransparency), sizeof(paletteSizeTransparency));
		totalDataOffset += sizeof(paletteSizeTransparency);

		// add dummy bytes for alignment
		totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);

		// sMaterialCl material
		materialClOffset = totalDataOffset;
		data.append(reinterpret_cast<char *>(&materialCl), sizeof(materialCl));
		totalDataOffset += sizeof(materialCl);

		// fill materialClOffset value
		data.replace(materialClOffsetAddress, sizeof(materialClOffset),
			reinterpret_cast<char *>(&materialClOffset), sizeof(materialClOffset));

		// add dummy bytes for alignment
		totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);

		// palette data
		paletteItemsOffset = totalDataOffset;
		int paletteSizeBytes = totalSizeOfGradients * sizeof(cl_float4);
		data.append(reinterpret_cast<char *>(paletteCl.data()), paletteSizeBytes);
		totalDataOffset += paletteSizeBytes;

		// fill paletteItemsOffset value
		data.replace(paletteItemsOffsetAddress, sizeof(paletteItemsOffset),
			reinterpret_cast<char *>(&paletteItemsOffset), sizeof(paletteItemsOffset));
	}

	// fill materials offsets:
	data.replace(materialOffsetsAddress, materialOffsetsSize,
		reinterpret_cast<char *>(materialOffsets.data()), materialOffsetsSize);

	return numberOfMaterials;
}

void cOpenClDynamicData::BuildAOVectorsData(const sVectorsAround *AOVectors, cl_int vectorsCount)
{
	if (doublePrecision)
		BuildAOVectorsDataImpl<DynamicDoublePolicy>(AOVectors, vectorsCount);
	else
		BuildAOVectorsDataImpl<DynamicSinglePolicy>(AOVectors, vectorsCount);
}

template <typename Policy>
void cOpenClDynamicData::BuildAOVectorsDataImpl(
	const sVectorsAround *AOVectors, int vectorsCount)
{
	/* use __attribute__((aligned(16))) in kernel code for array
	 *
	 * header:
	 * cl_int vectorsCount
	 * cl_int arrayOffset;
	 *
	 * array (aligned to 16):
	 * 	sVectorsAroundCl item1
	 * 	sVectorsAroundCl item2
	 * 	...
	 *	sVectorsAroundCl itemN
	 */

	const int alignment = Policy::alignment;
	totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);
	itemOffsets[AOVectorsItemIndex].itemOffset = totalDataOffset;

	data.append(reinterpret_cast<char *>(&vectorsCount), sizeof(vectorsCount));
	totalDataOffset += sizeof(vectorsCount);

	// reserve bytes for array offset
	cl_int arrayOffset = 0;
	int arrayOffsetAddress = totalDataOffset;
	data.append(reinterpret_cast<char *>(&arrayOffset), sizeof(arrayOffset));
	totalDataOffset += sizeof(arrayOffset);

	// copy AO vectors aligned
	for (int i = 0; i < vectorsCount; i++)
	{
		totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);
		if (i == 0) arrayOffset = totalDataOffset;

		typename Policy::VectorsAroundCl vector;
		vector.v = Policy::vec3(AOVectors[i].v);
		vector.color = Policy::vec3(AOVectors[i].color);

		data.append(reinterpret_cast<char *>(&vector), sizeof(vector));
		totalDataOffset += sizeof(vector);
	}

	// replace arrayOffset:
	data.replace(arrayOffsetAddress, sizeof(arrayOffset), reinterpret_cast<char *>(&arrayOffset),
		sizeof(arrayOffset));
}

void cOpenClDynamicData::BuildLightsData(
	const cLights *lights, const QMap<QString, int> &textureIndexes)
{
	if (doublePrecision)
		BuildLightsDataImpl<DynamicDoublePolicy>(lights, textureIndexes);
	else
		BuildLightsDataImpl<DynamicSinglePolicy>(lights, textureIndexes);
}

template <typename Policy>
void cOpenClDynamicData::BuildLightsDataImpl(
	const cLights *lights, const QMap<QString, int> &textureIndexes)
{
	/* use __attribute__((aligned(16))) in kernel code for array
	 *
	 * header:
	 * cl_int numberOfLights
	 * cl_int arrayOffset;
	 *
	 * array (aligned to 16):
	 * 	sLightCl light1
	 * 	sLightCl light1
	 *  ...
	 * 	sLightCl lightN
	 */

	const int alignment = Policy::alignment;
	totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);
	itemOffsets[lightsItemIndex].itemOffset = totalDataOffset;

	cl_int numberOfLights = lights->GetNumberOfLights();
	data.append(reinterpret_cast<char *>(&numberOfLights), sizeof(numberOfLights));
	totalDataOffset += sizeof(numberOfLights);

	// reserve bytes for array offset
	cl_int arrayOffset = 0;
	int arrayOffsetAddress = totalDataOffset;
	data.append(reinterpret_cast<char *>(&arrayOffset), sizeof(arrayOffset));
	totalDataOffset += sizeof(arrayOffset);

	// copy lights aligned
	for (int i = 0; i < numberOfLights; i++)
	{
		totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);
		if (i == 0) arrayOffset = totalDataOffset;

		typename Policy::LightCl lightCl;
		const cLight *light = lights->GetLight(i);

		lightCl.enabled = light->enabled;
		lightCl.castShadows = light->castShadows;
		lightCl.penetrating = light->penetrating;
		lightCl.relativePosition = light->relativePosition;
		lightCl.repeatTexture = light->repeatTexture;
		lightCl.volumetric = light->volumetric;

		lightCl.coneAngle = light->coneAngle;
		lightCl.coneSoftAngle = light->coneSoftAngle;
		lightCl.intensity = light->intensity;
		lightCl.visibility = light->visibility;
		lightCl.volumetricVisibility = light->volumetricVisibility;
		lightCl.size = light->size;
		lightCl.softShadowCone = light->softShadowCone;
		lightCl.contourSharpness = light->contourSharpness;
		lightCl.coneRatio = light->coneRatio;
		lightCl.coneSoftRatio = light->coneSoftRatio;
		lightCl.projectionHorizontalRatio = light->projectionHorizontalRatio;
		lightCl.projectionVerticalRatio = light->projectionVerticalRatio;

		lightCl.position = Policy::vec3(light->position);
		lightCl.rotation = Policy::vec3(light->rotation);
		lightCl.target = Policy::vec3(light->target);
		lightCl.lightDirection = Policy::vec3(light->lightDirection);
		lightCl.lightTopVector = Policy::vec3(light->lightTopVector);
		lightCl.lightRightVector = Policy::vec3(light->lightRightVector);

		lightCl.color = Policy::vec3(light->color);

		lightCl.rotMatrix = Policy::mat33(light->rotMatrix);

		lightCl.type = static_cast<enumLightTypeCl>(light->type);
		lightCl.decayFunction = static_cast<enumLightDecayFunctionCl>(light->decayFunction);

		QString textureName = light->colorTexture.GetFileName();
		lightCl.colorTextureIndex =
			textureIndexes.contains(textureName) ? textureIndexes[textureName] : -1;

		data.append(reinterpret_cast<char *>(&lightCl), sizeof(lightCl));
		totalDataOffset += sizeof(lightCl);
	}

	// replace arrayOffset:
	data.replace(arrayOffsetAddress, sizeof(arrayOffset), reinterpret_cast<char *>(&arrayOffset),
		sizeof(arrayOffset));
}

QString cOpenClDynamicData::BuildPrimitivesData(const cPrimitives *primitivesContainer)
{
	return doublePrecision ? BuildPrimitivesDataImpl<DynamicDoublePolicy>(primitivesContainer)
												 : BuildPrimitivesDataImpl<DynamicSinglePolicy>(primitivesContainer);
}

template <typename Policy>
QString cOpenClDynamicData::BuildPrimitivesDataImpl(const cPrimitives *primitivesContainer)
{
	/* use __attribute__((aligned(16))) in kernel code for array
	 *
	 * header:
	 * cl_int numberOfPrimitives
	 * cl_int globalPositionOffset
	 * cl_int arrayOffset;
	 *
	 * sPrimitiveGlobalPositionCl (aligned to 16)
	 *
	 * array (aligned to 16):
	 * 	sPrimitiveCl primitive1
	 * 	sPrimitiveCl primitive2
	 *  ...
	 * 	sPrimitiveCl primitiveN
	 */

	const int alignment = Policy::alignment;
	totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);
	itemOffsets[primitivesItemIndex].itemOffset = totalDataOffset;

	cl_int numberOfPrimitives = primitivesContainer->GetNumberOfPrimivives();
	data.append(reinterpret_cast<char *>(&numberOfPrimitives), sizeof(numberOfPrimitives));
	totalDataOffset += sizeof(numberOfPrimitives);

	// reserve bytes for sPrimitiveGlobalPosition offset
	cl_int globalPositionOffset = 0;
	int globalPositionOffsetAddress = totalDataOffset;
	data.append(reinterpret_cast<char *>(&globalPositionOffset), sizeof(globalPositionOffset));
	totalDataOffset += sizeof(globalPositionOffset);

	// reserve bytes for array offset
	cl_int arrayOffset = 0;
	int arrayOffsetAddress = totalDataOffset;
	data.append(reinterpret_cast<char *>(&arrayOffset), sizeof(arrayOffset));
	totalDataOffset += sizeof(arrayOffset);

	totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);
	globalPositionOffset = totalDataOffset;
	typename Policy::PrimitiveGlobalCl globalData;
	globalData.allPrimitivesPosition = Policy::vec3(primitivesContainer->allPrimitivesPosition);
	globalData.allPrimitivesRotation = Policy::vec3(primitivesContainer->allPrimitivesRotation);
	globalData.mRotAllPrimitivesRotation =
		Policy::mat33(primitivesContainer->mRotAllPrimitivesRotation);
	globalData.primitiveIndexForBasicFog = primitivesContainer->primitiveIndexForBasicFog;
	globalData.primitiveIndexForDistFog = primitivesContainer->primitiveIndexForDistFog;
	globalData.primitiveIndexForIterFog = primitivesContainer->primitiveIndexForIterFog;
	globalData.primitiveIndexForClouds = primitivesContainer->primitiveIndexForClouds;
	data.append(reinterpret_cast<char *>(&globalData), sizeof(globalData));
	totalDataOffset += sizeof(globalData);
	data.replace(globalPositionOffsetAddress, sizeof(globalPositionOffset),
		reinterpret_cast<char *>(&globalPositionOffset), sizeof(globalPositionOffset));

	bool usePrimitivePlane = false;
	bool usePrimitiveBox = false;
	bool usePrimitiveSphere = false;
	bool usePrimitiveRectangle = false;
	bool usePrimitiveCylinder = false;
	bool usePrimitiveCircle = false;
	bool usePrimitiveCone = false;
	bool usePrimitiveWater = false;
	bool usePrimitiveTorus = false;
	bool usePrimitivePrism = false;
	bool usePrimitiveEllipsoid = false;

	// copy primitives data aligned
	for (int i = 0; i < numberOfPrimitives; i++)
	{
		totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);

		if (i == 0) arrayOffset = totalDataOffset;

		typename Policy::PrimitiveCl primitiveCl;
		memset(&primitiveCl, 0, sizeof(primitiveCl));
		const std::shared_ptr<sPrimitiveBasic> primitive = primitivesContainer->GetPrimitive(i);

		// FIXME: to correct OpenCL code for objectsTree
		// primitiveCl.object.enable = primitive->enable;
		primitiveCl.object.objectId = primitive->objectId;
		primitiveCl.object.objectType = static_cast<enumObjectTypeCl>(primitive->objectType);
		// primitiveCl.object.position = Policy::vec3(primitive->position);
		// primitiveCl.object.rotationMatrix = Policy::mat33(primitive->rotationMatrix);
		primitiveCl.object.size = Policy::vec3(primitive->size);
		// primitiveCl.object.repeat = Policy::vec3(primitive->repeat);
		primitiveCl.booleanOperator =
			static_cast<enumClPrimitiveBooleanOperator>(primitive->booleanOperator);
		primitiveCl.object.usedForVolumetric = primitive->usedForVolumetric;
		primitiveCl.object.wallThickness = primitive->wallThickness;

		try
		{
			switch (primitive->objectType)
			{
				case fractal::objPlane:
				{
					const sPrimitivePlane *plane = dynamic_cast<const sPrimitivePlane *>(primitive.get());
					if (plane)
					{
						primitiveCl.data.plane.empty = plane->empty;
						usePrimitivePlane = true;
					}
					else
						throw QString("sPrimitivePlane");
					break;
				}

				case fractal::objBox:
				{
					const sPrimitiveBox *box = dynamic_cast<const sPrimitiveBox *>(primitive.get());
					if (box)
					{
						primitiveCl.data.box.empty = box->empty;
						primitiveCl.data.box.rounding = box->rounding;
						primitiveCl.data.box.limitsEnable = box->limitsEnable;
						primitiveCl.data.box.limitsMax = Policy::vec3(box->limitsMax);
						primitiveCl.data.box.limitsMin = Policy::vec3(box->limitsMin);
						usePrimitiveBox = true;
					}
					else
						throw QString("sPrimitivePlane");
					break;
				}

				case fractal::objSphere:
				{
					const sPrimitiveSphere *sphere = dynamic_cast<const sPrimitiveSphere *>(primitive.get());
					if (sphere)
					{
						primitiveCl.data.sphere.empty = sphere->empty;
						primitiveCl.data.sphere.radius = sphere->radius;
						primitiveCl.data.sphere.limitsEnable = sphere->limitsEnable;
						primitiveCl.data.sphere.limitsMax = Policy::vec3(sphere->limitsMax);
						primitiveCl.data.sphere.limitsMin = Policy::vec3(sphere->limitsMin);
						usePrimitiveSphere = true;
					}
					else
						throw QString("sPrimitiveSphere");
					break;
				}

				case fractal::objWater:
				{
					const sPrimitiveWater *water = dynamic_cast<const sPrimitiveWater *>(primitive.get());
					if (water)
					{
						primitiveCl.data.water.empty = water->empty;
						primitiveCl.data.water.waveFromObjectsEnable = water->waveFromObjectsEnable;
						primitiveCl.data.water.relativeAmplitude = water->relativeAmplitude;
						primitiveCl.data.water.animSpeed = water->animSpeed;
						primitiveCl.data.water.animProgressionSpeed = water->animProgressionSpeed;
						primitiveCl.data.water.length = water->length;
						primitiveCl.data.water.waveFromObjectsRelativeAmplitude =
							water->waveFromObjectsRelativeAmplitude;
						primitiveCl.data.water.iterations = water->iterations;
						primitiveCl.data.water.animFrame = water->animFrame;
						primitiveCl.data.water.limitsEnable = water->limitsEnable;
						primitiveCl.data.water.limitsMax = Policy::vec3(water->limitsMax);
						primitiveCl.data.water.limitsMin = Policy::vec3(water->limitsMin);
						usePrimitiveWater = true;
					}
					else
						throw QString("sPrimitiveWater");
					break;
				}

				case fractal::objCone:
				{
					const sPrimitiveCone *cone = dynamic_cast<const sPrimitiveCone *>(primitive.get());
					if (cone)
					{
						primitiveCl.data.cone.empty = cone->empty;
						primitiveCl.data.cone.caps = cone->caps;
						primitiveCl.data.cone.radius = cone->radius;
						primitiveCl.data.cone.height = cone->height;
						primitiveCl.data.cone.wallNormal = Policy::vec2(cone->wallNormal);
						primitiveCl.data.cone.limitsEnable = cone->limitsEnable;
						primitiveCl.data.cone.limitsMax = Policy::vec3(cone->limitsMax);
						primitiveCl.data.cone.limitsMin = Policy::vec3(cone->limitsMin);
						usePrimitiveCone = true;
					}
					else
						throw QString("sPrimitiveCone");
					break;
				}

				case fractal::objCylinder:
				{
					const sPrimitiveCylinder *cylinder =
						dynamic_cast<const sPrimitiveCylinder *>(primitive.get());
					if (cylinder)
					{
						primitiveCl.data.cylinder.empty = cylinder->empty;
						primitiveCl.data.cylinder.caps = cylinder->caps;
						primitiveCl.data.cylinder.radius = cylinder->radius;
						primitiveCl.data.cylinder.height = cylinder->height;
						primitiveCl.data.cylinder.limitsEnable = cylinder->limitsEnable;
						primitiveCl.data.cylinder.limitsMax = Policy::vec3(cylinder->limitsMax);
						primitiveCl.data.cylinder.limitsMin = Policy::vec3(cylinder->limitsMin);
						usePrimitiveCylinder = true;
					}
					else
						throw QString("sPrimitiveCylinder");
					break;
				}

				case fractal::objTorus:
				{
					const sPrimitiveTorus *torus = dynamic_cast<const sPrimitiveTorus *>(primitive.get());
					if (torus)
					{
						primitiveCl.data.torus.empty = torus->empty;
						primitiveCl.data.torus.radius = torus->radius;
						primitiveCl.data.torus.radiusLPow = torus->radiusLPow;
						primitiveCl.data.torus.tubeRadius = torus->tubeRadius;
						primitiveCl.data.torus.tubeRadiusLPow = torus->tubeRadiusLPow;
						primitiveCl.data.torus.limitsEnable = torus->limitsEnable;
						primitiveCl.data.torus.limitsMax = Policy::vec3(torus->limitsMax);
						primitiveCl.data.torus.limitsMin = Policy::vec3(torus->limitsMin);
						usePrimitiveTorus = true;
					}
					else
						throw QString("sPrimitiveTorus");
					break;
				}

				case fractal::objCircle:
				{
					const sPrimitiveCircle *circle = dynamic_cast<const sPrimitiveCircle *>(primitive.get());
					if (circle)
					{
						primitiveCl.data.circle.radius = circle->radius;
						usePrimitiveCircle = true;
					}
					else
						throw QString("sPrimitiveCircle");
					break;
				}

				case fractal::objRectangle:
				{
					const sPrimitiveRectangle *rectangle =
						dynamic_cast<const sPrimitiveRectangle *>(primitive.get());
					if (rectangle)
					{
						primitiveCl.data.rectangle.height = rectangle->height;
						primitiveCl.data.rectangle.width = rectangle->width;
						usePrimitiveRectangle = true;
					}
					else
						throw QString("sPrimitiveRectangle");
					break;
				}

				case fractal::objPrism:
				{
					const sPrimitivePrism *prism = dynamic_cast<const sPrimitivePrism *>(primitive.get());
					if (prism)
					{
						primitiveCl.data.prism.empty = prism->empty;
						primitiveCl.data.prism.triangleHeight = prism->triangleHeight;
						primitiveCl.data.prism.height = prism->height;
						primitiveCl.data.prism.prismAngle = prism->prismAngle;
						primitiveCl.data.prism.normals = Policy::vec3(prism->normals);
						// primitiveCl.data.prism.repeat = Policy::vec3(prism->repeat);

						usePrimitivePrism = true;
					}
					else
						throw QString("sPrimitivePrism");
					break;
				}

				case fractal::objEllipsoid:
				{
					const sPrimitiveEllipsoid *ellipsoid =
						dynamic_cast<const sPrimitiveEllipsoid *>(primitive.get());
					if (ellipsoid)
					{
						primitiveCl.data.ellipsoid.empty = ellipsoid->empty;
						primitiveCl.data.ellipsoid.limitsEnable = ellipsoid->limitsEnable;
						primitiveCl.data.ellipsoid.limitsMax = Policy::vec3(ellipsoid->limitsMax);
						primitiveCl.data.ellipsoid.limitsMin = Policy::vec3(ellipsoid->limitsMin);
						usePrimitiveEllipsoid = true;
					}
					else
						throw QString("sPrimitiveEllipsoid");
					break;
				}

				default:
				{
					qCritical() << "cOpenClDynamicData::BuildPrimitivesData - invalid object type";
					break;
				}
			}
		}
		catch (const QString &ex)
		{
			qCritical() << QString(
				"cOpenClDynamicData::BuildPrimitivesData - invalid dynamic cast to %1 "
				"object - error: ")
									<< ex;
		}

		data.append(reinterpret_cast<char *>(&primitiveCl), sizeof(primitiveCl));
		totalDataOffset += sizeof(primitiveCl);
	}

	// replace arrayOffset:
	data.replace(arrayOffsetAddress, sizeof(arrayOffset), reinterpret_cast<char *>(&arrayOffset),
		sizeof(arrayOffset));

	QString definesCollector;
	if (usePrimitiveBox) definesCollector += " -DUSE_PRIMITIVE_BOX";
	if (usePrimitiveCircle) definesCollector += " -DUSE_PRIMITIVE_CIRCLE";
	if (usePrimitiveCone) definesCollector += " -DUSE_PRIMITIVE_CONE";
	if (usePrimitiveCylinder) definesCollector += " -DUSE_PRIMITIVE_CYLINDER";
	if (usePrimitivePlane) definesCollector += " -DUSE_PRIMITIVE_PLANE";
	if (usePrimitivePrism) definesCollector += " -DUSE_PRIMITIVE_PRISM";
	if (usePrimitiveRectangle) definesCollector += " -DUSE_PRIMITIVE_RECTANGLE";
	if (usePrimitiveSphere) definesCollector += " -DUSE_PRIMITIVE_SPHERE";
	if (usePrimitiveTorus) definesCollector += " -DUSE_PRIMITIVE_TORUS";
	if (usePrimitiveWater) definesCollector += " -DUSE_PRIMITIVE_WATER";
	if (usePrimitiveEllipsoid) definesCollector += " -DUSE_PRIMITIVE_ELLIPSOID";

	if (primitivesContainer->primitiveIndexForBasicFog >= 0)
		definesCollector += " -DBASIC_FOG_SHAPE_FROM_PRIMITIVE";
	if (primitivesContainer->primitiveIndexForDistFog >= 0)
		definesCollector += " -DDIST_FOG_SHAPE_FROM_PRIMITIVE";
	if (primitivesContainer->primitiveIndexForIterFog >= 0)
		definesCollector += " -DITER_FOG_SHAPE_FROM_PRIMITIVE";
	if (primitivesContainer->primitiveIndexForClouds >= 0)
		definesCollector += " -DCLOUDS_SHAPE_FROM_PRIMITIVE";

	return definesCollector;
}

void cOpenClDynamicData::BuildObjectsData(const std::vector<cObjectData> *objectData)
{
	if (doublePrecision)
		BuildObjectsDataImpl<DynamicDoublePolicy>(objectData);
	else
		BuildObjectsDataImpl<DynamicSinglePolicy>(objectData);
}

template <typename Policy>
void cOpenClDynamicData::BuildObjectsDataImpl(const std::vector<cObjectData> *objectData)
{
	/* use __attribute__((aligned(16))) in kernel code for array
	 *
	 * header:
	 * cl_int numberOfObjects
	 * cl_int arrayOffset;
	 *
	 * array (aligned to 16):
	 * 	objectDataCl object1
	 * 	objectDataCl object2
	 *  ...
	 * 	objectDataCl objectN
	 */

	const int alignment = Policy::alignment;
	totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);
	itemOffsets[objectsItemIndex].itemOffset = totalDataOffset;

	cl_int numberOfObjects = cl_int(objectData->size());
	data.append(reinterpret_cast<char *>(&numberOfObjects), sizeof(numberOfObjects));
	totalDataOffset += sizeof(numberOfObjects);

	// reserve bytes for array offset
	cl_int arrayOffset = 0;
	int arrayOffsetAddress = totalDataOffset;
	data.append(reinterpret_cast<char *>(&arrayOffset), sizeof(arrayOffset));
	totalDataOffset += sizeof(arrayOffset);

	// copy objects aligned
	for (int i = 0; i < numberOfObjects; i++)
	{
		totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);
		if (i == 0) arrayOffset = totalDataOffset;

		typename Policy::ObjectDataCl objectCl;
		memset(&objectCl, 0, sizeof(objectCl));
		const cObjectData *object = &objectData->at(i);
		objectCl.usedForVolumetric = object->usedForVolumetric;
		objectCl.wallThickness = object->wallThickness;
		objectCl.materialId = object->materialId;
		objectCl.objectId = i;
		objectCl.objectType = static_cast<enumObjectTypeCl>(object->objectType);
		objectCl.enable = true;
		objectCl.position = Policy::vec3(CVector3(0.0, 0.0, 0.0));
		objectCl.size = Policy::vec3(object->size);
		objectCl.repeat = Policy::vec3(CVector3(0.0, 0.0, 0.0));
		objectCl.rotationMatrix = Policy::mat33(object->rotationMatrix);
		objectCl.worldToLocalMatrix = Policy::mat44(object->worldToLocalMatrix);
		objectCl.absScale = object->absScale;
		objectCl.detailLevelMultiplier = object->detailLevelMultiplier;

		data.append(reinterpret_cast<char *>(&objectCl), sizeof(objectCl));
		totalDataOffset += sizeof(objectCl);
	}

	// replace arrayOffset:
	data.replace(arrayOffsetAddress, sizeof(arrayOffset), reinterpret_cast<char *>(&arrayOffset),
		sizeof(arrayOffset));
}

void cOpenClDynamicData::BuildNodesData(
	const std::vector<cObjectsTree::sNodeDataForRendering> *nodesData)
{
	if (doublePrecision)
		BuildNodesDataImpl<DynamicDoublePolicy>(nodesData);
	else
		BuildNodesDataImpl<DynamicSinglePolicy>(nodesData);
}

template <typename Policy>
void cOpenClDynamicData::BuildNodesDataImpl(
	const std::vector<cObjectsTree::sNodeDataForRendering> *nodesData)
{
	/* use __attribute__((aligned(16))) in kernel code for array
	 *
	 * header:
	 * cl_int numberOfNodes
	 * cl_int arrayOffset;
	 *
	 * array (aligned to 16):
	 * 	sNodeDataForRenderingCl node1
	 * 	sNodeDataForRenderingCl node2
	 *  ...
	 * 	sNodeDataForRenderingCl nodeN
	 */

	// cObjectsTree::DebugPrintNodes(*nodesData);

	const int alignment = Policy::alignment;
	totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);
	itemOffsets[nodesItemIndex].itemOffset = totalDataOffset;

	cl_int numberOfNodes = cl_int(nodesData->size());
	data.append(reinterpret_cast<char *>(&numberOfNodes), sizeof(numberOfNodes));
	totalDataOffset += sizeof(numberOfNodes);

	// reserve bytes for array offset
	cl_int arrayOffset = 0;
	int arrayOffsetAddress = totalDataOffset;
	data.append(reinterpret_cast<char *>(&arrayOffset), sizeof(arrayOffset));
	totalDataOffset += sizeof(arrayOffset);

	// copy nodes aligned
	for (int i = 0; i < numberOfNodes; i++)
	{
		totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);
		if (i == 0) arrayOffset = totalDataOffset;

		typename Policy::NodeDataCl nodeCl;
		memset(&nodeCl, 0, sizeof(nodeCl));
		const cObjectsTree::sNodeDataForRendering &node = nodesData->at(i);
		nodeCl.id = node.id;
		nodeCl.type = static_cast<enumNodeTypeCl>(static_cast<int>(node.type));
		nodeCl.parentId = node.parentId;
		nodeCl.userObjectId = node.userObjectId;
		nodeCl.internalObjectId = node.internalObjectId;
		nodeCl.primitiveIdx = node.primitiveIdx;
		nodeCl.level = node.level;
		nodeCl.hybridSequenceIndex = node.hybridSequenceIndex;
		nodeCl.repeat = Policy::vec3(node.repeat);
		nodeCl.scale = node.scale;
		nodeCl.absScale = node.absScale;
		nodeCl.material = node.material;
		nodeCl.rotationMatrix = Policy::mat33(node.rotationMatrix);
		nodeCl.worldToLocalMatrix = Policy::mat44(node.worldToLocalMatrix);
		nodeCl.enabled = node.enabled ? 1 : 0;
		nodeCl.detailLevelMultiplier = node.detailLevelMultiplier;
		// Common fractal parameters shared by all node types (including boolean groups)
		nodeCl.julia_mode = node.juliaMode ? 1 : 0;
		nodeCl.julia_c = Policy::vec3(node.juliaConstant);
		nodeCl.fractal_constant_factor = Policy::vec3(node.fractalConstantMultiplier);
		nodeCl.initial_waxis = node.initialWAxis;
		nodeCl.smooth_de_combine_enable = node.smoothDECombineEnable ? 1 : 0;
		nodeCl.smooth_de_combine_distance = node.smoothDECombineDistance;
		nodeCl.formula_maxiter = node.formulaMaxiter;

		data.append(reinterpret_cast<char *>(&nodeCl), sizeof(nodeCl));
		totalDataOffset += sizeof(nodeCl);
	}

	// replace arrayOffset:
	data.replace(arrayOffsetAddress, sizeof(arrayOffset), reinterpret_cast<char *>(&arrayOffset),
		sizeof(arrayOffset));
}

template <typename Policy>
void cOpenClDynamicData::BuildHybridSequencesDataImpl(
	const cHybridFractalSequences *hybridSequences)
{
	/* hybrid sequences dynamic data structure:
	 *
	 * header:
	 * cl_int numberOfSequences
	 * cl_int sequencesArrayOffset  // offset to sHybridSequenceCl array
	 *
	 * array of sHybridSequenceCl (aligned):
	 *   sHybridSequenceCl seq0
	 *   sHybridSequenceCl seq1
	 *   ...
	 *
	 * for each sequence:
	 *   cl_int sequenceArray[] (the iteration-to-fractal mapping)
	 *   sHybridFractalDataCl fractData[]
	 */

	const int alignment = Policy::alignment;
	totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);
	itemOffsets[hybridSequencesItemIndex].itemOffset = totalDataOffset;

	cl_int numberOfSequences = hybridSequences->GetNumberOfSequences();
	data.append(reinterpret_cast<char *>(&numberOfSequences), sizeof(numberOfSequences));
	totalDataOffset += sizeof(numberOfSequences);

	// reserve bytes for sequences array offset
	cl_int sequencesArrayOffset = 0;
	int sequencesArrayOffsetAddress = totalDataOffset;
	data.append(reinterpret_cast<char *>(&sequencesArrayOffset), sizeof(sequencesArrayOffset));
	totalDataOffset += sizeof(sequencesArrayOffset);

	// write sequence headers (sHybridSequenceCl array)
	totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);
	sequencesArrayOffset = totalDataOffset;

	// store addresses where we need to patch offsets
	std::vector<int> seqArrayOffsetAddresses(numberOfSequences);
	std::vector<int> fractDataOffsetAddresses(numberOfSequences);

	int formulaBaseIndex = 0; // cumulative global formula index across all sequences
	for (int i = 0; i < numberOfSequences; i++)
	{
		totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);

		const cHybridFractalSequences::sSequence *seq = hybridSequences->GetSequence(i);

		typename Policy::HybridSequenceCl seqCl;
		memset(&seqCl, 0, sizeof(seqCl));
		seqCl.length = seq->length;
		seqCl.tableLength = seq->tableLength;
		seqCl.numberOfFractalsInTheSequence = seq->numberOfFractalsInTheSequence;
		seqCl.internalObjectId = seq->internalObjectId;
		seqCl.DEFunctionType = static_cast<enumDEFunctionTypeCl>(seq->DEFunctionType);
		seqCl.DEType = static_cast<enumDETypeCl>(seq->DEType);
		seqCl.DEAnalyticFunction = static_cast<enumDEAnalyticFunctionCl>(seq->DEAnalyticFunction);
		seqCl.coloringFunction = static_cast<enumColoringFunctionCl>(seq->coloringFunction);
		seqCl.isHybrid = seq->isHybrid;
		seqCl.juliaEnabled = seq->juliaEnabled;
		seqCl.juliaConstant = Policy::vec3(seq->juliaConstant);
		seqCl.constantMultiplier = Policy::vec3(seq->constantMultiplier);
		seqCl.initialWAxis = seq->initialWAxis;
		seqCl.formulaMaxiter = seq->formulaMaxiter;
		seqCl.sequenceArrayOffset = 0;	// will be patched later
		seqCl.fractDataArrayOffset = 0; // will be patched later
		seqCl.formulaBaseIndex = formulaBaseIndex;

		formulaBaseIndex += seq->numberOfFractalsInTheSequence;

		// record addresses for patching
		int seqClStartAddress = totalDataOffset;
		seqArrayOffsetAddresses[i] =
			seqClStartAddress + offsetof(typename Policy::HybridSequenceCl, sequenceArrayOffset);
		fractDataOffsetAddresses[i] =
			seqClStartAddress + offsetof(typename Policy::HybridSequenceCl, fractDataArrayOffset);

		data.append(reinterpret_cast<char *>(&seqCl), sizeof(seqCl));
		totalDataOffset += sizeof(seqCl);
	}

	// now write variable-length data for each sequence
	for (int i = 0; i < numberOfSequences; i++)
	{
		const cHybridFractalSequences::sSequence *seq = hybridSequences->GetSequence(i);

		// write sequence array (cl_int[]); the whole table is uploaded (not only the
		// valid part) so that tail iterations repeat the last active formula identically
		// to the CPU code (old cNineFractals behavior)
		totalDataOffset += PutDummyToAlign(totalDataOffset, 4, &data);
		cl_int seqArrayOff = totalDataOffset;

		for (int j = 0; j < seq->tableLength; j++)
		{
			cl_int val = seq->seqence[j];
			data.append(reinterpret_cast<char *>(&val), sizeof(val));
			totalDataOffset += sizeof(val);
		}

		// patch sequenceArrayOffset
		data.replace(seqArrayOffsetAddresses[i], sizeof(cl_int), reinterpret_cast<char *>(&seqArrayOff),
			sizeof(cl_int));

		// write fractData array (sHybridFractalDataCl[])
		totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);
		cl_int fractDataOff = totalDataOffset;

		for (int j = 0; j < seq->numberOfFractalsInTheSequence; j++)
		{
			totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);
			const cHybridFractalSequences::sFractalData &fd = seq->fractData[j];

			typename Policy::HybridFractalDataCl fdCl;
			memset(&fdCl, 0, sizeof(fdCl));
			fdCl.formulaWeight = fd.formulaWeight;
			fdCl.formulaIterations = fd.formulaIterations;
			fdCl.formulaStartIteration = fd.formulaStartIteration;
			fdCl.formulaStopIteration = fd.formulaStopIteration;
			fdCl.addCConstant = fd.addCConstant;
			fdCl.checkForBailout = fd.checkForBailout;
			fdCl.bailout = fd.bailout;
			fdCl.useAdditionalBailoutCond = fd.useAdditionalBailoutCond;
			fdCl.fractalParameters = Policy::fractal(fd.fractalParameters);

			data.append(reinterpret_cast<char *>(&fdCl), sizeof(fdCl));
			totalDataOffset += sizeof(fdCl);
		}

		// patch fractDataArrayOffset
		data.replace(fractDataOffsetAddresses[i], sizeof(cl_int),
			reinterpret_cast<char *>(&fractDataOff), sizeof(cl_int));
	}

	// patch sequencesArrayOffset in header
	data.replace(sequencesArrayOffsetAddress, sizeof(numberOfSequences),
		reinterpret_cast<char *>(&sequencesArrayOffset), sizeof(sequencesArrayOffset));
}

void cOpenClDynamicData::BuildHybridSequencesData(const cHybridFractalSequences *hybridSequences)
{
	if (doublePrecision)
		BuildHybridSequencesDataImpl<DynamicDoublePolicy>(hybridSequences);
	else
		BuildHybridSequencesDataImpl<DynamicSinglePolicy>(hybridSequences);
}

void cOpenClDynamicData::BuildFractalData(const cHybridFractalSequences *hybridSequences)
{
	if (doublePrecision)
		BuildFractalDataImpl<DynamicDoublePolicy>(hybridSequences);
	else
		BuildFractalDataImpl<DynamicSinglePolicy>(hybridSequences);
}

template <typename Policy>
void cOpenClDynamicData::BuildFractalDataImpl(const cHybridFractalSequences *hybridSequences)
{
	/* fractal dynamic data structure:
	 *
	 * header:
	 * cl_int numberOfFractals
	 * cl_int fractalsArrayOffset  // offset to sFractalCl array
	 *
	 * array of sFractalCl (aligned):
	 *   sFractalCl fractal0
	 *   sFractalCl fractal1
	 *   ...
	 */

	const int alignment = Policy::alignment;
	totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);
	itemOffsets[fractalsItemIndex].itemOffset = totalDataOffset;

	// Count total number of fractals across all sequences
	int totalFractals = 0;
	int numberOfSequences = hybridSequences->GetNumberOfSequences();
	for (int i = 0; i < numberOfSequences; i++)
	{
		const cHybridFractalSequences::sSequence *seq = hybridSequences->GetSequence(i);
		totalFractals += seq->numberOfFractalsInTheSequence;
	}

	data.append(reinterpret_cast<char *>(&totalFractals), sizeof(totalFractals));
	totalDataOffset += sizeof(totalFractals);

	// reserve bytes for fractals array offset
	cl_int fractalsArrayOffset = 0;
	int fractalsArrayOffsetAddress = totalDataOffset;
	data.append(reinterpret_cast<char *>(&fractalsArrayOffset), sizeof(fractalsArrayOffset));
	totalDataOffset += sizeof(fractalsArrayOffset);

	// Align and calculate the offset where fractal data will start
	totalDataOffset += PutDummyToAlign(totalDataOffset, alignment, &data);
	int fractalDataOffset = totalDataOffset;

	// write fractal data
	// counter of formulas written so far; kept for offset debugging/tracing
	[[maybe_unused]] int formulaBaseIndex = 0;
	for (int i = 0; i < numberOfSequences; i++)
	{
		const cHybridFractalSequences::sSequence *seq = hybridSequences->GetSequence(i);
		for (int f = 0; f < seq->numberOfFractalsInTheSequence; f++)
		{
			const cHybridFractalSequences::sFractalData &fd = seq->fractData[f];
			typename Policy::FractalCl fdCl;
			memset(&fdCl, 0, sizeof(fdCl));
			fdCl = Policy::fractal(fd.fractalParameters);

			data.append(reinterpret_cast<char *>(&fdCl), sizeof(fdCl));
			totalDataOffset += sizeof(fdCl);
		}
	}

	// patch fractalsArrayOffset in header with the correct offset
	data.replace(fractalsArrayOffsetAddress, sizeof(fractalsArrayOffset),
		reinterpret_cast<char *>(&fractalDataOffset), sizeof(fractalsArrayOffset));
}

void cOpenClDynamicData::BuildNebulaGradientsData(const sParamRender *params)
{
	/* use __attribute__((aligned(16))) in kernel code for array
	 *
	 * header:
	 * cl_int paletteItemsOffset
	 * cl_int paletteOffsetXAxis
	 * cl_int paletteSizeXAxis
	 * cl_int paletteOffsetYAxis
	 * cl_int paletteSizeYAxis
	 * cl_int paletteOffsetZAxis
	 * cl_int paletteSizeZAxis
	 * cl_int paletteOffsetIterations
	 * cl_int paletteSizeIterations
	 *
	 * array (aligned to 16):
	 * 	cl_float4 gradientXAxis1
	 * 	cl_float4 gradientXAxis2
	 *  ...
	 * 	cl_float4 gradientXAxisN
	 *
	 * 	cl_float4 gradientYAxis1
	 * 	cl_float4 gradientYAxis2
	 *  ...
	 * 	cl_float4 gradientYAxisN
	 *
	 * 	cl_float4 gradientZAxis1
	 * 	cl_float4 gradientZAxis2
	 *  ...
	 * 	cl_float4 gradientZAxisN
	 * 	cl_float4 gradientIterations1
	 * 	cl_float4 gradientIterations2
	 *  ...
	 * 	cl_float4 gradientIterationsN
	 */

	totalDataOffset += PutDummyToAlign(totalDataOffset, 16, &data);
	itemOffsets[nebulaGradientsItemIndex].itemOffset = totalDataOffset;

	std::vector<cl_float4> paletteCl;

	QList<cColorGradient::sColor> gradientXAxis = params->nebulaXAxisColors.GetListOfSortedColors();
	QList<cColorGradient::sColor> gradientYAxis = params->nebulaYAxisColors.GetListOfSortedColors();
	QList<cColorGradient::sColor> gradientZAxis = params->nebulaZAxisColors.GetListOfSortedColors();
	QList<cColorGradient::sColor> gradientIterations =
		params->nebulaIterationsColors.GetListOfSortedColors();

	int paletteOffsetXAxis = 0;
	int paletteSizeXAxis = gradientXAxis.size();

	int paletteOffsetYAxis = paletteOffsetXAxis + paletteSizeXAxis;
	int paletteSizeYAxis = gradientYAxis.size();

	int paletteOffsetZAxis = paletteOffsetYAxis + paletteSizeYAxis;
	int paletteSizeZAxis = gradientZAxis.size();

	int paletteOffsetIterations = paletteOffsetZAxis + paletteSizeZAxis;
	int paletteSizeIterations = gradientIterations.size();

	int totalSizeOfGradients =
		paletteSizeXAxis + paletteSizeYAxis + paletteSizeZAxis + paletteSizeIterations;

	paletteCl.resize(totalSizeOfGradients);

	for (int i = 0; i < paletteSizeXAxis; i++)
	{
		paletteCl[i + paletteOffsetXAxis] =
			toClFloat4(CVector4(gradientXAxis[i].color.R / 256.0, gradientXAxis[i].color.G / 256.0,
				gradientXAxis[i].color.B / 256.0, gradientXAxis[i].position));
	}

	for (int i = 0; i < paletteSizeYAxis; i++)
	{
		paletteCl[i + paletteOffsetYAxis] =
			toClFloat4(CVector4(gradientYAxis[i].color.R / 256.0, gradientYAxis[i].color.G / 256.0,
				gradientYAxis[i].color.B / 256.0, gradientYAxis[i].position));
	}

	for (int i = 0; i < paletteSizeZAxis; i++)
	{
		paletteCl[i + paletteOffsetZAxis] =
			toClFloat4(CVector4(gradientZAxis[i].color.R / 256.0, gradientZAxis[i].color.G / 256.0,
				gradientZAxis[i].color.B / 256.0, gradientZAxis[i].position));
	}

	for (int i = 0; i < paletteSizeIterations; i++)
	{
		paletteCl[i + paletteOffsetIterations] = toClFloat4(
			CVector4(gradientIterations[i].color.R / 256.0, gradientIterations[i].color.G / 256.0,
				gradientIterations[i].color.B / 256.0, gradientIterations[i].position));
	}

	cl_int paletteItemsOffset = 0;
	// reserve bytes cl_int paletteItemsOffset
	int paletteItemsOffsetAddress = totalDataOffset;
	data.append(reinterpret_cast<char *>(&paletteItemsOffset), sizeof(paletteItemsOffset));
	totalDataOffset += sizeof(paletteItemsOffset);

	// cl_int paletteOffsetXAxis
	data.append(reinterpret_cast<char *>(&paletteOffsetXAxis), sizeof(paletteOffsetXAxis));
	totalDataOffset += sizeof(paletteOffsetXAxis);
	// cl_int paletteSizeXAxis
	data.append(reinterpret_cast<char *>(&paletteSizeXAxis), sizeof(paletteSizeXAxis));
	totalDataOffset += sizeof(paletteSizeXAxis);

	// cl_int paletteOffsetYAxis
	data.append(reinterpret_cast<char *>(&paletteOffsetYAxis), sizeof(paletteOffsetYAxis));
	totalDataOffset += sizeof(paletteOffsetYAxis);
	// cl_int paletteSizeYAxis
	data.append(reinterpret_cast<char *>(&paletteSizeYAxis), sizeof(paletteSizeYAxis));
	totalDataOffset += sizeof(paletteSizeYAxis);

	// cl_int paletteOffsetZAxis
	data.append(reinterpret_cast<char *>(&paletteOffsetZAxis), sizeof(paletteOffsetZAxis));
	totalDataOffset += sizeof(paletteOffsetZAxis);
	// cl_int paletteSizeZAxis
	data.append(reinterpret_cast<char *>(&paletteSizeZAxis), sizeof(paletteSizeZAxis));
	totalDataOffset += sizeof(paletteSizeZAxis);

	// cl_int paletteOffsetIterations
	data.append(reinterpret_cast<char *>(&paletteOffsetIterations), sizeof(paletteOffsetIterations));
	totalDataOffset += sizeof(paletteOffsetIterations);
	// cl_int paletteSizeIterations
	data.append(reinterpret_cast<char *>(&paletteSizeIterations), sizeof(paletteSizeIterations));
	totalDataOffset += sizeof(paletteSizeIterations);

	// add dummy bytes for alignment to 16
	totalDataOffset += PutDummyToAlign(totalDataOffset, 16, &data);

	// palette data
	paletteItemsOffset = totalDataOffset;
	int paletteSizeBytes = totalSizeOfGradients * sizeof(cl_float4);
	data.append(reinterpret_cast<char *>(paletteCl.data()), paletteSizeBytes);
	totalDataOffset += paletteSizeBytes;

	// fill paletteItemsOffset value
	data.replace(paletteItemsOffsetAddress, sizeof(paletteItemsOffset),
		reinterpret_cast<char *>(&paletteItemsOffset), sizeof(paletteItemsOffset));
}

void cOpenClDynamicData::BuildNebulaSequenceData(const cHybridFractalSequences *hybridSequences)
{
	/* nebula sequence dynamic data structure:
	 *
	 * header:
	 * cl_int numberOfSequences
	 * cl_int arrayOffset  // offset to sNebulaSequenceCl array
	 *
	 * array of sNebulaSequenceCl (aligned to 16):
	 *   sNebulaSequenceCl seq0
	 *   sNebulaSequenceCl seq1
	 *   ...
	 */

	totalDataOffset += PutDummyToAlign(totalDataOffset, 16, &data);
	itemOffsets[nebulaSequencesItemIndex].itemOffset = totalDataOffset;

	cl_int numberOfSequences = static_cast<cl_int>(hybridSequences->GetNumberOfSequences());
	data.append(reinterpret_cast<char *>(&numberOfSequences), sizeof(numberOfSequences));
	totalDataOffset += sizeof(numberOfSequences);

	// reserve bytes for array offset
	cl_int arrayOffset = 0;
	int arrayOffsetAddress = totalDataOffset;
	data.append(reinterpret_cast<char *>(&arrayOffset), sizeof(arrayOffset));
	totalDataOffset += sizeof(arrayOffset);

	// copy nebula sequences aligned to 16
	for (int i = 0; i < numberOfSequences; i++)
	{
		totalDataOffset += PutDummyToAlign(totalDataOffset, 16, &data);
		if (i == 0) arrayOffset = totalDataOffset;

		const cHybridFractalSequences::sSequence *seq = hybridSequences->GetSequence(i);
		sNebulaSequenceCl seqCl;
		memset(&seqCl, 0, sizeof(seqCl));

		seqCl.formulaWeight =
			static_cast<cl_float>(seq->fractData.size() > 0 ? seq->fractData[0].formulaWeight : 0.0);
		seqCl.DEFunctionType = static_cast<enumDEFunctionTypeCl>(seq->DEFunctionType);
		seqCl.DEType = static_cast<enumDETypeCl>(seq->DEType);
		seqCl.counts =
			static_cast<cl_int>(seq->fractData.size() > 0 ? seq->fractData[0].formulaIterations : 0);
		seqCl.formulaStartIteration =
			static_cast<cl_int>(seq->fractData.size() > 0 ? seq->fractData[0].formulaStartIteration : 0);
		seqCl.formulaStopIteration =
			static_cast<cl_int>(seq->fractData.size() > 0 ? seq->fractData[0].formulaStopIteration : 0);
		seqCl.addCConstant = seq->fractData.size() > 0 ? (seq->fractData[0].addCConstant ? 1 : 0) : 0;
		seqCl.checkForBailout =
			seq->fractData.size() > 0 ? (seq->fractData[0].checkForBailout ? 1 : 0) : 0;
		seqCl.bailout =
			static_cast<cl_float>(seq->fractData.size() > 0 ? seq->fractData[0].bailout : 0.0);
		seqCl.juliaEnabled = seq->juliaEnabled ? 1 : 0;
		seqCl.juliaConstant = cl_float4{{static_cast<cl_float>(seq->juliaConstant.x),
			static_cast<cl_float>(seq->juliaConstant.y), static_cast<cl_float>(seq->juliaConstant.z),
			0.0f}};
		seqCl.constantMultiplier = cl_float4{{static_cast<cl_float>(seq->constantMultiplier.x),
			static_cast<cl_float>(seq->constantMultiplier.y),
			static_cast<cl_float>(seq->constantMultiplier.z), 0.0f}};
		seqCl.initialWAxis = static_cast<cl_float>(seq->initialWAxis);
		seqCl.useAdditionalBailoutCond =
			seq->fractData.size() > 0 ? (seq->fractData[0].useAdditionalBailoutCond ? 1 : 0) : 0;
		seqCl.formulaMaxiter = static_cast<cl_int>(seq->formulaMaxiter);
		seqCl.DEAnalyticFunction = static_cast<enumDEAnalyticFunctionCl>(seq->DEAnalyticFunction);
		seqCl.coloringFunction = static_cast<enumColoringFunctionCl>(seq->coloringFunction);

		data.append(reinterpret_cast<char *>(&seqCl), sizeof(seqCl));
		totalDataOffset += sizeof(seqCl);
	}

	// replace arrayOffset:
	data.replace(arrayOffsetAddress, sizeof(arrayOffset), reinterpret_cast<char *>(&arrayOffset),
		sizeof(arrayOffset));
}

#endif // USE_OPENCL
