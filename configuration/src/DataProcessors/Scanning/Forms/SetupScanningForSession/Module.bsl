///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Resolution = Parameters.Resolution;
	Chromaticity = Parameters.Chromaticity;
	Rotation = Parameters.Rotation;
	PaperSize = Parameters.PaperSize;
	DuplexScanning = Parameters.DuplexScanning;
	UseImageMagickToConvertToPDF = Parameters.UseImageMagickToConvertToPDF;
	ShowScannerDialog = Parameters.ShowScannerDialog;
	ScannedImageFormat = Parameters.ScannedImageFormat;
	JPGQuality = Parameters.JPGQuality;
	TIFFDeflation = Parameters.TIFFDeflation;
	ShouldSaveAsPDF = Parameters.ShouldSaveAsPDF;
	MultipageStorageFormat = Parameters.MultipageStorageFormat;
	
	Items.Rotation.Visible = Parameters.RotationAvailable;
	Items.PaperSize.Visible = Parameters.PaperSizeAvailable;
	Items.DuplexScanning.Visible = Parameters.DuplexScanningAvailable;
	
	JPGFormat = Enums.ScannedImageFormats.JPG;
	TIFFormat = Enums.ScannedImageFormats.TIF;
	
	MultiPageTIFFormat = Enums.MultipageFileStorageFormats.TIF;
	
	If Not UseImageMagickToConvertToPDF Then
		MultipageStorageFormat = MultiPageTIFFormat;
	EndIf;
	
	Items.JPGQuality.Visible = (ScannedImageFormat = JPGFormat);
	Items.TIFFDeflation.Visible = (ScannedImageFormat = TIFFormat);
	
	Items.MultipageStorageFormat.Enabled = UseImageMagickToConvertToPDF;
	Items.JPGQuality.Title = StrTemplate(NStr("en = 'Quality (%1)';"), JPGQuality);
	InstallHints();
	
EndProcedure

&AtClient
Procedure JPGQualityOnChange(Item)
	Items.JPGQuality.Title = StrTemplate(NStr("en = 'Quality (%1)';"), JPGQuality);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ScannedImageFormatOnChange(Item)
	
	Items.GroupJPGQuantity.Visible = (ScannedImageFormat = JPGFormat);
	Items.TIFFDeflation.Visible = (ScannedImageFormat = TIFFormat);
	InstallHints();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	ClearMessages();
	If Not CheckFilling() Then 
		Return;
	EndIf;
	
	SelectionResult = New Structure;
	SelectionResult.Insert("ShowScannerDialog",  ShowScannerDialog);
	SelectionResult.Insert("Resolution",               Resolution);
	SelectionResult.Insert("Chromaticity",                Chromaticity);
	SelectionResult.Insert("Rotation",                  Rotation);
	SelectionResult.Insert("PaperSize",             PaperSize);
	SelectionResult.Insert("DuplexScanning", DuplexScanning);
	
	SelectionResult.Insert("UseImageMagickToConvertToPDF",
		UseImageMagickToConvertToPDF);
	
	SelectionResult.Insert("ScannedImageFormat", ScannedImageFormat);
	SelectionResult.Insert("JPGQuality",                     JPGQuality);
	SelectionResult.Insert("TIFFDeflation",                      TIFFDeflation);
	SelectionResult.Insert("ShouldSaveAsPDF",                   ShouldSaveAsPDF);
	SelectionResult.Insert("MultipageStorageFormat",   MultipageStorageFormat);
	
	SinglePageStorageFormat = ConvertScanningFormatToStorageFormat(ScannedImageFormat, ShouldSaveAsPDF);
	SelectionResult.Insert("SinglePageStorageFormat",    SinglePageStorageFormat);
	
	NotifyChoice(SelectionResult);
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function ConvertScanningFormatToStorageFormat(ScanningFormat, ShouldSaveAsPDF)
	
	Return FilesOperationsInternal.ConvertScanningFormatToStorageFormat(ScanningFormat, ShouldSaveAsPDF); 
	
EndFunction

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

#EndRegion
