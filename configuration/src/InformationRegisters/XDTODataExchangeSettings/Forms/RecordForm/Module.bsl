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
	
	RecordManager = InformationRegisters.XDTODataExchangeSettings.CreateRecordManager();
	FillPropertyValues(RecordManager, Record.SourceRecordKey);
	RecordManager.Read();
	
	SettingsSupportedObjects = InformationRegisters.XDTODataExchangeSettings.SettingValue(
		RecordManager.InfobaseNode, "SupportedObjects");
		
	If Not SettingsSupportedObjects = Undefined Then
		SupportedObjects.Load(SettingsSupportedObjects);
	EndIf;
	
	CorrespondentSettingsSupportedObjects = InformationRegisters.XDTODataExchangeSettings.CorrespondentSettingValue(
		RecordManager.InfobaseNode, "SupportedObjects");
	
	If Not CorrespondentSettingsSupportedObjects = Undefined Then
		SupportedCorrespondentObjects.Load(CorrespondentSettingsSupportedObjects);
	EndIf;
	
EndProcedure

#EndRegion
