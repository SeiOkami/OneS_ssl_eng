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
	
	If Not Users.IsFullUser(Undefined, True, False) Then
		Raise NStr("en = 'Insufficient rights to administer data exchange.';");
	EndIf;
	
	SetPrivilegedMode(True);
	
	RefreshNodesStatesList();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure GoToDataExportEventLog(Command)
	
	CurrentData = Items.NodesStateList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.InfobaseNode = Undefined Then
		Return;
	EndIf;
	
	DataExchangeClient.GoToDataEventLogModally(CurrentData.InfobaseNode, ThisObject, "DataExport");
	
EndProcedure

&AtClient
Procedure GoToDataImportEventLog(Command)
	
	CurrentData = Items.NodesStateList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.InfobaseNode = Undefined Then
		Return;
	EndIf;
	
	DataExchangeClient.GoToDataEventLogModally(CurrentData.InfobaseNode, ThisObject, "DataImport");
	
EndProcedure

&AtClient
Procedure RefreshScreen(Command)
	
	RefreshMonitorData();
	
EndProcedure

&AtClient
Procedure More(Command)
	
	DetailsAtServer();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure RefreshNodesStatesList()
	
	NodesStateList.Clear();
	
	NodesStateList.Load(
		DataExchangeSaaS.DataExchangeMonitorTable(DataExchangeCached.SeparatedSSLExchangePlans()));
		
EndProcedure

&AtClient
Procedure RefreshMonitorData()
	
	NodesStatesListRowIndex = GetCurrentRowIndex();
	
	// Updating monitor tables on the server
	RefreshNodesStatesList();
	
	// positioning a mouse pointer positioning
	ExecuteCursorPositioning(NodesStatesListRowIndex);
	
EndProcedure

&AtClient
Function GetCurrentRowIndex()
	
	// Function return value.
	RowIndex = Undefined;
	
	// Positioning the mouse pointer upon the monitor update
	CurrentData = Items.NodesStateList.CurrentData;
	
	If CurrentData <> Undefined Then
		
		RowIndex = NodesStateList.IndexOf(CurrentData);
		
	EndIf;
	
	Return RowIndex;
EndFunction

&AtClient
Procedure ExecuteCursorPositioning(RowIndex)
	
	If RowIndex <> Undefined Then
		
		// Checking the mouse pointer position once new data is received
		If NodesStateList.Count() <> 0 Then
			
			If RowIndex > NodesStateList.Count() - 1 Then
				
				RowIndex = NodesStateList.Count() - 1;
				
			EndIf;
			
			// 
			Items.NodesStateList.CurrentRow = NodesStateList[RowIndex].GetID();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DetailsAtServer()
	
	Items.NodesStateListDetailed.Check = Not Items.NodesStateListDetailed.Check;
	
	Items.NodesStatesListLastSuccessfulExportDate.Visible = Items.NodesStateListDetailed.Check;
	Items.NodesStatesListLastSuccessfulImportDate.Visible = Items.NodesStateListDetailed.Check;
	Items.NodesStateListExchangePlanName.Visible = Items.NodesStateListDetailed.Check;
	
EndProcedure

#EndRegion