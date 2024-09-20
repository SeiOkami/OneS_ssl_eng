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
	
	DigitalSignatureInternal.SetCertificateListConditionalAppearance(List);
	
	Parameters.Filter.Property("Organization", Organization);
	
	CloseOnChoice = False;
	
	If Metadata.DataProcessors.Find("ApplicationForNewQualifiedCertificateIssue") <> Undefined Then
		ProcessingApplicationForNewQualifiedCertificateIssue =
			Common.ObjectManagerByFullName(
				"DataProcessor.ApplicationForNewQualifiedCertificateIssue");
		
		QueryText = List.QueryText;
		ProcessingApplicationForNewQualifiedCertificateIssue.AddCertificateListRequest(
			QueryText);
	Else
		QueryText = StrReplace(List.QueryText, "&AdditionalCondition", "TRUE");
	EndIf;
	
	ListProperties = Common.DynamicListPropertiesStructure();
	ListProperties.QueryText = QueryText;
	Common.SetDynamicListProperties(Items.List, ListProperties);
	
	UsersGroupOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_DigitalSignatureAndEncryptionKeysCertificates")
	   And Parameter.IsNew Then
		
		Items.List.Refresh();
		Items.List.CurrentRow = Source;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UsersGroupUsageOnChange(Item)
	
	UsersGroupOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure UsersGroupOnChange(Item)
	
	UsersGroupOnChangeAtServer();
	
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	
	Cancel = True;
	
	If Not Copy Then
		CreationParameters = New Structure;
		CreationParameters.Insert("ToPersonalList", True);
		CreationParameters.Insert("Organization",   Organization);
		
		DigitalSignatureInternalClient.AddCertificateAfterPurposeChoice(
			"ToEncryptOnly", CreationParameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Add(Command)
	
	Items.List.AddRow();
	
EndProcedure

&AtClient
Procedure AddFromFile(Command)
	
	CreationParameters = New Structure;
	CreationParameters.Insert("ToPersonalList", True);
	CreationParameters.Insert("Organization",   Organization);
	
	DigitalSignatureInternalClient.AddCertificateOnlyToEncryptFromFile(CreationParameters);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure UsersGroupOnChangeAtServer()
	
	CommonClientServer.SetDynamicListParameter(
		List, "UsersGroup", UsersGroup, UsersGroupUsage);
	
EndProcedure

#EndRegion
