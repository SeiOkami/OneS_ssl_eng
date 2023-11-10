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
Procedure CommandProcessing(Variants, CommandExecuteParameters)
	If TypeOf(Variants) <> Type("Array") Or Variants.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'Select report options to reset custom settings.';"));
		Return;
	EndIf;
	
	OpenForm("Catalog.ReportsOptions.Form.UserSettingsReset",
		New Structure("Variants", Variants), CommandExecuteParameters.Source);
EndProcedure

#EndRegion
