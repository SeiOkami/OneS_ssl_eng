///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// See also InfobaseUpdateOverridable.OnSetUpInitialItemsFilling.
// 
// Parameters:
//  Settings - See InfobaseUpdateOverridable.OnSetUpInitialItemsFilling.Settings
//
Procedure OnSetUpInitialItemsFilling(Settings) Export

	Settings.OnInitialItemFilling = False;

EndProcedure

// See also InfobaseUpdateOverridable.OnInitialItemsFilling
// 
// Parameters:
//   LanguagesCodes - See InfobaseUpdateOverridable.OnInitialItemsFilling.LanguagesCodes
//   Items - See InfobaseUpdateOverridable.OnInitialItemsFilling.Items
//   TabularSections - See InfobaseUpdateOverridable.OnInitialItemsFilling.TabularSections
//
Procedure OnInitialItemsFilling(LanguagesCodes, Items, TabularSections) Export

	Item = Items.Add();
	Item.PredefinedDataName = "FormPrinted";
	Item.Description = NStr("en = 'Form printed';", Common.DefaultLanguageCode());
	Item.LongDesc = NStr("en = 'State that means that the print form was printed only.';", Common.DefaultLanguageCode());
	Item.Code = "000000001";
	Item.AddlOrderingAttribute = "1";

	Item = Items.Add();
	Item.PredefinedDataName = "OriginalsNotAll";
	Item.Description = NStr("en = 'Not all originals';", Common.DefaultLanguageCode());
	Item.LongDesc = NStr("en = 'Overall state of a document whose print form originals have different states.';", Common.DefaultLanguageCode());
	Item.Code = "000000002";
	Item.AddlOrderingAttribute = "99998";

	Item = Items.Add();
	Item.PredefinedDataName = "OriginalReceived";
	Item.Description = NStr("en = 'Original received';", Common.DefaultLanguageCode());
	Item.LongDesc = NStr("en = 'State that means that the signed print form original is available.';", Common.DefaultLanguageCode());
	Item.Code = "000000003";
	Item.AddlOrderingAttribute = "99999";

EndProcedure


////////////////////////////////////////////////////////////////////////////////
// Update handlers.

// Registers in the InfobaseUpdate exchange plan the objects to update.
// 
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	SourceDocumentsOriginalsStates.Ref AS Ref
		|FROM
		|	Catalog.SourceDocumentsOriginalsStates AS SourceDocumentsOriginalsStates
		|
		|ORDER BY
		|	SourceDocumentsOriginalsStates.AddlOrderingAttribute";
	
	Result = Query.Execute().Unload();
	ReferencesArrray = Result.UnloadColumn("Ref");
	
	InfobaseUpdate.MarkForProcessing(Parameters, ReferencesArrray);
	
EndProcedure

// Set value for attribute AddlOrderingAttribute of catalog SourceDocumentsOriginalsStates.
// 
Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
		
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, "Catalog.SourceDocumentsOriginalsStates");
	
	StateOfOrder = New ValueTable();
	StateOfOrder.Columns.Add("Ref");
	StateOfOrder.Columns.Add("Order");

	While Selection.Next() Do
		CurState = StateOfOrder.Add();
		CurState.Ref = Selection.Ref;
		CurState.Order = Selection.Ref.AddlOrderingAttribute;
	EndDo;
	
	StateOfOrder.Sort("Order");
	
	ObjectsWithIssuesCount = 0;
	ObjectsProcessed = 0;
	
	Order = 2;
	
	For Each IsmStatus In StateOfOrder Do
		RepresentationOfTheReference = String(IsmStatus.Ref);
		Try
			
			If IsmStatus.Ref = Catalogs.SourceDocumentsOriginalsStates.FormPrinted Then
				FillInTheDetailsOfTheAdditionalOrderingDetails(IsmStatus, 1);
				ObjectsProcessed = ObjectsProcessed + 1;
			ElsIf IsmStatus.Ref = Catalogs.SourceDocumentsOriginalsStates.OriginalsNotAll Then
				FillInTheDetailsOfTheAdditionalOrderingDetails(IsmStatus, 99998);
				ObjectsProcessed = ObjectsProcessed + 1;
			ElsIf IsmStatus.Ref = Catalogs.SourceDocumentsOriginalsStates.OriginalReceived Then
			    FillInTheDetailsOfTheAdditionalOrderingDetails(IsmStatus, 99999);
				ObjectsProcessed = ObjectsProcessed + 1;
			Else
				FillInTheDetailsOfTheAdditionalOrderingDetails(IsmStatus, Order);
				ObjectsProcessed = ObjectsProcessed + 1;
				Order = Order + 1;
			EndIf;
			
		Except
			// 
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process %1 due to:
					|%2';"), 
					RepresentationOfTheReference, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				Metadata.Catalogs.SourceDocumentsOriginalsStates, IsmStatus.Ref, MessageText);
		EndTry;
		
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "Catalog.SourceDocumentsOriginalsStates");
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some states of source document originals: %1';"), 
				ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			Metadata.Catalogs.SourceDocumentsOriginalsStates,,
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Yet another batch of states of source document originals is processed: %1';"),
					ObjectsProcessed));
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// In the passed item, re-populate internal attribute AddlOrderingAttribute.
//
Procedure FillInTheDetailsOfTheAdditionalOrderingDetails(Selection, Order)
	
	BeginTransaction();
	Try
	
		// Lock the object (to ensure that it won't be edited in other sessions).
		Block = New DataLock;
		LockItem = Block.Add("Catalog.SourceDocumentsOriginalsStates");
		LockItem.SetValue("Ref", Selection.Ref);
		Block.Lock();
		
		TheStateOfTheObject = Selection.Ref.GetObject();
		
		// 
		TheStateOfTheObject.AddlOrderingAttribute = Order;
		
		// 
		InfobaseUpdate.WriteData(TheStateOfTheObject);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf

