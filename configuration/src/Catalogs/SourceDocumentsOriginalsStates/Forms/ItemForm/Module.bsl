///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventHandlersForm

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)

	If Not Object.Ref = PredefinedValue("Catalog.SourceDocumentsOriginalsStates.OriginalReceived") 
		And Not Object.Ref = PredefinedValue("Catalog.SourceDocumentsOriginalsStates.FormPrinted")
		And Object.Ref.IsEmpty() Then
		Object.AddlOrderingAttribute = CalculateItemOrder();
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	RefreshReusableValues();
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function CalculateItemOrder()

	Query = New Query;
	Query.Text ="SELECT TOP 1
	              |	SourceDocumentsOriginalsStates.AddlOrderingAttribute AS Order
	              |FROM
	              |	Catalog.SourceDocumentsOriginalsStates AS SourceDocumentsOriginalsStates
	              |WHERE
	              |	SourceDocumentsOriginalsStates.Predefined = FALSE
	              |
	              |ORDER BY
	              |	AddlOrderingAttribute DESC" ;
	
	Selection = Query.Execute().Select();
	Selection.Next();

	If Not Selection.Order = Undefined Then 
		DefaultOrder1 = Selection.Order + 1;
	Else
		DefaultOrder1 = 2;
	EndIf;

	Return DefaultOrder1; 

EndFunction

#EndRegion