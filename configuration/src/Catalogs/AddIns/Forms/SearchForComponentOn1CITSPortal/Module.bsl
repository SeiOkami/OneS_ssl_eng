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
	
	If IsBlankString(Parameters.ExplanationText) Then
		ExplanationText = AddInsInternal.AddInPresentation(Parameters.Id, Parameters.Version);
	Else 
		ExplanationText = Parameters.ExplanationText;
	EndIf;
	
	Items.DecorationNote.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1
		           |
		           |The add-in is not imported to the application.
		           |Do you want to import it?';"),
		ExplanationText);
	
	PortalAuthenticationDataSaved = PortalAuthenticationDataSaved();
	CanImportFromPortal = AddInsInternal.CanImportFromPortal();
	
	Items.EnableOnlineSupport.Visible = Not PortalAuthenticationDataSaved;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not CanImportFromPortal Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure EnableOnlineSupport(Command = Undefined)
	
	If CommonClient.SubsystemExists("OnlineUserSupport") Then
		ModuleOnlineUserSupportClient = CommonClient.CommonModule("OnlineUserSupportClient");
		Notification = New NotifyDescription("AfterEnableOnlineSupport", ThisObject);
		ModuleOnlineUserSupportClient.EnableInternetUserSupport(Notification, ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure Load(Command)
	
	If Not PortalAuthenticationDataSaved Then 
		EnableOnlineSupport();
		Return;
	EndIf;
	
	Items.Load.Enabled = False;
	Items.Pages.CurrentPage = Items.TimeConsumingOperation;
	
	TimeConsumingOperation = StartGettingAddInFromPortal(Parameters.Id, Parameters.Version, Parameters.AutoUpdate);
	
	If TimeConsumingOperation = Undefined Then 
		BriefErrorDescription = NStr("en = 'Cannot create a background job for add-in update.';");
		Items.Pages.CurrentPage = Items.Error;
	EndIf;
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OwnerForm = ThisObject;
	IdleParameters.OutputIdleWindow = False;
	
	Notification = New NotifyDescription("AfterGetAddInFromPortal", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, Notification, IdleParameters);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AfterEnableOnlineSupport(Result, Parameter) Export
	
	If TypeOf(Result) = Type("Structure") Then
		Items.EnableOnlineSupport.Visible = False;
		PortalAuthenticationDataSaved = True;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function PortalAuthenticationDataSaved()
	
	If Common.SubsystemExists("OnlineUserSupport") Then
		ModuleOnlineUserSupport = Common.CommonModule("OnlineUserSupport");
		Return ModuleOnlineUserSupport.AuthenticationDataOfOnlineSupportUserFilled();
	EndIf;
	
	Return False;
	
EndFunction

&AtServer
Function StartGettingAddInFromPortal(Id, Version, AutoUpdate)
	
	If Not AddInsInternal.CanImportFromPortal() Then
		Return Undefined;
	EndIf;
	
	ProcedureParameters = AddInsInternal.ComponentParametersFromThePortal();
	ProcedureParameters.Id = Id;
	ProcedureParameters.Version = Version;
	ProcedureParameters.AutoUpdate = AutoUpdate;
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Getting add-in.';");
	
	Return TimeConsumingOperations.ExecuteInBackground("AddInsInternal.NewAddInsFromPortal",
		ProcedureParameters, ExecutionParameters);
	
EndFunction

&AtClient
Procedure AfterGetAddInFromPortal(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		BriefErrorDescription = Result.BriefErrorDescription;
		Items.Pages.CurrentPage = Items.Error;
	EndIf;
	
	If Result.Status = "Completed2" Then 
		Close(True);
	EndIf;
	
EndProcedure

#EndRegion