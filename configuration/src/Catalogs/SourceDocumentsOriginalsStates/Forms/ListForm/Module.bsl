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

	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlers

&AtClient
Procedure ListOnChange(Item)
	
	RefreshReusableValues();
	Notify("AddDeleteSourceDocumentOriginalState");
	
EndProcedure

#EndRegion


#Region FormCommandHandlers

// Standard subsystems.Pluggable commands

// Parameters:
//  Command - FormCommand
//
&AtClient
Procedure Attachable_ExecuteCommand(Command)

	CurrentData = Items.List.CurrentData;

	If Command.Name = "ItemsOrderSetupCommon__Down" Or Command.Name = "ItemsOrderSetupCommon__Up" Then
		If CurrentData.Ref = PredefinedValue("Catalog.SourceDocumentsOriginalsStates.FormPrinted")
			Or CurrentData.Ref = PredefinedValue("Catalog.SourceDocumentsOriginalsStates.OriginalReceived") Then
			ShowMessageBox(,NStr("en = 'Cannot move the initial and final state.';"));
		Else

			If Command.Name = "ItemsOrderSetupCommon__Down" Then
				Move = CanMove("Down",CurrentData.AddlOrderingAttribute);
			ElsIf Command.Name = "ItemsOrderSetupCommon__Up" Then
				Move = CanMove("Up",CurrentData.AddlOrderingAttribute);
			EndIf;

			If Move Then
				 AttachableCommandsClient.StartCommandExecution(ThisObject, Command, Items.List);
			Else
				ShowMessageBox(,NStr("en = 'Cannot move the initial and final state.';"));
			EndIf;

		EndIf;
	Else
		AttachableCommandsClient.StartCommandExecution(ThisObject, Command, Items.List);
 	EndIf;

EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export

    ExecuteCommandAtServer(ExecutionParameters);

EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)

    AttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Items.List);

EndProcedure
&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
EndProcedure
//End StandardSubsystems.AttachableCommands

#EndRegion

#Region Private

&AtServer
Function CanMove(Move, OrderNumber);

	Query = New Query;
	Query.Text ="SELECT
	              |	SourceDocumentsOriginalsStates.Ref AS Ref
	              |FROM
	              |	Catalog.SourceDocumentsOriginalsStates AS SourceDocumentsOriginalsStates
	              |WHERE
	              |	SourceDocumentsOriginalsStates.AddlOrderingAttribute > &OrderNumber
	              |	AND SourceDocumentsOriginalsStates.Ref <> VALUE(Catalog.SourceDocumentsOriginalsStates.FormPrinted)
	              |	AND SourceDocumentsOriginalsStates.Ref <> VALUE(Catalog.SourceDocumentsOriginalsStates.OriginalsNotAll)
	              |	AND SourceDocumentsOriginalsStates.Ref <> VALUE(Catalog.SourceDocumentsOriginalsStates.OriginalReceived)";

	If Move = "Up" Then
		Query.Text = StrReplace(Query.Text,"> &OrderNumber","< &OrderNumber");
	EndIf;

	Query.SetParameter("OrderNumber", OrderNumber);
	
	Selection = Query.Execute();

	If Not Selection.IsEmpty() Then
		Return True;
	Else
		Return False;
	EndIf;

EndFunction

#EndRegion
