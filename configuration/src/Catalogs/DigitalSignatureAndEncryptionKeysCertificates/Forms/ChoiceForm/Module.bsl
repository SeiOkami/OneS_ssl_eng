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
	
	If Not DigitalSignature.UseEncryption()
	   And Not DigitalSignature.CommonSettings().CertificateIssueRequestAvailable Then
		
		CommonClientServer.SetFormItemProperty(Items,
			"FormCreate", "Title", NStr("en = 'Add';"));
		
		CommonClientServer.SetFormItemProperty(Items,
			"ListContextMenuCreate", "Title", NStr("en = 'Add';"));
	EndIf;
	
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
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_DigitalSignatureAndEncryptionKeysCertificates")
	   And Parameter.IsNew Then
		Items.List.Refresh();
		Items.List.CurrentRow = Source;
	EndIf;
	
	// When changing usage settings.
	If Upper(EventName) <> Upper("Write_ConstantsSet") Then
		Return;
	EndIf;
	
	If Upper(Source) = Upper("UseDigitalSignature")
	 Or Upper(Source) = Upper("UseEncryption") Then
		
		AttachIdleHandler("OnChangeSigningOrEncryptionUsage", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	
	Cancel = True;
	If Not Copy Then
		
		CreationParameters = New Structure;
		CreationParameters.Insert("ToPersonalList", True);
		CreationParameters.Insert("Organization", Organization);
		
		DigitalSignatureInternalClient.ToAddCertificate(CreationParameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure OnChangeSigningOrEncryptionUsage()
	
	If DigitalSignatureClient.UseEncryption()
	 Or DigitalSignatureClient.CommonSettings().CertificateIssueRequestAvailable Then
		
		CommonClientServer.SetFormItemProperty(Items,
			"FormCreate", "Title", NStr("en = 'Add…';"));
		
		CommonClientServer.SetFormItemProperty(Items,
			"ListContextMenuCreate", "Title", NStr("en = 'Add…';"));
	Else
		CommonClientServer.SetFormItemProperty(Items,
			"FormCreate", "Title", NStr("en = 'Add';"));
		
		CommonClientServer.SetFormItemProperty(Items,
			"ListContextMenuCreate", "Title", NStr("en = 'Add';"));
	EndIf;
	
EndProcedure

#EndRegion
