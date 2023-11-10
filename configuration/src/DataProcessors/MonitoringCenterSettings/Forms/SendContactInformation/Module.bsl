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
	MonitoringCenterParameters = New Structure("ContactInformation, ContactInformationComment1");
	MonitoringCenterParameters = MonitoringCenterInternal.GetMonitoringCenterParameters(MonitoringCenterParameters);
	Contacts = MonitoringCenterParameters.ContactInformation;
	Comment = MonitoringCenterParameters.ContactInformationComment1;
	If Common.SubsystemExists("OnlineUserSupport") Then
		ModuleOnlineUserSupport = Common.CommonModule("OnlineUserSupport");
		AuthenticationData = ModuleOnlineUserSupport.OnlineSupportUserAuthenticationData();
		If AuthenticationData <> Undefined Then
			Login = AuthenticationData.Login;
		EndIf;
	EndIf;
	If Parameters.Property("OnRequest") Then
		OnRequest = True;
		Items.Title.Title = NStr("en = 'Earlier you signed up to send anonymous depersonalized reports about the application usage. The analysis of the submitted reports revealed performance issues. If you are ready to submit a copy of your infobase (can be depersonalized) to 1C Company to get your performance issues looked into, please specify your contact details so that 1C Company employees can contact you.
                                             |If you refuse, no identification data will be sent.';");
		Items.FormSend.Title = NStr("en = 'Send contact information';");
	Else
		Items.Comment.InputHint = NStr("en = 'Describe your issue';");
		Items.FormCancel13.Visible = False;
		Items.Contacts.AutoMarkIncomplete = True;
		Items.Comment.AutoMarkIncomplete = True;
	EndIf;
	ResetWindowLocationAndSize();    	
EndProcedure

#EndRegion


#Region FormCommandHandlers

&AtClient
Procedure Send(Command) 
	If Not FilledCorrectly1() Then
		Return;
	EndIf;
	NewParameters = New Structure;
	NewParameters.Insert("ContactInformationRequest", 1);
	NewParameters.Insert("ContactInformationChanged", True);
	NewParameters.Insert("ContactInformation", Contacts);
	NewParameters.Insert("ContactInformationComment1", Comment);
	NewParameters.Insert("PortalUsername", Login);
	SetMonitoringCenterParameters(NewParameters);
	Close();
EndProcedure

&AtClient
Procedure DoNotSend(Command)
	NewParameters = New Structure;
	NewParameters.Insert("ContactInformationRequest", 0);
	NewParameters.Insert("ContactInformationChanged", True);
	NewParameters.Insert("ContactInformation", "");
	NewParameters.Insert("ContactInformationComment1", Comment);
	SetMonitoringCenterParameters(NewParameters);
	Close();
EndProcedure

#EndRegion

#Region Private

&AtClient
Function FilledCorrectly1()
	CheckResult = True;
	If OnRequest Then
		If IsBlankString(Contacts)Then
			CommonClient.MessageToUser(NStr("en = 'Contact information is not specified.';"),,"Contacts");
			CheckResult = False;
		EndIf; 
	Else 
		If IsBlankString(Contacts)Then
			CommonClient.MessageToUser(NStr("en = 'Contact information is not specified.';"),,"Contacts");
			CheckResult = False;
		EndIf; 
		If IsBlankString(Comment)Then
			CommonClient.MessageToUser(NStr("en = 'Comment is not filled in.';"),,"Comment");
			CheckResult = False;
		EndIf; 
	EndIf;                	
	Return CheckResult;		
EndFunction

&AtServer
Procedure ResetWindowLocationAndSize()
	WindowOptionsKey = ?(OnRequest, "OnRequest", "Independent1");
EndProcedure

&AtServerNoContext
Procedure SetMonitoringCenterParameters(NewParameters)
	MonitoringCenterInternal.SetMonitoringCenterParametersExternalCall(NewParameters);
EndProcedure

#EndRegion