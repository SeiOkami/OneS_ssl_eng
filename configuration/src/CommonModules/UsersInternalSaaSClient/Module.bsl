///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// Opens the service user password input form.
//
// Parameters:
//  ContinuationHandler      - NotifyDescription - to be processed after the password is entered.
//  OwnerForm             - ClientApplicationForm - that requests the password.
//  ServiceUserPassword - String - a current SaaS user password.
//
Procedure RequestPasswordForAuthenticationInService(ContinuationHandler, OwnerForm, ServiceUserPassword) Export
	
	Context = New Structure;
	Context.Insert("ContinuationHandler", ContinuationHandler);
	Context.Insert("OwnerForm", OwnerForm);
	Context.Insert("ServiceUserPassword", ServiceUserPassword);
	
	If ServiceUserPassword = Undefined Then
		Notification = New NotifyDescription("AfterAuthenticationPasswordRequestInService", ThisObject, Context);
		OpenForm("CommonForm.AuthenticationInService", , OwnerForm, , , , Notification);
	Else
		AfterAuthenticationPasswordRequestInService(ServiceUserPassword, Context)
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure AfterAuthenticationPasswordRequestInService(ServiceUserPassword, Context) Export
	
	Context.ServiceUserPassword = ServiceUserPassword;
	
	Notification = New NotifyDescription(
		"AfterAuthenticationPasswordRequestInServiceFollowUp", ThisObject, Context);
	
	StandardSubsystemsClient.StartProcessingNotification(Notification);
	
EndProcedure

Procedure AfterAuthenticationPasswordRequestInServiceFollowUp(Result, Context) Export

	ErrorText = "";
	Try
		ExecuteNotifyProcessing(Context.ContinuationHandler, Context.ServiceUserPassword);
	Except
		ErrorInfo = ErrorInfo();
		UsersInternalSaaSServerCall.WriteTheErrorToTheLog(
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
		ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo) + Chars.LF
			+ NStr("en = 'Password may be incorrect. Retype the password.';");
	EndTry;
	
	If ValueIsFilled(ErrorText) Then
		Notification = New NotifyDescription("AfterRequestAuthenticationPasswordInServiceAndErrorWarning", ThisObject, Context);
		ShowMessageBox(Notification, ErrorText);
	EndIf;
	
EndProcedure

Procedure AfterRequestAuthenticationPasswordInServiceAndErrorWarning(Context) Export
	
	RequestPasswordForAuthenticationInService(Context.ContinuationHandler,
		Context.OwnerForm, Undefined);
	
EndProcedure

#EndRegion
