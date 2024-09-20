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

	OriginalStates = SourceDocumentsOriginalsRecording.AllStates();
	For Each State In OriginalStates Do 
		OriginalStatesList.Add(State,,False);
	EndDo;
	OriginalStatesList.Add("Statesnotable",NStr("en = '<Unknown state>';"),False);

	If Parameters.Property("StatesList") Then
		For Each State In Parameters.StatesList Do
			 FoundState = OriginalStatesList.FindByValue(State.Value);
			 If Not FoundState = Undefined Then
				FoundState.Check=True;
			EndIf;
		EndDo;
	EndIf;


EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)

	NotifyChoice(OriginalStatesList);

EndProcedure

&AtClient
Procedure SelectAllCheckBoxes(Command)

	For Each CurrentFilter In OriginalStatesList Do
		CurrentFilter.Check = True;
	EndDo;

EndProcedure

&AtClient
Procedure ClearAllCheckBoxes(Command)

	For Each CurrentFilter In OriginalStatesList Do
		CurrentFilter.Check = False;
	EndDo;

EndProcedure

#EndRegion