///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DigitalSignatures.SignedObject AS SignedObject,
	|	DigitalSignatures.SequenceNumber AS SequenceNumber
	|FROM
	|	InformationRegister.DigitalSignatures AS DigitalSignatures
	|WHERE
	|	(DigitalSignatures.SignatureFileName LIKE ""%\%"" ESCAPE ""~""
	|			OR DigitalSignatures.SignatureFileName LIKE ""%/%"" ESCAPE ""~"")
	|	OR DigitalSignatures.SignatureID = &BlankUUID";
	
	Query.SetParameter("BlankUUID", New UUID("00000000-0000-0000-0000-000000000000"));
	
	AdditionalParameters = InfobaseUpdate.AdditionalProcessingMarkParameters();
	AdditionalParameters.IsIndependentInformationRegister = True;
	AdditionalParameters.FullRegisterName = Metadata.InformationRegisters.DigitalSignatures.FullName();
	
	InfobaseUpdate.MarkForProcessing(Parameters, Query.Execute().Unload(), AdditionalParameters);
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	ProcessingCompleted = True;
	
	RegisterMetadata    = Metadata.InformationRegisters.DigitalSignatures;
	FullRegisterName     = RegisterMetadata.FullName();
	Selection = InfobaseUpdate.SelectStandaloneInformationRegisterDimensionsToProcess(
		Parameters.Queue, FullRegisterName);
	
	Processed = 0;
	RecordsWithIssuesCount = 0;
	
	While Selection.Next() Do
		RecordSet = InformationRegisters.DigitalSignatures.CreateRecordSet();
		RecordSet.Filter.SignedObject.Set(Selection.SignedObject);
		RecordSet.Filter.SequenceNumber.Set(Selection.SequenceNumber);
		Block = New DataLock;
		LockItem = Block.Add(FullRegisterName);
		LockItem.SetValue("SignedObject", Selection.SignedObject);
		LockItem = Block.Add(FullRegisterName);
		LockItem.SetValue("SequenceNumber", Selection.SequenceNumber);
		BeginTransaction();
		Try
			Block.Lock();
			RecordSet.Read();
			If RecordSet.Count() > 0 Then
				Record = RecordSet[0];
				TheNameOfTheSignatureFileWithoutAPath = Undefined;
				NameParts = StrSplit(Record.SignatureFileName, "\/", False);
				If NameParts.Count() > 0 Then
					TheNameOfTheSignatureFileWithoutAPath = NameParts[NameParts.UBound()];
				EndIf;
				WriteSet = False;
				If Not ValueIsFilled(Record.SignatureID) Then
					Record.SignatureID = New UUID;
					WriteSet = True;
				EndIf;
				If TheNameOfTheSignatureFileWithoutAPath <> Undefined And Record.SignatureFileName <> TheNameOfTheSignatureFileWithoutAPath Then
					Record.SignatureFileName = TheNameOfTheSignatureFileWithoutAPath;
					WriteSet = True;
				EndIf;
				If WriteSet Then
					InfobaseUpdate.WriteRecordSet(RecordSet);
				EndIf;
			EndIf;
			InfobaseUpdate.MarkProcessingCompletion(RecordSet);
			Processed = Processed + 1;
			CommitTransaction();
		Except
			RollbackTransaction();
			ErrorInfo = ErrorInfo();
			RecordsWithIssuesCount = RecordsWithIssuesCount + 1;
			KeyProperties1 = New Structure("SignedObject, SequenceNumber",
				Selection.SignedObject, Selection.SequenceNumber);
			RecordKey = InformationRegisters.DigitalSignatures.CreateRecordKey(KeyProperties1);
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process a ""%1"" register record. Reason:
					|%2';"),
				GetURL(RecordKey),
				ErrorProcessing.DetailErrorDescription(ErrorInfo));
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Warning,
				RegisterMetadata, , 
				MessageText);
		EndTry;
	EndDo;
	
	If Not InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, FullRegisterName) Then
		ProcessingCompleted = False;
	EndIf;
	
	ProcedureName = FullRegisterName + "." + "ProcessDataForMigrationToNewVersion";
	
	If Processed = 0 And RecordsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Procedure %1 failed to process (skipped) some records: %2.';"), 
			ProcedureName,
			RecordsWithIssuesCount);
		Raise MessageText;
	EndIf;
	
	WriteLogEvent(
		InfobaseUpdate.EventLogEvent(), 
		EventLogLevel.Information, RegisterMetadata, ,
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Procedure %1 processed yet another batch of records: %2.';"),
			ProcedureName,
			Processed));
	
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

#EndRegion

#EndIf
