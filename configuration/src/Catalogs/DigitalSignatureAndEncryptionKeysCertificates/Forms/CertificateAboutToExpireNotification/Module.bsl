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
	
	Certificate = Parameters.Certificate;
	
	CertificateIssueRequestAvailable = DigitalSignature.CommonSettings().CertificateIssueRequestAvailable;
	
	YesReissued = IssuedCertificates.Count() > 0;
	Items.DecorationReissued.Visible = YesReissued;
	
	CertificateIssueRequestAvailable = CertificateIssueRequestAvailable
		And AccessRight("Edit", Metadata.Catalogs.DigitalSignatureAndEncryptionKeysCertificates);
		
	AdditionalDataChecks = Parameters.AdditionalDataChecks; // See DigitalSignatureInternalClientServer.WarningWhileVerifyingCertificateAuthorityCertificate
	
	If ValueIsFilled(AdditionalDataChecks) And TypeOf(AdditionalDataChecks) = Type("Structure") Then
		
		Items.DecorationCertificate.Title = AdditionalDataChecks.ErrorText;
		If ValueIsFilled(AdditionalDataChecks.Cause) Then
			Items.DecorationReason.Title = AdditionalDataChecks.Cause;
			Items.DecorationReason.Visible = True;
		EndIf;
		
		If Not YesReissued Then
			If AdditionalDataChecks.PossibleReissue And Not CertificateIssueRequestAvailable Then
				Items.DecorationDecision.Title = Decision();
				Items.DecorationDecision.Visible = True;
			Else
				If ValueIsFilled(AdditionalDataChecks.Decision) Then
					Items.DecorationDecision.Title = AdditionalDataChecks.Decision;
					Items.DecorationDecision.Visible = True;
				EndIf;
			EndIf;
		EndIf;
		
	Else
		
		If ValueIsFilled(Certificate) Then
			ValidBefore = Common.ObjectAttributeValue(Certificate, "ValidBefore")
				+ DigitalSignatureInternal.TimeAddition();
			Items.DecorationCertificate.Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The certificate expires on %1';"), ValidBefore);
			If Not YesReissued Then
				If CertificateIssueRequestAvailable Then
					Decision = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Submit <a href = ""%1"">application</a> for a new certificate.';"),
						"ApplyforCertificate");
				Else
					Decision = Decision();
				EndIf;

				Items.DecorationDecision.Title = StringFunctions.FormattedString(Decision);
				Items.DecorationDecision.Visible = True;
			EndIf;
		Else
			Items.DecorationCertificate.Title = NStr("en = 'The Certificate parameter is not filled in when opening the form.';");
		EndIf;
		
	EndIf;

EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DontRemindAgainOnChange(Item)
	
	DigitalSignatureInternalClient.EditMarkONReminder(Certificate, Not DontRemindAgain, ThisObject);
	
EndProcedure

&AtClient
Procedure DecorationReissuedURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	If IssuedCertificates.Count() = 1 Then
		OpenCertificateAfterSelectionFromList(IssuedCertificates[0], Undefined);
	Else	
		NotifyDescription = New NotifyDescription("OpenCertificateAfterSelectionFromList", ThisObject, Item);
		ShowChooseFromList(NotifyDescription, IssuedCertificates);
	EndIf;
	
EndProcedure

&AtClient
Procedure DecorationDecisionURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	AdditionalData = DigitalSignatureInternalClient.AdditionalDataForErrorClassifier();
	AdditionalData.Certificate = Certificate;
	DigitalSignatureInternalClient.HandleNaviLinkClassifier(
		Item, FormattedStringURL, StandardProcessing, AdditionalData);
		
EndProcedure

#EndRegion


#Region Private

&AtClient
Procedure OpenCertificateAfterSelectionFromList(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		OpenForm("Catalog.DigitalSignatureAndEncryptionKeysCertificates.ObjectForm", 
			New Structure("Key", Result.Value));
	EndIf;
		
EndProcedure

&AtServer
Function Decision()
	
	If DigitalSignature.CommonSettings().AvailableCheckAccordingtoCAList Then
		ModuleDigitalSignatureClientServerLocalization = Common.CommonModule(
			"DigitalSignatureClientServerLocalization");
		Return StringFunctions.FormattedString(
				NStr("en = 'Get a new certificate from <a href = ""%1"">respective certificate authority</a>.';"),
					ModuleDigitalSignatureClientServerLocalization.LinktothearticleonCAs());
	Else
		Return NStr("en = 'Get a new certificate.';");
	EndIf;
	
EndFunction

#EndRegion