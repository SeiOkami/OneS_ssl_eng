///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Variables

&AtClient
Var Attachable_Module;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	ClientID = Parameters.ClientID;
	UserScanSettings = FilesOperations.GetUserScanSettings(ClientID);
	FillPropertyValues(ThisObject, UserScanSettings);
			
	MethodOfConversionToPDF = ?(UseImageMagickToConvertToPDF, 1, 0);
		
	JPGFormat = Enums.ScannedImageFormats.JPG;
	TIFFormat = Enums.ScannedImageFormats.TIF;
	
	MultiPageTIFFormat = Enums.MultipageFileStorageFormats.TIF;
	
	Items.GroupJPGQuantity.Visible = (ScannedImageFormat = JPGFormat);
	Items.TIFFDeflation.Visible = (ScannedImageFormat = TIFFormat);
	
	Items.PathToConverterApplication.Enabled = UseImageMagickToConvertToPDF;
	
	SinglePageStorageFormatPrevious = SinglePageStorageFormat;
	
	InstallHints();
	
	Rescanning = Parameters.Rescanning;
	
	If Parameters.Rescanning Then
		Items.OK.Title = NStr("en = 'Scan';");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	RefreshStatus();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DeviceNameOnChange(Item)
	ReadScannerSettings();
EndProcedure

&AtClient
Procedure DeviceNameChoiceProcessing(Item, ValueSelected, StandardProcessing)
	If DeviceName = ValueSelected Then // If nothing has changed, do not do anything.
		StandardProcessing = False;
	EndIf;	
EndProcedure

&AtClient
Procedure ScannedImageFormatOnChange(Item)
	
	Items.GroupJPGQuantity.Visible = (ScannedImageFormat = JPGFormat);
	Items.TIFFDeflation.Visible = (ScannedImageFormat = TIFFormat);
	InstallHints();
	
EndProcedure

&AtClient
Procedure PathToConverterApplicationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not FilesOperationsInternalClient.FileSystemExtensionAttached1() Then
		Return;
	EndIf;
		
	OpenFileDialog = New FileDialog(FileDialogMode.Open);
	OpenFileDialog.FullFileName = PathToConverterApplication;
	Filter = NStr("en = 'Executable files (*.exe)|*.exe';");
	OpenFileDialog.Filter = Filter;
	OpenFileDialog.Multiselect = False;
	OpenFileDialog.Title = NStr("en = 'Select file to convert to PDF';");
	If OpenFileDialog.Choose() Then
		PathToConverterApplication = OpenFileDialog.FullFileName;
	EndIf;
	
EndProcedure

&AtClient
Procedure MethodOfConversionToPDFOnChange(Item)
	
	UseImageMagickToConvertToPDF = MethodOfConversionToPDF = 1;
	ProcessChangesUseImageMagick();
	
EndProcedure

&AtClient
Procedure JPGQualityOnChange(Item)
	Items.JPGQuality.Title = StrTemplate(NStr("en = 'Quality (%1)';"), JPGQuality);
EndProcedure

&AtClient
Procedure DeviceNameStartChoice(Item, StandardProcessing)
	StandardProcessing = False;
	Try
		DeviceArray = FilesOperationsInternalClient.EnumDevices(Attachable_Module);
	Except
		DeviceArray = New Array;
	EndTry;
	If DeviceArray.Count() > 0 Then
		ChoiceList = New ValueList();
		For Each String In DeviceArray Do
			ChoiceList.Add(String);
		EndDo;
	
		NotifyDescription = New NotifyDescription("DeviceNameStartChoiceCompletion", ThisObject, Item);
		ChoiceList.ShowChooseItem(NotifyDescription, NStr("en = 'Select scanner';"));
	Else
		ShowMessageBox(,NStr("en = 'No connected scanners are found. Check scanner connection.';"));
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	ClearMessages();
	If Not CheckFilling() Then 
		Return;
	EndIf;
		
	UserScanSettings = FilesOperationsClientServer.UserScanSettings();
	FillPropertyValues(UserScanSettings, ThisObject);
	
	If UserScanSettings.UseImageMagickToConvertToPDF Then
		If Not ValueIsFilled(UserScanSettings.PathToConverterApplication) Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Path to the %1 application is not specified.';"), 
			"ImageMagick");
			CommonClient.MessageToUser(ErrorText, , "PathToConverterApplication");
			Return;
		Else
			Context = New Structure;
			CheckResultHandler = New NotifyDescription("AfterCheckInstalledConversionApp", ThisObject, UserScanSettings);
			FilesOperationsClient.StartCheckConversionAppPresence(UserScanSettings.PathToConverterApplication, CheckResultHandler);
			Return;
		EndIf;
	EndIf;
	OKCompletion(UserScanSettings);
EndProcedure

&AtClient
Procedure CustomizeStandardSettings(Command)
	ReadScannerSettings();
EndProcedure

&AtClient
Procedure OpenScannedFilesNumbers(Command)
	OpenForm("InformationRegister.ScannedFilesNumbers.ListForm");
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure RefreshStatus()
	
	Items.JPGQuality.Title = StrTemplate(NStr("en = 'Quality (%1)';"), JPGQuality);
	Items.ScannedImageFormat.Enabled = False;
	Items.Resolution.Enabled = False;
	Items.Chromaticity.Enabled = False;
	Items.Rotation.Enabled = False;
	Items.PaperSize.Enabled = False;
	Items.DuplexScanning.Enabled = False;
	Items.CustomizeStandardSettings.Enabled = False;
	Items.ShouldSaveAsPDF.Enabled = False;
	Items.JPGQuality.Enabled = False;
	Items.TIFFDeflation.Enabled = False;
	Items.MultipageStorageFormat.Enabled = False;
	Items.MethodOfConversionToPDF.Enabled = False;
	Items.ShowScannerDialog.Enabled = False;
	
	NotifyDescription = New NotifyDescription("UpdateStateAfterInitialization", ThisObject);
	FilesOperationsInternalClient.InitAddIn(NotifyDescription, True);
EndProcedure

&AtClient
Procedure UpdateStateAfterInitialization(InitializationCheckResult, Context) Export
	IsAddInInitialized = InitializationCheckResult.Attached;
	
	If Not IsAddInInitialized Then
		Items.DeviceName.Enabled = False;
		Return;
	EndIf;
	Attachable_Module = InitializationCheckResult.Attachable_Module;
		
	If Not FilesOperationsInternalClient.IsReadyForScanning(Attachable_Module) Then
		Items.DeviceName.InputHint = NStr("en = 'Check scanner connection';");
		Return;
	Else
		Items.DeviceName.InputHint = "";
	EndIf;
		
	If IsBlankString(DeviceName) Then
		Return;
	EndIf;
	
	Items.ScannedImageFormat.Enabled = True;
	Items.Resolution.Enabled = True;
	Items.Chromaticity.Enabled = True;
	Items.CustomizeStandardSettings.Enabled = True;
	Items.ShouldSaveAsPDF.Enabled = True;
	Items.JPGQuality.Enabled = True;
	Items.TIFFDeflation.Enabled = True;
	Items.MultipageStorageFormat.Enabled = True;
	Items.MethodOfConversionToPDF.Enabled = True;
	Items.ShowScannerDialog.Enabled = True;
	
	DuplexScanningNumber = FilesOperationsInternalClient.GetSetting(Attachable_Module, 
		DeviceName, "DUPLEX");
		
	Items.DuplexScanning.Enabled = (DuplexScanningNumber <> -1);
	
	If Not Resolution.IsEmpty() And Not Chromaticity.IsEmpty() Then
		Items.Rotation.Enabled = Not Rotation.IsEmpty();
		Items.PaperSize.Enabled = Not PaperSize.IsEmpty();
		Return;
	EndIf;
	
	PermissionNumber = FilesOperationsInternalClient.GetSetting(Attachable_Module, DeviceName, "XRESOLUTION");
	ChromaticityNumber  = FilesOperationsInternalClient.GetSetting(Attachable_Module, DeviceName, "PIXELTYPE");
	RotationNumber = FilesOperationsInternalClient.GetSetting(Attachable_Module, DeviceName, "ROTATION");
	PaperSizeNumber  = FilesOperationsInternalClient.GetSetting(Attachable_Module, DeviceName, "SUPPORTEDSIZES");
	
	Items.Rotation.Enabled = (RotationNumber <> -1);
	Items.PaperSize.Enabled = (PaperSizeNumber <> -1);
	
	DuplexScanning = ? ((DuplexScanningNumber = 1), True, False);
	Modified = True;
	ConvertScannerParametersToEnums(PermissionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber);
	
EndProcedure

&AtClient
Procedure ReadScannerSettings()
	Modified = True;
	Items.DuplexScanning.Enabled = False;
	
	If IsBlankString(DeviceName) Then
		Items.Rotation.Enabled = False;
		Items.PaperSize.Enabled = False;
		Return;
	Else
		Items.ScannedImageFormat.Enabled = True;
		Items.Resolution.Enabled = True;
		Items.Chromaticity.Enabled = True;
		Items.CustomizeStandardSettings.Enabled = True;
		Items.ShouldSaveAsPDF.Enabled = True;
		Items.JPGQuality.Enabled = True;
		Items.TIFFDeflation.Enabled = True;
		Items.MultipageStorageFormat.Enabled = True;
		Items.MethodOfConversionToPDF.Enabled = True;
		Items.ShowScannerDialog.Enabled = True;
	EndIf;
	
	PermissionNumber = FilesOperationsInternalClient.GetSetting(Attachable_Module,
		DeviceName, "XRESOLUTION");
	
	ChromaticityNumber = FilesOperationsInternalClient.GetSetting(Attachable_Module,
		DeviceName, "PIXELTYPE");
	
	RotationNumber = FilesOperationsInternalClient.GetSetting(Attachable_Module,
		DeviceName, "ROTATION");
	
	PaperSizeNumber = FilesOperationsInternalClient.GetSetting(Attachable_Module,
		DeviceName, "SUPPORTEDSIZES");
	
	DuplexScanningNumber = FilesOperationsInternalClient.GetSetting(Attachable_Module,
		DeviceName, "DUPLEX");
	
	Items.Rotation.Enabled = (RotationNumber <> -1);
	Items.PaperSize.Enabled = (PaperSizeNumber <> -1);
	
	Items.DuplexScanning.Enabled = (DuplexScanningNumber <> -1);
	DuplexScanning = ? ((DuplexScanningNumber = 1), True, False);
	
	ConvertScannerParametersToEnums(
		PermissionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber);
		
EndProcedure

&AtServerNoContext
Procedure ConvertScannerParametersToEnums(PermissionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber) 
	
	Result = FilesOperationsInternal.ScannerParametersInEnumerations(PermissionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber);
	Resolution = Result.Resolution;
	Chromaticity = Result.Chromaticity;
	Rotation = Result.Rotation;
	PaperSize = Result.PaperSize;
	
EndProcedure

&AtClient
Procedure ProcessChangesUseImageMagick()
	
	Items.PathToConverterApplication.Enabled = UseImageMagickToConvertToPDF;
	
EndProcedure

&AtServer
Procedure InstallHints()
	
	FormatTooltip = "";
	ExtendedTooltip = String(Items.ShouldSaveAsPDF.ExtendedTooltip.Title); 
	Hints = StrSplit(ExtendedTooltip, Chars.LF);
	CurFormat = String(ScannedImageFormat);
	For Each ToolTip In Hints Do
		If StrStartsWith(ToolTip, CurFormat) Then
			 FormatTooltip = ToolTip;
		EndIf;
	EndDo;
	
	Items.SinglePageDocumentFormatDetails.Title = FormatTooltip;
	
EndProcedure

&AtClient
Procedure DeviceNameStartChoiceCompletion(SelectedElement, Item) Export
	If SelectedElement <> Undefined Then
		DeviceName = SelectedElement.Value;
		DeviceNameOnChange(Item);
	EndIf;
EndProcedure

&AtClient
Procedure OKCompletion(UserScanSettings)
	FilesOperationsClient.SaveUserScanSettings(UserScanSettings);
	Result = New Structure("Rescanning", Rescanning);
	Close(Result);
EndProcedure

&AtClient
Procedure AfterCheckInstalledConversionApp(RunResult, UserScanSettings) Export
	If StrFind(RunResult.OutputStream, "ImageMagick") <> 0 Then
		OKCompletion(UserScanSettings);
	Else
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Specified path to the %1 application is incorrect.';"), "ImageMagick"); 
		CommonClient.MessageToUser(MessageText, , "PathToConverterApplication");
	EndIf;
EndProcedure

#EndRegion
