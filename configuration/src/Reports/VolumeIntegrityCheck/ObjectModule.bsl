///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	FilesTableOnHardDrive = FilesOperationsInVolumesInternal.UnnecessaryFilesOnHardDrive();
	Settings = SettingsComposer.GetSettings();
	ParameterVolume = Settings.DataParameters.Items.Find("Volume");
	
	If ParameterVolume <> Undefined Then
		VolumePath = FilesOperationsInVolumesInternal.FullVolumePath(ParameterVolume.Value);
	EndIf;
	
	CheckedFiles = FindFiles(VolumePath, "*", True);
	For Each File In CheckedFiles Do
		If Not File.IsFile() Then 
			Continue;
		EndIf;
		NewRow = FilesTableOnHardDrive.Add();
		NewRow.Name = File.Name;
		NewRow.BaseName = File.BaseName;
		NewRow.FullName = File.FullName;
		NewRow.Path = File.Path;
		NewRow.Extension = File.Extension;
		NewRow.CheckStatus = "ExtraFileInTome";
		NewRow.Count = 1;
		NewRow.Volume = ParameterVolume.Value;
	EndDo;
	
	FilesOperationsInVolumesInternal.FillInExtraFiles(FilesTableOnHardDrive, ParameterVolume.Value);
	FilesTableOnHardDrive.Indexes.Add("CheckStatus");
	
	StandardProcessing = False;
		
	ExternalDataSets = New Structure;
	ExternalDataSets.Insert("VolumeCheckTable", FilesTableOnHardDrive);	
	TemplateComposer = New DataCompositionTemplateComposer;	
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, Settings, DetailsData);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData, True);
	
	ResultDocument.Clear();	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	OutputProcessor.Output(CompositionProcessor);
	
	SettingsComposer.UserSettings.AdditionalProperties.Insert("ReportIsBlank", FilesTableOnHardDrive.Count() = 0);
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	ReportSettings = SettingsComposer.GetSettings();
	Volume = ReportSettings.DataParameters.Items.Find("Volume").Value;
	
	If Not ValueIsFilled(Volume) Then
		Common.MessageToUser(
			NStr("en = 'Please fill the ""Volume"" parameter.';"), , );
		Cancel = True;
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf