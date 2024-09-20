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
	
	// Only users with full access rights can create and disable standalone workstations.
	If Not Users.IsFullUser() Then
		
		Raise NStr("en = 'Insufficient rights for standalone mode setup.';");
		
	ElsIf Not StandaloneModeInternal.StandaloneModeSupported() Then
		
		Raise NStr("en = 'Standalone mode is unavailable in the application.';");
		
	EndIf;
	
	UpdateStandaloneModeMonitorAtServer();
	
	BigFilesTransferSupported = StandaloneModeInternal.BigFilesTransferSupported();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AttachIdleHandler("UpdateStandaloneModeMonitor", 60);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If    EventName = "CreateStandaloneWorkstation"
		Or EventName = "Write_StandaloneWorkstation"
		Or EventName = "DeleteStandaloneWorkstation" Then
		
		UpdateStandaloneModeMonitor();
		
	ElsIf EventName = "DataExchangeResultFormClosed" Then
		
		UpdateSwitchToConflictsTitle();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CreateStandaloneWorkstation(Command)
	
	Notification = New NotifyDescription("CreateStandaloneWorkstationCompletion", ThisObject);
	
	If BigFilesTransferSupported Then
		FileSystemClient.AttachFileOperationsExtension(Notification, "", False);
	Else
		ExecuteNotifyProcessing(Notification, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure StopSynchronizationWithStandaloneWorkstation(Command)
	
	DisconnectStandaloneWorkstation(StandaloneWorkstation);
	
EndProcedure

&AtClient
Procedure StopSynchronizationWithStandaloneWorkstationInList(Command)
	
	CurrentData = Items.StandaloneWorkstationsList.CurrentData;
	
	If CurrentData <> Undefined Then
		
		DisconnectStandaloneWorkstation(CurrentData.StandaloneWorkstation);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeStandaloneWorkstation(Command)
	
	If StandaloneWorkstation <> Undefined Then
		
		ShowValue(, StandaloneWorkstation);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeStandaloneWorkstationInList(Command)
	
	CurrentData = Items.StandaloneWorkstationsList.CurrentData;
	
	If CurrentData <> Undefined Then
		
		ShowValue(, CurrentData.StandaloneWorkstation);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	UpdateStandaloneModeMonitor();
	
EndProcedure

&AtClient
Procedure StandaloneWorkstationsListSelection(Item, RowSelected, Field, StandardProcessing)
	
	ShowValue(, Items.StandaloneWorkstationsList.CurrentData.StandaloneWorkstation);
	
EndProcedure

&AtClient
Procedure HowToInstallOrUpdate1CEnterprisePlatfomVersion(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("TemplateName", "HowToInstallOrUpdate1CEnterprisePlatfomVersion");
	FormParameters.Insert("Title", NStr("en = 'How to install or update 1C:Enterprise platform';"));
	
	OpenForm("DataProcessor.StandaloneWorkstationCreationWizard.Form.AdditionalDetails", FormParameters, ThisObject, "HowToInstallOrUpdate1CEnterprisePlatfomVersion");
	
EndProcedure

&AtClient
Procedure HowToConfigureStandaloneWorkstation(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("TemplateName", "SWSetupInstruction");
	FormParameters.Insert("Title", NStr("en = 'How to set up a standalone workstation';"));
	
	OpenForm("DataProcessor.StandaloneWorkstationCreationWizard.Form.AdditionalDetails", FormParameters, ThisObject, "SWSetupInstruction");
	
EndProcedure

&AtClient
Procedure GoToConflicts(Command)
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("ExchangeNodes", UsedNodesArray(StandaloneWorkstation, StandaloneWorkstationsList));
	
	OpenForm("InformationRegister.DataExchangeResults.Form.Form", OpeningParameters);
	
EndProcedure

&AtClient
Procedure DataToSendComposition(Command)
	
	CurrentPage = Items.StandaloneMode.CurrentPage;
	StandaloneNode  = Undefined;
	
	If CurrentPage = Items.SingleStandaloneWorkstation Then
		StandaloneNode = StandaloneWorkstation;
		
	ElsIf CurrentPage = Items.MultipleStandaloneWorkstations Then
		CurrentData = Items.StandaloneWorkstationsList.CurrentData;
		If CurrentData <> Undefined Then
			StandaloneNode = CurrentData.StandaloneWorkstation;
		EndIf;
		
	EndIf;
		
	If ValueIsFilled(StandaloneNode) Then
		DataExchangeClient.OpenCompositionOfDataToSend(StandaloneNode);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure CreateStandaloneWorkstationCompletion(ExtensionAttached, AdditionalParameters) Export
	
	If ExtensionAttached Then
		OpenForm("DataProcessor.StandaloneWorkstationCreationWizard.Form.SetupSaaS", , ThisObject, "1");
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateStandaloneModeMonitorAtServer()
	
	SetPrivilegedMode(True);
	
	StandaloneWorkstationsCount = StandaloneModeInternal.StandaloneWorkstationsCount();
	UpdateSwitchToConflictsTitle();
	
	If StandaloneWorkstationsCount = 0 Then
		
		Items.StandaloneModeNotConfigured.Visible = True;
		
		Items.StandaloneMode.CurrentPage = Items.StandaloneModeNotConfigured;
		Items.SingleStandaloneWorkstation.Visible = False;
		Items.MultipleStandaloneWorkstations.Visible = False;
		
	ElsIf StandaloneWorkstationsCount = 1 Then
		
		Items.SingleStandaloneWorkstation.Visible = True;
		
		Items.StandaloneMode.CurrentPage = Items.SingleStandaloneWorkstation;
		Items.StandaloneModeNotConfigured.Visible = False;
		Items.MultipleStandaloneWorkstations.Visible = False;
		
		StandaloneWorkstation = StandaloneModeInternal.StandaloneWorkstation();
		StandaloneWorkstationsList.Clear();
		
		Items.LastSynchronizationInfo.Title = DataExchangeServer.SynchronizationDatePresentation(
			StandaloneModeInternal.LastSuccessfulSynchronizationDate(StandaloneWorkstation)) + ".";
		
		Items.DataTransferRestrictionsDetails.Title = StandaloneModeInternal.DataTransferRestrictionsDetails(StandaloneWorkstation);
		
	ElsIf StandaloneWorkstationsCount > 1 Then
		
		Items.MultipleStandaloneWorkstations.Visible = True;
		
		Items.StandaloneMode.CurrentPage = Items.MultipleStandaloneWorkstations;
		Items.StandaloneModeNotConfigured.Visible = False;
		Items.SingleStandaloneWorkstation.Visible = False;
		
		StandaloneWorkstation = Undefined;
		StandaloneWorkstationsList.Load(StandaloneModeInternal.StandaloneWorkstationsMonitor());
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateSwitchToConflictsTitle()
	
	If DataExchangeCached.VersioningUsed() Then
		
		UsedNodesArray = UsedNodesArray(StandaloneWorkstation, StandaloneWorkstationsList);
		TitleStructure = InformationRegisters.DataExchangeResults.TheNumberOfWarningsForTheFormElement(UsedNodesArray);
		
		FillPropertyValues (Items.GoToConflicts, TitleStructure);
		FillPropertyValues (Items.GoToConflicts1, TitleStructure);
		
	Else
		
		Items.GoToConflicts.Visible = False;
		Items.GoToConflicts1.Visible = False;
		
	EndIf;
	
EndProcedure

&AtClient
Function GetCurrentRowIndex()
	
	// Function return value.
	RowIndex = Undefined;
	
	// Positioning the mouse pointer upon the monitor update
	CurrentData = Items.StandaloneWorkstationsList.CurrentData;
	
	If CurrentData <> Undefined Then
		
		RowIndex = StandaloneWorkstationsList.IndexOf(CurrentData);
		
	EndIf;
	
	Return RowIndex;
EndFunction

&AtClient
Procedure ExecuteCursorPositioning(RowIndex)
	
	If RowIndex <> Undefined Then
		
		// Checking the mouse pointer position once new data is received
		If StandaloneWorkstationsList.Count() <> 0 Then
			
			If RowIndex > StandaloneWorkstationsList.Count() - 1 Then
				
				RowIndex = StandaloneWorkstationsList.Count() - 1;
				
			EndIf;
			
			// 
			Items.StandaloneWorkstationsList.CurrentRow = StandaloneWorkstationsList[RowIndex].GetID();
			
		EndIf;
		
	EndIf;
	
	// If setting the current row by TableName value failed, the first row is set as the current one
	If Items.StandaloneWorkstationsList.CurrentRow = Undefined
		And StandaloneWorkstationsList.Count() <> 0 Then
		
		Items.StandaloneWorkstationsList.CurrentRow = StandaloneWorkstationsList[0].GetID();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateStandaloneModeMonitor()
	
	RowIndex = GetCurrentRowIndex();
	
	UpdateStandaloneModeMonitorAtServer();
	
	// Positioning the mouse pointer.
	ExecuteCursorPositioning(RowIndex);
	
EndProcedure

&AtClientAtServerNoContext
Function UsedNodesArray(StandaloneWorkstation, StandaloneWorkstationsList)
	
	ExchangeNodes = New Array;
	
	If ValueIsFilled(StandaloneWorkstation) Then
		ExchangeNodes.Add(StandaloneWorkstation);
	Else
		For Each NodeRow In StandaloneWorkstationsList Do
			ExchangeNodes.Add(NodeRow.StandaloneWorkstation);
		EndDo;
	EndIf;
	
	Return ExchangeNodes;
	
EndFunction

&AtClient
Procedure DisconnectStandaloneWorkstation(StandaloneWorkstationToDisconnect)
	
	FormParameters = New Structure("StandaloneWorkstation", StandaloneWorkstationToDisconnect);
	
	OpenForm("CommonForm.StandaloneWorkstationDisconnection", FormParameters, ThisObject, StandaloneWorkstationToDisconnect);
	
EndProcedure

#EndRegion
