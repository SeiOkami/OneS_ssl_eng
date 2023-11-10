///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	FormParameters.Insert("AuthorizationObject", CommandParameter);
	
	Try
		OpenForm(
			"Catalog.ExternalUsers.ObjectForm",
			FormParameters,
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness,
			CommandExecuteParameters.Window);
	Except
		ErrorInfo = ErrorInfo();
		If StrFind(ErrorProcessing.DetailErrorDescription(ErrorInfo),
		         "CauseTheException" + " " + "ErrorAsWarningDetails") > 0 Then
			
			ShowMessageBox(, ErrorProcessing.BriefErrorDescription(ErrorInfo));
		Else
			Raise;
		EndIf;
	EndTry;
	
EndProcedure

#EndRegion
