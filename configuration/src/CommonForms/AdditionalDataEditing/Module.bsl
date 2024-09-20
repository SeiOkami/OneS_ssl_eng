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
	
	If Not AccessRight("Update", Metadata.InformationRegisters.AdditionalInfo) Then
		Items.FormWrite.Visible = False;
		Items.FormWriteAndClose.Visible = False;
	EndIf;
	
	If Not AccessRight("Update", Metadata.Catalogs.AdditionalAttributesAndInfoSets) Then
		Items.ChangeAdditionalDataContent.Visible = False;
	EndIf;
	
	ObjectReference = Parameters.Ref;
	
	// Getting the list of available property sets.
	PropertiesSets = PropertyManagerInternal.GetObjectPropertySets(Parameters.Ref);
	For Each String In PropertiesSets Do
		AvailablePropertySets.Add(String.Set);
	EndDo;
	
	// Filling the property value table.
	FillPropertiesValuesTable(True);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseCompletion", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_AdditionalAttributesAndInfoSets" Then
		
		If AvailablePropertySets.FindByValue(Source) <> Undefined Then
			FillPropertiesValuesTable(False);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region PropertyValueTableFormTableItemEventHandlers

&AtClient
Procedure PropertyValueTableOnChange(Item)
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure PropertyValueTableBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertyValueTableBeforeDeleteRow(Item, Cancel)
	
	If Item.CurrentData.PictureNumber = -1 Then
		Cancel = True;
		Item.CurrentData.Value = Item.CurrentData.ValueType.AdjustValue(Undefined);
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure PropertyValueTableOnStartEdit(Item, NewRow, Copy)
	
	Item.ChildItems.PropertyValueTableValue.TypeRestriction
		= Item.CurrentData.ValueType;
	
EndProcedure

&AtClient
Procedure PropertyValueTableBeforeRowChange(Item, Cancel)
	If Items.PropertyValueTable.CurrentData = Undefined Then
		Return;
	EndIf;
	
	String = Items.PropertyValueTable.CurrentData;
	
	ChoiceParametersArray1 = New Array;
	If String.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues"))
		Or String.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
		ChoiceParametersArray1.Add(New ChoiceParameter("Filter.Owner",
			?(ValueIsFilled(String.AdditionalValuesOwner),
				String.AdditionalValuesOwner, String.Property)));
	EndIf;
	Items.PropertyValueTableValue.ChoiceParameters = New FixedArray(ChoiceParametersArray1);
EndProcedure

&AtClient
Procedure PropertyValueTableSelection(Item, RowSelected, Field, StandardProcessing)
	
	If Field.Name <> Items.PropertyValueTableQuestionColumn.Name Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	String = PropertyValueTable.FindByID(RowSelected);
	If Not ValueIsFilled(String.ToolTip) Then
		Return;
	EndIf;
	
	TitleText = NStr("en = 'Tooltip of the ""%1"" information record';");
	TitleText = StringFunctionsClientServer.SubstituteParametersToString(TitleText, String.Description);
	
	QuestionToUserParameters = StandardSubsystemsClient.QuestionToUserParameters();
	QuestionToUserParameters.Title = TitleText;
	QuestionToUserParameters.PromptDontAskAgain = False;
	QuestionToUserParameters.Picture = PictureLib.Information32;
	
	Buttons = New ValueList;
	Buttons.Add("OK", NStr("en = 'OK';"));
	StandardSubsystemsClient.ShowQuestionToUser(Undefined, String.ToolTip, Buttons, QuestionToUserParameters);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Write(Command)
	
	WritePropertiesValues();
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	WriteAndCloseCompletion();
	
EndProcedure

&AtClient
Procedure ChangeAdditionalDataContent(Command)
	
	If AvailablePropertySets.Count() = 0
	 Or Not ValueIsFilled(AvailablePropertySets[0].Value) Then
		
		ShowMessageBox(,
			NStr("en = 'Cannot get the additional information record sets of the object.
			           |
			           |Probably some of the required object attributes are blank.';"));
	Else
		FormParameters = New Structure;
		FormParameters.Insert("PropertyKind",
			PredefinedValue("Enum.PropertiesKinds.AdditionalInfo"));
		
		OpenForm("Catalog.AdditionalAttributesAndInfoSets.ListForm", FormParameters);
		
		MigrationParameters = New Structure;
		MigrationParameters.Insert("Set", AvailablePropertySets[0].Value);
		MigrationParameters.Insert("Property", Undefined);
		MigrationParameters.Insert("IsAdditionalInfo", True);
		MigrationParameters.Insert("PropertyKind",
			PredefinedValue("Enum.PropertiesKinds.AdditionalInfo"));
		
		If Items.PropertyValueTable.CurrentData <> Undefined Then
			MigrationParameters.Insert("Set", Items.PropertyValueTable.CurrentData.Set);
			MigrationParameters.Insert("Property", Items.PropertyValueTable.CurrentData.Property);
		EndIf;
		
		Notify("GoAdditionalDataAndAttributeSets", MigrationParameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure WriteAndCloseCompletion(Result = Undefined, AdditionalParameters = Undefined) Export
	
	WritePropertiesValues();
	Modified = False;
	Close();
	
EndProcedure

&AtServer
Procedure FillPropertiesValuesTable(FromOnCreateHandler)
	
	// Filling the tree with property values.
	If FromOnCreateHandler Then
		PropertiesValues = ReadPropertiesValuesFromInfoRegister(Parameters.Ref);
	Else
		PropertiesValues = GetCurrentPropertiesValues();
		PropertyValueTable.Clear();
	EndIf;
	
	TableToCheck = "InformationRegister.AdditionalInfo";
	AccessValue = Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo");
	
	Table = PropertyManagerInternal.PropertiesValues(
		PropertiesValues, AvailablePropertySets, Enums.PropertiesKinds.AdditionalInfo);
	
	CheckRights1 = Not Users.IsFullUser() And Common.SubsystemExists("StandardSubsystems.AccessManagement");
	
	If CheckRights1 Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		UniversalRestriction = ModuleAccessManagementInternal.LimitAccessAtRecordLevelUniversally();
		If Not UniversalRestriction Then
			PropertiesToCheck = Table.UnloadColumn("Property");
			AllowedProperties = ModuleAccessManagementInternal.AllowedDynamicListValues(
				TableToCheck,
				AccessValue,
				PropertiesToCheck, , True);
		EndIf;
	EndIf;
	
	For Each String In Table Do
		If Not CheckRights1 Then
			IsEditable = True;
		Else
			If UniversalRestriction Then
				Set = InformationRegisters.AdditionalInfo.CreateRecordSet();
				Set.Filter.Object.Set(Parameters.Ref);
				Set.Filter.Property.Set(String.Property);
				Record = Set.Add();
				Record.Property = String.Property;
				Record.Object = Parameters.Ref;
				IsEditable = ModuleAccessManagement.EditionAllowed(Set);
				If Not IsEditable
				   And Not ModuleAccessManagement.ReadingAllowed(Set) Then
					
					Continue;
				EndIf;
			Else
				IsEditable = False;
				// Check for reading the property.
				If AllowedProperties <> Undefined And AllowedProperties.Find(String.Property) = Undefined Then
					Continue;
				EndIf;
				
				// Check for writing the property.
				BeginTransaction();
				Try
					Set = InformationRegisters.AdditionalInfo.CreateRecordSet();
					Set.Filter.Object.Set(Parameters.Ref);
					Set.Filter.Property.Set(String.Property);
					
					Record = Set.Add();
					Record.Property = String.Property;
					Record.Object = Parameters.Ref;
					Set.DataExchange.Load = True;
					Set.Write(True);
					IsEditable = True;
					
					RollbackTransaction();
				Except
					ErrorInfo = ErrorInfo();
					ErrorProcessing.DetailErrorDescription(ErrorInfo);
					RollbackTransaction();
				EndTry;
			EndIf;
		EndIf;
		
		NewRow = PropertyValueTable.Add();
		FillPropertyValues(NewRow, String);
		
		If ValueIsFilled(NewRow.ToolTip) Then
			NewRow.ColumnQuestion = "?";
		EndIf;
		
		NewRow.PictureNumber = ?(String.Deleted, 0, -1);
		NewRow.IsEditable = IsEditable;
		
		If String.Value = Undefined
			And Common.TypeDetailsContainsType(String.ValueType, Type("Boolean")) Then
			NewRow.Value = False;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure WritePropertiesValues()
	
	// Writing property values in the information register.
	PropertiesValues = New Array;
	
	For Each String In PropertyValueTable Do
		Value = New Structure("Property, Value", String.Property, String.Value);
		PropertiesValues.Add(Value);
	EndDo;
	
	If PropertiesValues.Count() > 0 Then
		WritePropertySetInRegister(ObjectReference, PropertiesValues);
	EndIf;
	
	Modified = False;
	
EndProcedure

&AtServerNoContext
Procedure WritePropertySetInRegister(Val Ref, Val PropertiesValues)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.AdditionalInfo");
		LockItem.SetValue("Object", Ref);
		Block.Lock();
		
		Set = InformationRegisters.AdditionalInfo.CreateRecordSet();
		Set.Filter.Object.Set(Ref);
		Set.Read();
		CurrentValues = Set.Unload();
		For Each String In PropertiesValues Do
			Record = CurrentValues.Find(String.Property, "Property");
			If Record = Undefined Then
				Record = CurrentValues.Add();
				Record.Property = String.Property;
				Record.Value = String.Value;
				Record.Object   = Ref;
			EndIf;
			Record.Value = String.Value;
			
			If Not ValueIsFilled(Record.Value)
				Or Record.Value = False Then
				CurrentValues.Delete(Record);
			EndIf;
		EndDo;
		Set.Load(CurrentValues);
		Set.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
	EndTry;
	
EndProcedure

&AtServerNoContext
Function ReadPropertiesValuesFromInfoRegister(Ref)
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AdditionalInfo.Property,
	|	AdditionalInfo.Value
	|FROM
	|	InformationRegister.AdditionalInfo AS AdditionalInfo
	|WHERE
	|	AdditionalInfo.Object = &Object";
	Query.SetParameter("Object", Ref);
	
	Return Query.Execute().Unload();
	
EndFunction

&AtServer
Function GetCurrentPropertiesValues()
	
	PropertiesValues = New ValueTable;
	PropertiesValues.Columns.Add("Property");
	PropertiesValues.Columns.Add("Value");
	
	For Each String In PropertyValueTable Do
		
		If ValueIsFilled(String.Value) And (String.Value <> False) Then
			NewRow = PropertiesValues.Add();
			NewRow.Property = String.Property;
			NewRow.Value = String.Value;
		EndIf;
	EndDo;
	
	Return PropertiesValues;
	
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.PropertyValueTableValue.Name);
	
	// Date format - time.
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("PropertyValueTable.ValueType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = New TypeDescription("Date",,, New DateQualifiers(DateFractions.Time));
	Item.Appearance.SetParameterValue("Format", "DLF=T");
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.PropertyValueTableValue.Name);
	
	// Формат даты - 
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("PropertyValueTable.ValueType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = New TypeDescription("Date",,, New DateQualifiers(DateFractions.Date));
	Item.Appearance.SetParameterValue("Format", "DLF=D");
	
	//
	Item = ConditionalAppearance.Items.Add();
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.PropertyValueTableValue.Name);
	
	// 
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("PropertyValueTable.IsEditable");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	Item.Appearance.SetParameterValue("ReadOnly", True);
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
EndProcedure

#EndRegion
