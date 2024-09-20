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
	
	SetConditionalAppearance();
	
	Ref = Parameters.Ref;
	
	Items.NoVersions.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Earlier versions are not available: %1.';"), String(Ref));
	RefreshVersionList();
	
	GoToVersionAllowed = Users.IsFullUser() And Not ReadOnly;
	Items.RestoreVersion.Visible = GoToVersionAllowed;
	Items.VersionsTreeContextMenuGoToVersion.Visible = GoToVersionAllowed;
	Items.TechnicalInfoAboutObjectChanges.Visible = GoToVersionAllowed;
	
	Attributes = NStr("en = 'All';");
	Title = NStr("en = 'Change history:';") + " " + Ref;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetAvailability();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AttributesStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	NotifyDescription = New NotifyDescription("OnSelectAttribute", ThisObject);
	OpenForm("InformationRegister.ObjectsVersions.Form.SelectObjectAttributes", New Structure(
		"Ref,Filter", Ref, Filter.UnloadValues()), , , , , NotifyDescription);
EndProcedure

&AtClient
Procedure EventLogClick(Item)
	EventLogFilter = New Structure;
	EventLogFilter.Insert("Data", Ref);
	EventLogClient.OpenEventLog(EventLogFilter);
EndProcedure

#EndRegion

#Region VersionsListFormTableItemEventHandlers

&AtClient
Procedure VersionsTreeSelection(Item, RowSelected, Field, StandardProcessing)
	OpenReportOnObjectVersion();
EndProcedure

&AtClient
Procedure VersionsTreeOnActivateRow(Item)
	SetAvailability();
EndProcedure

&AtClient
Procedure VersionsTreeCommentOnChange(Item)
	CurrentData = Items.VersionsTree.CurrentData;
	If CurrentData <> Undefined Then
		AddCommentToVersion(Ref, CurrentData.VersionNumber, CurrentData.Comment);
	EndIf;
EndProcedure

&AtClient
Procedure VersionsTreeBeforeRowChange(Item, Cancel)
	If Not CanEditComments(Item.CurrentData.VersionAuthor) Then
		Cancel = True;
	EndIf;
EndProcedure


#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OpenObjectVersion(Command)
	
	OpenReportOnObjectVersion();
	
EndProcedure

&AtClient
Procedure RestoreVersion(Command)
	
	GoToSelectedVersion();
	
EndProcedure

&AtClient
Procedure GenerateReportOnChanges(Command)
	
	SelectedRows = Items.VersionsTree.SelectedRows;
	VersionsToCompare = GenerateSelectedVersionList(SelectedRows);
	
	If VersionsToCompare.Count() < 2 Then
		ShowMessageBox(, NStr("en = 'To generate a delta report, select at least two versions.';"));
		Return;
	EndIf;
	
	OpenReportForm(VersionsToCompare);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	RefreshVersionList();
EndProcedure

#EndRegion

#Region Private

&AtServer
Function GenerateVersionTable()
	
	If ObjectsVersioning.HasRightToReadObjectVersionData() Then
		SetPrivilegedMode(True);
	EndIf;
	
	VersionNumbers1 = New Array;
	If Filter.Count() > 0 Then
		VersionNumbers1 = VersionNumbersWithChangesInSelectedAttributes();
	EndIf;
	
	QueryText = 
	"SELECT
	|	ObjectsVersions.VersionNumber AS VersionNumber,
	|	ObjectsVersions.VersionAuthor AS VersionAuthor,
	|	ObjectsVersions.VersionDate AS VersionDate,
	|	ObjectsVersions.Comment AS Comment,
	|	ObjectsVersions.Checksum,
	|	ObjectsVersions.HasVersionData,
	|	&NoFilter
	|		OR ObjectsVersions.VersionNumber IN (&VersionNumbers1) AS MatchesFilter,
	|	ObjectsVersions.VersionOwner,
	|	ObjectsVersions.ObjectVersionType,
	|	ObjectsVersions.Node
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.Object = &Ref
	|
	|ORDER BY
	|	VersionNumber DESC";
	
	Query = New Query(QueryText);
	Query.SetParameter("NoFilter", Filter.Count() = 0);
	Query.SetParameter("VersionNumbers1", VersionNumbers1);
	Query.SetParameter("Ref", Ref);
	
	VersionTable = Query.Execute().Unload();
	
	VersionTable.Columns.Add("CurrentVersion", New TypeDescription("Boolean"));
	
	CustomVersions = VersionTable.FindRows(New Structure("ObjectVersionType", Enums.ObjectVersionTypes.ChangedByUser));
	If CustomVersions.Count() > 0 Then
		CustomVersions[0].HasVersionData = True;
		CustomVersions[0].CurrentVersion = True;
		CurrentVersionNumber = CustomVersions[0].VersionNumber;
	EndIf;
	
	For IndexOf = 1 To CustomVersions.Count() - 1 Do
		If Not CustomVersions[IndexOf].HasVersionData Then
			If IsBlankString(CustomVersions[IndexOf].Checksum) Or CustomVersions[IndexOf].Checksum = CustomVersions[IndexOf-1].Checksum Then
				CustomVersions[IndexOf].HasVersionData = CustomVersions[IndexOf-1].HasVersionData;
			EndIf;
		EndIf;
	EndDo;
	
	ThisInfobaseName = ThisInfobaseName();
	For Each Version In VersionTable Do
		If IsBlankString(Version.Node) Then
			Version.Node = ThisInfobaseName;
		EndIf;
	EndDo;
	
	Result = VersionTable.Copy(VersionTable.FindRows(New Structure("MatchesFilter", True)),
		"VersionNumber, VersionAuthor, VersionDate, Comment, HasVersionData, VersionOwner, Node, CurrentVersion");
		
	Return Result;
	
EndFunction

&AtClient
Procedure GoToSelectedVersion(CancelPosting = False)
	
	CurrentData = Items.VersionsTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	VersionNumberPresentation = CurrentData.VersionNumberPresentation;
	Result = RestoreVersionServer(Ref, CurrentData.VersionNumber, CancelPosting);
	
	If Result = "RecoveryError" Then
		CommonClient.MessageToUser(ErrorMessageText);
	ElsIf Result = "PostingError" Then
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot restore the document version. Reason:
				|%1
				|Do you want to unpost the document and restore the version?';"),
			ErrorMessageText);
			
		NotifyDescription = New NotifyDescription("GoToSelectedVersionQuestionAsked", ThisObject);
		Buttons = New ValueList;
		Buttons.Add("GoTo", NStr("en = 'Yes';"));
		Buttons.Add(DialogReturnCode.Cancel);
		ShowQueryBox(NotifyDescription, QueryText, Buttons);
	Else //Result = "RestoringComplete"
		NotifyChanged(Ref);
		If FormOwner <> Undefined Then
			Try
				FormOwner.Read();
			Except
				// Do nothing if the form has no Read() method.
			EndTry;
		EndIf;
		ShowUserNotification(
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Version #%1 is restored.';"), VersionNumberPresentation),
			GetURL(Ref),
			String(Ref),
			PictureLib.Information32);
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToSelectedVersionQuestionAsked(QuestionResult, AdditionalParameters) Export
	If QuestionResult <> "GoTo" Then
		Return;
	EndIf;
	
	GoToSelectedVersion(True);
EndProcedure

&AtServer
Function RestoreVersionServer(Ref, VersionNumber, UndoPosting = False)
	ErrorMessageText = "";
	Result = ObjectsVersioning.RestoreVersionServer(Ref, VersionNumber, ErrorMessageText, UndoPosting);
	
	RefreshVersionList();
	
	Return Result;
EndFunction

&AtClient
Procedure OpenReportOnObjectVersion()
	
	VersionsToCompare = New ValueList;
	VersionsToCompare.Add(Items.VersionsTree.CurrentData.VersionNumber, Items.VersionsTree.CurrentData.VersionNumberPresentation);
	OpenReportForm(VersionsToCompare);
	
EndProcedure

&AtClient
Procedure OpenReportForm(VersionsToCompare)
	
	ReportParameters = New Structure;
	ReportParameters.Insert("Ref", Ref);
	ReportParameters.Insert("VersionsToCompare", VersionsToCompare);
	
	OpenForm("InformationRegister.ObjectsVersions.Form.ObjectVersionsReport",
		ReportParameters,
		ThisObject,
		UUID);
	
EndProcedure

&AtClient
Function GenerateSelectedVersionList(SelectedRows)
	
	VersionsToCompare = New ValueList;
	
	For Each SelectedRowNumber In SelectedRows Do
		RowData = Items.VersionsTree.RowData(SelectedRowNumber);
		VersionsToCompare.Add(RowData.VersionNumber, RowData.VersionNumberPresentation);
	EndDo;
	
	VersionsToCompare.SortByValue(SortDirection.Asc);
	
	If VersionsToCompare.Count() = 1 Then
		If VersionsToCompare.FindByValue(CurrentVersionNumber) = Undefined Then
			CurrentVersion = CurrentVersion(VersionsTree);
			If CurrentVersion = Undefined Then
				VersionsToCompare.Add(CurrentVersionNumber);
			Else
				VersionsToCompare.Add(CurrentVersion.VersionNumber, CurrentVersion.VersionNumberPresentation);
			EndIf;
		EndIf;
	EndIf;
	
	Return VersionsToCompare;
	
EndFunction

&AtClient
Function CurrentVersion(VersionsList)
	For Each Version In VersionsList.GetItems() Do
		If Version.CurrentVersion Then
			Result = Version;
		Else
			Result = CurrentVersion(Version);
		EndIf;
		If Result <> Undefined Then
			Return Result;
		EndIf;
	EndDo;
	Return Undefined;
EndFunction

&AtClient
Procedure SetAvailability()
	
	OneVersionSelected = Items.VersionsTree.SelectedRows.Count() = 1;
	
	Items.OpenVersion.Enabled = OneVersionSelected;
	Items.VersionsTreeContextMenuOpenVersion.Enabled = OneVersionSelected;
	
	Items.RestoreVersion.Enabled = OneVersionSelected;
	Items.VersionsTreeContextMenuGoToVersion.Enabled = OneVersionSelected;
	
	Items.Compare.Enabled = Items.VersionsTree.SelectedRows.Count() > 0;
	
EndProcedure

&AtClient
Procedure OnSelectAttribute(SelectionResult, AdditionalParameters) Export
	If SelectionResult = Undefined Then
		Return;
	EndIf;
	
	Attributes = SelectionResult.SelectedItemsPresentation;
	Filter.LoadValues(SelectionResult.SelectedAttributes);
	RefreshVersionList();
EndProcedure

&AtServer
Procedure RefreshVersionList()
	
	VersionTable = GenerateVersionTable();
	HasVersions = VersionTable.Count() > 0;
	
	If HasVersions Then
		Items.BasicPage.CurrentPage = Items.SelectVersionsToCompare;
	
		VersionTable.Sort("VersionOwner Asc, VersionNumber Desc");
		
		VersionHierarchy = FormAttributeToValue("VersionsTree");
		VersionHierarchy.Rows.Clear();
		
		ObjectsVersioning.FillVersionHierarchy(VersionHierarchy, VersionTable);
		ObjectsVersioning.NumberVersions(VersionHierarchy.Rows);
		
		ValueToFormAttribute(VersionHierarchy, "VersionsTree");
		
		VersionTable.GroupBy("Node");
		Items.VersionsTreeNode.Visible = VersionTable.Count() > 1 Or VersionTable.Count() = 1 And VersionTable[0].Node <> ThisInfobaseName();
	Else
		Items.BasicPage.CurrentPage = Items.NoVersionsToCompare;
	EndIf;
	
	Items.ActionsWithVersion.Enabled = HasVersions;
	Items.Attributes.Enabled = HasVersions;
	
EndProcedure

&AtClient
Procedure AttributesClearing(Item, StandardProcessing)
	StandardProcessing = False;
	Attributes = "";
	Filter.Clear();
	RefreshVersionList();
EndProcedure

&AtServer
Function VersionNumbersWithChangesInSelectedAttributes()
	QueryText =
	"SELECT
	|	ObjectsVersions.VersionNumber AS VersionNumber,
	|	ObjectsVersions.HasVersionData,
	|	ObjectsVersions.ObjectVersion AS Data
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.ObjectVersionType = VALUE(Enum.ObjectVersionTypes.ChangedByUser)
	|	AND ObjectsVersions.Object = &Ref
	|
	|ORDER BY
	|	VersionNumber DESC";
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Ref);
	StoredVersions = Query.Execute().Unload();
	
	VersionData = New ValueStorage(ObjectsVersioning.SerializeObject(Ref.GetObject()), New Deflation(9));
	CurrentVersion = StoredVersions[0];
	CurrentVersion.Data = VersionData;
	CurrentVersion.VersionNumber = ObjectsVersioning.LastVersionNumber(Ref);
	CurrentVersion.HasVersionData = True;
	
	For Each VersionDetails In StoredVersions Do
		If Not VersionDetails.HasVersionData Then
			VersionDetails.Data = VersionData;
		Else
			VersionData = VersionDetails.Data;
		EndIf;
	EndDo;
	
	Result = New Array;
	Result.Add(StoredVersions[StoredVersions.Count() - 1].VersionNumber);
	
	ObjectData = StoredVersions[0].Data.Get();
	If TypeOf(ObjectData) = Type("Structure") Then
		ObjectData = ObjectData.Object;
	EndIf;
	CurrentVersion = ObjectsVersioning.XMLObjectPresentationParsing(ObjectData, Ref);
	For LineNumber = 1 To StoredVersions.Count() - 1 Do
		VersionDetails = StoredVersions[LineNumber];
		
		ObjectData = VersionDetails.Data.Get();
		If TypeOf(ObjectData) = Type("Structure") Then
			ObjectData = ObjectData.Object;
		EndIf;
		PreviousVersion = ObjectsVersioning.XMLObjectPresentationParsing(ObjectData, Ref);
		
		If AttributesChanged(CurrentVersion, PreviousVersion, Filter.UnloadValues()) Then
			Result.Add(StoredVersions[LineNumber - 1].VersionNumber);
		EndIf;
		CurrentVersion =PreviousVersion;
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Function AttributesChanged(CurrentVersion, PreviousVersion, AttributesList)
	
	For Each Attribute In AttributesList Do
		If AttributeChanged(CurrentVersion, PreviousVersion, Attribute) Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

&AtServer
Function AttributeChanged(CurrentVersion, PreviousVersion, Attribute)
	
	TabularSectionName = Undefined;
	AttributeName = Attribute;
	If StrFind(AttributeName, ".") > 0 Then
		NameParts = StrSplit(AttributeName, ".", False);
		If NameParts.Count() > 1 Then
			TabularSectionName = NameParts[0];
			AttributeName = NameParts[1];
		EndIf;
	EndIf;
	
	// Tabular section attribute change check.
	If TabularSectionName <> Undefined Then
		CurrentTabularSection = CurrentVersion.TabularSections[TabularSectionName];
		PreviousTabularSection = PreviousVersion.TabularSections[TabularSectionName];
		
		// Table is missing.
		If CurrentTabularSection = Undefined Or PreviousTabularSection = Undefined Then
			Return Not CurrentTabularSection = Undefined And PreviousTabularSection = Undefined;
		EndIf;
		
		// If the number of tabular section rows is changed.
		If CurrentTabularSection.Count() <> PreviousTabularSection.Count() Then
			Return True;
		EndIf;
		
		If AttributeName = "*" Then
			Return Common.ValueToXMLString(CurrentTabularSection) <> Common.ValueToXMLString(PreviousTabularSection);
		EndIf;
		
		// Attribute is missing.
		CurrentAttributeExists = CurrentTabularSection.Columns.Find(AttributeName) <> Undefined;
		PreviousAttributeExists = PreviousTabularSection.Columns.Find(AttributeName) <> Undefined;
		If CurrentAttributeExists <> PreviousAttributeExists Then
			Return True;
		EndIf;
		If Not CurrentAttributeExists Then
			Return False;
		EndIf;
		
		// Row-by-row comparison.
		For LineNumber = 0 To CurrentTabularSection.Count() - 1 Do
			If CurrentTabularSection[LineNumber][AttributeName] <> PreviousTabularSection[LineNumber][AttributeName] Then
				Return True;
			EndIf;
		EndDo;
		
		Return False;
	EndIf;
	
	// Check the header attribute.
	
	If AttributeName = "*" Then
		Return Common.ValueToXMLString(CurrentVersion) <> Common.ValueToXMLString(PreviousVersion);
	EndIf;
	
	CurrentAttribute = CurrentVersion.Attributes.Find(AttributeName, "AttributeDescription");
	CurrentAttributeExists = CurrentAttribute <> Undefined;
	CurrentAttributeValue = Undefined;
	If CurrentAttributeExists Then
		CurrentAttributeValue = CurrentAttribute.AttributeValue;
	EndIf;
	
	PreviousAttribute = PreviousVersion.Attributes.Find(AttributeName, "AttributeDescription");
	PreviousAttributeExists = PreviousAttribute <> Undefined;
	PreviousAttributeValue = Undefined;
	If PreviousAttributeExists Then
		PreviousAttributeValue = PreviousAttribute.AttributeValue;
	EndIf;
	
	If CurrentAttributeExists <> PreviousAttributeExists
		Or CurrentAttributeValue <> PreviousAttributeValue Then
		Return True;
	EndIf;
	
	Return False;
EndFunction

&AtServerNoContext
Procedure AddCommentToVersion(ObjectReference, VersionNumber, Comment);
	ObjectsVersioning.AddCommentToVersion(ObjectReference, VersionNumber, Comment);
EndProcedure

&AtServerNoContext
Function CanEditComments(VersionAuthor)
	Return Users.IsFullUser()
		Or VersionAuthor = Users.CurrentUser();
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// Missing version data.
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("VersionsTree.HasVersionData");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.VersionsTree.Name);
	
	
	// 
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("VersionsTree.IsRejected");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.VersionsTree.Name);
	
	// 
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("VersionsTree.CurrentVersion");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Font = StyleFonts.ImportantLabelFont;
	
	Item.Appearance.SetParameterValue("Font", Font);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.VersionsTree.Name);
	
EndProcedure

&AtServer
Function ThisInfobaseName()
	Return NStr("en = 'This application';");
EndFunction

#EndRegion
