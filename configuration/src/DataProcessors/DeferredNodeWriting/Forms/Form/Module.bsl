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
	
	If Not Parameters.Property("Node") Then
		Raise NStr("en = 'The data processor cannot be opened manually.';");
	EndIf;
	
	Node = Parameters.Node;
	NodeStructureAddress = Parameters.NodeStructureAddress;
	
	IsStandaloneWorkstation = DataExchangeCached.IsStandaloneWorkstationNode(Node);
	
	TitleTemplate1 = NStr("en = 'Saving the ""%1"" node';");
	Title = StrTemplate(TitleTemplate1, String(Node)); 
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	TimeConsumingOperation = StartProcedureExecution();
	
	CompletionNotification2 = New NotifyDescription("ProcessResult", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CompletionNotification2, IdleParameters());

EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure DoneCommand(Command)
	Close();
EndProcedure

&AtClient
Procedure CloseCommand(Command)
	Close();
EndProcedure

#EndRegion

#Region Private

&AtClient
Function IdleParameters()
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.MessageText = "";
	IdleParameters.OutputProgressBar = False;
	IdleParameters.OutputIdleWindow = False;
	IdleParameters.OutputMessages = False;
	Return IdleParameters;
	
EndFunction

&AtServer
Function StartProcedureExecution()
	
	ExecutionParameters = TimeConsumingOperations.ProcedureExecutionParameters();
	DescriptionTemplate1 = NStr("en = '""Long """"%1"""" node saving';");
	ExecutionParameters.BackgroundJobDescription = StrTemplate(DescriptionTemplate1, String(Node));
	ExecutionParameters.BackgroundJobKey = "DeferredNodeWriting";
	
	StructureNode = GetFromTempStorage(NodeStructureAddress);
	Return TimeConsumingOperations.ExecuteProcedure(ExecutionParameters, "DataProcessors.DeferredNodeWriting.WriteANode", Node, StructureNode);
		
EndFunction

&AtClient
Procedure ProcessResult(Result, AdditionalParameters) Export
	
	If Result.Status = "Completed2" Then
		
		Items.PanelMain.CurrentPage = Items.EndPage;
		
		If IsStandaloneWorkstation Then
			Notify("Write_StandaloneWorkstation");
		Else
			Notify("Write_ExchangePlanNode");
		EndIf;
		
	ElsIf Result.Status = "Error" Then
		
		CommonClient.MessageToUser(Result.BriefErrorDescription);
		Items.PanelMain.CurrentPage = Items.ErrorPage;
		
	EndIf;
	
EndProcedure 

#EndRegion
