///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Opens the formula editor.
//
// Parameters:
//  Parameters - See FormulaEditingOptions
//  CompletionHandler - NotifyDescription 
//
Procedure StartEditingTheFormula(Parameters, CompletionHandler) Export
	
	OpenForm("DataProcessor.FormulasConstructor.Form.FormulaEdit", Parameters, , , , , CompletionHandler);
	
EndProcedure

// The FormulaParameters parameter constructor for the FormulaPresentation function.
// 
// Returns:
//  Structure:
//   * Formula - String
//   * Operands - String - an address in the temporary operand collection storage. The collection type can be: 
//                         ValueTable - see FieldsTable 
//                         ValueTree - see FieldsTree 
//                         DataCompositionSchema - the operand list is taken from the FilterAvailableFields collection
//                                                  of the Settings Composer. You can override the collection name
//                                                  in the DCSCollectionName parameter.
//   * Operators - String - an address in the temporary operator collection storage. The collection type can be: 
//                         ValueTable - see FieldsTable 
//                         ValueTree - see FieldsTree 
//                         DataCompositionSchema - the operand list is taken from the FilterAvailableFields collection
//                                                  of the Settings Composer. You can override the collection name
//                                                  in the DCSCollectionName parameter.
//   * OperandsDCSCollectionName  - String - a field collection name in the Settings Composer. Use the parameter
//                                          if a data composition schema is passed in the Operands parameter.
//                                          The default value is FilterAvailableFields.
//   * OperatorsDCSCollectionName - String - a field collection name in the Settings Composer. Use the parameter
//                                          if a data composition schema is passed in the Operators parameter.
//                                          The default value is FilterAvailableFields.
//   * Description - Undefined - the description is not used for the formula and the field is not available.
//                  - String       - 
//                                   
//   * ForQuery   - Boolean - the formula is for inserting in a query. This parameter affects the default operator list
//                             and the selection of the formula check algorithm.
//
Function FormulaEditingOptions() Export
	
	Return FormulasConstructorClientServer.FormulaEditingOptions();
	
EndFunction

// Handler of expanding the list being connected.
// 
// Parameters:
//  Form   - ClientApplicationForm - the list owner.
//  Item - FormTable - a list where string expansion is executed.
//  String  - Number - list string ID.
//  Cancel   - Boolean - indicates that expansion is canceled.
//
Procedure ListOfFieldsBeforeExpanding(Form, Item, String, Cancel) Export
	
	FieldListSettings = FieldListSettings(Form, Item.Name);
	ItemsCollection = Form[Item.Name].FindByID(String).GetItems();
	If ItemsCollection.Count() > 0 And ItemsCollection[0].Field = Undefined Then
		Cancel = True;
		FieldListSettings.ExpandableBranches = FieldListSettings.ExpandableBranches + Format(String, "NZ=0; NG=0;") + ";";
		Form.AttachIdleHandler("Attachable_ExpandTheCurrentFieldListItem", 0.1, True);
	EndIf;
	
EndProcedure

// Handler of expanding the list being connected.
// Expands the current list item.
//
// Parameters:
//  Form - ClientApplicationForm
// 
Procedure ExpandTheCurrentFieldListItem(Form) Export
	
	For Each AttachedFieldList In Form.ConnectedFieldLists Do
		FieldList = Form.Items[AttachedFieldList.NameOfTheFieldList];
		
		For Each RowID In StrSplit(AttachedFieldList.ExpandableBranches, ";", False) Do
			FillParameters = New Structure;
			FillParameters.Insert("RowID", RowID);
			FillParameters.Insert("ListName", FieldList.Name);
			
			Form.Attachable_FillInTheListOfAvailableFields(FillParameters);
			FieldList.Expand(RowID);
		EndDo;
		
		AttachedFieldList.ExpandableBranches = "";
	EndDo;
	
EndProcedure

// Handler of dragging the list being connected
// 
// Parameters:
//  Form   - ClientApplicationForm - the list owner.
//  Item - FormTable - a list where dragging is executed.
//  DragParameters - DragParameters - contains a dragged value, an action type, 
//                                                      and possible values when dragging.
//  Perform - Boolean - if False, cannot start dragging.
//
Procedure ListOfFieldsStartDragging(Form, Item, DragParameters, Perform) Export
	
	NameOfTheFieldList = Item.Name;
	Attribute = Form[NameOfTheFieldList].FindByID(DragParameters.Value);
	
	FieldListSettings = FormulasConstructorClientServer.FieldListSettings(Form, NameOfTheFieldList);
	If FieldListSettings.ViewBrackets Then
		DragParameters.Value = "[" + Attribute.RepresentationOfTheDataPath + "]";
	Else
		DragParameters.Value = Attribute.RepresentationOfTheDataPath;
	EndIf;
	
EndProcedure

// Returns details of the current selected field of the list being connected.
//
// Parameters:
//  Form - ClientApplicationForm - the list owner.
//  NameOfTheFieldList - String - a list name set upon calling FormulasConstructor.AddFieldsListToForm.
//  
// Returns:
//  Structure:
//   * Name - String
//   * Title - String
//   * DataPath - String
//   * RepresentationOfTheDataPath - String
//   * Type - TypeDescription
//   * Parent - See TheSelectedFieldInTheFieldList
//
Function TheSelectedFieldInTheFieldList(Form, NameOfTheFieldList = Undefined) Export
	
	If Form.ConnectedFieldLists.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	If NameOfTheFieldList = Undefined Then
		FieldList = Form.CurrentItem; // FormTable
		NameOfTheFieldList = FieldList.Name;
		If FormulasConstructorClientServer.FieldListSettings(Form, NameOfTheFieldList)= Undefined Then
			NameOfTheFieldList = Form.ConnectedFieldLists[0].NameOfTheFieldList;
		EndIf;
	EndIf;
	
	FieldList = Form.Items[NameOfTheFieldList];
	CurrentData = FieldList.CurrentData;
	
	If CurrentData = Undefined Then
		Return Undefined;
	EndIf;
	
	Return DescriptionOfTheSelectedField(CurrentData);
	
EndFunction

// Handler of the event of the string searching the list being connected.
// 
// Parameters:
//  Form   - ClientApplicationForm - the list owner.
//  Item - FormField - search bar.
//  Text - String - search string text.
//  StandardProcessing - Boolean - if False, cannot execute the standard action.
//
Procedure SearchStringEditTextChange(Form, Item, Text, StandardProcessing) Export
	
	UpdateNameOfSearchString(Form, Item.Name);
	
	Form[Form.NameOfCurrSearchString] = Text;
	
	Form.DetachIdleHandler("Attachable_PerformASearchInTheListOfFields");
	Form.DetachIdleHandler("Attachable_StartSearchInFieldsList");
	AttachedFieldListParameters = AttachedFieldListParameters(Form, Form.NameOfCurrSearchString);
	If AttachedFieldListParameters.UseBackgroundSearch Then
		Form.AttachIdleHandler("Attachable_StartSearchInFieldsList", 0.5, True);
	Else
		Form.AttachIdleHandler("Attachable_PerformASearchInTheListOfFields", 0.5, True);
	EndIf;
	
EndProcedure

// Handler of the event of the string searching the list being connected.
// 
// Parameters:
//  Form   - ClientApplicationForm - the list owner.
//  Item - FormButton -
//  DeleteStandardDataProcessor - Boolean -
//
Procedure SearchStringClearing(Form, Item, DeleteStandardDataProcessor = Undefined) Export

	UpdateNameOfSearchString(Form, Item.Name);
	
	AttachedFieldList = AttachedFieldListParameters(Form, Form.NameOfCurrSearchString);
	
	If AttachedFieldList.UseBackgroundSearch Then
		AdditionalParameters = HandlerParameters();
		AdditionalParameters.RunAtServer = True;
		AdditionalParameters.OperationKey = "ClearUpSearchString";
		Form.Attachable_FormulaEditorHandlerClient(Item.Name, AdditionalParameters);
		Item = Form.Items[StrReplace(Item.Name, "Clearing", "")];
		Item.UpdateEditText();
	EndIf;
	
	SearchStringEditTextChange(Form, Item, "", DeleteStandardDataProcessor);
	
EndProcedure

#EndRegion

#Region Internal

// Parameters:
//  Operator - See TheSelectedFieldInTheFieldList
//
Function ExpressionToInsert(Operator) Export
	
	If ValueIsFilled(Operator.ExpressionToInsert) Then
		Return Operator.ExpressionToInsert;
	EndIf;
	
	Result = Operator.Title + "()";
	
	If Not ValueIsFilled(Operator.Parent) Then
		Return "";
	EndIf;
	
	OperatorsGroup = Operator.Parent; // See TheSelectedFieldInTheFieldList
	OperatorGroupName = OperatorsGroup.Name;
	
	If OperatorGroupName = "Separators" Then
		Result = "+ """ + Operator.Title + """ +";
		If Operator.Name = "[ ]" Then
			Result = "+ "" "" +";
		EndIf;
	EndIf;
	
	If OperatorGroupName = "LogicalOperatorsAndConstants"
		Or OperatorGroupName = "Operators"
		Or OperatorGroupName = "OperationsOnStrings"
		Or OperatorGroupName = "LogicalOperations"
		Or OperatorGroupName = "ComparisonOperation" And Operator.Name <> "In" Then
		Result = Operator.Title;
	EndIf;
	
	If OperatorGroupName = "OtherFunctions" Then
		If Operator.Name = "[?]" Or Operator.Name = "Format" Then
			Result = Operator.Title + "(,,)";
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// 
// Parameters:
//  Form   - ClientApplicationForm -
//
Procedure StartSearchInFieldsList(Form) Export
	
	NameOfTheSearchString = Form.NameOfCurrSearchString;
	AttachedFieldList = AttachedFieldListParameters(Form, Form.NameOfCurrSearchString);
	
	Filter = Form[Form.NameOfCurrSearchString];
	FilterStringLength = StrLen(Filter);
	
	WaitStringMessage = NStr("en = 'Continue typing…';");
	
	NameOfTheFieldList = AttachedFieldList.NameOfTheFieldList;
	TreeOnForm = Form[NameOfTheFieldList];
	FieldList = Form.Items[NameOfTheFieldList];
		
	If FilterStringLength >= AttachedFieldList.NumberOfCharsToAllowSearching Then
		Form.Items[NameOfTheSearchString+"Clearing"].Picture = PictureLib.TimeConsumingOperation16;
		SetPreSelection(TreeOnForm, Filter);
		Form.Items[NameOfTheFieldList+ "Presentation"].Visible = False;
		Form.Items[NameOfTheFieldList+ "RepresentationOfTheDataPath"].Visible = True;
		FieldList.Representation = TableRepresentation.List;
	ElsIf FilterStringLength = 0 Then
		ResetSelection(TreeOnForm);
		DeleteWaitingLine(TreeOnForm, WaitStringMessage);
		Form.Items[NameOfTheFieldList+ "Presentation"].Visible = True;
		Form.Items[NameOfTheFieldList+ "RepresentationOfTheDataPath"].Visible = False;
		FieldList.Representation = TableRepresentation.Tree;
		Return;
	Else
		ResetSelection(TreeOnForm);
		AddWaitingLine(TreeOnForm, WaitStringMessage);
		Form.Items[NameOfTheFieldList+ "Presentation"].Visible = True;
		Form.Items[NameOfTheFieldList+ "RepresentationOfTheDataPath"].Visible = False;
		FieldList.Representation = TableRepresentation.List;
		Return;
	EndIf;
	
	AdditionalParameters = HandlerParameters();
	AdditionalParameters.RunAtServer = True;
	AdditionalParameters.OperationKey = "RunBackgroundSearchInFieldList";
	
	TimeConsumingOperation = Undefined;
	
	Form.Attachable_FormulaEditorHandlerClient(TimeConsumingOperation, AdditionalParameters);
	
	If TimeConsumingOperation <> Undefined Then 
		CompletionParameters = New Structure("Form, JobID", Form, TimeConsumingOperation.JobID);
		
		CompletionNotification = New NotifyDescription("CompletionChangeBorderColor", ThisObject, CompletionParameters);
		ExecutionProgressNotification = New NotifyDescription("HandleSearchInFieldsList", ThisObject, Form); 
		
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(Form);
		IdleParameters.MessageText = NStr("en = 'Search for fields';");
		IdleParameters.UserNotification.Show = False;
		IdleParameters.OutputIdleWindow = False;
		IdleParameters.OutputMessages = False;
		IdleParameters.ExecutionProgressNotification = ExecutionProgressNotification;
		
		TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CompletionNotification, IdleParameters);
	EndIf;
EndProcedure

// 
// 
// Parameters:
//  Result - See TimeConsumingOperationsClient.WaitCompletion.CompletionNotification2.Результат.
//  CompletionParameters - Structure:
//    * Form - ClientApplicationForm
//    * JobID - UUID - ID of the background task.
//
Procedure CompletionChangeBorderColor(Result, CompletionParameters) Export
			
	JobID = CompletionParameters.JobID;
	Form = CompletionParameters.Form;
	
	MatchingTasks = GetFromTempStorage(Form.AddressOfLongRunningOperationDetails);
	For Each Job In MatchingTasks Do
		If Job.Value = JobID Then
			NameOfTheSearchString = Job.Key;
			Break;
		EndIf;
	EndDo;
	
	If NameOfTheSearchString = Undefined Then
		Return;
	EndIf;
	
	Form.Items[NameOfTheSearchString+"Clearing"].Picture = PictureLib.InputFieldClear;
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		Raise Result.BriefErrorDescription;
	EndIf;
	
	If Result.Messages <> Undefined Then
		ProcessMessages(Form, Result.Messages, JobID);
	EndIf;

	ProcessResult(Form, Result.ResultAddress, JobID);
			
EndProcedure

// 
// 
// Parameters:
//  Result - See TimeConsumingOperationsClient.WaitCompletion.CompletionNotification2.Результат
//  Form - ClientApplicationForm -
//
Procedure HandleSearchInFieldsList(Result, Form) Export
	If Result = Undefined Then
		Return;
	EndIf;
		
	If Result.Status = "Error" Then
		Raise Result.BriefErrorDescription;
	EndIf;
	
	JobID = Result.JobID;
	
	NameOfTheSearchString = "";
	MatchingTasks = GetFromTempStorage(Form.AddressOfLongRunningOperationDetails);
	For Each Job In MatchingTasks Do
		If Job.Value = JobID Then
			NameOfTheSearchString = Job.Key;
			Break;
		EndIf;
	EndDo;
	
	If ValueIsFilled(NameOfTheSearchString) Then
		Form.Items[NameOfTheSearchString+"Clearing"].Picture = PictureLib.TimeConsumingOperation16;
		AttachedFieldList = AttachedFieldListParameters(Form, NameOfTheSearchString);
		
		FilterStringLength = StrLen(Form[NameOfTheSearchString]);
		
		If FilterStringLength < AttachedFieldList.NumberOfCharsToAllowSearching Then
			Form.Items[NameOfTheSearchString+"Clearing"].Picture = PictureLib.InputFieldClear;
			Return;
		Else
			Form.Items[NameOfTheSearchString+"Clearing"].Picture = PictureLib.TimeConsumingOperation16;
		EndIf;
	EndIf;
	
	If Result.Messages <> Undefined Then
		ProcessMessages(Form, Result.Messages, JobID);
	EndIf;
	
	If Result.Status <> "Running" Then
		If ValueIsFilled(NameOfTheSearchString) Then
			Form.Items[NameOfTheSearchString+"Clearing"].Picture = PictureLib.InputFieldClear;
		EndIf;
	EndIf;
	
EndProcedure

// 
// 
// Parameters:
//  Form - ClientApplicationForm
//  Parameter - Arbitrary
//  AdditionalParameters - See HandlerParameters
//
Procedure FormulaEditorHandler(Form, Parameter, AdditionalParameters) Export
	If AdditionalParameters = Undefined Then
		AdditionalParameters = HandlerParameters();
	EndIf;
	
	If AdditionalParameters.RunAtServer = True Then
		Return;
	EndIf;
	
	OperationKey = AdditionalParameters.OperationKey;
	If OperationKey = "HandleSearchMessage" Then	
		Messages = Parameter.Messages;
		JobID = Parameter.JobID;
		ProcessSearchMessages(Form, Messages, JobID);
	ElsIf OperationKey = "ProcessSearchResults" Then	
		ResultAddress = Parameter.ResultAddress;
		JobID = Parameter.JobID;
		ProcessSearchResults(Form, ResultAddress, JobID);
	EndIf;
	
EndProcedure

// 
// 
// Returns:
//  Structure:
//   * RunAtServer - Boolean -
//   * OperationKey - String 
//
Function HandlerParameters() Export
	Parameters = New Structure;
	Parameters.Insert("RunAtServer", False);
	Parameters.Insert("OperationKey");
	Return Parameters;
EndFunction

#EndRegion

#Region Private

Function DescriptionOfTheSelectedField(Field)
	
	Result = New Structure;
	Result.Insert("Name");
	Result.Insert("Title");
	Result.Insert("DataPath");
	Result.Insert("RepresentationOfTheDataPath");
	Result.Insert("Type");
	Result.Insert("Parent");
	Result.Insert("ExpressionToInsert");
	
	FillPropertyValues(Result, Field);
	
	Parent = Field.GetParent();
	If Parent <> Undefined Then
		Result.Parent = DescriptionOfTheSelectedField(Parent);
	EndIf;
	
	Return Result;
	
EndFunction

Procedure ProcessMessages(Form, Messages, JobID)
	AdditionalParameters = HandlerParameters();
	AdditionalParameters.OperationKey = "HandleSearchMessage";
	AdditionalParameters.RunAtServer = False;
	
	ParameterStructure = New Structure("Messages, JobID");
	ParameterStructure.Messages = Messages;
	ParameterStructure.JobID = JobID;
	
	Form.Attachable_FormulaEditorHandlerClient(ParameterStructure, AdditionalParameters);
EndProcedure

Procedure ProcessResult(Form, ResultAddress, JobID)
	AdditionalParameters = HandlerParameters();
	AdditionalParameters.OperationKey = "ProcessSearchResults";
	AdditionalParameters.RunAtServer = False;
	
	ParameterStructure = New Structure("ResultAddress, JobID");
	ParameterStructure.ResultAddress = ResultAddress;
	ParameterStructure.JobID = JobID;
	
	Form.Attachable_FormulaEditorHandlerClient(ParameterStructure, AdditionalParameters);
EndProcedure

Function AttachedFieldListParameters(Form, AttributeName)
	NameOfTheFieldList = NameOfFieldsListAttribute(AttributeName);
	If StrEndsWith(NameOfTheFieldList, "Clearing") Then
		NameOfTheFieldList = StrReplace(NameOfTheFieldList+" ", "Clearing ", "");
	EndIf;
	
	RowFilter = New Structure("NameOfTheFieldList", NameOfTheFieldList);
	FieldsListLine = Form.ConnectedFieldLists.FindRows(RowFilter);
	AttachedFieldList = FieldsListLine[0];
	Return AttachedFieldList;
EndFunction

Function NameOfFieldsListAttribute(NameOfFieldLIstSearchString)
	
	Result = StrReplace(NameOfFieldLIstSearchString, "SearchString", "");
	
	Return Result;
	
EndFunction

Procedure UpdateNameOfSearchString(Form, Name)
	RemovableEnding = "Clearing";
	If StrEndsWith(Name, RemovableEnding) Then
		NameLength = StrLen(Name) - StrLen(RemovableEnding);
		Form.NameOfCurrSearchString = Left(Name, NameLength); 
	Else
		Form.NameOfCurrSearchString = Name;
	EndIf;
EndProcedure

Function FieldListSettings(Form, NameOfTheFieldList)
	
	For Each AttachedFieldList In Form.ConnectedFieldLists Do
		If NameOfTheFieldList = AttachedFieldList.NameOfTheFieldList Then
			Return AttachedFieldList;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

Procedure ProcessSearchMessages(Form, Messages, JobID)
	
	NameOfTheSearchString = SearchStringNameByTaskID(Form, JobID);
	If NameOfTheSearchString = Undefined Then
		Return;
	EndIf;
	
	ListName = NameOfFieldsListAttribute(NameOfTheSearchString);
	FieldTree = Form[ListName];
	BackgroundSearchData = FormulasConstructorServerCall.BackgroundSearchData(Messages);
	DeserializedMessages = BackgroundSearchData.DeserializedMessages;
	
	AdditionalData = New Structure("AllRefsTypeDetails", BackgroundSearchData.AllRefsTypeDetails);
	For MessageIndex = 0 To Messages.UBound() Do
	
		Result = DeserializedMessages[MessageIndex]; 
		
		If TypeOf(Result) <> Type("Structure") Then
			Return;
		EndIf;
						
		If Result.Property("FoundItems1") Then
			
			FoundItems1 = Result.FoundItems1;
			For Each FoundItem In FoundItems1 Do
				ItemToAdd = AddItemByDataPath(FieldTree, FoundItem, AdditionalData);
				FillPropertyValues(ItemToAdd, FoundItem);
				ItemToAdd.MatchesFilter = True;
				ItemParent = ItemToAdd.GetParent();
				If ItemParent <> Undefined Then
					ItemParent.TheSubordinateElementCorrespondsToTheSelection = True;
				EndIf;
			EndDo;
			
		EndIf;
	EndDo;
EndProcedure

Procedure ProcessSearchResults(Form, ResultAddress, JobID)
	
	SearchResult = GetFromTempStorage(ResultAddress);
	
	If SearchResult = Undefined Then
		Return;
	EndIf;
	
	NameOfTheSearchString = SearchStringNameByTaskID(Form, JobID);
	
	If NameOfTheSearchString = Undefined Then
		Return;
	EndIf;
	
	ListName = NameOfFieldsListAttribute(NameOfTheSearchString);
	FieldTree = Form[ListName];
	BackgroundSearchData = FormulasConstructorServerCall.BackgroundSearchData();
	
	AdditionalData = New Structure("AllRefsTypeDetails", BackgroundSearchData.AllRefsTypeDetails);
	If SearchResult.Property("AllRefsTypeDetails") Then
		AdditionalData.AllRefsTypeDetails = SearchResult.AllRefsTypeDetails;
	EndIf;
			
	FoundItems1 = SearchResult.FoundItems1;
	For Each FoundItem In FoundItems1 Do
		ItemToAdd = AddItemByDataPath(FieldTree, FoundItem, AdditionalData);
		FillPropertyValues(ItemToAdd, FoundItem);
		ItemToAdd.MatchesFilter = True;
		ItemParent = ItemToAdd.GetParent();
		If ItemParent <> Undefined Then
			ItemParent.TheSubordinateElementCorrespondsToTheSelection = True;
		EndIf;
	EndDo;
	Form.Items[ListName + "Presentation"].Visible = False;
	Form.Items[ListName + "RepresentationOfTheDataPath"].Visible = True;
	
EndProcedure

Function AddItemByDataPath(FieldTree, StringToAdd, RecursiveContext)
	
	If Not RecursiveContext.Property("DataPathElements") Then
		RecursiveContext.Insert("DataPathElements", New Map);
	EndIf;
	
	CurCollection = FieldTree;
	FoundRow = FindItemWithIndexing(CurCollection, RecursiveContext.DataPathElements, StringToAdd.DataPath);
	
	If FoundRow <> Undefined Then
		Return FoundRow;
	Else
		CurLevelLines = CurCollection.GetItems();
		FieldsTreeNewRow = CurLevelLines.Add();
		FillPropertyValues(FieldsTreeNewRow, StringToAdd);
		RecursiveContext.DataPathElements.Insert(FieldsTreeNewRow.DataPath, FieldsTreeNewRow);
			
		HasSubordinateItems = FieldsTreeNewRow.Folder Or FieldsTreeNewRow.Table;
	
		If Not HasSubordinateItems Then
			For Each Type In FieldsTreeNewRow.Type.Types() Do
				
				HasSubordinateItems = HasSubordinateItems Or IsReference(Type, RecursiveContext.AllRefsTypeDetails);
				If HasSubordinateItems Then
					Break;
				EndIf; 
			EndDo;
		EndIf;
		
		If HasSubordinateItems Then
			FieldsTreeNewRow.GetItems().Add();
		EndIf;

		Return FieldsTreeNewRow;
		
	EndIf;
	
EndFunction

Function IsReference(TypeToCheck, AllRefsTypeDetails) Export
	
	Return TypeToCheck <> Type("Undefined") And AllRefsTypeDetails.ContainsType(TypeToCheck);
	
EndFunction

Function FindItemWithIndexing(FieldTree, DataPathElements, DataPath)
	
	FoundRow = DataPathElements.Get(DataPath);
	If FoundRow <> Undefined Then
		Return FoundRow;
	EndIf;
	
	Items = FieldTree.GetItems();
	For Each Item In Items Do
		If Item.DataPath = DataPath Then
			Return Item;
		ElsIf StrStartsWith(DataPath, Item.DataPath+".") Then
			FoundItem = FindItemWithIndexing(Item, DataPathElements, DataPath);
			If FoundItem = Undefined Then
				FieldTree = Item;
			EndIf;
			Return FoundItem;			
		EndIf;
		If Item.DataPath <> "" Then
			DataPathElements.Insert(Item.DataPath, Item);
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

Function SearchStringNameByTaskID(Form, JobID)
	MatchingTasks = GetFromTempStorage(Form.AddressOfLongRunningOperationDetails);
	For Each Job In MatchingTasks Do
		If Job.Value = JobID Then
			Return Job.Key;
		EndIf;
	EndDo;
EndFunction

Procedure SetPreSelection(List, Filter)
	For Each Item In List.GetItems() Do
		MatchesFilter = StrOccurrenceCount(Lower(Item.RepresentationOfTheDataPath), Lower(Filter)) > 0;
		Item.MatchesFilter = MatchesFilter;
		Item.TheSubordinateElementCorrespondsToTheSelection = False;
		If MatchesFilter And TypeOf(List) = Type("FormDataTreeItem") Then
			 Item.GetParent().TheSubordinateElementCorrespondsToTheSelection = True; 
		EndIf;
		
		SetPreSelection(Item, Filter);
	EndDo;	
EndProcedure

Procedure ResetSelection(List)
	For Each Item In List.GetItems() Do
		Item.MatchesFilter = False;
		Item.TheSubordinateElementCorrespondsToTheSelection = False;
		ResetSelection(Item);
	EndDo;	
EndProcedure

Procedure AddWaitingLine(List, WaitStringMessage)
	WaitingLineIsDisplayed = False;
	Rows = List.GetItems();
	For Each Item In Rows Do
		If Item.Title = WaitStringMessage Then
			WaitingLineIsDisplayed = True;
			Break;
		EndIf;
	EndDo;	
	
	If Not WaitingLineIsDisplayed Then
		Item = Rows.Add();
		Item.Title = WaitStringMessage;
		Item.RepresentationOfTheDataPath = WaitStringMessage;
	EndIf;
	
	Item.MatchesFilter = True;
EndProcedure

Procedure DeleteWaitingLine(List, WaitStringMessage)
	WaitingString = Undefined;
	Rows = List.GetItems();
	For Each Item In Rows Do
		If Item.Title = WaitStringMessage Then
			WaitingString = Item;
			Break;
		EndIf;
	EndDo;	
	
	If WaitingString <> Undefined Then
		Rows.Delete(WaitingString);
	EndIf;
EndProcedure

#EndRegion
