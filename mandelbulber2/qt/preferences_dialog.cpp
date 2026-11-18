/**
 * Mandelbulber v2, a 3D fractal generator       ,=#MKNmMMKmmßMNWy,
 *                                             ,B" ]L,,p%%%,,,§;, "K
 * Copyright (C) 2016-24 Mandelbulber Team     §R-==%w["'~5]m%=L.=~5N
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
 * Authors: Sebastian Jennen (jenzebas@gmail.com), Robert Pancoast (RobertPancoast77@gmail.com)
 *
 * cPreferencesDialog - dialog to configure and maintain application Preferences
 */

#include "preferences_dialog.h"

#include <memory>

#include <QCryptographicHash>
#include <QFileDialog>
#include <QMessageBox>

#include "ui_preferences_dialog.h"

#include "dock_navigation.h"
#include "thumbnail_widget.h"

#include "src/automated_widgets.hpp"
#include "src/file_downloader.hpp"
#include "src/fractal_container.hpp"
#include "src/fractal_enums.h"
#include "src/global_data.hpp"
#include "src/initparameters.hpp"
#include "src/interface.hpp"
#include "src/opencl_engine_render_fractal.h"
#include "src/opencl_engine_render_ssao.h"
#include "src/opencl_global.h"
#include "src/opencl_hardware.h"
#include "src/progress_text.hpp"
#include "src/render_window.hpp"
#include "src/settings.hpp"
#include "src/system.hpp"
#include "src/system_data.hpp"
#include "src/system_directories.hpp"
#include "src/texture_cache.h"
#include "src/wait.hpp"

cPreferencesDialog::cPreferencesDialog(QWidget *parent)
		: QDialog(parent), ui(new Ui::cPreferencesDialog)
{
	initFinished = false;
	ui->setupUi(this);

	int maximumCores = get_cpu_count();
	ui->spinboxInt_limit_CPU_cores->setMaximum(maximumCores);

#ifndef WIN32
	ui->label_threads_priority->hide();
	ui->comboBox_threads_priority->hide();
#endif

	automatedWidgets = new cAutomatedWidgets(this);
	automatedWidgets->ConnectSignalsForSlidersInWindow(this);

	ui->comboBox_ui_style_type->addItems(QStyleFactory::keys());
	SynchronizeInterfaceWindow(this, gPar, qInterface::write);

	ui->comboBox_ui_skin->setCurrentIndex(gPar->Get<int>("ui_skin"));

	ui->comboboxLanguage->addItems(systemData.supportedLanguages.values());

	if (systemData.supportedLanguages.contains(gPar->Get<QString>("language")))
	{
		QString value = systemData.supportedLanguages[gPar->Get<QString>("language")];
		int index = ui->comboboxLanguage->findText(value);
		ui->comboboxLanguage->setCurrentIndex(index);
	}
	else
	{
		int index = ui->comboboxLanguage->findText(systemData.locale.name());
		ui->comboboxLanguage->setCurrentIndex(index);
	}

	ui->label_path_to_logfile->setText(tr("Path to log file: %1").arg(systemData.logfileName));

#ifdef USE_OPENCL
	UpdateOpenCLListBoxes(false);
	UpdateOpenCLMemoryLimits();
	UpdateOpenCLPrecisionComboBox();
	connect(ui->listWidget_opencl_device_list, &QListWidget::itemSelectionChanged, this,
		&cPreferencesDialog::UpdateOpenCLPrecisionComboBox);
#else	 // USE_OPENCL
	ui->tabWidget->removeTab(2); // hide GPU tab for now
#endif // USE_OPENCL

	if (gPar->Get<bool>("ui_colorize"))
		cInterface::ColorizeGroupBoxes(this, gPar->Get<int>("ui_colorize_random_seed"));
	cInterface::AdjustLayoutSpacing(this, gPar->Get<int>("ui_layout_spacing"));

	initFinished = true;
}

cPreferencesDialog::~cPreferencesDialog()
{
	delete ui;
}

void cPreferencesDialog::showEvent(QShowEvent *event)
{
	QDialog::showEvent(event);
#ifdef USE_OPENCL
	// The dialog is reused after being closed, so recompute the precision gate
	// from the current device list and checkbox state each time it is shown.
	UpdateOpenCLPrecisionComboBox();
#endif
}

void cPreferencesDialog::on_buttonBox_accepted()
{
	SynchronizeInterfaceWindow(this, gPar, qInterface::read);

	QFont font = gMainInterface->mainWindow->font();
	font.setPointSizeF(gPar->Get<int>("ui_font_size"));
	gMainInterface->mainWindow->setFont(font);

	QString value = ui->comboboxLanguage->currentText();
	QString key = systemData.supportedLanguages.key(value);
	gPar->Set<QString>("language", key);

	systemData.loggingVerbosity = gPar->Get<int>("logging_verbosity");
	systemData.numberOfThreads = gPar->Get<int>("limit_CPU_cores");
	systemData.threadsPriority = enumRenderingThreadPriority(gPar->Get<int>("threads_priority"));
	systemData.enableConsoleOutput = gPar->Get<bool>("console_output_enable");

#ifdef USE_OPENCL
	bool openClSettingsChanged = false;

	// OpenCL preference dialogue supports (1) platform
	int selectedPlatform = ui->listWidget_opencl_platform_list->currentIndex().row();
	if (selectedPlatform < 0) selectedPlatform = 0;

	if (selectedPlatform != gPar->Get<int>("opencl_platform")) openClSettingsChanged = true;

	gPar->Set("opencl_platform", selectedPlatform);

	QList<QListWidgetItem *> selectedDevicesItems =
		ui->listWidget_opencl_device_list->selectedItems();
	QList<QPair<QString, QString>> devices = GetOpenCLDevices();
	QStringList activeDevices;
	for (auto selectedDevicesItem : selectedDevicesItems)
	{
		activeDevices.append(selectedDevicesItem->data(1).toString());
	}
	QString listString = activeDevices.join("|");

	if (listString != gPar->Get<QString>("opencl_device_list")) openClSettingsChanged = true;

	if (openClSettingsChanged)
	{
		// OpenCL preference dialogue supports multiple devices
		gOpenCl->Reset();
		cOpenClDevice::enumOpenClDeviceType deviceType =
			cOpenClDevice::enumOpenClDeviceType(gPar->Get<int>("opencl_device_type"));
		gOpenCl->openClHardware->ListOpenClDevices(selectedPlatform, deviceType);
		gPar->Set("opencl_device_list", listString);
		gOpenCl->openClHardware->EnableDevicesByHashList(listString);

		gOpenCl->openClHardware->CreateAllContexts(selectedPlatform, deviceType);
	}

	gTextureCache->setMaxSize(gPar->Get<int>("maximum_texture_cache_size") * 1024L * 1024L);

	gPar->Set<int>("toolbar_icon_size", gPar->Get<int>("toolbar_icon_size"));
	gMainInterface->mainWindow->slotPopulateToolbar(true);
#endif
}

void cPreferencesDialog::on_pushButton_select_image_path_clicked()
{
	QString dir = QDir::toNativeSeparators(
		QFileDialog::getExistingDirectory(this, tr("Select default directory for images"),
			QDir::toNativeSeparators(ui->text_default_image_path->text())));
	if (dir.length() > 0)
	{
		ui->text_default_image_path->setText(dir);
	}
}

void cPreferencesDialog::on_pushButton_select_settings_path_clicked()
{
	QString dir = QDir::toNativeSeparators(
		QFileDialog::getExistingDirectory(this, tr("Select default directory for settings files"),
			QDir::toNativeSeparators(ui->text_default_settings_path->text())));
	if (dir.length() > 0)
	{
		ui->text_default_settings_path->setText(dir);
	}
}

void cPreferencesDialog::on_pushButton_select_textures_path_clicked()
{
	QString dir = QDir::toNativeSeparators(
		QFileDialog::getExistingDirectory(this, tr("Select default directory for textures"),
			QDir::toNativeSeparators(ui->text_default_textures_path->text())));
	if (dir.length() > 0)
	{
		ui->text_default_textures_path->setText(dir);
	}
}

void cPreferencesDialog::on_pushButton_select_user_textures_path_clicked()
{
	QString dir = QDir::toNativeSeparators(
		QFileDialog::getExistingDirectory(this, tr("Select directory for user textures"),
			QDir::toNativeSeparators(ui->text_default_user_textures_path->text())));
	if (dir.length() > 0)
	{
		ui->text_default_user_textures_path->setText(dir);
	}
}

void cPreferencesDialog::on_pushButton_select_toolbar_path_clicked()
{
	QString dir = QDir::toNativeSeparators(
		QFileDialog::getExistingDirectory(this, tr("Select default directory for toolbar presets"),
			QDir::toNativeSeparators(ui->text_toolbar_path->text())));
	if (dir.length() > 0)
	{
		ui->text_toolbar_path->setText(dir);
	}
}

void cPreferencesDialog::on_pushButton_clear_thumbnail_cache_clicked() const
{
	QDir thumbnailDir(systemDirectories.GetThumbnailsFolder());
	thumbnailDir.setFilter(QDir::AllEntries | QDir::NoDotAndDotDot);
	uint thumbnailDirCount = thumbnailDir.count();

	// confirmation dialog before clearing
	QMessageBox::StandardButton reply;
	reply = QMessageBox::question(nullptr, QObject::tr("Are you sure to clear the thumbnail cache?"),
		QObject::tr("Are you sure to clear the thumbnail cache?\nThere are currently %1 thumbnails "
								"cached. These will be deleted and rerendered when necessary.\n Clear now?")
			.arg(thumbnailDirCount),
		QMessageBox::Yes | QMessageBox::No);

	if (reply == QMessageBox::Yes)
	{
		// match exact 32 char hash images, example filename: c0ad626d8c25ab6a25c8d19a53960c8a.png
		DeleteAllFilesFromDirectory(
			systemDirectories.GetThumbnailsFolder(), "????????????????????????????????.*");
	}
	else
	{
		return;
	}
}

// void cPreferencesDialog::on_pushButton_load_thumbnail_cache_clicked() const
//{
//	QMessageBox::StandardButton reply;
//	reply = QMessageBox::question(nullptr,
//		QObject::tr("Are you sure to load the thumbnail cache from the server?"),
//		QObject::tr("This will try to load missing common thumbnails from the server.\nProceed?"),
//		QMessageBox::Yes | QMessageBox::No);
//
//	if (reply == QMessageBox::Yes)
//	{
//		cFileDownloader fileDownloader(
//			QString("http://cdn.mandelbulber.org/thumbnail/%1").arg(MANDELBULBER_VERSION_STRING),
//			systemDirectories.GetThumbnailsFolder());
//		QObject::connect(&fileDownloader,
//			SIGNAL(updateProgressAndStatus(const QString &, const QString &, double)),
//			gMainInterface->mainWindow,
//			SLOT(slotUpdateProgressAndStatus(const QString &, const QString &, double)));
//		fileDownloader.downloadFileList();
//	}
//	else
//	{
//		return;
//	}
// }

void cPreferencesDialog::on_pushButton_generate_thumbnail_cache_clicked()
{
	QMessageBox::StandardButton reply;
	QString infoGenerateCacheFiles =
		"This is a development feature. If you want to obtain all example cache files, click load!\n\n";
	infoGenerateCacheFiles +=
		"This will render all settings files which are yet missing in your thumbnail cache.\n";
	infoGenerateCacheFiles +=
		"This process will take a lot of time and cannot be cancelled.\nProceed?";

	reply = QMessageBox::question(nullptr,
		QObject::tr("Are you sure to generate all example thumbnail cache files?"),
		infoGenerateCacheFiles, QMessageBox::Yes | QMessageBox::No);

	if (reply == QMessageBox::Yes)
	{
		// this renders all example files and from settings folder as a thumbnail and saves them to the
		// thumbnail cache

		QStringList listOfFiles;

		{
			QString examplePath = QDir::toNativeSeparators(systemDirectories.sharedDir + "examples");
			QDirIterator it(
				examplePath, QStringList() << "*.fract", QDir::Files, QDirIterator::Subdirectories);
			QStringList exampleFiles;
			while (it.hasNext())
				listOfFiles << it.next();
		}
		{
			QDirIterator it(systemDirectories.GetSettingsFolder(), QStringList() << "*.fract",
				QDir::Files, QDirIterator::Subdirectories);
			QStringList settingsFiles;
			while (it.hasNext())
				listOfFiles << it.next();
		}

		std::shared_ptr<cParameterContainer> examplePar(new cParameterContainer);
		std::shared_ptr<cFractalContainer> exampleParFractal(new cFractalContainer);

		double dpiScale = devicePixelRatioF();
		int thumbnailSize = systemData.GetPreferredThumbnailSize() * 1.5;
		std::unique_ptr<cThumbnailWidget> thumbWidget(
			new cThumbnailWidget(thumbnailSize, thumbnailSize, dpiScale));

		QObject::connect(thumbWidget.get(),
			SIGNAL(updateProgressAndStatus(const QString &, const QString &, double)),
			gMainInterface->mainWindow,
			SLOT(slotUpdateProgressAndStatus(const QString &, const QString &, double)));

		examplePar->SetContainerName("main");
		InitParams(examplePar);
		InitNodeParams(1, examplePar);
		/****************** TEMPORARY CODE FOR MATERIALS *******************/

		InitMaterialParams(1, examplePar);

		/*******************************************************************/
		for (int i = 0; i < exampleParFractal->size(); i++)
		{
			exampleParFractal->at(i)->SetContainerName(QString("fractal") + QString::number(i));
			InitFractalParams(exampleParFractal->at(i));
		}
		for (int i = 0; i < listOfFiles.size(); i++)
		{
			if (systemData.globalStopRequest) break;

			QString filename = listOfFiles.at(i);
			gMainInterface->mainWindow->slotUpdateProgressAndStatus(QString("Rendering examples"),
				tr("rendering %1, %2 of %3")
					.arg(filename, QString::number(i + 1), QString::number(listOfFiles.size())),
				1.0 * (i + 1) / listOfFiles.size(), cProgressText::progress_ANIMATION);

			cSettings parSettings(cSettings::formatFullText);
			parSettings.BeQuiet(true);
			parSettings.LoadFromFile(filename);

			if (parSettings.Decode(examplePar, exampleParFractal))
			{
				examplePar->Set("opencl_mode", gPar->Get<int>("opencl_mode"));
				examplePar->Set("opencl_enabled", gPar->Get<bool>("opencl_enabled"));

				thumbWidget->DisableTimer();
				thumbWidget->AssignParameters(examplePar, exampleParFractal);
				if (!thumbWidget->IsRendered())
				{
					thumbWidget->slotRender();
					while (!thumbWidget->IsRendered())
					{
						gApplication->processEvents();
						Wait(100);
					}
				}
				else
				{
					// "touch" the file, to mark it with current time stamp
					QFile file(thumbWidget->GetThumbnailFileName());
					if (file.open(QIODevice::Append))
					{
						QDataStream out(&file);
						out << "";
						file.close();
					}
				}
			}
		}
	}
	else
	{
		return;
	}
}

void cPreferencesDialog::on_comboBox_ui_style_type_currentIndexChanged(int index) const
{
	Q_UNUSED(index)

	if (!initFinished) return;
	gPar->Set<QString>("ui_style_type", ui->comboBox_ui_style_type->currentText());

	UpdateUIStyle();
}

void cPreferencesDialog::on_comboBox_ui_skin_currentIndexChanged(int index) const
{
	if (!initFinished) return;
	gPar->Set<int>("ui_skin", index);
	UpdateUISkin();
}

void cPreferencesDialog::on_pushButton_retrieve_toolbar_clicked() const
{
	QMessageBox::StandardButton reply;
	reply = QMessageBox::question(nullptr, QObject::tr("Retrieve toolbar"),
		QObject::tr("Are you sure to retrieve default presets into toolbar?\nIt could overwrite some "
								"of existing presets.\nProceed?"),
		QMessageBox::Yes | QMessageBox::No);

	if (reply == QMessageBox::Yes)
	{
		RetrieveToolbarPresets(true);
	}
}

void cPreferencesDialog::on_pushButton_retrieve_materials_clicked() const
{
	QMessageBox::StandardButton reply;
	reply = QMessageBox::question(nullptr, QObject::tr("Retrieve materials"),
		QObject::tr("Are you sure to retrieve default materials into materials folder?\nIt could "
								"overwrite some of existing materials.\nProceed?"),
		QMessageBox::Yes | QMessageBox::No);

	if (reply == QMessageBox::Yes)
	{
		RetrieveExampleMaterials(true);
	}
}

void cPreferencesDialog::on_pushButton_key_layout_default_clicked()
{
	gPar->Set("key_move_forward", QString("Q"));
	gPar->Set("key_move_backward", QString("Z"));
	gPar->Set("key_move_left", QString("A"));
	gPar->Set("key_move_right", QString("D"));
	gPar->Set("key_move_up", QString("W"));
	gPar->Set("key_move_down", QString("S"));
	gPar->Set("key_rotate_up", QString("Up"));
	gPar->Set("key_rotate_down", QString("Down"));
	gPar->Set("key_rotate_left", QString("Left"));
	gPar->Set("key_rotate_right", QString("Right"));
	gPar->Set("key_roll_left", QString(","));
	gPar->Set("key_roll_right", QString("."));

	gPar->Set("key_render", QString("R"));
	gPar->Set("key_stop", QString("T"));
	gPar->Set("key_add_keyframe", QString("K"));
	gPar->Set("key_modify_keyframe", QString("M"));

	SynchronizeInterfaceWindow(this, gPar, qInterface::write);
}
void cPreferencesDialog::on_pushButton_key_layout_mb3d_clicked()
{
	gPar->Set("key_move_forward", QString("W"));
	gPar->Set("key_move_backward", QString("S"));
	gPar->Set("key_move_left", QString("A"));
	gPar->Set("key_move_right", QString("D"));
	gPar->Set("key_move_up", QString("E"));
	gPar->Set("key_move_down", QString("C"));
	gPar->Set("key_rotate_up", QString("I"));
	gPar->Set("key_rotate_down", QString("K"));
	gPar->Set("key_rotate_left", QString("J"));
	gPar->Set("key_rotate_right", QString("L"));
	gPar->Set("key_roll_left", QString("U"));
	gPar->Set("key_roll_right", QString("O"));

	SynchronizeInterfaceWindow(this, gPar, qInterface::write);
}

QList<QPair<QString, QString>> cPreferencesDialog::GetOpenCLDevices()
{
	QList<QPair<QString, QString>> devices;
#ifdef USE_OPENCL
	QList<cOpenClDevice::sDeviceInformation> openclDevs =
		gOpenCl->openClHardware->getDevicesInformation();
	for (cOpenClDevice::sDeviceInformation openclDev : openclDevs)
	{
		QByteArray hash = openclDev.hash;
		devices << QPair<QString, QString>(hash.toHex(), openclDev.deviceName);
	}
#endif // USE_OPENCL
	return devices;
}

#ifdef USE_OPENCL
void cPreferencesDialog::on_listWidget_opencl_platform_list_currentRowChanged(int index)
{
	if (index >= 0)
	{
		gOpenCl->Reset();
		gOpenCl->openClHardware->ListOpenClDevices(
			index, cOpenClDevice::enumOpenClDeviceType(ui->comboBox_opencl_device_type->currentIndex()));

		ui->listWidget_opencl_device_list->clear();

		QList<QPair<QString, QString>> devices = GetOpenCLDevices();
		QStringList selectedDevices = gPar->Get<QString>("opencl_device_list").split("|");
		for (auto device : devices)
		{
			QListWidgetItem *item = new QListWidgetItem(device.second);
			item->setData(1, device.first);
			bool selected = selectedDevices.contains(device.first);
			ui->listWidget_opencl_device_list->addItem(item);
			item->setSelected(selected);
		}
	}

	UpdateOpenCLPrecisionComboBox();
}

void cPreferencesDialog::on_groupCheck_opencl_enabled_toggled(bool state)
{
	if (state)
	{
		gOpenCl->Reset();
		gOpenCl->openClHardware->ListOpenClPlatforms();

		if (gOpenCl->openClHardware->getNumberOfPlatforms() > 0)
		{
			if (gPar->Get<int>("opencl_platform") >= 0)
			{
				gOpenCl->openClHardware->ListOpenClDevices(gPar->Get<int>("opencl_platform"),
					cOpenClDevice::enumOpenClDeviceType(ui->comboBox_opencl_device_type->currentIndex()));
				gOpenCl->openClHardware->EnableDevicesByHashList(gPar->Get<QString>("opencl_device_list"));
				gOpenCl->openClHardware->CreateAllContexts(gPar->Get<int>("opencl_platform"),
					cOpenClDevice::enumOpenClDeviceType(ui->comboBox_opencl_device_type->currentIndex()));
			}

			UpdateOpenCLListBoxes(true);
		}
		else
		{
			ui->groupCheck_opencl_enabled->setChecked(false);
		}
	}

	gMainInterface->mainWindow->GetWidgetDockNavigation()->EnableOpenCLModeComboBox(state);
	UpdateOpenCLPrecisionComboBox();
}

void cPreferencesDialog::UpdateOpenCLListBoxes(bool refreshOpenClPlatforms)
{
	// list of platforms
	if (refreshOpenClPlatforms)
	{
		gOpenCl->openClHardware->ListOpenClPlatforms();
	}

	QList<cOpenClHardware::sPlatformInformation> platformsInformation =
		gOpenCl->openClHardware->getPlatformsInformation();

	ui->listWidget_opencl_platform_list->clear();
	for (auto &platformInformation : platformsInformation)
	{
		QListWidgetItem *item =
			new QListWidgetItem(platformInformation.name + ", " + platformInformation.vendor + ", "
													+ platformInformation.version);
		ui->listWidget_opencl_platform_list->addItem(item);
	}

	int selectedPlatformIndex = gPar->Get<int>("opencl_platform");
	if (selectedPlatformIndex < platformsInformation.size() && selectedPlatformIndex >= 0)
	{
		ui->listWidget_opencl_platform_list->item(selectedPlatformIndex)->setSelected(true);
		ui->listWidget_opencl_platform_list->setCurrentRow(selectedPlatformIndex);

		cOpenClDevice::enumOpenClDeviceType deviceType =
			cOpenClDevice::enumOpenClDeviceType(gPar->Get<int>("opencl_device_type"));
		if (refreshOpenClPlatforms)
		{
			gOpenCl->openClHardware->ListOpenClDevices(selectedPlatformIndex, deviceType);
		}
		ui->listWidget_opencl_device_list->clear();
		QList<QPair<QString, QString>> devices = GetOpenCLDevices();
		QStringList selectedDevices = gPar->Get<QString>("opencl_device_list").split("|");
		bool noDeviceSelected = selectedDevices.first().isEmpty();

		for (QPair<QString, QString> device : devices)
		{
			QListWidgetItem *item = new QListWidgetItem(device.second);
			item->setData(1, device.first);
			bool selected = selectedDevices.contains(device.first);
			ui->listWidget_opencl_device_list->addItem(item);
			if (noDeviceSelected)
			{
				noDeviceSelected = false;
				selected = true;
			}
			item->setSelected(selected);
		}
	}

	UpdateOpenCLPrecisionComboBox();
}

bool cPreferencesDialog::IsDoublePrecisionSupportedBySelection() const
{
	const QList<cOpenClDevice::sDeviceInformation> &devicesInformation =
		gOpenCl->openClHardware->getDevicesInformation();

	if (devicesInformation.isEmpty()) return false;

	QList<QListWidgetItem *> selectedItems = ui->listWidget_opencl_device_list->selectedItems();

	if (selectedItems.isEmpty())
	{
		// The renderer falls back to the first available device when no device is
		// selected, so use the same rule for the precision gate.
		return devicesInformation.first().compilerAvailable
					 && devicesInformation.first().IsDoublePrecisionSupported();
	}

	for (QListWidgetItem *item : selectedItems)
	{
		const QString selectedHash = item->data(1).toString();
		bool found = false;
		for (const cOpenClDevice::sDeviceInformation &deviceInformation : devicesInformation)
		{
			if (deviceInformation.hash.toHex() == selectedHash)
			{
				found = true;
				if (!deviceInformation.compilerAvailable
						|| !deviceInformation.IsDoublePrecisionSupported())
				{
					return false;
				}
				break;
			}
		}
		if (!found) return false;
	}
	return true;
}

void cPreferencesDialog::UpdateOpenCLPrecisionComboBox()
{
	// Use the checkbox state instead of the parameter value: toggling OpenCL in
	// the dialog must update the precision gate immediately, before OK is pressed.
	const bool openclEnabled = ui->groupCheck_opencl_enabled->isChecked();
	const bool doubleSupported = openclEnabled && IsDoublePrecisionSupportedBySelection();

	ui->comboBox_opencl_precision->setEnabled(doubleSupported);
	if (doubleSupported)
	{
		ui->comboBox_opencl_precision->setToolTip(
			tr("<p>Floating point precision of the OpenCL kernels: single is faster, double is more "
				 "accurate and slower. Double requires FP64 device support.</p>"));
		ui->label_explanation_opencl_missing_features->setText(
			tr("<html><head/><body><p>Mandelbulber can use OpenCL to accelerate rendering.<br/>For "
				 "more information about setup and workflow see the User Manual<br/>under Menu &gt; Help "
				 "&gt; User Manual.<br/></p></body></html>"));
	}
	else if (openclEnabled)
	{
		// Reflect the effective precision: the renderer will fall back to single
		// precision when FP64 is unavailable.
		ui->comboBox_opencl_precision->setCurrentIndex(0);
		ui->comboBox_opencl_precision->setToolTip(
			tr("<p>Double precision (FP64) is not supported by the selected OpenCL device(s). "
				 "Only single precision can be used.</p>"));
		ui->label_explanation_opencl_missing_features->setText(
			tr("<html><head/><body><p>Mandelbulber can use OpenCL to accelerate rendering.<br/>For "
				 "more information about setup and workflow see the User Manual<br/>under Menu &gt; "
				 "Help &gt; User Manual.<br/></p><p><b>Warning:</b> The selected OpenCL device(s) do "
				 "not support FP64 (cl_khr_fp64), so double precision is disabled and renders will "
				 "use single precision.</p></body></html>"));
	}
	else
	{
		// Preserve the saved precision while OpenCL is disabled. It becomes
		// effective again when OpenCL is enabled.
		ui->comboBox_opencl_precision->setToolTip(
			tr("<p>Enable OpenCL to choose the kernel precision.</p>"));
		ui->label_explanation_opencl_missing_features->setText(
			tr("<html><head/><body><p>Mandelbulber can use OpenCL to accelerate rendering.<br/>For "
				 "more information about setup and workflow see the User Manual<br/>under Menu &gt; Help "
				 "&gt; User Manual.<br/></p></body></html>"));
	}
}

void cPreferencesDialog::on_comboBox_opencl_device_type_currentIndexChanged(int index)
{
	Q_UNUSED(index);
	on_listWidget_opencl_platform_list_currentRowChanged(
		ui->listWidget_opencl_platform_list->currentRow());
}

void cPreferencesDialog::UpdateOpenCLMemoryLimits()
{
	// TODO: support multi-GPU
	if (gOpenCl->openClHardware->getDevicesInformation().size() > 0
			&& gOpenCl->openClHardware->getSelectedDevicesInformation().size() > 0)
	{
		cOpenClDevice::sDeviceInformation deviceInformation =
			gOpenCl->openClHardware->getSelectedDevicesInformation().at(0);

		// TODO: Review here:
		for (auto i : gOpenCl->openClHardware->getSelectedDevicesInformation())
		{
			// Select device with lowest memory for symmetrical allocation limit
			if (i.globalMemSize < deviceInformation.globalMemSize) deviceInformation = i;
		}

		int globalMemSize = int(deviceInformation.globalMemSize / 1024 / 1024);
		int maxMemAllocSize = int(deviceInformation.maxMemAllocSize / 1024 / 1024);

		ui->spinboxInt_opencl_memory_limit->setMaximum(globalMemSize);
		ui->sliderInt_opencl_memory_limit->setMaximum(globalMemSize);
		ui->label_opencl_suggested_memory_limit->setText(
			tr("Suggested memory limit (based on CL_DEVICE_MAX_MEM_ALLOC_SIZE): %1 MB")
				.arg(maxMemAllocSize - 1));
	}
}

void cPreferencesDialog::on_pushButton_select_clang_format_path_clicked()
{
	QFileDialog dialog(this);
	dialog.setOption(QFileDialog::DontUseNativeDialog);
	dialog.setFileMode(QFileDialog::ExistingFile);
	dialog.setDirectory(
		QDir::toNativeSeparators(QFileInfo(ui->text_clang_format_path->text()).absolutePath()));
	dialog.setNameFilter(tr(
		"clang-format executable (clang-format.exe clang-format-*.exe clang-format-* clang-format)"));
	dialog.setAcceptMode(QFileDialog::AcceptOpen);
	dialog.setWindowTitle(
		tr("Select clang-format executable (exe on windows, program name on MacOS / Linux)..."));
	if (dialog.exec())
	{
		QStringList filenames = dialog.selectedFiles();
		const QString filename = QDir::toNativeSeparators(filenames.first());
		ui->text_clang_format_path->setText(filename);
	}
}

#endif
