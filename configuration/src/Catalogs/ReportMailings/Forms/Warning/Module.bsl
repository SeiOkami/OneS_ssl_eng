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
	
	SetHeader();
	SetDescription();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure GoToDocumentation(Command)
	
	ModuleEmailOperationsClient = CommonClient.CommonModule("EmailOperationsClient");
	ModuleEmailOperationsClient.GoToEmailAccountInputDocumentation();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetHeader()
	
	TitleText = CommonClientServer.StructureProperty(Parameters, "Title");
	
	If ValueIsFilled(TitleText) Then 
		Title = TitleText;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetDescription()
	
	LongDesc = New Structure("Text, More, Ref");
	FillPropertyValues(LongDesc, Parameters);
	
	Items.GoToDocumentation.Visible =
		Common.SubsystemExists("StandardSubsystems.EmailOperations")
		And ValueIsFilled(LongDesc.More)
		And CommonClientServer.StructureProperty(Parameters, "UseEmail", False);
	
	If Not ValueIsFilled(LongDesc.Text) Then 
		Return;
	EndIf;
	
	Text.Add(LongDesc.Text, Type("FormattedDocumentText"));
	
	If ValueIsFilled(LongDesc.More) Then 
		
		Text.Add(, Type("FormattedDocumentLinefeed"));
		Text.Add(, Type("FormattedDocumentLinefeed"));
		Text.Add(LongDesc.More, Type("FormattedDocumentText"));
		
		Items.Indicator.Picture = PictureLib.Warning32;
		
	EndIf;
	
	SetAuthenticationErrorDescription(LongDesc);
	
EndProcedure

&AtServer
Procedure SetAuthenticationErrorDescription(LongDesc)
	
	If StrFind(Upper(LongDesc.More), "USERNAME AND PASSWORD NOT ACCEPTED") = 0 Then 
		Return;
	EndIf;
	
	Text.Add(, Type("FormattedDocumentLinefeed"));
	Text.Add(, Type("FormattedDocumentLinefeed"));
	
	Ref = CommonClientServer.StructureProperty(Parameters, "Ref");
	
	If ValueIsFilled(Ref) Then 
		
		StringPattern = NStr("en = 'Go to <a href = ""%1"">email account settings</a> to correct the username and password.';");
		URL = GetURL(Ref);
		
		String = StringFunctions.FormattedString(StringPattern, URL);
		
	Else
		
		String = NStr("en = 'Go to email account settings to correct the username and password.';");
		
	EndIf;
	
	Rows = New Array;
	Rows.Add(Text.GetFormattedString());
	Rows.Add(String);
	
	Text.SetFormattedString(New FormattedString(Rows));
	
EndProcedure

#EndRegion