///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventHandlersForm
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	QueryConsoleID = "QueryConsole";
	
	CurrentObject = ThisObject();
	CurrentObject.ReadSettings();
	CurrentObject.ReadSSLSupportFlags();
	
	String = TrimAll(CurrentObject.QueryExternalDataProcessorAddressSetting);
	If Lower(Right(String, 4)) = ".epf" Then
		QueryConsoleUsageOption = 0;
	ElsIf Metadata.DataProcessors.Find(String) <> Undefined Then
		QueryConsoleUsageOption = 1;
		String = "";	
	Else 
		QueryConsoleUsageOption = 0;
		String = "";
	EndIf;
	CurrentObject.QueryExternalDataProcessorAddressSetting = String;
	
	ThisObject(CurrentObject);
	
	ChoiceList = Items.ExternalQueryDataProcessor.ChoiceList;
	
	// The data processor is included in the metadata if it is a predefined part of the configuration.
	If Metadata.DataProcessors.Find(QueryConsoleID) = Undefined Then
		CurItem = ChoiceList.FindByValue(1);
		If CurItem <> Undefined Then
			ChoiceList.Delete(CurItem);
		EndIf;
	EndIf;
	
	Items.QueryConsole.Visible = (ChoiceList.Count() > 0);
	
	// Option string from the file
	If CurrentObject.IsFileInfobase() Then
		CurItem = ChoiceList.FindByValue(2);
		If CurItem <> Undefined Then
			CurItem.Presentation = NStr("en = 'In directory:';");
		EndIf;
	EndIf;

	// 
	Items.SLGroup.Visible = CurrentObject.ConfigurationSupportsSSL
	
EndProcedure

#EndRegion

#Region FormCommandHandlers
//

&AtClient
Procedure ConfirmSelection(Command)
	
	Validation = CheckSettings();
	If Validation.HasErrors Then
		// Report errors.
		If Validation.QueryExternalDataProcessorAddressSetting <> Undefined Then
			ReportError(Validation.QueryExternalDataProcessorAddressSetting, "Object.QueryExternalDataProcessorAddressSetting");
			Return;
		EndIf;
	EndIf;
	
	// Successful.
	ShouldSaveSettings();
	Close();
EndProcedure

#EndRegion

#Region Private
//

&AtClient
Procedure ReportError(Text, Var_AttributeName = Undefined)
	
	If Var_AttributeName = Undefined Then
		ErrorTitle = NStr("en = 'Error';");
		ShowMessageBox(, Text, , ErrorTitle);
		Return;
	EndIf;
	
	Message = New UserMessage();
	Message.Text = Text;
	Message.Field  = Var_AttributeName;
	Message.SetData(ThisObject);
	Message.Message();
EndProcedure	

&AtServer
Function ThisObject(CurrentObject = Undefined) 
	If CurrentObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(CurrentObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function CheckSettings()
	CurrentObject = ThisObject();
	
	If QueryConsoleUsageOption = 2 Then
		
		CurrentObject.QueryExternalDataProcessorAddressSetting = TrimAll(CurrentObject.QueryExternalDataProcessorAddressSetting);
		If StrStartsWith(CurrentObject.QueryExternalDataProcessorAddressSetting, """")
			And StrEndsWith(CurrentObject.QueryExternalDataProcessorAddressSetting, """") Then
			CurrentObject.QueryExternalDataProcessorAddressSetting = Mid(CurrentObject.QueryExternalDataProcessorAddressSetting, 
				2, StrLen(CurrentObject.QueryExternalDataProcessorAddressSetting) - 2);
		EndIf;
		
		If Not StrEndsWith(Lower(TrimAll(CurrentObject.QueryExternalDataProcessorAddressSetting)), ".epf") Then
			CurrentObject.QueryExternalDataProcessorAddressSetting = TrimAll(CurrentObject.QueryExternalDataProcessorAddressSetting) + ".epf";
		EndIf;
		
	ElsIf QueryConsoleUsageOption = 0 Then
		CurrentObject.QueryExternalDataProcessorAddressSetting = "";
		
	EndIf;
	
	Result = CurrentObject.CheckSettingsCorrectness();
	ThisObject(CurrentObject);
	
	Return Result;
EndFunction

&AtServer
Procedure ShouldSaveSettings()
	CurrentObject = ThisObject();
	If QueryConsoleUsageOption = 0 Then
		CurrentObject.QueryExternalDataProcessorAddressSetting = "";
	ElsIf QueryConsoleUsageOption = 1 Then
		CurrentObject.QueryExternalDataProcessorAddressSetting = QueryConsoleID		;
	EndIf;
	CurrentObject.ShouldSaveSettings();
	ThisObject(CurrentObject);
EndProcedure

#EndRegion
