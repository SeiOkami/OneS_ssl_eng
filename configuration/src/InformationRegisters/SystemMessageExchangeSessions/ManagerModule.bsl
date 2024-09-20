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

// Creates a message exchange session and returns the session ID
//
Function NewSession() Export
	
	Session = New UUID;
	
	RecordStructure = New Structure("Session, StartDate", Session, CurrentUniversalDate());
	
	AddRecord(RecordStructure);
	
	Return Session;
EndFunction

// Gets a session status: Running, Done, or Error.
//
Function SessionStatus(Val Session) Export
	
	QueryText =
	"SELECT
	|	CASE
	|		WHEN SystemMessageExchangeSessions.OperationFailed
	|			THEN ""Error""
	|		WHEN SystemMessageExchangeSessions.OperationSuccessful
	|			THEN ""Success""
	|		ELSE ""Running""
	|	END AS Result
	|FROM
	|	InformationRegister.SystemMessageExchangeSessions AS SystemMessageExchangeSessions
	|WHERE
	|	SystemMessageExchangeSessions.Session = &Session";
	Record = RecordMessagesExchangeSession(QueryText, Session);
	
	Return Record.Result;
	
EndFunction

// Sets the CompletedSuccessfully flag value to True for a session passed to the procedure
//
Procedure CommitSuccessfulSession(Val Session) Export
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Session", Session);
	RecordStructure.Insert("OperationSuccessful", True);
	RecordStructure.Insert("OperationFailed", False);
	
	UpdateRecord(RecordStructure);
	
EndProcedure

// Sets the CompletedWithError flag value to False for a session passed to the procedure
//
Procedure CommitUnsuccessfulSession(Val Session, Val ErrorDescription = "") Export
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Session", Session);
	RecordStructure.Insert("OperationSuccessful", False);
	RecordStructure.Insert("OperationFailed", True);
	RecordStructure.Insert("ErrorDescription", ErrorDescription);
	
	UpdateRecord(RecordStructure);
	
EndProcedure

// Saves session data and sets the CompletedSuccessfully flag value to True
//
Procedure SaveSessionData(Val Session, Data) Export
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Session", Session);
	RecordStructure.Insert("Data", Data);
	RecordStructure.Insert("OperationSuccessful", True);
	RecordStructure.Insert("OperationFailed", False);
	UpdateRecord(RecordStructure);
	
EndProcedure

// Reads session data and deletes the session from the infobase.
//
Function GetSessionData(Val Session) Export
	
	QueryText =
	"SELECT
	|	SystemMessageExchangeSessions.Data AS Data
	|FROM
	|	InformationRegister.SystemMessageExchangeSessions AS SystemMessageExchangeSessions
	|WHERE
	|	SystemMessageExchangeSessions.Session = &Session";
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.SystemMessageExchangeSessions");
		LockItem.SetValue("Session", Session);
		Block.Lock();
		
		Record = RecordMessagesExchangeSession(QueryText, Session);
		
		Result = Record.Data;
		
		DeleteRecord(Session);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Result;
	
EndFunction

// 
//
Function SessionErrorDetails(Val Session) Export
	
	QueryText =
		"SELECT
		|	SystemMessageExchangeSessions.ErrorDescription AS ErrorDescription
		|FROM
		|	InformationRegister.SystemMessageExchangeSessions AS SystemMessageExchangeSessions
		|WHERE
		|	SystemMessageExchangeSessions.Session = &Session";
	
	Record = RecordMessagesExchangeSession(QueryText, Session);
	
	Return Record.ErrorDescription;
	
EndFunction

// Auxiliary procedures and functions

Function RecordMessagesExchangeSession(QueryText, Session)
	
	Query = New Query(QueryText);
	Query.SetParameter("Session", Session);
	
	Selection = Query.Execute().Select();
	
	If Not Selection.Next() Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'System message exchange session with ID %1 not found.';"),
			String(Session));
	EndIf;
	
	Return Selection;
	
EndFunction

Procedure AddRecord(RecordStructure)
	
	DataExchangeInternal.AddRecordToInformationRegister(RecordStructure, "SystemMessageExchangeSessions");
	
EndProcedure

Procedure UpdateRecord(RecordStructure)
	
	DataExchangeInternal.UpdateInformationRegisterRecord(RecordStructure, "SystemMessageExchangeSessions");
	
EndProcedure

Procedure DeleteRecord(Val Session)
	
	DataExchangeInternal.DeleteRecordSetFromInformationRegister(New Structure("Session", Session), "SystemMessageExchangeSessions");
	
EndProcedure

#EndRegion

#EndIf