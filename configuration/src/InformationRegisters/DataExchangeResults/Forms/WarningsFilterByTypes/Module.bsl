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
	Var SelectingTypesOfWarnings;
	
	TheVersioningSubsystemExists = Common.SubsystemExists("StandardSubsystems.ObjectsVersioning");
	
	ValuesCache = New Structure;
	ValuesCache.Insert("TheVersioningSubsystemExists", TheVersioningSubsystemExists);
	ValuesCache.Insert("RejectedConflictData", Undefined);
	ValuesCache.Insert("ConflictDataAccepted", Undefined);
	ValuesCache.Insert("RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase", Undefined);
	ValuesCache.Insert("RejectedDueToPeriodEndClosingDateObjectExistsInInfobase", Undefined);
	ValuesCache.Insert("IsExchangeMessageOutsideOfArchive", Undefined);
	
	If TheVersioningSubsystemExists Then
		
		EnumManager = Enums["ObjectVersionTypes"];
		ValuesCache.RejectedConflictData = EnumManager.RejectedConflictData;
		ValuesCache.ConflictDataAccepted = EnumManager.ConflictDataAccepted;
		ValuesCache.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase = EnumManager.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase;
		ValuesCache.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase = EnumManager.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase;
		
		Items.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase.Visible = True;
		Items.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase.Visible = True;
		Items.ConflictDataAccepted.Visible = True;
		Items.RejectedConflictData.Visible = True;
		
	EndIf;
	
	Parameters.Property("SelectingTypesOfWarnings", SelectingTypesOfWarnings);
	ValuesForSelectingWarningTypesInTheFormDetails(SelectingTypesOfWarnings);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	MatchingBankDetails = New Map;
	MatchingBankDetails.Insert("ApplicationAdministrativeError", PredefinedValue("Enum.DataExchangeIssuesTypes.ApplicationAdministrativeError"));
	MatchingBankDetails.Insert("BlankAttributes", PredefinedValue("Enum.DataExchangeIssuesTypes.BlankAttributes"));
	MatchingBankDetails.Insert("UnpostedDocument", PredefinedValue("Enum.DataExchangeIssuesTypes.UnpostedDocument"));
	MatchingBankDetails.Insert("CheckErrorBeforeSendXTDO", PredefinedValue("Enum.DataExchangeIssuesTypes.ConvertedObjectValidationError"));
	MatchingBankDetails.Insert("HandlersCodeExecutionErrorOnGetData", PredefinedValue("Enum.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnGetData"));
	MatchingBankDetails.Insert("HandlersCodeExecutionErrorOnSendData", PredefinedValue("Enum.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnSendData"));
	MatchingBankDetails.Insert("IsExchangeMessageOutsideOfArchive", PredefinedValue("Enum.DataExchangeIssuesTypes.IsExchangeMessageOutsideOfArchive"));
	
	If ValuesCache.TheVersioningSubsystemExists Then
		
		MatchingBankDetails.Insert("RejectedConflictData", ValuesCache.RejectedConflictData);
		MatchingBankDetails.Insert("ConflictDataAccepted", ValuesCache.ConflictDataAccepted);
		MatchingBankDetails.Insert("RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase", ValuesCache.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase);
		MatchingBankDetails.Insert("RejectedDueToPeriodEndClosingDateObjectExistsInInfobase", ValuesCache.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase);
		
	EndIf;
	
	SelectingTypesOfWarnings = New Array;
	For Each MapValue In MatchingBankDetails Do
		
		If ThisObject[MapValue.Key] Then
			
			SelectingTypesOfWarnings.Add(MapValue.Value);
			
		EndIf;
		
	EndDo;
	
	Close(SelectingTypesOfWarnings);
	
EndProcedure

&AtClient
Procedure Reset(Command)
	
	ApplicationAdministrativeError = False;
	BlankAttributes = False;
	UnpostedDocument = False;
	CheckErrorBeforeSendXTDO = False;
	HandlersCodeExecutionErrorOnGetData = False;
	HandlersCodeExecutionErrorOnSendData = False;
	RejectedConflictData = False;
	RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase = False;
	RejectedDueToPeriodEndClosingDateObjectExistsInInfobase = False;
	ConflictDataAccepted = False;
	IsExchangeMessageOutsideOfArchive = False;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure ValuesForSelectingWarningTypesInTheFormDetails(SelectingTypesOfWarnings)
	
	If TypeOf(SelectingTypesOfWarnings) <> Type("Array") Then
		
		Return;
		
	EndIf;
		
	MatchingBankDetails = New Map;
	MatchingBankDetails.Insert(Enums.DataExchangeIssuesTypes.ApplicationAdministrativeError, "ApplicationAdministrativeError");
	MatchingBankDetails.Insert(Enums.DataExchangeIssuesTypes.BlankAttributes, "BlankAttributes");
	MatchingBankDetails.Insert(Enums.DataExchangeIssuesTypes.UnpostedDocument, "UnpostedDocument");
	MatchingBankDetails.Insert(Enums.DataExchangeIssuesTypes.ConvertedObjectValidationError, "CheckErrorBeforeSendXTDO");
	MatchingBankDetails.Insert(Enums.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnGetData, "HandlersCodeExecutionErrorOnGetData");
	MatchingBankDetails.Insert(Enums.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnSendData, "HandlersCodeExecutionErrorOnSendData");
	MatchingBankDetails.Insert(Enums.DataExchangeIssuesTypes.IsExchangeMessageOutsideOfArchive, "IsExchangeMessageOutsideOfArchive");
	
	If ValuesCache.TheVersioningSubsystemExists Then
		
		MatchingBankDetails.Insert(ValuesCache.RejectedConflictData, "RejectedConflictData");
		MatchingBankDetails.Insert(ValuesCache.ConflictDataAccepted, "ConflictDataAccepted");
		MatchingBankDetails.Insert(ValuesCache.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase, "RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase");
		MatchingBankDetails.Insert(ValuesCache.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase, "RejectedDueToPeriodEndClosingDateObjectExistsInInfobase");
		
	EndIf;
	
	For Each WarningType In SelectingTypesOfWarnings Do
		
		ThisObject[MatchingBankDetails[WarningType]] = True;
		
	EndDo;
	
EndProcedure

#EndRegion