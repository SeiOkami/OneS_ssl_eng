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
	
	Items.SignedObject.Visible = False;
	
	If ValueIsFilled(Parameters.ExtensionMode) Then
		
		UpdateDataView(True);
		
		If Parameters.ExtensionMode = "RequireImprovementSignatures" Then 
			SignatureType = Constants.CryptoSignatureTypeDefault.Get();
			Items.AddArchiveTimestamp.Visible = False;
			Items.SignatureType.Visible = False;
			Items.DecorationImprovement.Visible = True;
			Items.DecorationImprovement.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Signatures will be enhanced to:
			|%1';"), SignatureType);
		ElsIf Parameters.ExtensionMode = "RequiredAddArchiveTags" Then
			Items.AddArchiveTimestamp.Visible = False;
			Items.DecorationAddingTimestamps.Visible = True; 
			Items.DecorationAddingTimestamps.Title = NStr("en = 'Archive timestamps will be added to the signatures';");
			Items.SignatureType.Visible = False;
		Else
			Items.AddArchiveTimestamp.Visible = True;
			Items.SignatureType.Visible = True;
		EndIf;
		
	Else
		
		If ValueIsFilled(Parameters.Signature) Then
			Signature = PutToTempStorage(Parameters.Signature, UUID);
		EndIf;
		
		If TypeOf(Parameters.Signature) = Type("Structure") Then
			If ValueIsFilled(Parameters.Signature.SignedObject) Then
				SignedObject = Parameters.Signature.SignedObject;
				SequenceNumber = Parameters.Signature.SequenceNumber; 
				Items.SignedObject.Visible = True; 
			EndIf;
		EndIf;
		
		If ValueIsFilled(Parameters.DataTitle) Then
			Items.DataPresentation.Title = Parameters.DataTitle;
		Else
			Items.DataPresentation.TitleLocation = FormItemTitleLocation.None;
		EndIf;
		
		DataPresentation = Parameters.DataPresentation;
		Items.DataPresentation.Hyperlink = Parameters.DataPresentationCanOpen;
		
	EndIf;
	
	If ValueIsFilled(Parameters.SignatureType) Then
		If Parameters.SignatureType = Enums.CryptographySignatureTypes.ArchivalCAdESAv3
			Or Parameters.SignatureType = Enums.CryptographySignatureTypes.CAdESAv2 Then
			
			Items.AddArchiveTimestamp.Visible = False;
			Items.DecorationAddingTimestamps.Visible = True; 
			Items.DecorationAddingTimestamps.Title = NStr("en = 'Archive timestamps will be added to the signatures';");
			
			Items.SignatureType.Visible = False;
			AddArchiveTimestamp = True;
		Else
			Items.AddArchiveTimestamp.Visible = False;
			Items.SignatureType.Visible = True;
		EndIf;
	Else
		If ValueIsFilled(SignedObject) Then
			DetermineTypeSignaturesObject();
		EndIf;
	EndIf;

	If Not ValueIsFilled(DataPresentation) Then
		Items.DataPresentation.Visible = False;
	EndIf;
	
	If Items.SignatureType.Visible Then
		DigitalSignatureInternal.FillListSignatureTypesCryptography(Items.SignatureType.ChoiceList,
			"Improvement", ?(ValueIsFilled(Parameters.SignatureType), Parameters.SignatureType, Undefined));
		If Items.AddArchiveTimestamp.Visible Then
			Items.SignatureType.ChoiceList.Add(Enums.CryptographySignatureTypes.EmptyRef(), NStr("en = 'Do not enhance';"));
		EndIf;
		If Items.SignatureType.ChoiceList.Count() = 1 Then
			SignatureType = Items.SignatureType.ChoiceList[0].Value;
			Items.SignatureType.Visible = False;
			Items.DecorationImprovement.Visible = True;
			Items.DecorationImprovement.Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Signatures will be enhanced to:
					|%1';"), SignatureType);
		Else
			SignatureType = Constants.CryptoSignatureTypeDefault.Get();
			If SignatureType = Enums.CryptographySignatureTypes.BasicCAdESBES
				Or SignatureType = Enums.CryptographySignatureTypes.EmptyRef()
				Or SignatureType = Enums.CryptographySignatureTypes.NormalCMS Then
				SignatureType = Items.SignatureType.ChoiceList[0].Value;
			EndIf;
		EndIf;
	EndIf;
	
	If Items.AddArchiveTimestamp.Visible Then
		AddArchiveTimestamp = Constants.AddTimestampsAutomatically.Get();
	EndIf;
	
	StandardSubsystemsServer.ResetWindowLocationAndSize(ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers
	
&AtClient
Procedure SignedObjectClick(Item, StandardProcessing)
	If IsReference(SignedObject) Then
		ShowValue(,SignedObject);
	EndIf;
EndProcedure

&AtClient
Procedure DataPresentationClick(Item, StandardProcessing)
	
	If ValueIsFilled(Parameters.ExtensionMode) Then
		StandardProcessing = False;
		ReportParameters = New Structure("VariantKey", Parameters.ExtensionMode); 
		If Errors.Count() > 0 Then
			ReportParameters.Insert("Errors", GetAddressofErrorsInTemporaryStorage());
		EndIf;
		OpenForm("Report.RenewDigitalSignatures.Form", ReportParameters);
	EndIf;
	
EndProcedure
	
#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExecuteActions(Command)
	
	Errors.Clear();
	
	If Parameters.ExtensionMode = "rawsignatures"
		Or Parameters.ExtensionMode = "RequiredAddArchiveTags"
		Or Parameters.ExtensionMode = "ErrorsOnAutoRenewal"
		Or Parameters.ExtensionMode = "RequireImprovementSignatures" Then
		FillSignature();
	EndIf;
	
	If Not ValueIsFilled(Signature) Then
		ShowMessageBox(, NStr("en = 'Signature data is required';"));
		Return;
	EndIf;
	
	DataDetails = New Structure("Signature, SignatureType, AddArchiveTimestamp",
		Signature, SignatureType, AddArchiveTimestamp);
	DataDetails.Signature = GetFromTempStorage(Signature);
		
	Notification = New NotifyDescription("AfterExecution", ThisObject);  
	DigitalSignatureClient.EnhanceSignature(DataDetails, ThisObject, Notification, False); 
	Items.ExecuteActions.Enabled = False;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillSignature()
	
	QueryOptions = New Structure;
	QueryOptions.Insert(Parameters.ExtensionMode, True);
	Query = DigitalSignatureInternal.RequestForExtensionSignatureCredibility(QueryOptions);
	
	Array = New Array;
	SetPrivilegedMode(True);
	QueryResult = Query.Execute();
	SetPrivilegedMode(False);
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Array.Add(New Structure("SignedObject, SequenceNumber",
			Selection.SignedObject, Selection.SequenceNumber));
	EndDo;
	
	SignaturesCount = Array.Count();
	If SignaturesCount > 0 Then
		Signature = PutToTempStorage(Array, UUID);
	EndIf;
	
	UpdateDataView();
	
EndProcedure

&AtServer
Procedure UpdateDataView(CalculateQuantity = False)
	
	If Not ValueIsFilled(Parameters.ExtensionMode) Then
		Return;
	EndIf;

	If CalculateQuantity Then
		SignaturesCount = DigitalSignatureInternal.SignaturesCount(Parameters.ExtensionMode);
		Items.DataPresentation.Hyperlink = True;
		Items.DataPresentation.TitleLocation = FormItemTitleLocation.None;
	EndIf;

	If Parameters.ExtensionMode = "RequireImprovementSignatures" Then
		DataPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Signatures pending enhancement (%1)';"), SignaturesCount);
	ElsIf Parameters.ExtensionMode = "RequiredAddArchiveTags" Then
		DataPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Signatures to add archive timestamps (%1)';"), SignaturesCount);
	ElsIf Parameters.ExtensionMode = "rawsignatures" Then
		DataPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Previously added signatures with a blank type (%1)';"), SignaturesCount);
	ElsIf Parameters.ExtensionMode = "ErrorsOnAutoRenewal" Then
		DataPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Automatic signature renewal errors (%1)';"), SignaturesCount);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterExecution(Result, Context) Export
	
	Items.ExecuteActions.Enabled = True;
	Notify("Write_Signature");
	If Not Result.Success Then 
		If Result.PropertiesSignatures <> Undefined Then
			For Each SignatureProperty In Result.PropertiesSignatures Do
				If SignatureProperty.Property("Error") Then
					NewRow = Errors.Add();
					FillPropertyValues(NewRow, SignatureProperty);
				EndIf;
			EndDo;
		EndIf;
		
		Items.Errors.Visible = Errors.Count() > 0;
		
		If ValueIsFilled(Result.ErrorText) Then
			ShowMessageBox(, Result.ErrorText);
		EndIf;
		UpdateDataView(True);
	Else
		Close(Result);
	EndIf;
	
EndProcedure

&AtServer
Function GetAddressofErrorsInTemporaryStorage()
	Return PutToTempStorage(Errors.Unload(), UUID);
EndFunction

&AtServerNoContext
Function IsReference(SignedObject)
	Return Common.IsReference(TypeOf(SignedObject));
EndFunction

&AtServer
Procedure DetermineTypeSignaturesObject()
	
	SetSignatures = DigitalSignature.SetSignatures(
		SignedObject, ?(ValueIsFilled(SequenceNumber), SequenceNumber, Undefined));
		
	ThereIsBasicSignature = False; ThereIsSignatureWithTimestamp = False; ThereIsArchivalSignature = False;
	
	For Each CurrentSignature In SetSignatures Do
		
		If Not CurrentSignature.SignatureCorrect Then
			Continue;
		EndIf;
		
		If Not ValueIsFilled(CurrentSignature.SignatureType) Then
			Break;
		EndIf;
		
		If Not ThereIsBasicSignature And DigitalSignatureInternalClientServer.ToBeImproved(
				CurrentSignature.SignatureType, Enums.CryptographySignatureTypes.WithTimeCAdEST) Then
			ThereIsBasicSignature = True;
			Continue;
		EndIf;
		
		If Not ThereIsSignatureWithTimestamp And DigitalSignatureInternalClientServer.ToBeImproved(
				CurrentSignature.SignatureType, Enums.CryptographySignatureTypes.ArchivalCAdESAv3) Then
			ThereIsSignatureWithTimestamp = True;
			Continue;
		EndIf;
		
		If Not ThereIsArchivalSignature
			And (CurrentSignature.SignatureType = Enums.CryptographySignatureTypes.CAdESAv2
			Or CurrentSignature.SignatureType = Enums.CryptographySignatureTypes.ArchivalCAdESAv3) Then
			ThereIsArchivalSignature = True;
			Continue;
		EndIf;
		
	EndDo;
	
	If ThereIsArchivalSignature Then
		Items.AddArchiveTimestamp.Visible = True;
	ElsIf ThereIsSignatureWithTimestamp Or ThereIsBasicSignature Then
		Items.AddArchiveTimestamp.Visible = False;
	EndIf;
	
	If ThereIsBasicSignature Then
		Parameters.SignatureType = Enums.CryptographySignatureTypes.BasicCAdESBES;
		Items.SignatureType.Visible = True;
	ElsIf ThereIsSignatureWithTimestamp Then
		Parameters.SignatureType = Enums.CryptographySignatureTypes.WithTimeCAdEST;
		Items.SignatureType.Visible = True;
	ElsIf ThereIsArchivalSignature Then
		Parameters.SignatureType = Enums.CryptographySignatureTypes.ArchivalCAdESAv3;
		Items.SignatureType.Visible = False;
	EndIf;

EndProcedure

#EndRegion