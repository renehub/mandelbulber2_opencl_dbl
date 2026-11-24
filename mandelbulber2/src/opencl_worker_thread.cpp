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
 * thread for one of GPUs in multi-gpu rendering
 */

#ifdef USE_OPENCL

#include "opencl_worker_thread.h"

#include <algorithm>
#include <memory>

#include <QDebug>
#include <QVector>

#include "algebra.hpp"
#include "opencl_engine.h"
#include "opencl_hardware.h"
#include "opencl_scheduler.h"
#include "opencl_worker_output_queue.h"
#include "system_data.hpp"
#include "wait.hpp"

using std::min;

cOpenClWorkerThread::cOpenClWorkerThread(
	cOpenClEngine *engine, const std::shared_ptr<cOpenClScheduler> scheduler, int _deviceIndex)
		: QObject(), deviceIndex(_deviceIndex)
{
	hardware = nullptr;
	pixelMask = nullptr;
	this->scheduler = scheduler;
	optimalStepX = 0;
	optimalStepY = 0;
	this->engine = engine;
	imageWidth = 0;
	imageHeight = 0;
	maxMonteCarloSamples = 1;
	stopRequest = nullptr;
	reservedGpuTime = 0.0;
	finishedWithSuccess = false;
	antiAliasingDepth = 0;
	isFullEngine = false;
	maxWorkgroupSize = 0;
	localWorkSize = 0;
	asyncBufferIndex = 0;
	asyncOutputEnabled = false;
}

cOpenClWorkerThread::~cOpenClWorkerThread()
{
	// nothing to destroy
}

bool cOpenClWorkerThread::checkErr(cl_int err, QString functionName)
{
	if (err != CL_SUCCESS)
	{
		qCritical() << "OpenCl ERROR: " << functionName << " (" << err << ")";
		return false;
	}
	else
		return true;
}

void cOpenClWorkerThread::ProcessRenderingLoop()
{
	int startTile = deviceIndex;
	if (startTile >= scheduler->getTileSequence()->length())
	{
		finishedWithSuccess = true;
		emit finished();
		return;
	}

	QElapsedTimer openclProcessingTime;
	// accumulator kept for debug/statistics purposes; not read in the current code path
	[[maybe_unused]] qint64 openclprocessingTimeNanoSeconds = 0;

	int actualAADepth = 0;
	int actualAARepeatIndex = 0;

	// One-tile lookahead: compute tile N+1 while tile N is copied back on a
	// separate queue. Only the unmasked 2D full-engine path is pipelined.
	asyncOutputEnabled = InitAsyncOutput();

	for (int monteCarloLoop = 1; monteCarloLoop <= maxMonteCarloSamples; monteCarloLoop++)
	{
		scheduler->ReserveTile(startTile, monteCarloLoop);

		for (int tile = startTile; !scheduler->AllDone(monteCarloLoop);
			tile = scheduler->GetNextTileToRender(tile, monteCarloLoop))
		{
			if (tile < 0) break;
			if (!scheduler->IsTileEnabled(tile)) continue;

			// refresh parameters (needed to update random seed)
			engine->AssignParametersToKernel(deviceIndex);

			// TODO calculation of aa depth and index
			if (isFullEngine)
			{
				AddAntiAliasingParameters(actualAADepth, actualAARepeatIndex);
			}

			quint64 gridX = scheduler->getTileSequence()->at(tile).x();
			quint64 gridY = scheduler->getTileSequence()->at(tile).y();
			quint64 jobX = gridX * optimalStepX;
			quint64 jobY = gridY * optimalStepY;
			quint64 pixelsLeftX = imageWidth - jobX;
			quint64 pixelsLeftY = imageHeight - jobY;
			quint64 jobWidth = min(optimalStepX, pixelsLeftX);
			quint64 jobHeight = min(optimalStepY, pixelsLeftY);
			quint64 sequenceSize = 0;

			if (isFullEngine && jobWidth > 0 && jobHeight > 0)
			{
				sequenceSize = UpdatePixelSequence(jobX, jobY, jobWidth, jobHeight, imageWidth);
			}
			//			qDebug() << "starting tile" << tile << gridX << gridY << jobX << jobY << jobWidth
			//							 << jobHeight;

			if (*stopRequest || systemData.globalStopRequest)
			{
				if (asyncOutputEnabled) ProcessPendingOutput();
				emit finished();
				finishedWithSuccess = false;
				return;
			}

			if (jobX < imageWidth && jobY < imageHeight)
			{
				openclProcessingTime.restart();
				const int writeBuffer = asyncOutputEnabled ? asyncBufferIndex : -1;
				int result = ProcessClQueue(
					jobX, jobY, pixelsLeftX, pixelsLeftY, sequenceSize, writeBuffer);
				if (!result)
				{
					if (asyncOutputEnabled) ProcessPendingOutput();
					emit finished();
					finishedWithSuccess = false;
					return;
				}

				if (asyncOutputEnabled)
				{
					cl::Event readEvent;
					if (!EnqueueAsyncOutputRead(writeBuffer, readEvent))
					{
						emit finished();
						finishedWithSuccess = false;
						return;
					}

					// Process the previous tile while this tile's kernel runs.
					if (!ProcessPendingOutput())
					{
						emit finished();
						finishedWithSuccess = false;
						return;
					}

					QueuePendingOutput(jobX, jobY, gridX, gridY, tile, jobWidth, jobHeight,
						sequenceSize, monteCarloLoop, actualAADepth, writeBuffer, readEvent);
					asyncBufferIndex ^= 1;
				}
				else
				{
					result = engine->ReadBuffersFromQueue(deviceIndex);
					if (!result)
					{
						emit finished();
						finishedWithSuccess = false;
						return;
					}

					openclprocessingTimeNanoSeconds = openclProcessingTime.nsecsElapsed();

					quint64 outputItemSize = outputBuffers.at(outputIndex).itemSize;
					quint64 outputItemlength = outputBuffers.at(outputIndex).length;
					cOpenCLWorkerOutputQueue::sClDataBuffer dataBuffer(outputItemSize, outputItemlength);

					char *startPtr = outputBuffers.at(outputIndex).ptr.get();
					char *endPtr = startPtr + outputBuffers.at(outputIndex).size();
					dataBuffer.data.assign(startPtr, endPtr);

					cOpenCLWorkerOutputQueue::sClSingleOutput outputDataForQueue;
					outputDataForQueue.jobX = jobX;
					outputDataForQueue.jobY = jobY;
					outputDataForQueue.gridX = gridX;
					outputDataForQueue.gridY = gridY;
					outputDataForQueue.tileIndex = tile;
					outputDataForQueue.jobWidth = jobWidth;
					outputDataForQueue.jobHeight = jobHeight;
					outputDataForQueue.monteCarloLoop = monteCarloLoop;
					outputDataForQueue.aaDepth = actualAADepth;
					outputDataForQueue.outputBuffers.append(dataBuffer);
					outputDataForQueue.pixelSequence = inPixelSequenceBuffer;
					outputDataForQueue.sequenceSize = sequenceSize;

					outputQueue->AddToQueue(&outputDataForQueue);
				}
			}

			// slow down to reduce length of queue
			int queueLength = outputQueue->getQueueLength();
			if (queueLength > 200)
			{
				Wait((queueLength - 200));
			}
		} // next tile

		// Drain the last lookahead tile before reporting progress/finishing.
		if (asyncOutputEnabled && !ProcessPendingOutput())
		{
			emit finished();
			finishedWithSuccess = false;
			return;
		}

		if (*stopRequest || systemData.globalStopRequest)
		{
			emit finished();
			finishedWithSuccess = false;
			return;
		}

		if (monteCarloLoop == 1) actualAADepth++;

		actualAARepeatIndex++;
		int numberOfAARepeats = int(pow(9.0, double((actualAADepth - 1) / 2))) * 4;
		// qDebug() << numberOfAARepeats;

		if (actualAARepeatIndex >= numberOfAARepeats)
		{
			actualAADepth++;
			actualAARepeatIndex = 0;
		}
	} // next monteCarloLoop

	finishedWithSuccess = true;
	emit finished();
}

bool cOpenClWorkerThread::ProcessClQueue(quint64 jobX, quint64 jobY, quint64 pixelsLeftX,
	quint64 pixelsLeftY, quint64 sequenceSize, int asyncOutputBuffer)
{
	size_t stepSizeX = optimalStepX;
	if (pixelsLeftX < stepSizeX) stepSizeX = pixelsLeftX;
	size_t stepSizeY = optimalStepY;
	if (pixelsLeftY < stepSizeY) stepSizeY = pixelsLeftY;

	cl_int err = 0;
	const bool use2D = isFullEngine && pixelMask && pixelMask->empty();

	if (asyncOutputBuffer >= 0)
	{
		err = clKernel->setArg(0, *asyncOutputBuffers[asyncOutputBuffer]);
		if (!checkErr(err, "kernel->setArg(0, async output buffer)")) return false;
	}

	if (use2D)
	{
		size_t localX = 8;
		size_t localY = 8;
		if (localWorkSize >= 128)
		{
			localX = 16;
			localY = 8;
		}
		else if (localWorkSize < 64)
		{
			localX = size_t(localWorkSize > 0 ? localWorkSize : 1);
			localY = 1;
		}

		const size_t globalX = ((stepSizeX + localX - 1) / localX) * localX;
		const size_t globalY = ((stepSizeY + localY - 1) / localY) * localY;
		err = clQueue->enqueueNDRangeKernel(*clKernel, cl::NDRange(jobX, jobY),
			cl::NDRange(globalX, globalY), cl::NDRange(localX, localY), nullptr, &lastKernelEvent);
	}
	else if (sequenceSize == 0)
	{
		err = clQueue->enqueueNDRangeKernel(*clKernel, cl::NDRange(jobX, jobY),
			cl::NDRange(stepSizeX, stepSizeY), cl::NullRange, nullptr, &lastKernelEvent);
	}
	else
	{
		// Masked / monte-carlo full-engine tiles use the 1D pixel sequence.
		// Pad the global size to whole work-groups; the kernel ignores extras.
		const size_t local = size_t(localWorkSize > 0 ? localWorkSize : 1);
		const size_t global = ((size_t(sequenceSize) + local - 1) / local) * local;
		err = clQueue->enqueueNDRangeKernel(*clKernel,
			cl::NDRange(size_t(jobX + jobY * imageWidth)), cl::NDRange(global), cl::NDRange(local),
			nullptr, &lastKernelEvent);
	}
	if (!checkErr(err, "CommandQueue::enqueueNDRangeKernel()"))
	{
		EmitErrorMessage(
			QObject::tr("Cannot enqueue OpenCL rendering jobs"), cErrorMessage::errorMessage, nullptr);
		return false;
	}

	return true;
}

bool cOpenClWorkerThread::InitAsyncOutput()
{
	if (!isFullEngine || !pixelMask || !pixelMask->empty()) return false;
	if (outputBuffers.isEmpty()) return false;
	if (asyncOutputBuffers[0]) return true;

	const size_t bufferSize = outputBuffers.at(outputIndex).size();
	if (bufferSize == 0) return false;

	cl_int err = CL_SUCCESS;
	for (int i = 0; i < 2; i++)
	{
		asyncOutputBuffers[i].reset(new cl::Buffer(
			*hardware->getContext(deviceIndex), CL_MEM_WRITE_ONLY, bufferSize, nullptr, &err));
		if (!checkErr(err, QString("new cl::Buffer(...) async output %1").arg(i))) return false;
		asyncHostBuffers[i].resize(bufferSize);
	}

	readQueue.reset(new cl::CommandQueue(*hardware->getContext(deviceIndex),
		*hardware->getEnabledDevices().at(deviceIndex), 0, &err));
	if (!checkErr(err, "new cl::CommandQueue(...) async readback")) return false;

	asyncOutputEnabled = true;
	return true;
}

bool cOpenClWorkerThread::EnqueueAsyncOutputRead(int bufferIndex, cl::Event &readEvent)
{
	if (!asyncOutputEnabled || bufferIndex < 0 || bufferIndex > 1) return false;

	std::vector<cl::Event> waitEvents;
	waitEvents.push_back(lastKernelEvent);
	readEvent = cl::Event();
	cl_int err = readQueue->enqueueReadBuffer(*asyncOutputBuffers[bufferIndex], CL_FALSE, 0,
		asyncHostBuffers[bufferIndex].size(), asyncHostBuffers[bufferIndex].data(), &waitEvents,
		&readEvent);
	return checkErr(err, "CommandQueue::enqueueReadBuffer() async output");
}

void cOpenClWorkerThread::QueuePendingOutput(quint64 jobX, quint64 jobY, quint64 gridX,
	quint64 gridY, quint64 tileIndex, quint64 jobWidth, quint64 jobHeight, quint64 sequenceSize,
	int monteCarloLoop, int aaDepth, int bufferIndex, const cl::Event &readEvent)
{
	pendingOutput.valid = true;
	pendingOutput.bufferIndex = bufferIndex;
	pendingOutput.readEvent = readEvent;
	pendingOutput.jobX = jobX;
	pendingOutput.jobY = jobY;
	pendingOutput.gridX = gridX;
	pendingOutput.gridY = gridY;
	pendingOutput.tileIndex = tileIndex;
	pendingOutput.jobWidth = jobWidth;
	pendingOutput.jobHeight = jobHeight;
	pendingOutput.sequenceSize = sequenceSize;
	pendingOutput.monteCarloLoop = monteCarloLoop;
	pendingOutput.aaDepth = aaDepth;
	pendingOutput.pixelSequence = inPixelSequenceBuffer;
}

bool cOpenClWorkerThread::ProcessPendingOutput()
{
	if (!pendingOutput.valid) return true;

	cl_int err = pendingOutput.readEvent.wait();
	if (!checkErr(err, "cl::Event::wait() async output"))
	{
		pendingOutput.valid = false;
		return false;
	}

	const quint64 outputItemSize = outputBuffers.at(outputIndex).itemSize;
	const quint64 outputItemlength = outputBuffers.at(outputIndex).length;
	cOpenCLWorkerOutputQueue::sClDataBuffer dataBuffer(outputItemSize, outputItemlength);

	const std::vector<char> &hostBuffer = asyncHostBuffers[pendingOutput.bufferIndex];
	dataBuffer.data.assign(hostBuffer.begin(), hostBuffer.end());

	cOpenCLWorkerOutputQueue::sClSingleOutput outputDataForQueue;
	outputDataForQueue.jobX = pendingOutput.jobX;
	outputDataForQueue.jobY = pendingOutput.jobY;
	outputDataForQueue.gridX = pendingOutput.gridX;
	outputDataForQueue.gridY = pendingOutput.gridY;
	outputDataForQueue.tileIndex = pendingOutput.tileIndex;
	outputDataForQueue.jobWidth = pendingOutput.jobWidth;
	outputDataForQueue.jobHeight = pendingOutput.jobHeight;
	outputDataForQueue.monteCarloLoop = pendingOutput.monteCarloLoop;
	outputDataForQueue.aaDepth = pendingOutput.aaDepth;
	outputDataForQueue.outputBuffers.append(dataBuffer);
	outputDataForQueue.pixelSequence = pendingOutput.pixelSequence;
	outputDataForQueue.sequenceSize = pendingOutput.sequenceSize;

	outputQueue->AddToQueue(&outputDataForQueue);
	pendingOutput.valid = false;
	return true;
}

bool cOpenClWorkerThread::AddAntiAliasingParameters(int actualDepth, int repeatIndex)
{
	CVector2<float> offset;

	if (actualDepth > 0)
	{
		int gridSize = int(pow(3.0, double((actualDepth - 1) / 2)));
		int positionIndex = repeatIndex / 4;

		int xIndex, yIndex;
		float baseOffsetX, baseOffsetY;
		float smallOffsetX = 0;
		float smallOffsetY = 0;

		xIndex = positionIndex % gridSize;
		yIndex = positionIndex / gridSize;

		//		qDebug() << repeatIndex << positionIndex << xIndex << yIndex;

		baseOffsetX = (xIndex - gridSize / 2) / float(gridSize);
		baseOffsetY = (yIndex - gridSize / 2) / float(gridSize);

		float gridOffset = 1.0 / gridSize / 3.0;
		if (actualDepth % 2 == 0)
		{
			switch (repeatIndex % 4)
			{
				case 0:
				{
					smallOffsetX = -gridOffset;
					smallOffsetY = 0;
					break;
				}
				case 1:
				{
					smallOffsetX = gridOffset;
					smallOffsetY = 0;
					break;
				}
				case 2:
				{
					smallOffsetX = 0;
					smallOffsetY = -gridOffset;
					break;
				}
				case 3:
				{
					smallOffsetX = 0;
					smallOffsetY = gridOffset;
					break;
				}
			}
		}
		else
		{
			switch (repeatIndex % 4)
			{
				case 0:
				{
					smallOffsetX = -gridOffset;
					smallOffsetY = -gridOffset;
					break;
				}
				case 1:
				{
					smallOffsetX = gridOffset;
					smallOffsetY = -gridOffset;
					break;
				}
				case 2:
				{
					smallOffsetX = -gridOffset;
					smallOffsetY = gridOffset;
					break;
				}
				case 3:
				{
					smallOffsetX = gridOffset;
					smallOffsetY = gridOffset;
					break;
				}
			}
		}

		offset.x = baseOffsetX + smallOffsetX;
		offset.y = baseOffsetY + smallOffsetY;

		//		qDebug() << "grid" << gridSize << "small" << smallOffsetX << smallOffsetY << "base"
		//						 << baseOffsetX << baseOffsetY << "offset" << offset.x << offset.y;
	}
	else
	{
		offset.x = 0.0f;
		offset.y = 0.0f;
	}

	cl_int err = CL_SUCCESS;
	if (engine->GetDoublePrecision())
	{
		// The kernel argument is REAL2, i.e. double2 when double precision is
		// enabled. Passing cl_float2 here would give CL_INVALID_ARG_VALUE.
		cl_double2 antiAliasingOffset = {{offset.x, offset.y}};
		err = clKernel->setArg(7, antiAliasingOffset);
	}
	else
	{
		cl_float2 antiAliasingOffset = {{offset.x, offset.y}};
		err = clKernel->setArg(7, antiAliasingOffset);
	}
	if (!checkErr(err, "kernel->setArg(7, antiAliasingOffset)"))
	{
		EmitErrorMessage(tr("Cannot set OpenCL argument for %1").arg(tr("antiAliasingDepth")),
			cErrorMessage::errorMessage, nullptr);
		return false;
	}

	return true;
}

quint64 cOpenClWorkerThread::UpdatePixelSequence(
	quint64 jobX, quint64 jobY, quint64 jobWidth, quint64 jobHeight, qint64 imageWidth)
{
	cl_int err = 0;

	// Unmasked full-engine tiles use the direct 2D path. No pixel sequence or
	// per-tile upload is needed; only a tiny dummy buffer is kept bound to the
	// kernel argument that the 1D path uses.
	const bool use2D = (isFullEngine && pixelMask && pixelMask->empty());
	if (use2D)
	{
		if (!inClPixelSequenceBuffer)
		{
			cl_int dummy = 0;
			inClPixelSequenceBuffer.reset(new cl::Buffer(*hardware->getContext(deviceIndex),
				CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, sizeof(cl_int), &dummy, &err));
			if (!checkErr(err, "new cl::Buffer(...) for 2D pixel mapping")) return 0;
		}

		const quint64 tilePixels = jobWidth * jobHeight;
		err = clKernel->setArg(8, cl_int(tilePixels));
		if (!checkErr(err, "kernel->setArg(8, sequenceSize)")) return 0;
		err = clKernel->setArg(9, cl_int(jobWidth));
		if (!checkErr(err, "kernel->setArg(9, jobWidth)")) return 0;
		err = clKernel->setArg(10, *inClPixelSequenceBuffer.get());
		if (!checkErr(err, "kernel->setArg(10, inPixelSequenceBuffer)")) return 0;
		err = clKernel->setArg(11, cl_int(jobHeight));
		if (!checkErr(err, "kernel->setArg(11, jobHeight)")) return 0;
		err = clKernel->setArg(12, cl_int(1));
		if (!checkErr(err, "kernel->setArg(12, use2D)")) return 0;

		return tilePixels;
	}

	inPixelSequenceBuffer.resize(jobWidth * jobHeight);
	quint64 sequenceSize = 0;

	int subTileSize = sqrt(maxWorkgroupSize);

	if (pixelMask->size() > 0)
	{
		// check number of pixels left to render
		quint64 pixelsToRender = 0;
		for (quint64 y = 0; y < jobHeight; y++)
		{
			for (quint64 x = 0; x < jobWidth; x++)
			{
				if (pixelMask->at((x + jobX) + (y + jobY) * imageWidth))
				{
					pixelsToRender++;
				}
			}
		}

		if (pixelsToRender > static_cast<quint64>(maxWorkgroupSize * 32))
		{
			// creating the sequence
			quint64 sequenceIndex = 0;
			for (quint64 y = 0; y < jobHeight; y += subTileSize)
			{
				for (quint64 x = 0; x < jobWidth; x += subTileSize)
				{
					// checking if at least one pixel in sub-tile is enabled
					bool havePixel = false;
					for (quint64 yy = y; yy < min(y + subTileSize, jobHeight); yy++)
					{
						for (quint64 xx = x; xx < min(x + subTileSize, jobWidth); xx++)
						{
							if (pixelMask->at((xx + jobX) + (yy + jobY) * imageWidth))
							{
								havePixel = true;
								break;
							}
						}
						if (havePixel) break;
					}

					// adding pixels from sub-tile to sequence
					for (quint64 yy = y; yy < min(y + subTileSize, jobHeight); yy++)
					{
						for (quint64 xx = x; xx < min(x + subTileSize, jobWidth); xx++)
						{
							if (havePixel)
							{
								inPixelSequenceBuffer[sequenceIndex] = xx + yy * jobWidth;
								sequenceIndex++;
							}
						}
					}
				}
			}
			sequenceSize = sequenceIndex;
		}
		else
		{
			// creating the sequence
			quint64 sequenceIndex = 0;
			for (quint64 y = 0; y < jobHeight; y++)
			{
				for (quint64 x = 0; x < jobWidth; x++)
				{
					if (pixelMask->at((x + jobX) + (y + jobY) * imageWidth))
					{
						inPixelSequenceBuffer[sequenceIndex] = x + y * jobWidth;
						sequenceIndex++;
					}
				}
			}
			sequenceSize = sequenceIndex;
		}
	}
	else
	{
		quint64 sequenceIndex = 0;
		for (quint64 y = 0; y < jobHeight; y += subTileSize)
		{
			for (quint64 x = 0; x < jobWidth; x += subTileSize)
			{
				for (quint64 yy = y; yy < min(y + subTileSize, jobHeight); yy++)
				{
					for (quint64 xx = x; xx < min(x + subTileSize, jobWidth); xx++)
					{
						inPixelSequenceBuffer[sequenceIndex] = xx + yy * jobWidth;
						sequenceIndex++;
					}
				}
			}
		}
		sequenceSize = sequenceIndex;
	}

	if (sequenceSize == 0)
	{
		sequenceSize = 1;
		inPixelSequenceBuffer[0] = 0;
	}

	inClPixelSequenceBuffer.reset(
		new cl::Buffer(*hardware->getContext(deviceIndex), CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR,
			sequenceSize * sizeof(cl_int), inPixelSequenceBuffer.data(), &err));

	if (!checkErr(err, "new cl::Buffer(...) for pixel mask"))
	{
		EmitErrorMessage(QObject::tr("OpenCL bufer for pixel mask cannot be created!"),
			cErrorMessage::errorMessage, nullptr);
		// qDebug() << "jobWidth" << jobWidth << "jobHeight" << jobHeight << "sequence size"
		//<< sequenceSize;
		return 0;
	}

	err = clQueue->enqueueWriteBuffer(*inClPixelSequenceBuffer.get(), CL_TRUE, 0,
		sequenceSize * sizeof(cl_int), inPixelSequenceBuffer.data());
	if (!checkErr(err, "CommandQueue::enqueueWriteBuffer(...) for pixel mask"))
	{
		EmitErrorMessage(QObject::tr("Cannot enqueue writing OpenCL pixel mask"),
			cErrorMessage::errorMessage, nullptr);
		return 0;
	}

	err = clKernel->setArg(8, cl_int(sequenceSize));
	if (!checkErr(err, "kernel->setArg(8, sequenceSize)"))
	{
		EmitErrorMessage(tr("Cannot set OpenCL argument for %1").arg(tr("sequenceSize")),
			cErrorMessage::errorMessage, nullptr);
		return 0;
	}

	err = clKernel->setArg(9, cl_int(jobWidth));
	if (!checkErr(err, "kernel->setArg(8, jobWidth)"))
	{
		EmitErrorMessage(tr("Cannot set OpenCL argument for %1").arg(tr("jobWidth")),
			cErrorMessage::errorMessage, nullptr);
		return 0;
	}

	err = clKernel->setArg(10, *inClPixelSequenceBuffer.get());
	if (!checkErr(err, "kernel->setArg(8, inClPixelSequenceBuffer)"))
	{
		EmitErrorMessage(tr("Cannot set OpenCL argument for %1").arg(tr("inClPixelSequenceBuffer")),
			cErrorMessage::errorMessage, nullptr);
		return 0;
	}

	// Masked / monte-carlo rendering keeps the pixel sequence path.
	err = clKernel->setArg(11, cl_int(jobHeight));
	if (!checkErr(err, "kernel->setArg(11, jobHeight)"))
	{
		EmitErrorMessage(tr("Cannot set OpenCL argument for %1").arg(tr("jobHeight")),
			cErrorMessage::errorMessage, nullptr);
		return 0;
	}
	err = clKernel->setArg(12, cl_int(0));
	if (!checkErr(err, "kernel->setArg(12, use2D)"))
	{
		EmitErrorMessage(tr("Cannot set OpenCL argument for %1").arg(tr("use2D")),
			cErrorMessage::errorMessage, nullptr);
		return 0;
	}

	return sequenceSize;
}
#endif // USE_OPENCL
