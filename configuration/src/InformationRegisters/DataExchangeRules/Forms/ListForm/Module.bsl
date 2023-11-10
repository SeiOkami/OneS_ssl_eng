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
	
	If Parameters.Property("ExchangePlansWithRulesFromFile") Then
		
		Items.RulesSource.Visible = False;
		CommonClientServer.SetDynamicListFilterItem(
			List,
			"RulesSource",
			Enums.DataExchangeRulesSources.File,
			DataCompositionComparisonType.Equal);
		
	EndIf;
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListBeforeDeleteRow(Item, Cancel)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure UpdateAllStandardRules(Command)
	
	UpdateAllStandardRulesAtServer();
	Items.List.Refresh();
	
	ShowUserNotification(NStr("en = 'The rule update is completed.';"));
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure UpdateAllStandardRulesAtServer()
	
	DataExchangeServer.UpdateDataExchangeRules();
	
	RefreshReusableValues();
	
EndProcedure

&AtClient
Procedure UseStandardRules(Command)
	UseStandardRulesAtServer();
	Items.List.Refresh();
	ShowUserNotification(NStr("en = 'The rule update is completed.';"));
EndProcedure

&AtServer
Procedure UseStandardRulesAtServer()
	
	For Each Record In Items.List.SelectedRows Do
		RecordManager = InformationRegisters.DataExchangeRules.CreateRecordManager();
		FillPropertyValues(RecordManager, Record);
		RecordManager.Read();
		RecordManager.RulesSource = Enums.DataExchangeRulesSources.ConfigurationTemplate;
		HasErrors = False;
		InformationRegisters.DataExchangeRules.ImportRules(HasErrors, RecordManager);
		If Not HasErrors Then
			RecordManager.Write();
		EndIf;
	EndDo;
	
	DataExchangeInternal.ResetObjectsRegistrationMechanismCache();
	RefreshReusableValues();
	
EndProcedure

#EndRegion
