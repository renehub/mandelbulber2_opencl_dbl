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
 * material struct for opencl
 */

#ifndef MANDELBULBER2_OPENCL_MATERIAL_CL_H_
#define MANDELBULBER2_OPENCL_MATERIAL_CL_H_

#ifndef OPENCL_KERNEL_CODE
#include "fractal_coloring_cl.hpp"
#include "opencl_algebra.h"
#include "texture_enums_cl.h"

#include "src/include_header_wrapper.hpp"
#include "src/material.h"

#endif /* not OPENCL_KERNEL_CODE */

typedef struct
{
	sFractalColoringCl fractalColoring;
	
	matrix33 rotMatrixTexture;
	matrix33 rotMatrixPerlinNoise;
	
	REAL3 specularColor;
	REAL3 transparencyColor;
	
	REAL3 textureCenter;
	REAL3 textureScale;
	REAL3 perlinNoisePeriod;
	REAL3 perlinNoisePositionOffset;
	
	REAL3 color;
	REAL3 luminosityColor;
	REAL3 transparencyInteriorColor;
	REAL3 reflectionsColor;
	
	REAL specular;
	REAL specularWidth;
	REAL specularMetallic;
	REAL specularMetallicRoughness;
	REAL specularMetallicWidth;
	REAL reflectance;
	REAL luminosity;
	REAL luminosityEmissive;
	REAL surfaceRoughness;
	REAL transparencyIndexOfRefraction;
	REAL transparencyOfInterior;
	REAL transparencyOfSurface;
	REAL paletteOffset;
	REAL coloring_speed;
	REAL colorTextureIntensity;
	REAL diffusionTextureIntensity;
	REAL luminosityTextureIntensity;
	REAL reflectanceTextureIntensity;
	REAL transparencyTextureIntensity;
	REAL transparencyAlphaTextureIntensity;
	REAL transparencyTextureIntensityVol;
	REAL transparencyAlphaTextureIntensityVol;
	REAL roughnessTextureIntensity;
	REAL displacementTextureHeight;
	REAL normalMapTextureHeight;
	REAL iridescenceIntensity;
	REAL iridescenceSubsurfaceThickness;
	REAL textureFractalizeCubeSize;
	REAL perlinNoiseValueOffset;
	REAL perlinNoiseColorIntensity;
	REAL perlinNoiseLuminosityIntensity;
	REAL perlinNoiseDisplacementIntensity;
	REAL perlinNoiseReflectanceIntensity;
	REAL perlinNoiseTransparencyColorIntensity;
	REAL perlinNoiseTransparencyAlphaIntensity;
	REAL perlinNoiseTransparencyColorIntensityVol;
	REAL perlinNoiseTransparencyAlphaIntensityVol;
	REAL shading;
	
	cl_int id;
	cl_int textureFractalizeStartIteration;
	cl_int perlinNoiseIterations;
	
	cl_int fresnelReflectance;
	cl_int useColorsFromPalette;
	cl_int specularPlasticEnable;
	cl_int metallic;
	cl_int roughSurface;

	cl_int perlinNoiseEnable;
	cl_int perlinNoiseAbs;
	cl_int perlinNoiseColorEnable;
	cl_int perlinNoiseColorInvert;
	cl_int perlinNoiseLuminosityEnable;
	cl_int perlinNoiseLuminosityInvert;
	cl_int perlinNoiseDisplacementEnable;
	cl_int perlinNoiseDisplacementInvert;
	cl_int perlinNoiseReflectanceEnable;
	cl_int perlinNoiseReflectanceInvert;
	cl_int perlinNoiseTransparencyColorEnable;
	cl_int perlinNoiseTransparencyColorInvert;
	cl_int perlinNoiseTransparencyAlphaEnable;
	cl_int perlinNoiseTransparencyAlphaInvert;

	cl_int useColorTexture;
	cl_int useDiffusionTexture;
	cl_int useLuminosityTexture;
	cl_int useDisplacementTexture;
	cl_int useNormalMapTexture;
	cl_int normalMapTextureFromBumpmap;
	cl_int normalMapTextureInvertGreen;
	cl_int useReflectanceTexture;
	cl_int useTransparencyTexture;
	cl_int useTransparencyAlphaTexture;
	cl_int useRoughnessTexture;
	cl_int iridescenceEnabled;
	cl_int textureFractalize;

	cl_int insideColoringEnable;
	cl_int subsurfaceScattering;

	cl_int colorTextureIndex;
	cl_int diffusionTextureIndex;
	cl_int luminosityTextureIndex;
	cl_int displacementTextureIndex;
	cl_int normalMapTextureIndex;
	cl_int reflectanceTextureIndex;
	cl_int transparencyTextureIndex;
	cl_int transparencyAlphaTextureIndex;
	cl_int roughnessTextureIndex;

	cl_int surfaceGradientEnable;
	cl_int specularGradientEnable;
	cl_int diffuseGradientEnable;
	cl_int luminosityGradientEnable;
	cl_int roughnessGradientEnable;
	cl_int reflectanceGradientEnable;
	cl_int transparencyGradientEnable;
	
	enumTextureMappingCl textureMappingType;


} sMaterialCl;

#ifndef OPENCL_KERNEL_CODE
sMaterialCl clCopySMaterialCl(const cMaterial &source)
{
	sMaterialCl target;

	target.id = source.id;
	target.textureFractalizeStartIteration = source.textureFractalizeStartIteration;
	target.perlinNoiseIterations = source.perlinNoiseIterations;

	target.shading = source.shading;
	target.specular = source.specular;
	target.specularWidth = source.specularWidth;
	target.specularMetallic = source.specularMetallic;
	target.specularMetallicRoughness = source.specularMetallicRoughness;
	target.specularMetallicWidth = source.specularMetallicWidth;
	target.reflectance = source.reflectance;
	target.luminosity = source.luminosity;
	target.luminosityEmissive = source.luminosityEmissive;
	target.surfaceRoughness = source.surfaceRoughness;
	target.transparencyIndexOfRefraction = source.transparencyIndexOfRefraction;
	target.transparencyOfInterior = source.transparencyOfInterior;
	target.transparencyOfSurface = source.transparencyOfSurface;
	target.paletteOffset = source.paletteOffset;
	target.coloring_speed = source.coloring_speed;
	target.colorTextureIntensity = source.colorTextureIntensity;
	target.diffusionTextureIntensity = source.diffusionTextureIntensity;
	target.luminosityTextureIntensity = source.luminosityTextureIntensity;
	target.reflectanceTextureIntensity = source.reflectanceTextureIntensity;
	target.transparencyTextureIntensity = source.transparencyTextureIntensity;
	target.transparencyAlphaTextureIntensity = source.transparencyAlphaTextureIntensity;
	target.transparencyTextureIntensityVol = source.transparencyTextureIntensityVol;
	target.transparencyAlphaTextureIntensityVol = source.transparencyAlphaTextureIntensityVol;
	target.roughnessTextureIntensity = source.roughnessTextureIntensity;
	target.displacementTextureHeight = source.displacementTextureHeight;
	target.normalMapTextureHeight = source.normalMapTextureHeight;
	target.iridescenceIntensity = source.iridescenceIntensity;
	target.iridescenceSubsurfaceThickness = source.iridescenceSubsurfaceThickness;
	target.textureFractalizeCubeSize = source.textureFractalizeCubeSize;
	target.perlinNoiseValueOffset = source.perlinNoiseValueOffset;
	target.perlinNoiseColorIntensity = source.perlinNoiseColorIntensity;
	target.perlinNoiseLuminosityIntensity = source.perlinNoiseLuminosityIntensity;
	target.perlinNoiseDisplacementIntensity = source.perlinNoiseDisplacementIntensity;
	target.perlinNoiseReflectanceIntensity = source.perlinNoiseReflectanceIntensity;
	target.perlinNoiseTransparencyColorIntensity = source.perlinNoiseTransparencyColorIntensity;
	target.perlinNoiseTransparencyAlphaIntensity = source.perlinNoiseTransparencyAlphaIntensity;
	target.perlinNoiseTransparencyColorIntensityVol = source.perlinNoiseTransparencyColorIntensityVol;
	target.perlinNoiseTransparencyAlphaIntensityVol = source.perlinNoiseTransparencyAlphaIntensityVol;

	target.color = toClFloat3(source.color);
	target.luminosityColor = toClFloat3(source.luminosityColor);
	target.transparencyInteriorColor = toClFloat3(source.transparencyInteriorColor);
	target.reflectionsColor = toClFloat3(source.reflectionsColor);
	target.specularColor = toClFloat3(source.specularColor);
	target.transparencyColor = toClFloat3(source.transparencyColor);

	target.textureCenter = toClFloat3(source.textureCenter);
	target.textureScale = toClFloat3(source.textureScale);
	target.perlinNoisePeriod = toClFloat3(source.perlinNoisePeriod);
	target.perlinNoisePositionOffset = toClFloat3(source.perlinNoisePositionOffset);

	target.rotMatrixTexture = toClMatrix33(source.rotMatrixTexture);
	target.rotMatrixPerlinNoise = toClMatrix33(source.rotMatrixPerlinNoise);

	target.textureMappingType = static_cast<enumTextureMappingCl>(source.textureMappingType);
	target.fresnelReflectance = source.fresnelReflectance;
	target.useColorsFromPalette = source.useColorsFromPalette;
	target.specularPlasticEnable = source.specularPlasticEnable;
	target.metallic = source.metallic;
	target.roughSurface = source.roughSurface;

	target.perlinNoiseEnable = source.perlinNoiseEnable;
	target.perlinNoiseAbs = source.perlinNoiseAbs;
	target.perlinNoiseColorEnable = source.perlinNoiseColorEnable;
	target.perlinNoiseColorInvert = source.perlinNoiseColorInvert;
	target.perlinNoiseLuminosityEnable = source.perlinNoiseLuminosityEnable;
	target.perlinNoiseLuminosityInvert = source.perlinNoiseLuminosityInvert;
	target.perlinNoiseDisplacementEnable = source.perlinNoiseDisplacementEnable;
	target.perlinNoiseDisplacementInvert = source.perlinNoiseDisplacementInvert;
	target.perlinNoiseReflectanceEnable = source.perlinNoiseReflectanceEnable;
	target.perlinNoiseReflectanceInvert = source.perlinNoiseReflectanceInvert;
	target.perlinNoiseTransparencyColorEnable = source.perlinNoiseTransparencyColorEnable;
	target.perlinNoiseTransparencyColorInvert = source.perlinNoiseTransparencyColorInvert;
	target.perlinNoiseTransparencyAlphaEnable = source.perlinNoiseTransparencyAlphaEnable;
	target.perlinNoiseTransparencyAlphaInvert = source.perlinNoiseTransparencyAlphaInvert;

	target.useColorTexture = source.useColorTexture;
	target.useDiffusionTexture = source.useDiffusionTexture;
	target.useLuminosityTexture = source.useLuminosityTexture;
	target.useDisplacementTexture = source.useDisplacementTexture;
	target.useNormalMapTexture = source.useNormalMapTexture;
	target.normalMapTextureFromBumpmap = source.normalMapTextureFromBumpmap;
	target.normalMapTextureInvertGreen = source.normalMapTextureInvertGreen;
	target.useReflectanceTexture = source.useReflectanceTexture;
	target.useTransparencyTexture = source.useTransparencyTexture;
	target.useTransparencyAlphaTexture = source.useTransparencyAlphaTexture;
	target.useRoughnessTexture = source.useRoughnessTexture;
	target.iridescenceEnabled = source.iridescenceEnabled;
	target.textureFractalize = source.textureFractalize;

	target.insideColoringEnable = source.insideColoringEnable;
	target.subsurfaceScattering = source.subsurfaceScattering;

	target.surfaceGradientEnable = source.surfaceGradientEnable;
	target.specularGradientEnable = source.specularGradientEnable;
	target.diffuseGradientEnable = source.diffuseGradientEnable;
	target.luminosityGradientEnable = source.luminosityGradientEnable;
	target.roughnessGradientEnable = source.roughnessGradientEnable;
	target.reflectanceGradientEnable = source.reflectanceGradientEnable;
	target.transparencyGradientEnable = source.transparencyGradientEnable;

	// these are initialized in cOpenClDynamicData::BuildMaterialsData()
	target.colorTextureIndex = 0;
	target.diffusionTextureIndex = 0;
	target.luminosityTextureIndex = 0;
	target.displacementTextureIndex = 0;
	target.normalMapTextureIndex = 0;
	target.reflectanceTextureIndex = 0;
	target.transparencyTextureIndex = 0;
	target.roughnessTextureIndex = 0;

	target.fractalColoring = clCopySFractalColoringCl(source.fractalColoring);

	return target;
}

#endif

#ifndef OPENCL_KERNEL_CODE
// BEGIN OPENCL_D_STRUCTS
typedef struct ALIGN_DOUBLE
{
	sFractalColoringClD fractalColoring;
	
	matrix33D rotMatrixTexture;
	matrix33D rotMatrixPerlinNoise;
	
	cl_double3 specularColor;
	cl_double3 transparencyColor;
	
	cl_double3 textureCenter;
	cl_double3 textureScale;
	cl_double3 perlinNoisePeriod;
	cl_double3 perlinNoisePositionOffset;
	
	cl_double3 color;
	cl_double3 luminosityColor;
	cl_double3 transparencyInteriorColor;
	cl_double3 reflectionsColor;
	
	cl_double specular;
	cl_double specularWidth;
	cl_double specularMetallic;
	cl_double specularMetallicRoughness;
	cl_double specularMetallicWidth;
	cl_double reflectance;
	cl_double luminosity;
	cl_double luminosityEmissive;
	cl_double surfaceRoughness;
	cl_double transparencyIndexOfRefraction;
	cl_double transparencyOfInterior;
	cl_double transparencyOfSurface;
	cl_double paletteOffset;
	cl_double coloring_speed;
	cl_double colorTextureIntensity;
	cl_double diffusionTextureIntensity;
	cl_double luminosityTextureIntensity;
	cl_double reflectanceTextureIntensity;
	cl_double transparencyTextureIntensity;
	cl_double transparencyAlphaTextureIntensity;
	cl_double transparencyTextureIntensityVol;
	cl_double transparencyAlphaTextureIntensityVol;
	cl_double roughnessTextureIntensity;
	cl_double displacementTextureHeight;
	cl_double normalMapTextureHeight;
	cl_double iridescenceIntensity;
	cl_double iridescenceSubsurfaceThickness;
	cl_double textureFractalizeCubeSize;
	cl_double perlinNoiseValueOffset;
	cl_double perlinNoiseColorIntensity;
	cl_double perlinNoiseLuminosityIntensity;
	cl_double perlinNoiseDisplacementIntensity;
	cl_double perlinNoiseReflectanceIntensity;
	cl_double perlinNoiseTransparencyColorIntensity;
	cl_double perlinNoiseTransparencyAlphaIntensity;
	cl_double perlinNoiseTransparencyColorIntensityVol;
	cl_double perlinNoiseTransparencyAlphaIntensityVol;
	cl_double shading;
	
	cl_int id;
	cl_int textureFractalizeStartIteration;
	cl_int perlinNoiseIterations;
	
	cl_int fresnelReflectance;
	cl_int useColorsFromPalette;
	cl_int specularPlasticEnable;
	cl_int metallic;
	cl_int roughSurface;

	cl_int perlinNoiseEnable;
	cl_int perlinNoiseAbs;
	cl_int perlinNoiseColorEnable;
	cl_int perlinNoiseColorInvert;
	cl_int perlinNoiseLuminosityEnable;
	cl_int perlinNoiseLuminosityInvert;
	cl_int perlinNoiseDisplacementEnable;
	cl_int perlinNoiseDisplacementInvert;
	cl_int perlinNoiseReflectanceEnable;
	cl_int perlinNoiseReflectanceInvert;
	cl_int perlinNoiseTransparencyColorEnable;
	cl_int perlinNoiseTransparencyColorInvert;
	cl_int perlinNoiseTransparencyAlphaEnable;
	cl_int perlinNoiseTransparencyAlphaInvert;

	cl_int useColorTexture;
	cl_int useDiffusionTexture;
	cl_int useLuminosityTexture;
	cl_int useDisplacementTexture;
	cl_int useNormalMapTexture;
	cl_int normalMapTextureFromBumpmap;
	cl_int normalMapTextureInvertGreen;
	cl_int useReflectanceTexture;
	cl_int useTransparencyTexture;
	cl_int useTransparencyAlphaTexture;
	cl_int useRoughnessTexture;
	cl_int iridescenceEnabled;
	cl_int textureFractalize;

	cl_int insideColoringEnable;
	cl_int subsurfaceScattering;

	cl_int colorTextureIndex;
	cl_int diffusionTextureIndex;
	cl_int luminosityTextureIndex;
	cl_int displacementTextureIndex;
	cl_int normalMapTextureIndex;
	cl_int reflectanceTextureIndex;
	cl_int transparencyTextureIndex;
	cl_int transparencyAlphaTextureIndex;
	cl_int roughnessTextureIndex;

	cl_int surfaceGradientEnable;
	cl_int specularGradientEnable;
	cl_int diffuseGradientEnable;
	cl_int luminosityGradientEnable;
	cl_int roughnessGradientEnable;
	cl_int reflectanceGradientEnable;
	cl_int transparencyGradientEnable;
	
	enumTextureMappingCl textureMappingType;
} sMaterialClD;

sMaterialClD clCopySMaterialClD(const cMaterial &source)
{
	sMaterialClD target;

	target.id = source.id;
	target.textureFractalizeStartIteration = source.textureFractalizeStartIteration;
	target.perlinNoiseIterations = source.perlinNoiseIterations;

	target.shading = source.shading;
	target.specular = source.specular;
	target.specularWidth = source.specularWidth;
	target.specularMetallic = source.specularMetallic;
	target.specularMetallicRoughness = source.specularMetallicRoughness;
	target.specularMetallicWidth = source.specularMetallicWidth;
	target.reflectance = source.reflectance;
	target.luminosity = source.luminosity;
	target.luminosityEmissive = source.luminosityEmissive;
	target.surfaceRoughness = source.surfaceRoughness;
	target.transparencyIndexOfRefraction = source.transparencyIndexOfRefraction;
	target.transparencyOfInterior = source.transparencyOfInterior;
	target.transparencyOfSurface = source.transparencyOfSurface;
	target.paletteOffset = source.paletteOffset;
	target.coloring_speed = source.coloring_speed;
	target.colorTextureIntensity = source.colorTextureIntensity;
	target.diffusionTextureIntensity = source.diffusionTextureIntensity;
	target.luminosityTextureIntensity = source.luminosityTextureIntensity;
	target.reflectanceTextureIntensity = source.reflectanceTextureIntensity;
	target.transparencyTextureIntensity = source.transparencyTextureIntensity;
	target.transparencyAlphaTextureIntensity = source.transparencyAlphaTextureIntensity;
	target.transparencyTextureIntensityVol = source.transparencyTextureIntensityVol;
	target.transparencyAlphaTextureIntensityVol = source.transparencyAlphaTextureIntensityVol;
	target.roughnessTextureIntensity = source.roughnessTextureIntensity;
	target.displacementTextureHeight = source.displacementTextureHeight;
	target.normalMapTextureHeight = source.normalMapTextureHeight;
	target.iridescenceIntensity = source.iridescenceIntensity;
	target.iridescenceSubsurfaceThickness = source.iridescenceSubsurfaceThickness;
	target.textureFractalizeCubeSize = source.textureFractalizeCubeSize;
	target.perlinNoiseValueOffset = source.perlinNoiseValueOffset;
	target.perlinNoiseColorIntensity = source.perlinNoiseColorIntensity;
	target.perlinNoiseLuminosityIntensity = source.perlinNoiseLuminosityIntensity;
	target.perlinNoiseDisplacementIntensity = source.perlinNoiseDisplacementIntensity;
	target.perlinNoiseReflectanceIntensity = source.perlinNoiseReflectanceIntensity;
	target.perlinNoiseTransparencyColorIntensity = source.perlinNoiseTransparencyColorIntensity;
	target.perlinNoiseTransparencyAlphaIntensity = source.perlinNoiseTransparencyAlphaIntensity;
	target.perlinNoiseTransparencyColorIntensityVol = source.perlinNoiseTransparencyColorIntensityVol;
	target.perlinNoiseTransparencyAlphaIntensityVol = source.perlinNoiseTransparencyAlphaIntensityVol;

	target.color = toClDouble3(source.color);
	target.luminosityColor = toClDouble3(source.luminosityColor);
	target.transparencyInteriorColor = toClDouble3(source.transparencyInteriorColor);
	target.reflectionsColor = toClDouble3(source.reflectionsColor);
	target.specularColor = toClDouble3(source.specularColor);
	target.transparencyColor = toClDouble3(source.transparencyColor);

	target.textureCenter = toClDouble3(source.textureCenter);
	target.textureScale = toClDouble3(source.textureScale);
	target.perlinNoisePeriod = toClDouble3(source.perlinNoisePeriod);
	target.perlinNoisePositionOffset = toClDouble3(source.perlinNoisePositionOffset);

	target.rotMatrixTexture = toClMatrix33D(source.rotMatrixTexture);
	target.rotMatrixPerlinNoise = toClMatrix33D(source.rotMatrixPerlinNoise);

	target.textureMappingType = static_cast<enumTextureMappingCl>(source.textureMappingType);
	target.fresnelReflectance = source.fresnelReflectance;
	target.useColorsFromPalette = source.useColorsFromPalette;
	target.specularPlasticEnable = source.specularPlasticEnable;
	target.metallic = source.metallic;
	target.roughSurface = source.roughSurface;

	target.perlinNoiseEnable = source.perlinNoiseEnable;
	target.perlinNoiseAbs = source.perlinNoiseAbs;
	target.perlinNoiseColorEnable = source.perlinNoiseColorEnable;
	target.perlinNoiseColorInvert = source.perlinNoiseColorInvert;
	target.perlinNoiseLuminosityEnable = source.perlinNoiseLuminosityEnable;
	target.perlinNoiseLuminosityInvert = source.perlinNoiseLuminosityInvert;
	target.perlinNoiseDisplacementEnable = source.perlinNoiseDisplacementEnable;
	target.perlinNoiseDisplacementInvert = source.perlinNoiseDisplacementInvert;
	target.perlinNoiseReflectanceEnable = source.perlinNoiseReflectanceEnable;
	target.perlinNoiseReflectanceInvert = source.perlinNoiseReflectanceInvert;
	target.perlinNoiseTransparencyColorEnable = source.perlinNoiseTransparencyColorEnable;
	target.perlinNoiseTransparencyColorInvert = source.perlinNoiseTransparencyColorInvert;
	target.perlinNoiseTransparencyAlphaEnable = source.perlinNoiseTransparencyAlphaEnable;
	target.perlinNoiseTransparencyAlphaInvert = source.perlinNoiseTransparencyAlphaInvert;

	target.useColorTexture = source.useColorTexture;
	target.useDiffusionTexture = source.useDiffusionTexture;
	target.useLuminosityTexture = source.useLuminosityTexture;
	target.useDisplacementTexture = source.useDisplacementTexture;
	target.useNormalMapTexture = source.useNormalMapTexture;
	target.normalMapTextureFromBumpmap = source.normalMapTextureFromBumpmap;
	target.normalMapTextureInvertGreen = source.normalMapTextureInvertGreen;
	target.useReflectanceTexture = source.useReflectanceTexture;
	target.useTransparencyTexture = source.useTransparencyTexture;
	target.useTransparencyAlphaTexture = source.useTransparencyAlphaTexture;
	target.useRoughnessTexture = source.useRoughnessTexture;
	target.iridescenceEnabled = source.iridescenceEnabled;
	target.textureFractalize = source.textureFractalize;

	target.insideColoringEnable = source.insideColoringEnable;
	target.subsurfaceScattering = source.subsurfaceScattering;

	target.surfaceGradientEnable = source.surfaceGradientEnable;
	target.specularGradientEnable = source.specularGradientEnable;
	target.diffuseGradientEnable = source.diffuseGradientEnable;
	target.luminosityGradientEnable = source.luminosityGradientEnable;
	target.roughnessGradientEnable = source.roughnessGradientEnable;
	target.reflectanceGradientEnable = source.reflectanceGradientEnable;
	target.transparencyGradientEnable = source.transparencyGradientEnable;

	// these are initialized in cOpenClDynamicData::BuildMaterialsData()
	target.colorTextureIndex = 0;
	target.diffusionTextureIndex = 0;
	target.luminosityTextureIndex = 0;
	target.displacementTextureIndex = 0;
	target.normalMapTextureIndex = 0;
	target.reflectanceTextureIndex = 0;
	target.transparencyTextureIndex = 0;
	target.roughnessTextureIndex = 0;

	target.fractalColoring = clCopySFractalColoringClD(source.fractalColoring);

	return target;
}

inline sMaterialClD clPromoteSMaterialClD(const sMaterialCl &source)
{
	sMaterialClD target;
	target.fractalColoring = clPromoteSFractalColoringClD(source.fractalColoring);
	target.rotMatrixTexture = toClMatrix33D(source.rotMatrixTexture);
	target.rotMatrixPerlinNoise = toClMatrix33D(source.rotMatrixPerlinNoise);
	target.specularColor = toClDouble3(source.specularColor);
	target.transparencyColor = toClDouble3(source.transparencyColor);
	target.textureCenter = toClDouble3(source.textureCenter);
	target.textureScale = toClDouble3(source.textureScale);
	target.perlinNoisePeriod = toClDouble3(source.perlinNoisePeriod);
	target.perlinNoisePositionOffset = toClDouble3(source.perlinNoisePositionOffset);
	target.color = toClDouble3(source.color);
	target.luminosityColor = toClDouble3(source.luminosityColor);
	target.transparencyInteriorColor = toClDouble3(source.transparencyInteriorColor);
	target.reflectionsColor = toClDouble3(source.reflectionsColor);
	target.specular = source.specular;
	target.specularWidth = source.specularWidth;
	target.specularMetallic = source.specularMetallic;
	target.specularMetallicRoughness = source.specularMetallicRoughness;
	target.specularMetallicWidth = source.specularMetallicWidth;
	target.reflectance = source.reflectance;
	target.luminosity = source.luminosity;
	target.luminosityEmissive = source.luminosityEmissive;
	target.surfaceRoughness = source.surfaceRoughness;
	target.transparencyIndexOfRefraction = source.transparencyIndexOfRefraction;
	target.transparencyOfInterior = source.transparencyOfInterior;
	target.transparencyOfSurface = source.transparencyOfSurface;
	target.paletteOffset = source.paletteOffset;
	target.coloring_speed = source.coloring_speed;
	target.colorTextureIntensity = source.colorTextureIntensity;
	target.diffusionTextureIntensity = source.diffusionTextureIntensity;
	target.luminosityTextureIntensity = source.luminosityTextureIntensity;
	target.reflectanceTextureIntensity = source.reflectanceTextureIntensity;
	target.transparencyTextureIntensity = source.transparencyTextureIntensity;
	target.transparencyAlphaTextureIntensity = source.transparencyAlphaTextureIntensity;
	target.transparencyTextureIntensityVol = source.transparencyTextureIntensityVol;
	target.transparencyAlphaTextureIntensityVol = source.transparencyAlphaTextureIntensityVol;
	target.roughnessTextureIntensity = source.roughnessTextureIntensity;
	target.displacementTextureHeight = source.displacementTextureHeight;
	target.normalMapTextureHeight = source.normalMapTextureHeight;
	target.iridescenceIntensity = source.iridescenceIntensity;
	target.iridescenceSubsurfaceThickness = source.iridescenceSubsurfaceThickness;
	target.textureFractalizeCubeSize = source.textureFractalizeCubeSize;
	target.perlinNoiseValueOffset = source.perlinNoiseValueOffset;
	target.perlinNoiseColorIntensity = source.perlinNoiseColorIntensity;
	target.perlinNoiseLuminosityIntensity = source.perlinNoiseLuminosityIntensity;
	target.perlinNoiseDisplacementIntensity = source.perlinNoiseDisplacementIntensity;
	target.perlinNoiseReflectanceIntensity = source.perlinNoiseReflectanceIntensity;
	target.perlinNoiseTransparencyColorIntensity = source.perlinNoiseTransparencyColorIntensity;
	target.perlinNoiseTransparencyAlphaIntensity = source.perlinNoiseTransparencyAlphaIntensity;
	target.perlinNoiseTransparencyColorIntensityVol = source.perlinNoiseTransparencyColorIntensityVol;
	target.perlinNoiseTransparencyAlphaIntensityVol = source.perlinNoiseTransparencyAlphaIntensityVol;
	target.shading = source.shading;
	target.id = source.id;
	target.textureFractalizeStartIteration = source.textureFractalizeStartIteration;
	target.perlinNoiseIterations = source.perlinNoiseIterations;
	target.fresnelReflectance = source.fresnelReflectance;
	target.useColorsFromPalette = source.useColorsFromPalette;
	target.specularPlasticEnable = source.specularPlasticEnable;
	target.metallic = source.metallic;
	target.roughSurface = source.roughSurface;
	target.perlinNoiseEnable = source.perlinNoiseEnable;
	target.perlinNoiseAbs = source.perlinNoiseAbs;
	target.perlinNoiseColorEnable = source.perlinNoiseColorEnable;
	target.perlinNoiseColorInvert = source.perlinNoiseColorInvert;
	target.perlinNoiseLuminosityEnable = source.perlinNoiseLuminosityEnable;
	target.perlinNoiseLuminosityInvert = source.perlinNoiseLuminosityInvert;
	target.perlinNoiseDisplacementEnable = source.perlinNoiseDisplacementEnable;
	target.perlinNoiseDisplacementInvert = source.perlinNoiseDisplacementInvert;
	target.perlinNoiseReflectanceEnable = source.perlinNoiseReflectanceEnable;
	target.perlinNoiseReflectanceInvert = source.perlinNoiseReflectanceInvert;
	target.perlinNoiseTransparencyColorEnable = source.perlinNoiseTransparencyColorEnable;
	target.perlinNoiseTransparencyColorInvert = source.perlinNoiseTransparencyColorInvert;
	target.perlinNoiseTransparencyAlphaEnable = source.perlinNoiseTransparencyAlphaEnable;
	target.perlinNoiseTransparencyAlphaInvert = source.perlinNoiseTransparencyAlphaInvert;
	target.useColorTexture = source.useColorTexture;
	target.useDiffusionTexture = source.useDiffusionTexture;
	target.useLuminosityTexture = source.useLuminosityTexture;
	target.useDisplacementTexture = source.useDisplacementTexture;
	target.useNormalMapTexture = source.useNormalMapTexture;
	target.normalMapTextureFromBumpmap = source.normalMapTextureFromBumpmap;
	target.normalMapTextureInvertGreen = source.normalMapTextureInvertGreen;
	target.useReflectanceTexture = source.useReflectanceTexture;
	target.useTransparencyTexture = source.useTransparencyTexture;
	target.useTransparencyAlphaTexture = source.useTransparencyAlphaTexture;
	target.useRoughnessTexture = source.useRoughnessTexture;
	target.iridescenceEnabled = source.iridescenceEnabled;
	target.textureFractalize = source.textureFractalize;
	target.insideColoringEnable = source.insideColoringEnable;
	target.subsurfaceScattering = source.subsurfaceScattering;
	target.colorTextureIndex = source.colorTextureIndex;
	target.diffusionTextureIndex = source.diffusionTextureIndex;
	target.luminosityTextureIndex = source.luminosityTextureIndex;
	target.displacementTextureIndex = source.displacementTextureIndex;
	target.normalMapTextureIndex = source.normalMapTextureIndex;
	target.reflectanceTextureIndex = source.reflectanceTextureIndex;
	target.transparencyTextureIndex = source.transparencyTextureIndex;
	target.transparencyAlphaTextureIndex = source.transparencyAlphaTextureIndex;
	target.roughnessTextureIndex = source.roughnessTextureIndex;
	target.surfaceGradientEnable = source.surfaceGradientEnable;
	target.specularGradientEnable = source.specularGradientEnable;
	target.diffuseGradientEnable = source.diffuseGradientEnable;
	target.luminosityGradientEnable = source.luminosityGradientEnable;
	target.roughnessGradientEnable = source.roughnessGradientEnable;
	target.reflectanceGradientEnable = source.reflectanceGradientEnable;
	target.transparencyGradientEnable = source.transparencyGradientEnable;
	target.textureMappingType = static_cast<enumTextureMappingCl>(source.textureMappingType);
	return target;
}
// END OPENCL_D_STRUCTS
#endif /* OPENCL_KERNEL_CODE */

#endif /* MANDELBULBER2_OPENCL_MATERIAL_CL_H_ */
