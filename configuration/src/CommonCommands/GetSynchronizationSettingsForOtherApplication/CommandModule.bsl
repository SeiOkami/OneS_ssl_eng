///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Cancel = False;
	
	TempStorageAddress = "";
	
	GetSecondInfobaseDataExchangeSettingsAtServer(Cancel, TempStorageAddress, CommandParameter);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en = 'Cannot get data exchange settings.';"));
		
	Else
		
		SavingParameters = FileSystemClient.FileSavingParameters();
		SavingParameters.Dialog.Filter = "Files XML (*.xml)|*.xml";

		FileSystemClient.SaveFile(
			Undefined,
			TempStorageAddress,
			NStr("en = 'Synchronization settings.xml';"),
			SavingParameters);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure GetSecondInfobaseDataExchangeSettingsAtServer(Cancel, TempStorageAddress, InfobaseNode)
	
	DataExchangeCreationWizard = DataExchangeServer.ModuleDataExchangeCreationWizard().Create();
	DataExchangeCreationWizard.Initialization(InfobaseNode);
	DataExchangeCreationWizard.ExportWizardParametersToTempStorage(Cancel, TempStorageAddress);
	
EndProcedure

#EndRegion
