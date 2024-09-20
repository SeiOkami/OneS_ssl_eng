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
Procedure CommandProcessing(OptionRef1, CommandExecuteParameters)
	Variant = OptionRef1;
	Form = CommandExecuteParameters.Source;
	If TypeOf(Form) = Type("ClientApplicationForm") Then
		If Form.FormName = "Catalog.ReportsOptions.Form.ListForm" Then
			Variant = Form.Items.List.CurrentData;
		ElsIf Form.FormName = "Catalog.ReportsOptions.Form.ItemForm" Then
			Variant = Form.Object;
		EndIf;
	Else
		Form = Undefined;
	EndIf;
	
	ReportsOptionsClient.OpenReportForm(Form, Variant);
EndProcedure

#EndRegion
