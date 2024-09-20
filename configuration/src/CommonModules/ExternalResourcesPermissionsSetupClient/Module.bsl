///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonClientOverridable.AfterStart.
Procedure AfterStart() Export
	
	ClientParametersOnStart = StandardSubsystemsClient.ClientParametersOnStart();
	If ClientParametersOnStart.DisplayPermissionSetupAssistant Then
		
		If ClientParametersOnStart.CheckExternalResourceUsagePermissionsApplication Then
			
			AfterCheckApplicabilityOfPermissionsToUseExternalResources(
				ClientParametersOnStart.PermissionsToUseExternalResourcesApplicabilityCheck);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// 
// 
//

// Starts external resource permissions setup wizard.
//
// Operation result is form opening
// "DataProcessor.ExternalResourcePermissionSetup.Form.PermissionsRequestInitialization", for which a procedure is set
// as closing notification details
// DataProcessorAfterInitializeRequestForPermissionsToUseExternalResources.
//
// Parameters:
//  IDs - Array of UUID - IDs (UUID) of requests to use external resources,
//                  for which the wizard is called.
//  OwnerForm - ClientApplicationForm
//                - Undefined - 
//  ClosingNotification1 - NotifyDescription, Undefined - details of a notification that must be
//                        processed after closing the wizard.
//  EnablingMode - Boolean - indicates that the wizard is called upon enabling usage for the security profile
//                            infobase.
//  DisablingMode - Boolean - indicates that the wizard is called upon disabling usage for the security profile
//                             infobase.
//  RecoveryMode - Boolean - indicates that the wizard is called to restore settings of security profiles in
//                                 the server cluster (according to the current infobase data).
//
Procedure StartInitializingRequestForPermissionsToUseExternalResources(
		Val IDs,
		Val OwnerForm,
		Val ClosingNotification1,
		Val EnablingMode = False,
		Val DisablingMode = False,
		Val RecoveryMode = False) Export
	
	If EnablingMode Or SafeModeManagerClient.DisplayPermissionSetupAssistant() Then
		
		State = RequestForPermissionsToUseExternalResourcesState();
		State.RequestsIDs = IDs;
		State.NotifyDescription = ClosingNotification1;
		State.OwnerForm = OwnerForm;
		State.EnablingMode = EnablingMode;
		State.DisablingMode = DisablingMode;
		State.RecoveryMode = RecoveryMode;
		
		FormParameters = New Structure();
		FormParameters.Insert("IDs", IDs);
		FormParameters.Insert("EnablingMode", State.EnablingMode);
		FormParameters.Insert("DisablingMode", State.DisablingMode);
		FormParameters.Insert("RecoveryMode", State.RecoveryMode);
		
		NotifyDescription = New NotifyDescription(
			"AfterInitializeRequestForPermissionsToUseExternalResources",
			ExternalResourcesPermissionsSetupClient,
			State);
		
		OpenForm(
			"DataProcessor.ExternalResourcesPermissionsSetup.Form.PermissionsRequestInitialization",
			FormParameters,
			OwnerForm,
			,
			,
			,
			NotifyDescription,
			FormWindowOpeningMode.LockWholeInterface);
		
	Else
		
		ExecuteNotifyProcessing(ClosingNotification1, DialogReturnCode.OK);
		
	EndIf;
	
EndProcedure

// Starts the security profile permission setup dialog.
// Operation result is form opening:
// "DataProcessor.ExternalResourcePermissionSetup.Form.ExternalResourcePermissionSetup", 
// for which a procedure is set as closing notification details
// AfterSetUpPermissionsToUseExternalResources or abnormal wizard termination.
//
// Parameters:
//  Result - DialogReturnCode - a result of executing a previous operation of
//                                   external resource permissions application wizard (used values are OK and Cancel),
//  State - See RequestForPermissionsToUseExternalResourcesState
//
//
Procedure AfterInitializeRequestForPermissionsToUseExternalResources(Result, State) Export
	
	If TypeOf(Result) = Type("Structure") And Result.ReturnCode = DialogReturnCode.OK Then
		
		InitializationState = GetFromTempStorage(Result.StateStorageAddress);
		
		If InitializationState.PermissionApplicationRequired Then
			
			State.StorageAddress = InitializationState.StorageAddress;
			
			FormParameters = New Structure();
			FormParameters.Insert("StorageAddress", State.StorageAddress);
			FormParameters.Insert("RecoveryMode", State.RecoveryMode);
			FormParameters.Insert("CheckMode", State.CheckMode);
			
			NotifyDescription = New NotifyDescription(
				"AfterSetUpPermissionsToUseExternalResources",
				ExternalResourcesPermissionsSetupClient,
				State);
			
			OpenForm(
				"DataProcessor.ExternalResourcesPermissionsSetup.Form.ExternalResourcesPermissionsSetup",
				FormParameters,
				State.OwnerForm,
				,
				,
				,
				NotifyDescription,
				FormWindowOpeningMode.LockWholeInterface);
			
		Else
			
			// 
			// 
			CompleteSetUpPermissionsToUseExternalResourcesAsynchronously(State.NotifyDescription);
			
		EndIf;
		
	Else
		
		ExternalResourcesPermissionsSetupServerCall.CancelApplyRequestsToUseExternalResources(
			State.RequestsIDs);
		CancelSetUpPermissionsToUseExternalResourcesAsynchronously(State.NotifyDescription);
		
	EndIf;
	
EndProcedure

// Starts the dialog of waiting for server cluster security profile settings to be applied.
// Operation result is form opening:
// "DataProcessor.ExternalResourcePermissionSetup.PermissionsRequestEnd", for which a procedure is set
// as a closing notification details
// AfterCompleteRequestForPermissionsToUseExternalResources or abnormal wizard termination.
//
// Parameters:
//  Result - DialogReturnCode - a result of executing a previous operation of
//                                   external resource permissions application wizard (used values are OK, Skip, and Cancel).
//                                   Ignore value is used if no changes were made to the
//                                   security profile settings but requests to use external resources
//                                   must be considered applied (for example, if permissions to use
//                                   all external resources being requested have already been granted),
//  State - See RequestForPermissionsToUseExternalResourcesState
//
Procedure AfterSetUpPermissionsToUseExternalResources(Result, State) Export
	
	If Result = DialogReturnCode.OK Or Result = DialogReturnCode.Ignore Then
		
		PlanPermissionApplyingCheckAfterOwnerFormClose(
			State.OwnerForm,
			State.RequestsIDs);
		
		FormParameters = New Structure();
		FormParameters.Insert("StorageAddress", State.StorageAddress);
		FormParameters.Insert("RecoveryMode", State.RecoveryMode);
		
		If Result = DialogReturnCode.OK Then
			FormParameters.Insert("Duration", ChangeApplyingTimeout());
		Else
			FormParameters.Insert("Duration", 0);
		EndIf;
		
		NotifyDescription = New NotifyDescription(
			"AfterCompleteRequestForPermissionsToUseExternalResources",
			ExternalResourcesPermissionsSetupClient,
			State);
		
		OpenForm(
			"DataProcessor.ExternalResourcesPermissionsSetup.Form.PermissionsRequestEnd",
			FormParameters,
			ThisObject,
			,
			,
			,
			NotifyDescription,
			FormWindowOpeningMode.LockWholeInterface);
		
	Else
		
		ExternalResourcesPermissionsSetupServerCall.CancelApplyRequestsToUseExternalResources(
			State.RequestsIDs);
		CancelSetUpPermissionsToUseExternalResourcesAsynchronously(State.NotifyDescription);
		
	EndIf;
	
EndProcedure

// Processes the data entered to the external resource permission application wizard.
// The operation result is processing of the notification description, which was initially passed from the form for which
// the the wizard was opened.
//
// Parameters:
//  Result - DialogReturnCode - a result of executing a previous operation of
//                                   external resource permissions application wizard (used values are OK and Cancel),
//  State - See RequestForPermissionsToUseExternalResourcesState.
//
Procedure AfterCompleteRequestForPermissionsToUseExternalResources(Result, State) Export
	
	If Result = DialogReturnCode.OK Then
		
		ShowUserNotification(NStr("en = 'Permission settings';"),,
			NStr("en = 'Security profile settings are changed in the server cluster.';"));
		
		CompleteSetUpPermissionsToUseExternalResourcesAsynchronously(State.NotifyDescription);
		
	Else
		
		ExternalResourcesPermissionsSetupServerCall.CancelApplyRequestsToUseExternalResources(
			State.RequestsIDs);
		CancelSetUpPermissionsToUseExternalResourcesAsynchronously(State.NotifyDescription);
		
	EndIf;
	
EndProcedure

// Asynchronously (relative to the code, from which the wizard was called) processes the notification details
// that were initially passed from the form, for which the wizard was opened returning the return code OK.
//
// Parameters:
//  NotifyDescription - NotifyDescription - Description passed from the calling code.
//
Procedure CompleteSetUpPermissionsToUseExternalResourcesAsynchronously(Val NotifyDescription)
	
	ParameterName = "StandardSubsystems.NotificationOnApplyExternalResourceRequest";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	ApplicationParameters[ParameterName] = NotifyDescription;
	
	AttachIdleHandler("FinishExternalResourcePermissionSetup", 0.1, True);
	
EndProcedure

// Asynchronously (relative to the code, from which the wizard was called) processes the notification details
// that were initially passed from the form, for which the wizard was opened returning the return code Cancel.
//
// Parameters:
//  NotifyDescription - NotifyDescription - Description passed from the calling code.
//
Procedure CancelSetUpPermissionsToUseExternalResourcesAsynchronously(Val NotifyDescription)
	
	ParameterName = "StandardSubsystems.NotificationOnApplyExternalResourceRequest";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	ApplicationParameters[ParameterName] = NotifyDescription;
	
	AttachIdleHandler("CancelExternalResourcePermissionSetup", 0.1, True);
	
EndProcedure

// Synchronously (relative to the code, from which the wizard was called) processes the notification details
// that were initially passed from the form, for which the wizard was opened.
//
// Parameters:
//  ReturnCode - DialogReturnCode
//
Procedure CompleteSetUpPermissionsToUseExternalResourcesSynchronously(Val ReturnCode) Export
	
	ClosingNotification1 = ApplicationParameters["StandardSubsystems.NotificationOnApplyExternalResourceRequest"];
	ApplicationParameters["StandardSubsystems.NotificationOnApplyExternalResourceRequest"] = Undefined;
	If ClosingNotification1 <> Undefined Then
		ExecuteNotifyProcessing(ClosingNotification1, ReturnCode);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 
// 
// 
//

// Starts the wizard in operation completion check mode. In this mode, the wizard checks whether the operation whence requests for
// permissions to use external resources were applied is completed.
//
// The result of the procedure is a startup of the
// external resource permissions setup wizard in operation completion check mode.
// Once the wizard is closed, the
// PermissionApplyingAfterCheckAfterOwnerFormClose() procedure
// is used for processing the notification description.
//
// Parameters:
//  Result - Arbitrary - a result of closing the form, for which 
//                             external resource permissions setup wizard was opened. Does not used in the procedure body, the parameter is required
//                             for defining a form closing notification description procedure.
//  State - See PermissionsApplicabilityCheckStateAfterCloseOwnerForm.
//
Procedure CheckPermissionsAppliedAfterOwnerFormClose(Result, State) Export
	
	OriginalOnCloseNotifyDescription = State.NotifyDescription;
	If OriginalOnCloseNotifyDescription <> Undefined Then
		ExecuteNotifyProcessing(OriginalOnCloseNotifyDescription, Result);
	EndIf;
	
	Validation = ExternalResourcesPermissionsSetupServerCall.CheckApplyPermissionsToUseExternalResources();
	AfterCheckApplicabilityOfPermissionsToUseExternalResources(Validation);
	
EndProcedure

// Checks whether requests to use external resources were applied.
//
// Parameters:
//  Validation - See ExternalResourcesPermissionsSetupServerCall.CheckApplyPermissionsToUseExternalResources.
//
Procedure AfterCheckApplicabilityOfPermissionsToUseExternalResources(Val Validation)
	
	If Not Validation.CheckResult Then
		
		ApplyingState = RequestForPermissionsToUseExternalResourcesState();
		
		ApplyingState.RequestsIDs = Validation.RequestsIDs;
		ApplyingState.StorageAddress = Validation.StateTemporaryStorageAddress;
		ApplyingState.CheckMode = True;
		
		Result = New Structure();
		Result.Insert("ReturnCode", DialogReturnCode.OK);
		Result.Insert("StateStorageAddress", Validation.StateTemporaryStorageAddress);
		
		AfterInitializeRequestForPermissionsToUseExternalResources(
			Result, ApplyingState);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 
// 
//

// Calls the external resource permissions setup wizard in infobase security profile enabling
// mode.
//
// Parameters:
//  OwnerForm - ClientApplicationForm - Form that must be locked before permissions are applied.
//  ClosingNotification1 - NotifyDescription - it will be called once permissions are granted.
//
Procedure StartEnablingSecurityProfilesUsage(OwnerForm, ClosingNotification1 = Undefined) Export
	
	StartInitializingRequestForPermissionsToUseExternalResources(
		New Array(), OwnerForm, ClosingNotification1, True, False, False);
	
EndProcedure

// Calls the external resource permissions setup wizard in infobase security profile disabling
// mode.
//
// Parameters:
//  OwnerForm - ClientApplicationForm - Form that must be locked before permissions are applied.
//  ClosingNotification1 - NotifyDescription - it will be called once permissions are granted.
//
Procedure StartDisablingSecurityProfilesUsage(OwnerForm, ClosingNotification1 = Undefined) Export
	
	StartInitializingRequestForPermissionsToUseExternalResources(
		New Array(), OwnerForm, ClosingNotification1, False, True, False);
	
EndProcedure

// Calls the external resource permissions setup wizard in server cluster security profile settings recovery
// mode based on the current
// infobase state.
//
// Parameters:
//  OwnerForm - ClientApplicationForm - Form that must be locked before permissions are applied.
//  ClosingNotification1 - NotifyDescription - it will be called once permissions are granted.
//
Procedure StartRestoringSecurityProfiles(OwnerForm, ClosingNotification1 = Undefined) Export
	
	StartInitializingRequestForPermissionsToUseExternalResources(
		New Array(), OwnerForm, ClosingNotification1, False, False, True);
	
EndProcedure

// Creates a structure used for storing the
// external resource permissions setup wizard state.
//
// Returns: 
//   Structure - 
//
Function RequestForPermissionsToUseExternalResourcesState()
	
	Result = New Structure();
	
	// 
	Result.Insert("RequestsIDs", New Array());
	
	// 
	// 
	Result.Insert("NotifyDescription", Undefined);
	
	// 
	Result.Insert("StorageAddress", "");
	
	// Form, из которой первоначально было инициализировано применение запросов на использование
	// 
	Result.Insert("OwnerForm");
	
	// Режим включения - 
	Result.Insert("EnablingMode", False);
	
	// Режим отключения - 
	Result.Insert("DisablingMode", False);
	
	// Режим восстановления - 
	// 
	// 
	Result.Insert("RecoveryMode", False);
	
	// Режим проверки - 
	// 
	// 
	Result.Insert("CheckMode", False);
	
	Return Result;
	
EndFunction

// Creates a structure used for storing a state of check for completion
// of the operation where the requests for permissions to use external resources were applied.
//
// Returns: 
//   Structure - 
//
Function PermissionsApplicabilityCheckStateAfterCloseOwnerForm()
	
	Result = New Structure();
	
	// 
	Result.Insert("StorageAddress", Undefined);
	
	// Оригинальное описание оповещения формы-
	// 
	Result.Insert("NotifyDescription", Undefined);
	
	Return Result;
	
EndFunction

// Returns the duration of waiting for changes
// in server cluster security profile settings to be applied.
//
// Returns:
//   Number - 
//
Function ChangeApplyingTimeout()
	
	Return 20; // Interval that rphost uses to update the current security profile settings from rmngr.
	
EndFunction

// Plans (by substituting a value to OnCloseNotifyDescription form property) a wizard call
// to check whether the action is complete when the form that called the master is closed.
//
// As a result, the
// PermissionsApplicabilityCheckAfterOwnerFormClose procedure is called after closing the form, for which 
// external resource permissions setup wizard was opened.
//
// Parameters:
//  OwnerForm - ClientApplicationForm, Undefined - when this form is closed, the procedure will
//    check completion of operations that included requests for permissions to use
//    external resources.
//  RequestsIDs - Array of UUID - IDs (UUID) of requests for permissions to
//    use external resources applied within the operation, the completion of which is being checked.
//
Procedure PlanPermissionApplyingCheckAfterOwnerFormClose(FormOwner, RequestsIDs)
	
	If TypeOf(FormOwner) = Type("ClientApplicationForm") Then
		
		InitialNotifyDescription = FormOwner.OnCloseNotifyDescription;
		If InitialNotifyDescription <> Undefined Then
			
			If InitialNotifyDescription.Module = ExternalResourcesPermissionsSetupClient
					And InitialNotifyDescription.ProcedureName = "CheckPermissionsAppliedAfterOwnerFormClose" Then
				Return;
			EndIf;
			
		EndIf;
		
		State = PermissionsApplicabilityCheckStateAfterCloseOwnerForm();
		State.NotifyDescription = InitialNotifyDescription;
		
		PermissionsApplicabilityCheckNotifyDescription = New NotifyDescription(
			"CheckPermissionsAppliedAfterOwnerFormClose",
			ExternalResourcesPermissionsSetupClient,
			State);
		
		FormOwner.OnCloseNotifyDescription = PermissionsApplicabilityCheckNotifyDescription;
		
	EndIf;
	
EndProcedure

#EndRegion