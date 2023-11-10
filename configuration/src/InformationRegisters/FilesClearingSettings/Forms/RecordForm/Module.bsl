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
	
	Title = NStr("en = 'File cleanup settings:';")
		+ " " + Record.FileOwner;
	
	If AttributesArrayWithDateType.Count() = 0 Then
		Items.AddConditionByDate.Enabled = False;
	EndIf;
	
	If Common.IsMobileClient() Then
		Items.SettingRuleFilterColumnGroupApply.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	CurrentObject.FilterRule = New ValueStorage(Rule.GetSettings());
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If ValueIsFilled(CurrentObject.FileOwner) Then
		InitializeComposer();
	EndIf;
	If CurrentObject.FilterRule.Get() <> Undefined Then
		Rule.LoadSettings(CurrentObject.FilterRule.Get());
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceSource.FormName = "InformationRegister.FilesClearingSettings.Form.AddConditionsByDate" Then
		AddToFilterIntervalException(ValueSelected);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure InitializeComposer()
	
	If Not ValueIsFilled(Record.FileOwner) Then
		Return;
	EndIf;
	
	Rule.Settings.Filter.Items.Clear();
	
	DCS = New DataCompositionSchema;
	DataSource = DCS.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "Local";
	
	DataSet = DCS.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Name = "DataSet1";
	DataSet.DataSource = DataSource.Name;
	
	DCS.TotalFields.Clear();
	
	DCS.DataSets[0].Query = GetQueryText();
	
	DataCompositionSchema = PutToTempStorage(DCS, UUID);
	
	Rule.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
	
	Rule.Refresh(); 
	Rule.Settings.Structure.Clear();
	
EndProcedure

&AtServer
Function GetQueryText()
	
	AttributesArrayWithDateType.Clear();
	If TypeOf(Record.FileOwner) = Type("CatalogRef.MetadataObjectIDs") Then
		ObjectType = Record.FileOwner;
	Else
		ObjectType = Common.MetadataObjectID(TypeOf(Record.FileOwner));
	EndIf;
	AllCatalogs = Catalogs.AllRefsType();
	AllDocuments = Documents.AllRefsType();

	QueryText = 
		"SELECT
		|	&FileOwnerFields
		|FROM
		|	&FullNameFileOwner";
	
	FileOwnerFields = ObjectType.Name + ".Ref";
	If AllCatalogs.ContainsType(TypeOf(ObjectType.EmptyRefValue)) Then
		Catalog = Metadata.Catalogs[ObjectType.Name];
		For Each Attribute In Catalog.Attributes Do
			FileOwnerFields = FileOwnerFields + "," + Chars.LF + ObjectType.Name + "." + Attribute.Name;
		EndDo;
	ElsIf
		AllDocuments.ContainsType(TypeOf(ObjectType.EmptyRefValue)) Then
		Document = Metadata.Documents[ObjectType.Name];
		For Each Attribute In Document.Attributes Do
			FileOwnerFields = FileOwnerFields + "," + Chars.LF + ObjectType.Name + "." + Attribute.Name;
			If Attribute.Type.ContainsType(Type("Date")) Then
				AttributesArrayWithDateType.Add(Attribute.Name, Attribute.Synonym);
				FileOwnerFields = FileOwnerFields + "," + Chars.LF 
					+ StrReplace("DATEDIFF(&AttributeName, &CurrentDate, DAY) AS DaysBeforeDeletionFrom&AttributeName",
						"&AttributeName", Attribute.Name);
			EndIf;
		EndDo;
	EndIf;
	
	QueryText = StrReplace(QueryText, "&FileOwnerFields", FileOwnerFields);
	QueryText = StrReplace(QueryText, "&FullNameFileOwner", ObjectType.FullName + " AS " + ObjectType.Name);
	Return QueryText;
	
EndFunction

&AtClient
Procedure AddConditionByDate(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ArrayOfValues", AttributesArrayWithDateType);
	OpenForm("InformationRegister.FilesClearingSettings.Form.AddConditionsByDate", FormParameters, ThisObject);
	
EndProcedure

&AtServer
Procedure AddToFilterIntervalException(ValueSelected)
	
	FilterByInterval = Rule.Settings.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterByInterval.LeftValue = New DataCompositionField("DaysBeforeDeletionFrom" + ValueSelected.DateTypeAttribute);
	FilterByInterval.ComparisonType = DataCompositionComparisonType.GreaterOrEqual;
	FilterByInterval.RightValue = ValueSelected.IntervalException;
	PresentationOfAttributeWithDateType = AttributesArrayWithDateType.FindByValue(ValueSelected.DateTypeAttribute).Presentation;
	PresentationText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Clean up after %1 days since %2';"), 
		ValueSelected.IntervalException, PresentationOfAttributeWithDateType);
	FilterByInterval.Presentation = PresentationText;

EndProcedure

#EndRegion