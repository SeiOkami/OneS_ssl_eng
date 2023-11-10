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

	If TypeOf(Parameters.AddInsToUpdate) <> Type("Array") Or Parameters.AddInsToUpdate.Count() = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Form ""%2"" has invalid value in parameter ""%1"".';"), 
			"AddInsToUpdate", "ComponentsUpdateFrom1CITSPortal");
	EndIf;

	PortalAuthenticationDataSaved = PortalAuthenticationDataSaved();
	CanImportFromPortal = AddInsInternal.CanImportFromPortal();

	ExplanationText = "";
	PromptToUpdate = False;
	TheUpdatedComponentsParameter = Parameters.AddInsToUpdate; // Array of CatalogRef.AddIns
	AddInsAttributes = Common.ObjectsAttributesValues(TheUpdatedComponentsParameter,
		"Id, Version, UpdateFrom1CITSPortal");
	For Each AddInToUpdate In TheUpdatedComponentsParameter Do
		Attributes = AddInsAttributes[AddInToUpdate];
		ExplanationText = ExplanationText + AddInsInternal.AddInPresentation(Attributes.Id,
			Attributes.Version) + ?(Attributes.UpdateFrom1CITSPortal, "", " - " + NStr("en = 'Update disabled';")
			+ ".") + Chars.LF;

		PromptToUpdate = PromptToUpdate Or Attributes.UpdateFrom1CITSPortal;
		If Attributes.UpdateFrom1CITSPortal Then
			AddInsToUpdate.Add(AddInToUpdate);
		EndIf;
	EndDo;

	If PromptToUpdate Then

		Items.DecorationNote.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1
				 |Do you want to check for add-in updates and import them?';"), ExplanationText);

		Items.EnableOnlineSupport.Visible = Not PortalAuthenticationDataSaved;
		Items.Close.Visible = False;

	Else
		Items.DecorationNote.Title = ExplanationText;
		Items.EnableOnlineSupport.Visible = False;
		Items.Load.Visible = False;
		Items.Cancel.Visible = False;
		Items.Close.Visible = True;
	EndIf;

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
		ModuleOnlineUserSupportClient = CommonClient.CommonModule(
			"OnlineUserSupportClient");
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

	TimeConsumingOperation = StartUpdatingTheComponentsFromThePortal();

	If TimeConsumingOperation = Undefined Then
		BriefErrorDescription = NStr("en = 'Cannot create a background job for add-in update.';");
		Items.Pages.CurrentPage = Items.Error;
	EndIf;

	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OwnerForm = ThisObject;
	IdleParameters.OutputIdleWindow = False;

	Notification = New NotifyDescription("AfterUpdateAddInsFromPortal", ThisObject);
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
Function StartUpdatingTheComponentsFromThePortal()

	If Not AddInsInternal.CanImportFromPortal() Then
		Return Undefined;
	EndIf;

	ProcedureParameters = AddInsInternal.ParametersForUpdatingAComponentFromThePortal();
	ProcedureParameters.AddInsToUpdate = AddInsToUpdate.UnloadValues();

	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Updating add-in.';");

	Return TimeConsumingOperations.ExecuteInBackground("AddInsInternal.UpdateAddInsFromPortal",
		ProcedureParameters, ExecutionParameters);

EndFunction

&AtClient
Procedure AfterUpdateAddInsFromPortal(Result, AdditionalParameters) Export

	If Result = Undefined Then
		Return;
	EndIf;

	If Result.Status = "Error" Then
		BriefErrorDescription = Result.BriefErrorDescription;
		Items.Pages.CurrentPage = Items.Error;
	EndIf;

	If Result.Status = "Completed2" Then
		
		UpdateResult = GetFromTempStorage(Result.ResultAddress);
		
		ExecutionResult = "";
		For Each KeyAndValue In UpdateResult.Errors Do
			ExecutionResult = ExecutionResult + KeyAndValue.Value + Chars.LF;
		EndDo;
		For Each KeyAndValue In UpdateResult.Success Do
			ExecutionResult = ExecutionResult + KeyAndValue.Value + Chars.LF;
		EndDo;
		
		Items.Pages.CurrentPage = Items.Completed2;
		Items.Load.Visible = False;
		Items.Cancel.Visible = False;
		Items.Close.Visible = True;
	EndIf;

EndProcedure

#EndRegion