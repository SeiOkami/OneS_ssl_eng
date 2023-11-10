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
Procedure GoToList(Command)
	FormParameters = New Structure;
	FormParameters.Insert("ExchangePlansWithRulesFromFile", True);
	
	OpenForm("InformationRegister.DataExchangeRules.Form.ListForm", FormParameters);
EndProcedure

&AtClient
Procedure CloseForm(Command)
	Close();
EndProcedure

&AtClient
Procedure Checked(Command)
	MarkUserTaskDone();
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure MarkUserTaskDone()
	
	ArrayVersion  = StrSplit(Metadata.Version, ".");
	CurrentVersion = ArrayVersion[0] + ArrayVersion[1] + ArrayVersion[2];
	CommonSettingsStorage.Save("ToDoList", "ExchangePlans", CurrentVersion);
	
EndProcedure

#EndRegion