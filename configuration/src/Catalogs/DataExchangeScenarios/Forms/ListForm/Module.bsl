///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region FormCommandHandlers

&AtClient
Procedure EnableDisableScheduledJob(Command)
	
	SelectedRows = Items.List.SelectedRows;
	
	If SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	ScenariosCollection = New Array;
	For Each RowData In SelectedRows Do
		
		If RowData.DeletionMark Then
			Continue;
		EndIf;
		
		ScenariosCollection.Add(RowData.Ref);
		
	EndDo;
	
	EnableDisableScheduledJobAtServer(ScenariosCollection, Not CurrentData.UseScheduledJob);
	
	// 
	Items.List.Refresh();
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Procedure EnableDisableScheduledJobAtServer(ScenariosCollection, UseScheduledJob)
	
	BeginTransaction();
	Try
		Block = New DataLock;
		For Each Scenario In ScenariosCollection Do
			LockItem = Block.Add("Catalog.DataExchangeScenarios");
			LockItem.SetValue("Ref", Scenario);
		EndDo;
		Block.Lock();
		
		For Each Scenario In ScenariosCollection Do
			LockDataForEdit(Scenario);
			ScenarioObject = Scenario.GetObject(); // CatalogObject.DataExchangeScenarios
			ScenarioObject.UseScheduledJob = UseScheduledJob;
			ScenarioObject.Write();
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion
