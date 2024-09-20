///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

#Region InternalEventsHandlers

#Region StandardSubsystems

#Region Core

// The procedure is a handler for the event of the same name that occurs during data exchange in a distributed
// infobase.
//
// Parameters:
//   see the OnSendDataToMaster() event handler details in Syntax Assistant.
// 
Procedure OnSendDataToMaster(DataElement, ItemSend, Recipient) Export
	
	If ItemSend = DataItemSend.Ignore Then
		//
	ElsIf Common.IsStandaloneWorkplace() Then
		
		If TypeOf(DataElement) = Type("CatalogObject.AdditionalReportsAndDataProcessors") Then
			
			If Not IsServiceProcessing(DataElement.Ref) Then
				ItemSend = DataItemSend.Ignore;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// The procedure is a handler for the event of the same name that occurs during data exchange in a distributed
// infobase.
//
// Parameters:
//   see the OnSendDataToSubordinate() event handler details in the Syntax Assistant.
// 
Procedure OnSendDataToSlave(DataElement, ItemSend, InitialImageCreating, Recipient) Export
	
	If Not Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If ItemSend = DataItemSend.Delete
		Or ItemSend = DataItemSend.Ignore Then
		Return;
	EndIf;
		
	If TypeOf(DataElement) = Type("CatalogObject.AdditionalReportsAndDataProcessors") Then
		If AdditionalReportsAndDataProcessorsSaaS.IsSuppliedDataProcessor(DataElement.Ref) Then
			DataProcessorStartupParameters = AdditionalReportsAndDataProcessorsSaaS.DataProcessorToUseAttachmentParameters(DataElement.Ref);
			FillPropertyValues(DataElement, DataProcessorStartupParameters);
		EndIf;
	EndIf;
	
	If TypeOf(DataElement) = Type("ConstantValueManager.UseAdditionalReportsAndDataProcessors") Then
		If Not InitialImageCreating Then
			ItemSend = DataItemSend.Ignore;
		EndIf;
	EndIf;
	
EndProcedure

// The procedure is a handler for the event of the same name that occurs during data exchange in a distributed
// infobase.
//
// Parameters:
//   see the OnReceiveDataFromMaster() event handler details in Syntax Assistant.
// 
Procedure OnReceiveDataFromMaster(DataElement, ItemReceive, SendBack, Sender) Export
	
	If ItemReceive = DataItemReceive.Ignore Then
		
		// No overriding for standard processing
		
	ElsIf Common.IsStandaloneWorkplace() Then
		
		If TypeOf(DataElement) = Type("CatalogObject.AdditionalReportsAndDataProcessors") Then
			
			If ValueIsFilled(DataElement.Ref) Then
				DataProcessorRef1 = DataElement.Ref;
			Else
				DataProcessorRef1 = DataElement.GetNewObjectRef();
			EndIf;
			
			RegisterServiceProcessing(DataProcessorRef1);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// The procedure is a handler for the event of the same name that occurs during data exchange in a distributed
// infobase.
//
// Parameters:
//   see the OnReceiveDataFromSlave() event handler details in the Syntax Assistant.
// 
Procedure OnReceiveDataFromSlave(DataElement, ItemReceive, SendBack, Sender) Export
	
	If Not Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If ItemReceive = DataItemReceive.Ignore Then
		
		// No overriding for standard processing
		
	Else
		
		If TypeOf(DataElement) = Type("CatalogObject.AdditionalReportsAndDataProcessors") Then
			
			If AdditionalReportsAndDataProcessorsSaaS.IsSuppliedDataProcessor(DataElement.Ref) Then
				
				DataProcessorStartupParameters = AdditionalReportsAndDataProcessorsSaaS.DataProcessorToUseAttachmentParameters(DataElement.Ref);
				FillPropertyValues(DataElement, DataProcessorStartupParameters);
				DataElement.DataProcessorStorage = Undefined;
				
			Else
				
				If Not GetFunctionalOption("IndependentUsageOfAdditionalReportsAndDataProcessorsSaaS") Then
					ItemReceive = DataItemReceive.Ignore;
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region AdditionalReportsAndDataProcessors

// Call to determine whether the current user has right to add an additional
// report or data processor to a data area.
//
// Parameters:
//  AdditionalDataProcessor - 
//    
//  Result - Boolean - indicates whether the required rights are granted.
//  StandardProcessing - Boolean - flag specifying whether
//    standard processing is used to validate rights.
//
Procedure OnCheckInsertRight(Val AdditionalDataProcessor, Result, StandardProcessing) Export
	
	If Common.IsStandaloneWorkplace() Then
		
		Result = True;
		StandardProcessing = False;
		Return;
		
	EndIf;
	
EndProcedure

// Called to check whether an additional report or data processor can be imported from file.
//
// Parameters:
//  AdditionalDataProcessor - CatalogRef.AdditionalReportsAndDataProcessors,
//  Result - Boolean - indicates whether additional reports or data processors can be
//    imported from files.
//  StandardProcessing - Boolean - indicates whether
//    standard processing checks if additional reports or data processors can be imported from files.
//
Procedure OnCheckCanImportDataProcessorFromFile(Val AdditionalDataProcessor, Result, StandardProcessing) Export
	
	SetPrivilegedMode(True);
	
	If Common.IsStandaloneWorkplace() Then
		
		Result = Not IsServiceProcessing(AdditionalDataProcessor);
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// Called to check whether an additional report or data processor can be exported to a file.
//
// Parameters:
//  AdditionalDataProcessor - CatalogRef.AdditionalReportsAndDataProcessors,
//  Result - Boolean - indicates whether additional reports or data processors can be
//    exported to files.
//  StandardProcessing - Boolean - indicates whether
//    standard processing checks if additional reports or data processors can be exported to files.
//
Procedure OnCheckCanExportDataProcessorToFile(Val AdditionalDataProcessor, Result, StandardProcessing) Export
	
	SetPrivilegedMode(True);
	
	If Common.IsStandaloneWorkplace() Then
		
		Result = Not IsServiceProcessing(AdditionalDataProcessor);
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// Fills additional report or data processor publication kinds that cannot be used
// in the current infobase model.
//
// Parameters:
//  NotAvailablePublicationKinds - Array of String
//
Procedure OnFillUnavailablePublicationKinds(Val NotAvailablePublicationKinds) Export
	
	If Common.IsStandaloneWorkplace() Then
		NotAvailablePublicationKinds.Add("DebugMode");
	EndIf;
	
EndProcedure

// The procedure is called from the BeforeWrite event of catalog
//  AdditionalReportsAndDataProcessors. Validates changes to the catalog item
//  attributes for additional data processors retrieved from the
//  additional data processor directory from the service manager.
//
// Parameters:
//  Source - CatalogObject.AdditionalReportsAndDataProcessors,
//  Cancel - Boolean - indicates whether writing a catalog item must be canceled.
//
Procedure BeforeWriteAdditionalDataProcessor(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Common.IsStandaloneWorkplace() Then
		
		If (Source.DeletionMark Or Source.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.isDisabled) And IsServiceProcessing(Source.Ref) Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Additional report or data processor %1 was imported from the service and cannot be disabled from the standalone workstation.
					|To remove the additional report or data processor, perform a disconnection operation
					|in the service application and synchronize the standalone workstation data with the service.';"),
				Source.Description);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#EndRegion

#EndRegion

#Region Private

// It registers an additional report or a data processor as a data processor received
// to a standalone workstation from the service.
//
// Parameters:
//  Ref - CatalogRef.AdditionalReportsAndDataProcessors
//
Procedure RegisterServiceProcessing(Val Ref)
	
	Set = InformationRegisters.UseAdditionalReportsAndServiceProcessorsAtStandaloneWorkstation.CreateRecordSet();
	Set.Filter.AdditionalReportOrDataProcessor.Set(Ref);
	Record = Set.Add();
	Record.AdditionalReportOrDataProcessor = Ref;
	Record.Supplied = True;
	Set.Write();
	
EndProcedure

// The function checks whether an additional data processor was received to a standalone workstation from the service.
//
// Parameters:
//   Ref - CatalogRef.AdditionalReportsAndDataProcessors
//
// Returns:
//  Boolean
//
Function IsServiceProcessing(Ref)
	
	Manager = InformationRegisters.UseAdditionalReportsAndServiceProcessorsAtStandaloneWorkstation.CreateRecordManager();
	Manager.AdditionalReportOrDataProcessor = Ref;
	Manager.Read();
	
	If Manager.Selected() Then
		Return Manager.Supplied;
	Else
		Return False;
	EndIf;
	
EndFunction

#EndRegion
