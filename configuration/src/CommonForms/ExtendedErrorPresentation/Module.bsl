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
	
	AdditionalData = Parameters.AdditionalData;
	
	If ValueIsFilled(Parameters.SupportInformation) Then
		Items.SupportInformation.Title = Parameters.SupportInformation;
	Else
		Items.SupportInformation.Title = DigitalSignatureInternal.InfoHeadingForSupport();
	EndIf;
	
	DigitalSignatureInternal.ToSetTheTitleOfTheBug(ThisObject,
		Parameters.WarningTitle);
	
	ErrorTextClient = Parameters.ErrorTextClient;
	ErrorTextServer = Parameters.ErrorTextServer;
	ErrorText = Parameters.ErrorText;
	
	TwoMistakes = Not IsBlankString(ErrorTextClient)
		And Not IsBlankString(ErrorTextServer);
	
	SetItems(ErrorTextClient, TwoMistakes, "Client");
	SetItems(ErrorTextServer, TwoMistakes, "Server");
	SetItems(ErrorText, TwoMistakes, "");
	
	Items.SeparatorDecoration.Visible = TwoMistakes;
	
	If TwoMistakes
	   And IsBlankString(ErrorAnchorClient)
	   And IsBlankString(ErrorAnchorServer) Then
		
		Items.InstructionClient.Visible = False;
	EndIf;
	
	Items.FooterGroup.Visible = Parameters.ShowNeedHelp;
	Items.SeparatorDecoration2.Visible = Parameters.ShowNeedHelp;
	
	GuideRefVisibility =
		DigitalSignatureInternal.VisibilityOfRefToAppsTroubleshootingGuide();
	
	If Parameters.ShowNeedHelp Then
		Items.Help.Visible                     = Parameters.ShowInstruction;
		Items.FormOpenApplicationsSettings.Visible = Parameters.ShowOpenApplicationsSettings;
		Items.FormInstallExtension.Visible      = Parameters.ShowExtensionInstallation;
		Items.InstructionClient.Visible = Items.InstructionClient.Visible And GuideRefVisibility 
			And ValueIsFilled(ErrorAnchorClient);
		Items.InstructionServer.Visible = GuideRefVisibility And ValueIsFilled(ErrorAnchorServer);
		ErrorDescription = Parameters.ErrorDescription;
	Else
		Items.InstructionClient.Visible = Items.InstructionClient.Visible And GuideRefVisibility;
		Items.InstructionServer.Visible = GuideRefVisibility;
	EndIf;
	
	StandardSubsystemsServer.ResetWindowLocationAndSize(ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure InstructionClick(Item)
	
	ErrorAnchor = "";
	If Item.Name = "InstructionClient"
		And Not IsBlankString(ErrorAnchorClient) Then
		
		ErrorAnchor = ErrorAnchorClient;
	ElsIf Item.Name = "InstructionServer"
		And Not IsBlankString(ErrorAnchorServer) Then
		
		ErrorAnchor = ErrorAnchorServer;
	EndIf;
	
	DigitalSignatureClient.OpenInstructionOnTypicalProblemsOnWorkWithApplications(ErrorAnchor);
	
EndProcedure

&AtClient
Procedure SupportInformationURLProcessing(Item, Var_URL, StandardProcessing)
	
	StandardProcessing = False;
	
	If Var_URL = "TypicalIssues" Then
		DigitalSignatureClient.OpenInstructionOnTypicalProblemsOnWorkWithApplications();
	Else
	
		ErrorsText = "";
		FilesDetails = New Array;
		If ValueIsFilled(AdditionalData) Then
			DigitalSignatureInternalServerCall.AddADescriptionOfAdditionalData(
				AdditionalData, FilesDetails, ErrorsText);
		EndIf;
		
		ErrorsText = ErrorsText + ErrorDescription;
		DigitalSignatureInternalClient.GenerateTechnicalInformation(ErrorsText, , FilesDetails);
	
	EndIf;
	
EndProcedure

&AtClient
Procedure ReasonsClientTextURLProcessing(Item, FormattedStringURL, StandardProcessing)
	DigitalSignatureInternalClient.HandleNaviLinkClassifier(
		Item, FormattedStringURL, StandardProcessing, AdditionalData());
EndProcedure

&AtClient
Procedure DecisionsClientTextURLProcessing(Item, FormattedStringURL, StandardProcessing)
	DigitalSignatureInternalClient.HandleNaviLinkClassifier(
		Item, FormattedStringURL, StandardProcessing, AdditionalData());
EndProcedure

&AtClient
Procedure ReasonsServerTextURLProcessing(Item, FormattedStringURL, StandardProcessing)
	DigitalSignatureInternalClient.HandleNaviLinkClassifier(
		Item, FormattedStringURL, StandardProcessing, AdditionalData());
EndProcedure

&AtClient
Procedure DecisionsServerTextURLProcessing(Item, FormattedStringURL, StandardProcessing)
	DigitalSignatureInternalClient.HandleNaviLinkClassifier(
		Item, FormattedStringURL, StandardProcessing, AdditionalData());
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OpenApplicationsSettings(Command)
	
	Close();
	DigitalSignatureClient.OpenDigitalSignatureAndEncryptionSettings("Programs");
	
EndProcedure

&AtClient
Procedure InstallExtension(Command)
	
	DigitalSignatureClient.InstallExtension(True);
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetItems(ErrorText, TwoMistakes, ErrorLocation)
	
	If ErrorLocation = "Server" Then
		ItemError = Items.ErrorServer;
		ErrorTextElement = Items.ErrorTextServer;
		InstructionItem = Items.InstructionServer;
		ReasonItemText = Items.ReasonsServerText;
		ItemDecisionText = Items.DecisionsServerText;
		ReasonsAndDecisionsGroup = Items.PossibleCausesAndSolutionsServer;
	ElsIf ErrorLocation = "Client" Then
		ItemError = Items.ErrorClient;
		ErrorTextElement = Items.ErrorTextClient;
		InstructionItem = Items.InstructionClient;
		ReasonItemText = Items.ReasonsClientText;
		ItemDecisionText = Items.DecisionsClientText;
		ReasonsAndDecisionsGroup = Items.PossibleCausesAndSolutionsClient;
	Else
		ItemError = Items.Error;
		ErrorTextElement = Items.ErrorText;
		InstructionItem = Items.Instruction;
		ReasonItemText = Items.ReasonsText;
		ItemDecisionText = Items.SolutionsText;
		ReasonsAndDecisionsGroup = Items.PossibleCausesAndSolutions;
	EndIf;
	
	ItemError.Visible = Not IsBlankString(ErrorText);
	If Not IsBlankString(ErrorText) Then
		
		HaveReasonAndSolution = Undefined;
		If TypeOf(AdditionalData) = Type("Structure") Then
			If ErrorLocation = "Server" Then
				CheckSuffix_ = "AtServer";
			ElsIf ErrorLocation = "Client" Then
				CheckSuffix_ = "AtClient";
			Else
				CheckSuffix_ = "";
			EndIf;
				
			HaveReasonAndSolution = CommonClientServer.StructureProperty(AdditionalData, 
				"Additional_DataChecks" + CheckSuffix_, Undefined); // See DigitalSignatureInternalClientServer.WarningWhileVerifyingCertificateAuthorityCertificate
		EndIf;
		
		If ValueIsFilled(HaveReasonAndSolution) Then
			ClassifierError = New Structure;
			ClassifierError.Insert("Ref", "");
			Cause = HaveReasonAndSolution.Cause; // String
			ClassifierError.Insert("Cause", FormattedString(Cause));
			ClassifierError.Insert("Decision", FormattedString(HaveReasonAndSolution.Decision));
			ClassifierError.Insert("Remedy", "");
		Else
			ClassifierError = DigitalSignatureInternal.ClassifierError(ErrorText, ErrorLocation = "Server");
		EndIf;
		
		IsKnownError = ClassifierError <> Undefined;
		
		ReasonsAndDecisionsGroup.Visible = IsKnownError;
		If IsKnownError Then
			
			CommonClientServer.SetFormItemProperty(Items,
				InstructionItem.Name, "Title", NStr("en = 'Details';"));
			
			If ValueIsFilled(ClassifierError.Cause) Then
				CommonClientServer.SetFormItemProperty(Items,
				ReasonItemText.Name, "Title", ClassifierError.Cause);
			Else
				CommonClientServer.SetFormItemProperty(Items,
				ReasonItemText.Name, "Visible", False);
			EndIf;
			
			If ValueIsFilled(ClassifierError.Decision) Then
				CommonClientServer.SetFormItemProperty(Items,
					ItemDecisionText.Name, "Title", ClassifierError.Decision);
			Else
				CommonClientServer.SetFormItemProperty(Items,
					ItemDecisionText.Name, "Visible", False);
			EndIf;
			
			If ErrorLocation = "Server" Then
				ErrorAnchorServer = ClassifierError.Ref;
			ElsIf ErrorLocation = "Client" Then
				ErrorAnchorClient = ClassifierError.Ref;
			Else
				ErrorAnchor = ClassifierError.Ref;
			EndIf;
			
		EndIf;
		
		RequiredNumberOfRows = 0;
		MarginWidth = Int(?(Width < 20, 20, Width) * 1.4);
		For LineNumber = 1 To StrLineCount(ErrorText) Do
			RequiredNumberOfRows = RequiredNumberOfRows + 1
				+ Int(StrLen(StrGetLine(ErrorText, LineNumber)) / MarginWidth);
		EndDo;
		If RequiredNumberOfRows > 5 And Not TwoMistakes Then
			ErrorTextElement.Height = 4;
		ElsIf RequiredNumberOfRows > 3 Then
			ErrorTextElement.Height = 3;
		ElsIf RequiredNumberOfRows > 1 Then
			ErrorTextElement.Height = 2;
		Else
			ErrorTextElement.Height = 1;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Function AdditionalData()
	
	If Not ValueIsFilled(AdditionalData) Then
		Return Undefined;
	EndIf;
	
	AdditionalDataForErrorClassifier = DigitalSignatureInternalClient.AdditionalDataForErrorClassifier();
	Certificate = CommonClientServer.StructureProperty(AdditionalData, "Certificate", Undefined);
	If ValueIsFilled(Certificate) Then
		If TypeOf(Certificate) = Type("Array") Then
			If Certificate.Count() > 0 Then
				If TypeOf(Certificate[0]) = Type("CatalogRef.DigitalSignatureAndEncryptionKeysCertificates") Then
					AdditionalDataForErrorClassifier.Certificate = Certificate[0];
					AdditionalDataForErrorClassifier.CertificateData = CertificateData(Certificate[0], UUID);
				Else
					AdditionalDataForErrorClassifier.CertificateData = Certificate[0];
				EndIf;
			EndIf;
		ElsIf TypeOf(Certificate) = Type("CatalogRef.DigitalSignatureAndEncryptionKeysCertificates") Then
			AdditionalDataForErrorClassifier.Certificate = Certificate;
			AdditionalDataForErrorClassifier.CertificateData = CertificateData(Certificate, UUID);
		ElsIf TypeOf(Certificate) = Type("BinaryData") Then
			AdditionalDataForErrorClassifier.CertificateData = PutToTempStorage(Certificate, UUID);
		Else
			AdditionalDataForErrorClassifier.CertificateData = Certificate;
		EndIf;
	EndIf;
	
	CertificateData = CommonClientServer.StructureProperty(AdditionalData, "CertificateData", Undefined);
	If ValueIsFilled(CertificateData) Then
		AdditionalDataForErrorClassifier.CertificateData = CertificateData;
	EndIf;
	
	Return AdditionalDataForErrorClassifier;

EndFunction

&AtServer
Function FormattedString(Val String)
	
	If TypeOf(String) = Type("String") Then
		String = StringFunctions.FormattedString(String);
	EndIf;
	
	Return String;
	
EndFunction

&AtServerNoContext
Function CertificateData(Certificate, UUID)
	
	CertificateData = Common.ObjectAttributeValue(Certificate, "CertificateData").Get();
	If ValueIsFilled(CertificateData) Then
		Return PutToTempStorage(CertificateData, UUID);
	Else
		Return Undefined;
	EndIf;
	
EndFunction

#EndRegion
