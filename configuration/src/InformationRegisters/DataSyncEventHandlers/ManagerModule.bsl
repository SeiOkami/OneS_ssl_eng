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

// The procedure registers the need to execute infobase update handlers
// after getting data from each subordinate DIB node.
//
Procedure RegisterInfobaseDataUpdate() Export
	
	SetPrivilegedMode(True);
	
	TextTemplate1 = "ExchangePlan.%1";
	
	DIBExchangePlans = StandardSubsystemsCached.DIBExchangePlans();
	Query = New Query();
	Query.SetParameter("MasterNode", ExchangePlans.MasterNode());
	For Each ExchangePlanName In DIBExchangePlans Do
		If StrFind(DataExchangeServer.ExchangePlanPurpose(ExchangePlanName), "DIB") = 0 Then
			Continue;
		EndIf;
		
		Query.Text =
		"SELECT
		|	ExchangePlan.Ref AS Ref
		|FROM
		|	&ExchangePlanName AS ExchangePlan
		|WHERE
		|	NOT ExchangePlan.ThisNode
		|	AND NOT ExchangePlan.DeletionMark
		|	AND ExchangePlan.Ref <> &MasterNode";
		
		NameOfTheStringExchangePlan = StrTemplate(TextTemplate1, ExchangePlanName);
		Query.Text = StrReplace(Query.Text, "&ExchangePlanName", NameOfTheStringExchangePlan);
		
		NodeSelection = Query.Execute().Select();
		While NodeSelection.Next() Do
			
			RecordStructure = New Structure;
			RecordStructure.Insert("InfobaseNode", NodeSelection.Ref);
			RecordStructure.Insert("Event", "AfterGetData");
			RecordStructure.Insert("Handler", "InfobaseUpdate");
			DataExchangeInternal.AddRecordToInformationRegister(RecordStructure, "DataSyncEventHandlers");
			
		EndDo;
	EndDo;
	
	
EndProcedure

// The procedure executes handlers registered for exchange plan node events.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - an infobase node for handler execution.
//  Event - String - a name of event whose handlers are to be executed.
//
Procedure ExecuteHandlers(InfobaseNode, Event) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "SELECT
	|	Handlers.Handler
	|FROM
	|	InformationRegister.DataSyncEventHandlers AS Handlers
	|WHERE
	|	Handlers.InfobaseNode = &InfobaseNode
	|	AND Handlers.Event = &Event";
	
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.SetParameter("Event", Event);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If Selection.Handler = "InfobaseUpdate" Then
			
			InfobaseUpdateInternal.OnGetFirstDIBExchangeMessageAfterUpdate();
			
			RecordStructure = New Structure;
			RecordStructure.Insert("InfobaseNode", InfobaseNode);
			RecordStructure.Insert("Event", "AfterGetData");
			RecordStructure.Insert("Handler", "InfobaseUpdate");
			DataExchangeInternal.DeleteRecordSetFromInformationRegister(RecordStructure, "DataSyncEventHandlers");
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf