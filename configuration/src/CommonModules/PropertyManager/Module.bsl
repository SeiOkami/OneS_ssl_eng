///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

////////////////////////////////////////////////////////////////////////////////
// 

// Creates main form attributes and fields necessary for work.
// Fills additional attributes if used.
// Is called from the OnCreateAtServer handler of the object form with properties.
// 
// Parameters:
//  Form - ClientApplicationForm - where additional attributes with properties will be displayed:
//    * Object - FormDataStructure - by the object type, with properties:
//      ** Ref - AnyRef - a reference to the object the properties are attached to.
//
//  AdditionalParameters - Undefined - all additional parameters have default values.
//                               Earlier the attribute was called Object and had the meaning
//                               as the structure property of the same name specified below.
//                          - Structure - 
//
//    * Object - FormDataStructure - by the object type, contains properties:
//      ** Ref - AnyRef - a reference to the object the properties are attached to.
//
//    * ItemForPlacementName - String - a group name of the form, in which properties will be placed.
//
//    * ArbitraryObject - Boolean - if True, a table with additional
//            attribute details is created in the form, the Object parameter is ignored, and additional attributes are not created and not filled in.
//
//            It is useful upon sequential use of one form for viewing or editing
//            additional attributes of different objects (including objects of different types).
//
//            After executing OnCreateAtServer, call FillAdditionalAttributesInForm()
//            o add and fill additional attributes.
//            To save changes, call TransferValuesFromFormAttributesToObject().
//            To update the set of attributes, call UpdateAdditionalAttributesItems().
//
//    * CommandBarItemName - String - a group name of the form to which the button will be added.
//            EditContentOfAdditionalAttributes. If the item name is not specified,
//            the standard group "Form.CommandBar" is used.
//
//    * HideDeleted - Boolean - enable/disable the hide deleted mode.
//            If the parameter is not specified, but the Object parameter is specified and the Ref property is not filled in,
//            the initial value is set to True, otherwise, False.
//            When calling the BeforeWriteAtServer procedure in the hide deleted mode, deleted values
//            are cleared (not transferred back to object), and the HideDeleted mode is set to False.
//
//    * LabelsDisplayParameters - See LabelsDisplayParameters.
//
Procedure OnCreateAtServer(Form, AdditionalParameters = Undefined) Export
	
	If Not PropertiesUsed(Form, AdditionalParameters) Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("Object",                     Undefined);
	Context.Insert("ItemForPlacementName",   "");
	Context.Insert("DeferredInitialization",    False);
	Context.Insert("ArbitraryObject",         False);
	Context.Insert("CommandBarItemName", "");
	Context.Insert("HideDeleted",            Undefined);
	Context.Insert("LabelsDisplayParameters",  LabelsDisplayParameters());
	
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		FillPropertyValues(Context, AdditionalParameters);
	EndIf;
	
	If Context.ArbitraryObject Then
		CreateAdditionalAttributesDetails = True;
	Else
		If Context.Object = Undefined Then
			ObjectDetails = Form.Object;
		Else
			ObjectDetails = Context.Object;
		EndIf;
		CreateAdditionalAttributesDetails = UseAddlAttributes(ObjectDetails.Ref);
		If Not ValueIsFilled(ObjectDetails.Ref) And Context.HideDeleted = Undefined Then
			Context.HideDeleted = True;
		EndIf;
	EndIf;
	
	NewMainFormObjects(Form, Context, CreateAdditionalAttributesDetails);
	
	If Context.DeferredInitialization Then
		
		If Not Form.PropertiesUseProperties
			Or Not Form.PropertiesUseAddlAttributes Then
			Return;
		EndIf;
		
		AssignmentKey = Undefined;
		ObjectPropertySets = PropertyManagerInternal.GetObjectPropertySets(
			ObjectDetails, AssignmentKey);
		
		PropertyManagerInternal.FillSetsWithAdditionalAttributes(
			ObjectPropertySets,
			Form.PropertiesObjectAdditionalAttributeSets);
		
		DisplayTab = PropertyManagerInternal.DisplayMoreTab(
			ObjectDetails.Ref, Form.PropertiesObjectAdditionalAttributeSets);
		
		If Form.PropertiesParameters.Property("EmptyDecorationAdded") Then
			For Each DecorationName1 In Form.PropertiesParameters.DecorationCollections Do
				Form.Items[DecorationName1].Visible = DisplayTab;
			EndDo;
		EndIf;
		
		UpdateFormAssignmentKey(Form, AssignmentKey);
	EndIf;
	
	If Not Context.ArbitraryObject
		And Not Context.DeferredInitialization Then
		FillAdditionalAttributesInForm(Form, ObjectDetails, , Context.HideDeleted);
	EndIf;
	
	SetLabelsVisibility(Form, Context.LabelsDisplayParameters.LabelsDestinationElementName);
	FillObjectLabels(Form, ObjectDetails, Context.ArbitraryObject);
	If Context.ArbitraryObject Then
		FillLabelsLegend(Form, ObjectDetails);
	EndIf;
	
EndProcedure

// Fills in an object from attributes created in the form.
// Is called from the BeforeWriteAtServer handler of the object form with properties.
//
// Parameters:
//  Form         - ClientApplicationForm - already set in the OnCreateAtServer procedure.
//  CurrentObject - CatalogObjectCatalogName
//                - DocumentObjectDocumentName
//                - ChartOfCharacteristicTypesObjectChartOfCharacteristicTypesName
//                - BusinessProcessObjectNameOfBusinessProcess
//                - TaskObjectTaskName
//                - ChartOfCalculationTypesObjectChartOfCalculationTypesName
//                - ChartOfAccountsObjectChartOfAccountsName
//
Procedure OnReadAtServer(Form, CurrentObject) Export
	
	Structure = New Structure("PropertiesUseProperties");
	FillPropertyValues(Structure, Form);
	
	If TypeOf(Structure.PropertiesUseProperties) = Type("Boolean")
		And Structure.PropertiesUseProperties Then
		
		If Form.PropertiesParameters.Property("DeferredInitializationExecuted")
			And Not Form.PropertiesParameters.DeferredInitializationExecuted Then
			Return;
		EndIf;
		
		FillAdditionalAttributesInForm(Form, CurrentObject);
	EndIf;
	
EndProcedure

// Fills in an object from attributes created in the form.
// Is called from the BeforeWriteAtServer handler of the object form with properties.
//
// Parameters:
//  Form         - ClientApplicationForm - already set in the OnCreateAtServer procedure.
//  CurrentObject - CatalogObjectCatalogName
//                - DocumentObjectDocumentName
//                - ChartOfCharacteristicTypesObjectChartOfCharacteristicTypesName
//                - BusinessProcessObjectNameOfBusinessProcess
//                - TaskObjectTaskName
//                - ChartOfCalculationTypesObjectChartOfCalculationTypesName
//                - ChartOfAccountsObjectChartOfAccountsName
//
Procedure BeforeWriteAtServer(Form, CurrentObject) Export
	
	PropertyManagerInternal.TransferValuesFromFormAttributesToObject(Form, CurrentObject, True);
	
EndProcedure

// Checks whether required attributes are filled in.
// 
// Parameters:
//  Form - ClientApplicationForm - already set in the OnCreateAtServer procedure with the following properties:
//     * PropertiesAdditionalAttributeDetails - ValueTable:
//        ** ValueAttributeName - String
//        ** Property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo
//        ** AdditionalValuesOwner - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo
//        ** ValueType - TypeDescription
//        ** MultilineInputField - Number
//        ** Deleted - Boolean
//        ** RequiredToFill - Boolean
//        ** Available - Boolean
//        ** isVisible - Boolean
//        ** Description - String
//        ** FormItemAdded - Boolean
//        ** OutputAsHyperlink - Boolean
//        ** RefTypeString - Boolean
//  Cancel                - Boolean - a parameter of the FillCheckProcessingAtServer handler.
//  CheckedAttributes - Array - a parameter of the FillCheckProcessingAtServer handler.
//  Object        - CatalogObjectCatalogName
//                - DocumentObjectDocumentName
//                - ChartOfCharacteristicTypesObjectChartOfCharacteristicTypesName
//                - BusinessProcessObjectNameOfBusinessProcess
//                - TaskObjectTaskName
//                - ChartOfCalculationTypesObjectChartOfCalculationTypesName
//                - ChartOfAccountsObjectChartOfAccountsName
//                - Undefined - 
//                                  
//
Procedure FillCheckProcessing(Form, Cancel, CheckedAttributes, Object = Undefined) Export
	
	SessionParameters.PropertiesFillingInteractiveCheck = True;
	
	If Not Form.PropertiesUseProperties
	 Or Not Form.PropertiesUseAddlAttributes Then
		
		Return;
	EndIf;
	
	Receiver = New Structure;
	Receiver.Insert("PropertiesParameters", Undefined);
	FillPropertyValues(Receiver, Form);
	
	If TypeOf(Receiver.PropertiesParameters) = Type("Structure")
		And Receiver.PropertiesParameters.Property("DeferredInitializationExecuted")
		And Not Receiver.PropertiesParameters.DeferredInitializationExecuted Then
		FillAdditionalAttributesInForm(Form, Object);
	EndIf;
	
	For Each String In Form.PropertiesAdditionalAttributeDetails Do
		If String.RequiredToFill And Not String.Deleted Then
			If Not AttributeIsAvailableByFunctionalOptions(String) Then
				Continue;
			EndIf;
			Result = True;
			If Object = Undefined Then
				ObjectDetails = Form.Object;
			Else
				ObjectDetails = Object;
			EndIf;
			
			For Each DependentAttribute In Form.PropertiesDependentAdditionalAttributesDescription Do
				If DependentAttribute.ValueAttributeName = String.ValueAttributeName
					And DependentAttribute.FillingRequiredCondition <> Undefined Then
					
					Parameters = New Structure;
					Parameters.Insert("ParameterValues", DependentAttribute.FillingRequiredCondition.ParameterValues);
					Parameters.Insert("Form", Form);
					Parameters.Insert("ObjectDetails", ObjectDetails);
					Result = Common.CalculateInSafeMode(DependentAttribute.FillingRequiredCondition.ConditionCode, Parameters);
					
					Break;
				EndIf;
			EndDo;
			If Not Result Then
				Continue;
			EndIf;
			
			If Not ValueIsFilled(Form[String.ValueAttributeName]) Then
				Common.MessageToUser(
					StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The ""%1"" field is required.';"), String.Description),
					,
					String.ValueAttributeName,
					,
					Cancel);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Updates sets of additional attributes and info for an object kind with properties.
//  Used upon writing catalog items that are object kinds with properties.
//  For example, if there is the Products catalog, to which the Properties subsystem is applied and
// the ProductKinds catalog is created for it, you need to call this procedure when writing the ProductKind item.
//
// Parameters:
//  ObjectKind                - CatalogObjectCatalogName - for example, a product kind before writing.
//  ObjectWithPropertiesName    - String - for example, Products.
//  PropertySetAttributeName - String - used when there are several property sets or
//                              an attribute name of the default set that differs from PropertiesSet is used.
//
Procedure BeforeWriteObjectKind(ObjectKind,
                                  ObjectWithPropertiesName,
                                  PropertySetAttributeName = "PropertiesSet") Export
	
	SetPrivilegedMode(True);
	
	PropertiesSet   = ObjectKind[PropertySetAttributeName];
	SetParent = PropertiesSetByName(ObjectWithPropertiesName);
	If SetParent = Undefined Then
		SetParent = Catalogs.AdditionalAttributesAndInfoSets[ObjectWithPropertiesName];
	EndIf;
	
	If ValueIsFilled(PropertiesSet) Then
		
		OldSetProperties = Common.ObjectAttributesValues(
			PropertiesSet, "Description, Parent, DeletionMark");
		
		If OldSetProperties.Description    = ObjectKind.Description
		   And OldSetProperties.DeletionMark = ObjectKind.DeletionMark
		   And OldSetProperties.Parent        = SetParent Then
			
			Return;
		EndIf;
		
		If OldSetProperties.Parent = SetParent Then
			Block = New DataLock;
			LockItem = Block.Add("Catalog.AdditionalAttributesAndInfoSets");
			LockItem.SetValue("Ref", PropertiesSet);
			Block.Lock();
			
			LockDataForEdit(PropertiesSet);
			PropertySetObject = PropertiesSet.GetObject();
		Else
			PropertySetObject = PropertiesSet.Copy();
		EndIf;
	Else
		PropertySetObject = Catalogs.AdditionalAttributesAndInfoSets.CreateItem();
		PropertySetObject.Used = True;
	EndIf;
	
	PropertySetObject.Description    = StrReplace(ObjectKind.Description, ".", "");
	PropertySetObject.DeletionMark = ObjectKind.DeletionMark;
	PropertySetObject.Parent        = SetParent;
	PropertySetObject.Write();
	
	ObjectKind[PropertySetAttributeName] = PropertySetObject.Ref;
	
EndProcedure

// 
//
// Parameters:
//  ObjectKind                - CatalogObjectCatalogName -
//  PropertySetAttributeName - String - used when there are several property sets, or
//                              when the name of the main set's props is used, other than"property Set".
//
Procedure BeforeDeleteObjectKind(ObjectKind, PropertySetAttributeName = "PropertiesSet") Export
	
	SetPrivilegedMode(True);
	PropertiesSet = ObjectKind[PropertySetAttributeName];
	
	Query = New Query;
	Query.SetParameter("PropertiesSet", PropertiesSet);
	Query.Text =
		"SELECT
		|	AdditionalAttributesAndInfo.Ref AS Ref
		|FROM
		|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
		|WHERE
		|	AdditionalAttributesAndInfo.PropertiesSet = &PropertiesSet";
	Result = Query.Execute().Unload();
	AdditionalAttributes = Result.UnloadColumn("Ref");
	For Each AdditionalAttribute In AdditionalAttributes Do
		
		Block = New DataLock;
		LockItem = Block.Add("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo");
		LockItem.SetValue("Ref", AdditionalAttribute);
		Block.Lock();
			
		If Common.RefExists(AdditionalAttribute) Then
			AdditionalAttributeObject = AdditionalAttribute.GetObject();
			AdditionalAttributeObject.PropertiesSet = Catalogs.AdditionalAttributesAndInfoSets.EmptyRef();
			AdditionalAttributeObject.Write();
		EndIf;
		
	EndDo;
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.AdditionalAttributesAndInfoSets");
	LockItem.SetValue("Ref", PropertiesSet);
	Block.Lock();
	
	If Common.RefExists(PropertiesSet) Then
		PropertySetObject = PropertiesSet.GetObject();
		PropertySetObject.Delete(); 
	EndIf;
	
EndProcedure

// 
// 
// Parameters:
//  Form           - ClientApplicationForm - already set in the OnCreateAtServer procedure.
//
//  Object          - Undefined - take the object from the Object form attribute.
//                  - CatalogObjectCatalogName
//                  - DocumentObjectDocumentName
//                  - ChartOfCharacteristicTypesObjectChartOfCharacteristicTypesName
//                  - BusinessProcessObjectNameOfBusinessProcess
//                  - TaskObjectTaskName
//                  - ChartOfCalculationTypesObjectChartOfCalculationTypesName
//                  - ChartOfAccountsObjectChartOfAccountsName
//                  - FormDataStructure
//
//  HideDeleted - Undefined - do not change the current hide deleted mode set earlier.
//                  - Boolean - 
//                    
//                    
//
Procedure UpdateAdditionalAttributesItems(Form, Object = Undefined, HideDeleted = Undefined) Export
	
	PropertyManagerInternal.TransferValuesFromFormAttributesToObject(Form, Object);
	FillAdditionalAttributesInForm(Form, Object, , HideDeleted);
	
	PropertyManagerInternal.MoveSetLabelsIntoObject(Form, Object);
	FillObjectLabels(Form, Object);
	
EndProcedure

// 
// 
//
// Parameters:
//   Settings              - DataCompositionSettings -
//   Rows                 - DynamicListRows -
//   OwnerName           - String                    -
//                                                        
//                                                        
//
Procedure OnGetDataAtServer(Settings, Rows, OwnerName = Undefined) Export
	
	If Not Common.SubsystemExists("StandardSubsystems.Properties") Then
		Return;
	EndIf;
	
	If Not GetFunctionalOption("UseAdditionalAttributesAndInfo") Then
		Return;
	EndIf;
	
	Keys = Rows.GetKeys();
	If Keys.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Var_Key In Keys Do
		If OwnerName <> Undefined Then
			Owner = Var_Key[OwnerName];
		Else
			Owner = Var_Key;
		EndIf;
		If ValueIsFilled(Owner) Then
			ObjectsKind = Owner.Metadata().FullName();
			Break;
		EndIf;
	EndDo;
	
	PropertiesListForObjectsKind = PropertyManagerInternal.PropertiesListForObjectsKind(ObjectsKind, "Labels");
	If PropertiesListForObjectsKind = Undefined Then
		Return;
	EndIf;
	
	Labels = PropertiesListForObjectsKind.UnloadColumn("Property");
	LabelsAttributes = Common.ObjectsAttributesValues(Labels, "PropertiesColor, DeletionMark");
	
	For Each String In Rows Do
		Composite = String.Key;
		RowData = Rows.Get(Composite);
		If OwnerName <> Undefined Then
			Owner = Composite[OwnerName];
		Else
			Owner = Composite;
		EndIf;
		If Not ValueIsFilled(Owner) Then
			Continue;
		EndIf;
		AdditionalAttributes = Owner.AdditionalAttributes.Unload();
		Labels = PropertiesByAdditionalAttributesKind(AdditionalAttributes, Enums.PropertiesKinds.Labels);
		LabelNumber = 1;
		For Each Label In Labels Do
			LabelAttributes = LabelsAttributes.Get(Label);
			If LabelAttributes = Undefined Or LabelAttributes.DeletionMark Then
				Continue;
			EndIf;
			PropertyName = StrTemplate("Label%1", LabelNumber);
			If RowData.Data.Property(PropertyName) Then
				RowData.Data[PropertyName] =
					Enums.PropertiesColors.IndexOf(LabelAttributes.PropertiesColor) + 1;
				LabelNumber = LabelNumber + 1;
			Else
				Break;
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

// 
//
// Parameters:
//  Owner - MetadataObject
//           - String - 
//           - CatalogRef.AdditionalAttributesAndInfoSets - 
//  Parameters - See PropertyAdditionParameters.
//  IsInfoRecord - Boolean -
//                         
//
Procedure AddProperty(Owner, Parameters, IsInfoRecord = False) Export
	
	If TypeOf(Owner) = Type("MetadataObject") Then
		PredefinedItemName = StrReplace(Owner.FullName(), ".", "_");
	ElsIf TypeOf(Owner) = Type("String") Then
		If StrFind(Owner, ".") = 0 Then
			// 
			PredefinedItemName = Owner;
		Else
			PredefinedItemName = StrReplace(Owner, ".", "_");
		EndIf;
	EndIf;
	
	If TypeOf(Owner) = Type("CatalogRef.AdditionalAttributesAndInfoSets") Then
		PropertiesSet = Owner;
	Else
		PropertiesSet = PropertiesSetByName(PredefinedItemName);
		If PropertiesSet = Undefined Then
			ExceptionText = NStr("en = 'The passed ""%1"" object is not connected to the Properties subsystem.';");
			Raise StringFunctionsClientServer.SubstituteParametersToString(ExceptionText, Owner);
		EndIf;
	EndIf;
	
	MissingParameters = New Array;
	If Not Parameters.Property("Description")
		Or Not ValueIsFilled(Parameters.Description) Then
		MissingParameters.Add("Description");
	EndIf;
	
	If Not Parameters.Property("Type") 
	 Or Not ValueIsFilled(Parameters.Type) Then
		MissingParameters.Add("Type");
	EndIf;
	
	If MissingParameters.Count() > 0 Then
		MissingParameters = StrConcat(MissingParameters, ", ");
		ExceptionText = NStr("en = 'Required parameters are not passed:
			|%1.';");
		Raise StringFunctionsClientServer.SubstituteParametersToString(ExceptionText, MissingParameters);
	EndIf;
	
	EmptyRef = ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.EmptyRef();
	// 
	Result = PropertyManagerInternal.DescriptionAlreadyUsed(EmptyRef, PropertiesSet, Parameters.Description);
	If ValueIsFilled(Result) Then
		Raise Result;
	EndIf;
	
	// 
	If Parameters.Property("Name")
		And ValueIsFilled(Parameters.Name) Then
		Result = PropertyManagerInternal.NameAlreadyUsed(Parameters.Name, EmptyRef);
		If ValueIsFilled(Result) Then
			Raise Result;
		EndIf;
	Else
		Name = "";
		ObjectTitle = Parameters.Description;
		PropertyManagerInternal.DeleteDisallowedCharacters(ObjectTitle);
		ObjectTitleInParts = StrSplit(ObjectTitle, " ", False);
		For Each TitlePart In ObjectTitleInParts Do
			Name = Name + Upper(Left(TitlePart, 1)) + Mid(TitlePart, 2);
		EndDo;
		
		If PropertyManagerInternal.TheNameStartsWithANumber(Name) Then
			Name = "_" + Name;
		EndIf;
		
		Result = PropertyManagerInternal.NameAlreadyUsed(Name, EmptyRef);
		If ValueIsFilled(Result) Then
			UID = New UUID();
			UIDString = StrReplace(String(UID), "-", "");
			Name = Name + "_" + UIDString;
		EndIf;
		
		Parameters.Insert("Name", Name);
	EndIf;
	
	// 
	If Parameters.Property("IDForFormulas")
		And ValueIsFilled(Parameters.IDForFormulas) Then
		Result = PropertyManagerInternal.IDForFormulasAlreadyUsed(Parameters.IDForFormulas, EmptyRef);
		If ValueIsFilled(Result) Then
			Raise Result;
		EndIf;
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.AdditionalAttributesAndInfoSets");
	LockItem.SetValue("Ref", PropertiesSet);
	BeginTransaction();
	Try
		Block.Lock();
		
		NewProperty = ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.CreateItem();
		FillPropertyValues(NewProperty, Parameters);
		
		NewProperty.Title                 = Parameters.Description;
		NewProperty.IsAdditionalInfo = IsInfoRecord;
		NewProperty.PropertiesSet              = PropertiesSet;
		
		// 
		NewProperty.TitleLanguage1 = Parameters.Description;
		NewProperty.TitleLanguage2 = Parameters.Description;
	
		NewProperty.Write();
		
		ObjectPropertySet = PropertiesSet.GetObject();
		If NewProperty.IsAdditionalInfo Then
			TabularSection = ObjectPropertySet.AdditionalInfo;
		Else
			TabularSection = ObjectPropertySet.AdditionalAttributes;
		EndIf;
		FoundRow = TabularSection.Find(PropertiesSet.Ref, "Property");
		If FoundRow = Undefined Then
			NewRow = TabularSection.Add();
			NewRow.Property = NewProperty.Ref;
			ObjectPropertySet.Write();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// 
// 
//
// Parameters:
//  Owner  - String - Additional attribute's name.
//            - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo -  
//                
//  Parameters - See PropertyValAdditionParameters.
//  Hierarchy  - Boolean  
//
// Returns:
//  CatalogRef.ObjectsPropertiesValues
//  
//
Function AddPropertyValue(Val Owner, Parameters, Hierarchy = False) Export
	
	If Not Parameters.Property("Description")
		Or Not ValueIsFilled(Parameters.Description) Then
		Raise NStr("en = 'The required ""Description"" parameter is not specified.';");
	EndIf;
	
	If TypeOf(Owner) = Type("String") Then
		Query = New Query;
		Query.SetParameter("Name", Owner);
		Query.Text =
			"SELECT
			|	AdditionalAttributesAndInfo.Ref AS Ref
			|FROM
			|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
			|WHERE
			|	AdditionalAttributesAndInfo.Name = &Name";
		Result = Query.Execute().Unload();
		If Result.Count() = 0 Then
			ExceptionPattern = NStr("en = 'An additional attribute with the ""%1"" name is not found.';");
			Raise StringFunctionsClientServer.SubstituteParametersToString(ExceptionPattern, Owner);
		EndIf;
		
		Owner = Result[0].Ref;
	EndIf;
	
	AttributeType = Common.ObjectAttributeValue(Owner, "ValueType");
	If Not PropertyManagerInternal.ValueTypeContainsPropertyValues(AttributeType) Then
		ExceptionPattern = NStr("en = 'You can add values only for additional attributes
			|with the ""%1"" or ""%2"" types. The current attribute value type is ""%3""';");
		ExceptionPattern = StrReplace(ExceptionPattern, Chars.LF, " ");
		Raise StringFunctionsClientServer.SubstituteParametersToString(ExceptionPattern,
			Type("CatalogRef.ObjectsPropertiesValues"),
			Type("CatalogRef.ObjectPropertyValueHierarchy"),
			AttributeType);
	EndIf;
	
	IsFolder = Parameters.Property("IsFolder") And Parameters.IsFolder;
	If Hierarchy Then
		If IsFolder Then
			AttributeValue = Catalogs.ObjectPropertyValueHierarchy.CreateFolder();
		Else
			AttributeValue = Catalogs.ObjectPropertyValueHierarchy.CreateItem();
		EndIf;
	Else
		If IsFolder Then
			AttributeValue = Catalogs.ObjectsPropertiesValues.CreateFolder();
		Else
			AttributeValue = Catalogs.ObjectsPropertiesValues.CreateItem();
		EndIf;
	EndIf;
	
	AttributeValue.Owner = Owner;
	FillPropertyValues(AttributeValue, Parameters);
	
	AttributeValue.Write();
	
	Return AttributeValue.Ref;
	
EndFunction

// 
// 
// Returns:
//  Structure:
//     * Description - String -
//     * Type          - TypeDescription -
//     * Name          - String
//     * Comment  - String
//     * ValueFormTitle       - String
//     * ValueChoiceFormTitle - String
//     * IDForFormulas - String
//     * MultilineInputField - Boolean
//     * ToolTip              - String
//
Function PropertyAdditionParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("Description", "");
	Parameters.Insert("Type");
	Parameters.Insert("Name", "");
	Parameters.Insert("Comment", "");
	Parameters.Insert("ValueFormTitle", "");
	Parameters.Insert("ValueChoiceFormTitle", "");
	Parameters.Insert("IDForFormulas", "");
	Parameters.Insert("MultilineInputField", False);
	Parameters.Insert("ToolTip", "");
	
	Return Parameters;
	
EndFunction

// 
// 
// Returns:
//  Structure:
//     * Description - String -
//     * FullDescr - String
//     * Parent - CatalogRef.ObjectsPropertiesValues
//                - CatalogRef.ObjectPropertyValueHierarchy
//     * IsFolder - Boolean
//
Function PropertyValAdditionParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("Description", "");
	Parameters.Insert("FullDescr", "");
	Parameters.Insert("Parent");
	Parameters.Insert("IsFolder", False);
	
	Return Parameters;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for non-standard processing of additional properties.

// Returns a reference to a predefined property set by the set name.
// Used for sets specified in the
// PropertyManagerOverridable.OnCreatePredefinedPropertiesSets procedure.
//
// Parameters:
//  SetName - String - a name of the property set to be got.
//
// Returns:
//  CatalogRef.AdditionalAttributesAndInfoSets - 
//  
//
// Example:
//  Ref = PropertyManager.PropertiesSetByName('Catalog_Users");
//
Function PropertiesSetByName(SetName) Export
	PredefinedPropertiesSets = PropertyManagerCached.PredefinedPropertiesSets();
	Set = PredefinedPropertiesSets.Get(SetName); // See Catalogs.AdditionalAttributesAndInfoSets.SetProperties
	If Set = Undefined Then
		Return Undefined;
	Else
		Return Set.Ref;
	EndIf;
EndFunction

// Creates/recreates additional attributes and items in the property owner form.
//
// Parameters:
//  Form           - ClientApplicationForm - already set in the OnCreateAtServer procedure.
//
//  Object          - Undefined - take the object from the Object form attribute.
//                  - CatalogObjectCatalogName
//                  - DocumentObjectDocumentName
//                  - ChartOfCharacteristicTypesObjectChartOfCharacteristicTypesName
//                  - BusinessProcessObjectNameOfBusinessProcess
//                  - TaskObjectTaskName
//                  - ChartOfCalculationTypesObjectChartOfCalculationTypesName
//                  - ChartOfAccountsObjectChartOfAccountsName
//                  - FormDataStructure
//
//  LabelsFields    - Boolean - if True is specified, then instead of input fields, the label fields are created on the form.
//
//  HideDeleted - Undefined - do not change the current hide deleted mode set earlier.
//                  - Boolean - 
//                    
//                    
//
Procedure FillAdditionalAttributesInForm(Form, Object = Undefined, LabelsFields = False, HideDeleted = Undefined) Export
	
	If Not Form.PropertiesUseProperties
	 Or Not Form.PropertiesUseAddlAttributes Then
		Return;
	EndIf;
	
	If TypeOf(HideDeleted) = Type("Boolean") Then
		Form.PropertiesHideDeleted = HideDeleted;
	EndIf;
	
	If Object = Undefined Then
		ObjectDetails = Form.Object;
	Else
		ObjectDetails = Object;
	EndIf;
	
	Form.PropertiesObjectAdditionalAttributeSets = New ValueList;
	
	AssignmentKey = Undefined;
	ObjectPropertySets = PropertyManagerInternal.GetObjectPropertySets(
		ObjectDetails, AssignmentKey);
	
	PropertyManagerInternal.FillSetsWithAdditionalAttributes(
		ObjectPropertySets,
		Form.PropertiesObjectAdditionalAttributeSets);
	
	UpdateFormAssignmentKey(Form, AssignmentKey);
	
	PropertyKind = Enums.PropertiesKinds.AdditionalAttributes;
	PropertiesDetails = PropertyManagerInternal.PropertiesValues(
		ObjectDetails.AdditionalAttributes.Unload(),
		Form.PropertiesObjectAdditionalAttributeSets,
		PropertyKind);
	
	PropertiesDetails.Columns.Add("ValueAttributeName");
	PropertiesDetails.Columns.Add("RefTypeString");
	PropertiesDetails.Columns.Add("ReferenceAttributeNameValue");
	PropertiesDetails.Columns.Add("NameUniquePart");
	PropertiesDetails.Columns.Add("AdditionalValue");
	PropertiesDetails.Columns.Add("Boolean");
	
	DeleteOldAttributesAndItems(Form);
	
	// Create attributes.
	AttributesToBeAdded = New Array();
	
	For Each PropertyDetails In PropertiesDetails Do
		
		PropertyValueType1 = PropertyDetails.ValueType;
		TypesList = PropertyValueType1.Types();
		StringAttribute2 = (TypesList.Count() = 1) And (TypesList[0] = Type("String"));
		
		// Support of strings with unlimited length.
		UseUnlimitedString = PropertyManagerInternal.UseUnlimitedString(
			PropertyValueType1, PropertyDetails.MultilineInputField);
		
		If UseUnlimitedString Then
			PropertyValueType1 = New TypeDescription("String");
		ElsIf PropertyValueType1.ContainsType(Type("String"))
			And PropertyValueType1.StringQualifiers.Length = 0 Then
			// 
			// 
			PropertyValueType1 = New TypeDescription(PropertyDetails.ValueType,
				,,, New StringQualifiers(1024));
		EndIf;
		
		PropertyDetails.NameUniquePart = 
			StrReplace(Upper(String(PropertyDetails.Set.UUID())), "-", "x")
			+ "_"
			+ StrReplace(Upper(String(PropertyDetails.Property.UUID())), "-", "x");
		
		PropertyDetails.ValueAttributeName =
			"AdditionalAttributeValue_" + PropertyDetails.NameUniquePart;
		
		PropertyDetails.RefTypeString = False;
		If StringAttribute2
			And Not UseUnlimitedString
			And PropertyDetails.OutputAsHyperlink Then
			FormattedString                           = New TypeDescription("FormattedString");
			PropertyDetails.RefTypeString           = True;
			PropertyDetails.ReferenceAttributeNameValue = "ReferenceAdditionalAttributeValue" + PropertyDetails.NameUniquePart;
			
			Attribute = New FormAttribute(PropertyDetails.ReferenceAttributeNameValue, FormattedString, , PropertyDetails.Description, True);
			AttributesToBeAdded.Add(Attribute);
		EndIf;
		
		If PropertyDetails.Deleted Then
			PropertyValueType1 = New TypeDescription("String");
		EndIf;
		
		Attribute = New FormAttribute(PropertyDetails.ValueAttributeName, PropertyValueType1, , PropertyDetails.Description, True);
		AttributesToBeAdded.Add(Attribute);
		
		PropertyDetails.AdditionalValue =
			PropertyManagerInternal.ValueTypeContainsPropertyValues(PropertyValueType1);
		
		PropertyDetails.Boolean = Common.TypeDetailsContainsType(PropertyValueType1, Type("Boolean"));
	EndDo;
	Form.ChangeAttributes(AttributesToBeAdded);
	
	// Create form items.
	For Each PropertyDetails In PropertiesDetails Do
		
		ItemForPlacementName = Form.PropertiesItemNameForPlacement;
		If TypeOf(ItemForPlacementName) <> Type("ValueList") Then
			If ItemForPlacementName = Undefined Then
				ItemForPlacementName = "";
			EndIf;
			
			PlacementItem = ?(ItemForPlacementName = "", Undefined, Form.Items[ItemForPlacementName]);
		Else
			SectionsForPlacement = Form.PropertiesItemNameForPlacement;
			SetPlacement = SectionsForPlacement.FindByValue(PropertyDetails.Set);
			If SetPlacement = Undefined Then
				SetPlacement = SectionsForPlacement.FindByValue("AllOther");
			EndIf;
			PlacementItem = Form.Items[SetPlacement.Presentation];
		EndIf;
		
		FormPropertyDetails = Form.PropertiesAdditionalAttributeDetails.Add();
		FillPropertyValues(FormPropertyDetails, PropertyDetails);
		
		// Filling in the table of dependent additional attributes.
		If PropertyDetails.AdditionalAttributesDependencies.Count() > 0
			And Not PropertyDetails.Deleted Then
			DependentAttributeDetails = Form.PropertiesDependentAdditionalAttributesDescription.Add();
			FillPropertyValues(DependentAttributeDetails, PropertyDetails);
		EndIf;
		
		RowFilter = New Structure;
		RowFilter.Insert("PropertiesSet", PropertyDetails.Set);
		ThisSetDependencies = PropertyDetails.AdditionalAttributesDependencies.FindRows(RowFilter);
		For Each TableRow In ThisSetDependencies Do
			If TableRow.DependentProperty = "RequiredToFill"
				And PropertyDetails.ValueType = New TypeDescription("Boolean") Then
				Continue;
			EndIf;
			If PropertyDetails.Deleted Then
				Continue;
			EndIf;
			
			If TypeOf(TableRow.Attribute) = Type("String") Then
				AttributePath1 = "Parameters.ObjectDetails." + TableRow.Attribute;
			Else
				AdditionalAttributeDetails = PropertiesDetails.Find(TableRow.Attribute, "Property");
				If AdditionalAttributeDetails = Undefined Then
					Continue; // Additional attribute does not exist, the condition is ignored.
				EndIf;
				AttributePath1 = "Parameters.Form." + AdditionalAttributeDetails.ValueAttributeName;
			EndIf;
			
			PropertyManagerInternal.BuildDependenciesConditions(DependentAttributeDetails, AttributePath1, TableRow);
		EndDo;
		
		If PropertyDetails.RefTypeString Then
			If ValueIsFilled(PropertyDetails.Value) Then
				Value = PropertyDetails.ValueType.AdjustValue(PropertyDetails.Value);
				StringValue2 = StringFunctions.FormattedString(Value);
			Else
				Value = NStr("en = 'not set';");
				EditLink1 = "NotDefined";
				StringValue2 = New FormattedString(Value,, StyleColors.EmptyHyperlinkColor,, EditLink1);
			EndIf;
			Form[PropertyDetails.ReferenceAttributeNameValue] = StringValue2;
		EndIf;
		Form[PropertyDetails.ValueAttributeName] = PropertyDetails.Value;
		
		If PropertyDetails.Deleted And Form.PropertiesHideDeleted Then
			Continue;
		EndIf;
		
		If ObjectPropertySets.Count() > 1 Then
			
			ListItem = Form.PropertiesAdditionalAttributeGroupItems.FindByValue(
				PropertyDetails.Set);
			
			If ListItem <> Undefined Then
				Parent = Form.Items[ListItem.Presentation];
			Else
				SetDetails = ObjectPropertySets.Find(PropertyDetails.Set, "Set");
				
				If SetDetails = Undefined Then
					SetDetails = ObjectPropertySets.Add();
					SetDetails.Set     = PropertyDetails.Set;
					SetDetails.Title = NStr("en = 'Deleted attributes';")
				EndIf;
				
				If Not ValueIsFilled(SetDetails.Title) Then
					SetDetails.Title = String(PropertyDetails.Set);
				EndIf;
				
				SetItemName = "AdditionalAttributesSet" + PropertyDetails.NameUniquePart;
				
				Parent = Form.Items.Add(SetItemName, Type("FormGroup"), PlacementItem);
				
				Form.PropertiesAdditionalAttributeGroupItems.Add(
					PropertyDetails.Set, Parent.Name);
				
				If TypeOf(PlacementItem) = Type("FormGroup")
				   And PlacementItem.Type = FormGroupType.Pages Then
					
					Parent.Type = FormGroupType.Page;
				Else
					Parent.Type = FormGroupType.UsualGroup;
					Parent.Representation = UsualGroupRepresentation.None;
				EndIf;
				Parent.ShowTitle = False;
				Parent.Group = ChildFormItemsGroup.Vertical;
				
				FilledGroupProperties = New Structure;
				For Each Column In ObjectPropertySets.Columns Do
					If SetDetails[Column.Name] <> Undefined Then
						FilledGroupProperties.Insert(Column.Name, SetDetails[Column.Name]);
					EndIf;
				EndDo;
				FillPropertyValues(Parent, FilledGroupProperties);
			EndIf;
		Else
			Parent = PlacementItem;
		EndIf;
		
		If PropertyDetails.OutputAsHyperlink Then
			HyperlinkGroupName = "Group_" + PropertyDetails.NameUniquePart;
			HyperlinkGroup = Form.Items.Add(HyperlinkGroupName, Type("FormGroup"), Parent);
			HyperlinkGroup.Type = FormGroupType.UsualGroup;
			HyperlinkGroup.Representation = UsualGroupRepresentation.None;
			HyperlinkGroup.ShowTitle = False;
			HyperlinkGroup.Group = ChildFormItemsGroup.AlwaysHorizontal;
			HyperlinkGroup.Title = PropertyDetails.Description;
			
			Item = Form.Items.Add(PropertyDetails.ValueAttributeName, Type("FormField"), HyperlinkGroup); // 
			
			AttributeIsAvailable = AttributeIsAvailableByFunctionalOptions(PropertyDetails);
			If AttributeIsAvailable And Not LabelsFields Then
				ButtonName = "Button_" + PropertyDetails.NameUniquePart;
				Button = Form.Items.Add(
					ButtonName,
					Type("FormButton"),
					HyperlinkGroup);
				
				ButtonTitle = NStr("en = 'Start/finish editing of attribute %1';");
				Button.Title = StringFunctionsClientServer.SubstituteParametersToString(ButtonTitle, PropertyDetails.Description);
				Button.LocationInCommandBar = ButtonLocationInCommandBar.InAdditionalSubmenu;
				Button.CommandName = "EditAttributeHyperlink";
				Button.ShapeRepresentation = ButtonShapeRepresentation.WhenActive;
			EndIf;
			
			If Not PropertyDetails.RefTypeString And ValueIsFilled(PropertyDetails.Value) Then
				Item.Hyperlink = True;
			EndIf;
		Else
			Item = Form.Items.Add(PropertyDetails.ValueAttributeName, Type("FormField"), Parent); // 
		EndIf;
		
		FormPropertyDetails.FormItemAdded = True;
		
		If PropertyDetails.Boolean And IsBlankString(PropertyDetails.FormatProperties) Then
			Item.Type = FormFieldType.CheckBoxField;
			Item.TitleLocation = FormItemTitleLocation.Right;
		Else
			If LabelsFields Then
				Item.Type = FormFieldType.InputField;
			ElsIf PropertyDetails.OutputAsHyperlink
				And (PropertyDetails.RefTypeString
					Or ValueIsFilled(PropertyDetails.Value))Then
				Item.Type = FormFieldType.LabelField;
			Else
				Item.Type = FormFieldType.InputField;
				Item.AutoMarkIncomplete = PropertyDetails.RequiredToFill And Not PropertyDetails.Deleted;
			EndIf;
			
			Item.VerticalStretch = False;
			Item.TitleLocation     = FormItemTitleLocation.Left;
		EndIf;
		
		If PropertyDetails.RefTypeString Then
			Item.DataPath = PropertyDetails.ReferenceAttributeNameValue;
			Item.SetAction("URLProcessing", "Attachable_PropertiesExecuteCommand");
		Else
			Item.DataPath = PropertyDetails.ValueAttributeName;
		EndIf;
		Item.ToolTip   = PropertyDetails.ToolTip;
		Item.SetAction("OnChange", "Attachable_OnChangeAdditionalAttribute");
		
		If Item.Type = FormFieldType.InputField
		   And Not UseUnlimitedString
		   And PropertyDetails.ValueType.Types().Find(Type("String")) <> Undefined Then
			
			Item.TypeLink = New TypeLink("PropertiesAdditionalAttributeDetails.Property",
				PropertiesDetails.IndexOf(PropertyDetails));
		EndIf;
		
		If PropertyDetails.MultilineInputField > 0 Then
			If Not LabelsFields Then
				Item.MultiLine = True;
			EndIf;
			Item.Height = PropertyDetails.MultilineInputField;
		EndIf;
		
		If Not IsBlankString(PropertyDetails.FormatProperties)
			And Not PropertyDetails.OutputAsHyperlink Then
			If LabelsFields Then
				Item.Format = PropertyDetails.FormatProperties;
			Else
				FormatString = "";
				Array = StrSplit(PropertyDetails.FormatProperties, ";", False);
				
				For Each Substring In Array Do
					If StrFind(Substring, "ДП=") > 0 Or StrFind(Substring, "DE=") > 0 Then // @Non-NLS
						Continue;
					EndIf;
					If StrFind(Substring, "ЧН=") > 0 Or StrFind(Substring, "NZ=") > 0 Then // @Non-NLS
						Continue;
					EndIf;
					If StrFind(Substring, "ДФ=") > 0 Or StrFind(Substring, "DF=") > 0 Then // @Non-NLS
						If StrFind(Substring, "ддд") > 0 Or StrFind(Substring, "ddd") > 0 Then // @Non-NLS
							Substring = StrReplace(Substring, "ддд", "дд"); // @Non-NLS-1, @Non-NLS-2
							Substring = StrReplace(Substring, "ddd", "dd");
						EndIf;
						If StrFind(Substring, "дддд") > 0 Or StrFind(Substring, "dddd") > 0 Then // @Non-NLS
							Substring = StrReplace(Substring, "дддд", "дд"); // @Non-NLS-1, @Non-NLS-2
							Substring = StrReplace(Substring, "dddd", "dd");
						EndIf;
						If StrFind(Substring, "МММ") > 0 Or StrFind(Substring, "MMM") > 0 Then // @Non-NLS
							Substring = StrReplace(Substring, "МММ", "ММ"); // @Non-NLS-1, @Non-NLS-2
							Substring = StrReplace(Substring, "MMM", "MM");
						EndIf;
						If StrFind(Substring, "ММММ") > 0 Or StrFind(Substring, "MMMM") > 0 Then // @Non-NLS
							Substring = StrReplace(Substring, "ММММ", "ММ"); // @Non-NLS-1, @Non-NLS-2
							Substring = StrReplace(Substring, "MMMM", "MM");
						EndIf;
					EndIf;
					If StrFind(Substring, "ДЛФ=") > 0 Or StrFind(Substring, "DLF=") > 0 Then // @Non-NLS
						If StrFind(Substring, "ДД") > 0 Or StrFind(Substring, "DD") > 0 Then // @Non-NLS
							Substring = StrReplace(Substring, "ДД", "Д"); // @Non-NLS-1, @Non-NLS-2
							Substring = StrReplace(Substring, "DD", "D");
						EndIf;
					EndIf;
					FormatString = FormatString + ?(FormatString = "", "", ";") + Substring;
				EndDo;
				
				Item.Format = FormatString;
				Item.EditFormat = FormatString;
			EndIf;
		EndIf;
		
		If PropertyDetails.Deleted Then
			Item.TitleTextColor = StyleColors.InaccessibleCellTextColor;
			Item.TitleFont = StyleFonts.DeletedAttributeTitleFont;
			If Item.Type = FormFieldType.InputField Then
				Item.ClearButton = True;
				Item.ChoiceButton = False;
				Item.OpenButton = False;
				Item.DropListButton = False;
				Item.TextEdit = False;
			EndIf;
		EndIf;
		
		If Not LabelsFields And Item.Type = FormFieldType.InputField Then
			Item.ChoiceFoldersAndItems = FoldersAndItems.FoldersAndItems;
		EndIf;
		
		If Not LabelsFields And PropertyDetails.AdditionalValue And Item.Type = FormFieldType.InputField Then
			ChoiceParameters = New Array;
			ChoiceParameters.Add(New ChoiceParameter("Filter.Owner",
				?(ValueIsFilled(PropertyDetails.AdditionalValuesOwner),
					PropertyDetails.AdditionalValuesOwner, PropertyDetails.Property)));
			Item.ChoiceParameters = New FixedArray(ChoiceParameters);
		EndIf;
		
	EndDo;
	
	// Setting visibility, availability and required filling of additional attributes.
	For Each DependentAttributeDetails In Form.PropertiesDependentAdditionalAttributesDescription Do
		If DependentAttributeDetails.OutputAsHyperlink Then
			ProcessedItem = StrReplace(DependentAttributeDetails.ValueAttributeName, "AdditionalAttributeValue_", "Group_");
		Else
			ProcessedItem = DependentAttributeDetails.ValueAttributeName;
		EndIf;
		
		If DependentAttributeDetails.AvailabilityCondition <> Undefined Then
			Result = ConditionCalculationResult(Form, ObjectDetails, DependentAttributeDetails.AvailabilityCondition);
			Item = Form.Items[ProcessedItem]; // FormField
			If Item.Enabled <> Result Then
				Item.Enabled = Result;
			EndIf;
		EndIf;
		If DependentAttributeDetails.VisibilityCondition <> Undefined Then
			Result = ConditionCalculationResult(Form, ObjectDetails, DependentAttributeDetails.VisibilityCondition);
			Item = Form.Items[ProcessedItem];
			If Item.Visible <> Result Then
				Item.Visible = Result;
			EndIf;
		EndIf;
		If DependentAttributeDetails.FillingRequiredCondition <> Undefined Then
			If Not DependentAttributeDetails.RequiredToFill Then
				Continue;
			EndIf;
			
			Result = ConditionCalculationResult(Form, ObjectDetails, DependentAttributeDetails.FillingRequiredCondition);
			Item = Form.Items[ProcessedItem];
			If Not DependentAttributeDetails.OutputAsHyperlink
				And Item.AutoMarkIncomplete <> Result Then
				Item.AutoMarkIncomplete = Result;
			EndIf;
		EndIf;
	EndDo;
	
	Structure = New Structure("PropertiesParameters");
	FillPropertyValues(Structure, Form);
	If TypeOf(Structure.PropertiesParameters) = Type("Structure")
		And Structure.PropertiesParameters.Property("DeferredInitializationExecuted") Then
		Form.PropertiesParameters.DeferredInitializationExecuted = True;
		// Deleting temporary decoration if it was added.
		If Form.PropertiesParameters.Property("EmptyDecorationAdded") Then
			For Each DecorationName1 In Form.PropertiesParameters.DecorationCollections Do
				Form.Items.Delete(Form.Items[DecorationName1]);
			EndDo;
			Form.PropertiesParameters.Delete("EmptyDecorationAdded");
		EndIf;
	EndIf;
	
EndProcedure

// Transfers property values from form attributes to the tabular section of the object.
// 
// Parameters:
//  Form        - ClientApplicationForm - already set in the OnCreateAtServer procedure.
//  Object       - Undefined - take the object from the Object form attribute.
//               - CatalogObject, DocumentObject, FormDataStructure - 
//                 
//
Procedure TransferValuesFromFormAttributesToObject(Form, Object = Undefined) Export
	
	PropertyManagerInternal.TransferValuesFromFormAttributesToObject(Form, Object);
	
EndProcedure

// Removes old attributes and form items.
// 
// Parameters:
//  Form        - ClientApplicationForm - already set in the OnCreateAtServer procedure.
//  
Procedure DeleteOldAttributesAndItems(Form) Export
	
	AttributesToBeDeleted = New Array;
	For Each PropertyDetails In Form.PropertiesAdditionalAttributeDetails Do
		UniquePart = StrReplace(PropertyDetails.ValueAttributeName, "AdditionalAttributeValue_", "");
		
		AttributesToBeDeleted.Add(PropertyDetails.ValueAttributeName);
		If PropertyDetails.RefTypeString Then
			AttributesToBeDeleted.Add("ReferenceAdditionalAttributeValue" + UniquePart);
		EndIf;
		If PropertyDetails.FormItemAdded Then
			If PropertyDetails.OutputAsHyperlink Then
				Form.Items.Delete(Form.Items["Group_" + UniquePart]);
			Else
				Form.Items.Delete(Form.Items[PropertyDetails.ValueAttributeName]);
			EndIf;
		EndIf;
	EndDo;
	
	If AttributesToBeDeleted.Count() > 0 Then
		Form.ChangeAttributes(, AttributesToBeDeleted);
	EndIf;
	
	For Each ListItem In Form.PropertiesAdditionalAttributeGroupItems Do
		Form.Items.Delete(Form.Items[ListItem.Presentation]);
	EndDo;
	
	Form.PropertiesAdditionalAttributeDetails.Clear();
	Form.PropertiesAdditionalAttributeGroupItems.Clear();
	Form.PropertiesDependentAdditionalAttributesDescription.Clear();
	
EndProcedure

// 
//
// Parameters:
//  PropertiesOwner      - AnyRef - for example, CatalogRef.Products, DocumentRef.SalesOrder, …
//                       - CatalogObject, DocumentObject - 
//                       - FormDataStructure - 
//  GetAddlAttributes - Boolean - include additional attributes to the result.
//  GetAddlInfo  - Boolean - include additional info to the result.
//
// Returns:
//  Array of ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo
//
Function ObjectProperties(PropertiesOwner,
					    GetAddlAttributes = True,
					    GetAddlInfo = True) Export
	
	If Not (GetAddlAttributes Or GetAddlInfo) Then
		Return New Array;
	EndIf;
	
	GetAddlInfo = GetAddlInfo And AccessRight("Read", Metadata.InformationRegisters.AdditionalInfo);
	
	SetPrivilegedMode(True);
	ObjectPropertySets = PropertyManagerInternal.GetObjectPropertySets(
		PropertiesOwner);
	SetPrivilegedMode(False);
	
	ObjectPropertySetsArray = ObjectPropertySets.UnloadColumn("Set");
	
	QueryTextAddAttributes = 
		"SELECT
		|	PropertiesTable.Property AS Property
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS PropertiesTable
		|WHERE
		|	PropertiesTable.Ref IN (&ObjectPropertySetsArray)";
	
	QueryTextAddProperties = 
		"SELECT ALLOWED
		|	PropertiesTable.Property AS Property
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo AS PropertiesTable
		|WHERE
		|	PropertiesTable.Ref IN (&ObjectPropertySetsArray)";
	
	Query = New Query;
	QueryText = "";
	If GetAddlInfo Then
		QueryText = QueryTextAddProperties;
	EndIf;
	
	If GetAddlAttributes Then
		If ValueIsFilled(QueryText) Then
			QueryText = QueryText + "
			|
			| UNION ALL
			|" + QueryTextAddAttributes;
		Else
			QueryText = QueryTextAddAttributes;
		EndIf;
	EndIf;
	
	Query.Text = QueryText;
	Query.Parameters.Insert("ObjectPropertySetsArray", ObjectPropertySetsArray);
	
	Result = Query.Execute().Unload().UnloadColumn("Property");
	
	Return Result;
	
EndFunction

// ACC:142-off Design-based decision.

// Returns values of additional object properties.
//
// Parameters:
//  ObjectsWithProperties  - Array      -
//                                       
//                       - AnyRef - a link to an object, such as a reference link.Nomenclature,
//                                       Document link.Customer's order, ...
//  GetAddlAttributes - Boolean - include additional attributes to the result. The default value is True.
//  GetAddlInfo  - Boolean - include additional info to the result. The default value is True.
//  Properties             - Array of ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - values
//                            to be received.
//                       - Array of String -  
//                       - Undefined - 
//  LanguageCode             - String - a code of the language in which the property value presentation will be received.
//                                  If not specified, the current language is used.
//
// Returns:
//  ValueTable:
//    * Property    - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - an owner property.
//    * PropertyName - String - a unique owner property name.
//    * Value    - Arbitrary - values of any type from metadata object property type details:
//                    "Metadata.ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Type".
//    * Presentation   - String - a value presentation in the specified language.
//    * PropertiesOwner - AnyRef - a reference to an object.
//
Function PropertiesValues(ObjectsWithProperties,
                        GetAddlAttributes = True,
                        GetAddlInfo = True,
                        Properties = Undefined,
                        LanguageCode = "") Export
	
	If Not PropertiesAvailable() Then
		Return New ValueTable;
	EndIf;
	
	GetAddlInfo = GetAddlInfo And AccessRight("Read", Metadata.InformationRegisters.AdditionalInfo);
	
	If TypeOf(ObjectsWithProperties) = Type("Array") Then
		PropertiesOwner = ObjectsWithProperties[0];
	Else
		PropertiesOwner = ObjectsWithProperties;
	EndIf;
	
	ObjectWithPropertiesName = Common.TableNameByRef(PropertiesOwner);
	AllAttributes = New Array;
	If GetAddlAttributes Then
		GetAddlAttributes = UseAddlAttributes(PropertiesOwner);
		If GetAddlAttributes And Properties = Undefined Then
			ObjectAttributes = PropertyManagerInternal.PropertiesListForObjectsKind(ObjectWithPropertiesName, "AdditionalAttributes");
			If ObjectAttributes <> Undefined Then
				AllAttributes = ObjectAttributes.UnloadColumn("Property");
			EndIf;
		EndIf;
	EndIf;
	
	AllInfoRecords = New Array;
	If GetAddlInfo Then
		GetAddlInfo = UseAddlInfo(PropertiesOwner);
		If GetAddlInfo And Properties = Undefined Then
			ObjectInfoRecords = PropertyManagerInternal.PropertiesListForObjectsKind(ObjectWithPropertiesName, "AdditionalInfo");
			If ObjectInfoRecords <> Undefined Then
				AllInfoRecords = ObjectInfoRecords.UnloadColumn("Property");
			EndIf;
		EndIf;
	EndIf;
	
	If Not GetAddlAttributes And Not GetAddlInfo Then
		Return New ValueTable;
	EndIf;
	
	If Properties = Undefined Then
		Properties = AllAttributes;
		CommonClientServer.SupplementArray(Properties, AllInfoRecords);
	EndIf;
	
	QueryTextAddAttributes =
		"SELECT ALLOWED
		|	PropertiesTable.Property AS Property,
		|	PropertiesTable.Value AS Value,
		|	PropertiesTable.TextString,
		|	PropertiesTable.Ref AS PropertiesOwner,
		|	AdditionalAttributesAndInfo.Name AS PropertyName
		|FROM
		|	&NameOfObjectWithAdditionalAttributes AS PropertiesTable
		|		LEFT JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
		|		ON AdditionalAttributesAndInfo.Ref = PropertiesTable.Property
		|WHERE
		|	PropertiesTable.Ref IN (&ObjectsWithProperties)
		|	AND (AdditionalAttributesAndInfo.Ref IN (&Properties)
		|		OR AdditionalAttributesAndInfo.Name IN (&Properties))";
	
	QueryTextAddProperties =
		"SELECT ALLOWED
		|	PropertiesTable.Property AS Property,
		|	PropertiesTable.Value AS Value,
		|	"""" AS TextString,
		|	PropertiesTable.Object AS PropertiesOwner,
		|	AdditionalAttributesAndInfo.Name AS PropertyName
		|FROM
		|	InformationRegister.AdditionalInfo AS PropertiesTable
		|		LEFT JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
		|		ON AdditionalAttributesAndInfo.Ref = PropertiesTable.Property
		|WHERE
		|	PropertiesTable.Object IN (&ObjectsWithProperties)
		|	AND (AdditionalAttributesAndInfo.Ref IN (&Properties)
		|		OR AdditionalAttributesAndInfo.Name IN (&Properties))";
	
	Query = New Query;
	QueryText = "";
	If GetAddlAttributes Then
		QueryText = QueryTextAddAttributes;
	EndIf;
	
	If GetAddlInfo Then
		If ValueIsFilled(QueryText) Then
			QueryText = QueryText + "
			|
			| UNION ALL
			|" + StrReplace(QueryTextAddProperties, "ALLOWED", ""); // @Query-part-1, @Query-part-2
		Else
			QueryText = QueryTextAddProperties;
		EndIf;
	EndIf;
	
	QueryText = StrReplace(QueryText, "&NameOfObjectWithAdditionalAttributes",
		ObjectWithPropertiesName + ".AdditionalAttributes");
	QueryText = StrReplace(QueryText, "&NameOfObjectWithLabels", ObjectWithPropertiesName + ".Labels");
	
	Query.Parameters.Insert("ObjectsWithProperties", ObjectsWithProperties);
	Query.Parameters.Insert("Properties", Properties);
	Query.Text = QueryText;
	
	Result = Query.Execute().Unload();
	Result.Columns.Add("Presentation");
	PropertiesFormat = PropertiesFormat(Properties);
	ResultWithTextStrings = Undefined;
	RowIndex = 0;
	For Each PropertyValue In Result Do
		PropertyValue.Presentation = ValuePresentation(PropertyValue.Value,
			LanguageCode,
			PropertiesFormat[PropertyValue.Property]);
		
		TextString = PropertyValue.TextString;
		If Not IsBlankString(TextString) Then
			If ResultWithTextStrings = Undefined Then
				ResultWithTextStrings = Result.Copy(,"Property, PropertiesOwner, PropertyName, Presentation");
				ResultWithTextStrings.Columns.Add("Value");
				ResultWithTextStrings.LoadColumn(Result.UnloadColumn("Value"), "Value");
			EndIf;
			ResultWithTextStrings[RowIndex].Value = TextString;
		EndIf;
		RowIndex = RowIndex + 1;
	EndDo;
	
	Return ?(ResultWithTextStrings <> Undefined, ResultWithTextStrings, Result);
EndFunction

// ACC:142-on

// Returns a value of an additional object property.
//
// Parameters:
//  Object   - AnyRef - a reference to an object, for example, CatalogRef.Product,
//                           DocumentRef.SalesOrder, …
//  Property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - - a reference to
//                           the additional attribute whose value is to be received.
//           - String - 
//  LanguageCode - String - if specified, then instead of additional property value
//                      its presentation will be returned in the specified language.
//
// Returns:
//  Arbitrary - 
//
Function PropertyValue(Object, Property, LanguageCode = "") Export
	
	ShouldGetAttributes = PropertyManagerInternal.IsMetadataObjectWithProperties(Object.Metadata(), "AdditionalAttributes");
	
	Result = PropertiesValues(Object, ShouldGetAttributes, True, Property, LanguageCode);
	If Result.Count() = 1 Then
		If ValueIsFilled(LanguageCode) Then
			Return Result[0].Presentation;
		Else
			Return Result[0].Value;
		EndIf;
	EndIf;
EndFunction

// Checks whether the object has a property.
//
// Parameters:
//  PropertiesOwner - AnyRef - for example, CatalogRef.Products, DocumentRef.SalesOrder, …
//  Property        - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - a property being checked.
//
// Returns:
//  Boolean - 
//
Function CheckObjectProperty(PropertiesOwner, Property) Export
	
	PropertiesArray = ObjectProperties(PropertiesOwner);
	
	If PropertiesArray.Find(Property) = Undefined Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction

// Writes additional attributes and info to the property owner.
// Changes occur in a transaction.
// 
// Parameters:
//  PropertiesOwner - AnyRef - for example, CatalogRef.Products, DocumentRef.SalesOrder.
//  PropertyAndValueTable - ValueTable:
//    * Property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - an owner property.
//    * Value - Arbitrary - any value allowed for the property (specified in the property item).
//
Procedure WriteObjectProperties(PropertiesOwner, PropertyAndValueTable) Export
	
	AddlAttributesTable = New ValueTable;
	AddlAttributesTable.Columns.Add("Property", New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo"));
	AddlAttributesTable.Columns.Add("Value");
	AddlAttributesTable.Columns.Add("TextString");
	
	AdditionalInfoTable1 = AddlAttributesTable.CopyColumns();
	
	For Each PropertyTableRow In PropertyAndValueTable Do
		If PropertyTableRow.Property.IsAdditionalInfo Then
			NewRow = AdditionalInfoTable1.Add();
		Else
			NewRow = AddlAttributesTable.Add();
			
			If TypeOf(PropertyTableRow.Value) = Type("String")
				And StrLen(PropertyTableRow.Value) > 1024 Then
				NewRow.TextString = PropertyTableRow.Value;
			EndIf;
		EndIf;
		FillPropertyValues(NewRow, PropertyTableRow, "Property,Value");
	EndDo;
	
	HasAddlAttributes = AddlAttributesTable.Count() > 0;
	HasAdditionalInfo  = AdditionalInfoTable1.Count() > 0;
	
	PropertiesArray = ObjectProperties(PropertiesOwner);
	
	AddlAttributesArray = New Array;
	AdditionalInfoArray = New Array;
	
	For Each AdditionalProperty1 In PropertiesArray Do
		If AdditionalProperty1.IsAdditionalInfo Then
			AdditionalInfoArray.Add(AdditionalProperty1);
		Else
			AddlAttributesArray.Add(AdditionalProperty1);
		EndIf;
	EndDo;
	
	BeginTransaction();
	Try
		If HasAddlAttributes Then
			Block = New DataLock;
			LockItem = Block.Add(PropertiesOwner.Metadata().FullName());
			LockItem.SetValue("Ref", PropertiesOwner);
			Block.Lock();
			
			PropertiesOwnerObject = PropertiesOwner.GetObject();
			LockDataForEdit(PropertiesOwnerObject.Ref);
			
			For Each AdditionalAttribute5 In AddlAttributesTable Do
				If AddlAttributesArray.Find(AdditionalAttribute5.Property) = Undefined Then
					Continue;
				EndIf;
				RowsArray = PropertiesOwnerObject.AdditionalAttributes.FindRows(New Structure("Property", AdditionalAttribute5.Property));
				If RowsArray.Count() Then
					PropertyRow = RowsArray[0];
				Else
					PropertyRow = PropertiesOwnerObject.AdditionalAttributes.Add();
				EndIf;
				FillPropertyValues(PropertyRow, AdditionalAttribute5, "Property,Value,TextString");
			EndDo;
			PropertiesOwnerObject.Write();
		EndIf;
		
		If HasAdditionalInfo Then
			For Each AdditionalInfoItem1 In AdditionalInfoTable1 Do
				If AdditionalInfoArray.Find(AdditionalInfoItem1.Property) = Undefined Then
					Continue;
				EndIf;
				
				Block = New DataLock;
				LockItem = Block.Add("InformationRegister.AdditionalInfo");
				LockItem.SetValue("Object", PropertiesOwner);
				LockItem.SetValue("Property", AdditionalInfoItem1.Property);
				Block.Lock();
				
				RecordManager = InformationRegisters.AdditionalInfo.CreateRecordManager();
				
				RecordManager.Object = PropertiesOwner;
				RecordManager.Property = AdditionalInfoItem1.Property;
				RecordManager.Value = AdditionalInfoItem1.Value;
				
				RecordManager.Write(True);
			EndDo;
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Checks if additional attributes are used with the object.
//
// Parameters:
//  PropertiesOwner - AnyRef - for example, CatalogRef.Products, DocumentRef.SalesOrder, …
//
// Returns:
//  Boolean - 
//
Function UseAddlAttributes(PropertiesOwner) Export
	
	OwnerMetadata = PropertiesOwner.Metadata();
	Return OwnerMetadata.TabularSections.Find("AdditionalAttributes") <> Undefined
	      And OwnerMetadata <> Metadata.Catalogs.AdditionalAttributesAndInfoSets;
	
EndFunction

// Checks if the object uses additional info.
//
// Parameters:
//  PropertiesOwner - AnyRef - for example, CatalogRef.Products, DocumentRef.SalesOrder, …
//
// Returns:
//  Boolean - 
//
Function UseAddlInfo(PropertiesOwner) Export
	
	Return Metadata.CommonCommands.Find("AdditionalInfoCommandBar") <> Undefined
		And Metadata.CommonCommands.AdditionalInfoCommandBar.CommandParameterType.Types().Find(TypeOf(PropertiesOwner)) <> Undefined;
	
EndFunction

// Checks subsystem availability for the current user.
//
// Returns:
//  Boolean - 
//
Function PropertiesAvailable() Export
	Return AccessRight("Read", Metadata.Catalogs.AdditionalAttributesAndInfoSets);
EndFunction

// Returns a presentation of an additional object property value
// in the required language.
//
// Parameters:
//  Object   - AnyRef - a reference to an object, for example, CatalogRef.Product,
//                           DocumentRef.SalesOrder, …
//  Property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - - a reference to
//                           the additional attribute whose value is to be received.
//           - String - 
//  LanguageCode - String - a code of the language in which the presentation is to be received.
//
// Returns:
//  String
//
Function RepresentationOfThePropertyValue(Object, Property, LanguageCode = "") Export
	Presentation = PropertyValue(Object, Property, LanguageCode);
	Return Presentation;
EndFunction

// Returns the values of additional object properties.
// Suits for parameter substitution upon forming print forms.
//
// Parameters:
//  ObjectsWithProperties  - Array      - objects for which additional property values are to be received.
//                       - AnyRef - a link to an object, such as a reference link.Nomenclature,
//                                       Document link.Customer's order, ...
//  LanguageCode             - String - a code of the language in which the presentation is to be received.
//
// Returns:
//  Map of KeyAndValue:
//   * Key - AnyRef - object reference.
//   * Value - Structure:
//        * Key - String - property name.
//        * Value - String - a property presentation in the passed language.
//
Function RepresentationsOfPropertyValues(ObjectsWithProperties, LanguageCode = "") Export
	PropertiesValues = PropertiesValues(ObjectsWithProperties, True, True, Undefined, LanguageCode);
	
	Result = New Map;
	
	For Each PropertyValue In PropertiesValues Do
		If Result[PropertyValue.PropertiesOwner] = Undefined Then
			Result.Insert(PropertyValue.PropertiesOwner, New Structure);
		EndIf;
		
		PropertyName = PropertyValue.PropertyName;
		FirstChar = Left(PropertyValue.PropertyName, 1);
		If StrFind("0123456789", FirstChar) > 0 Then
			PropertyName = "_" + PropertyName;
		EndIf;
		Result[PropertyValue.PropertiesOwner].Insert(PropertyName, PropertyValue.Presentation);
	EndDo;
	
	If TypeOf(ObjectsWithProperties) = Type("Array") Then
		For Each ObjectWithProperties In ObjectsWithProperties Do
			If Result[ObjectWithProperties] = Undefined Then
				Result[ObjectWithProperties] = New Structure;
			EndIf;
		EndDo;
	Else
		If Result[ObjectWithProperties] = Undefined Then
			Result[ObjectWithProperties] = New Structure;
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Labels

// 
// 
// Parameters:
//  Form           - ClientApplicationForm - it is already configured in the procedure for joining the server.
//
Procedure SetLabelsLegendVisibility(Form) Export
	
	If Form.Items["GroupHideableLegendPart"].Visible Then
		Form.Items["GroupHideableLegendPart"].Visible = False;
		Form.Items["MakeLegendVisible"].Picture = PictureLib.GreenDownArrow;
		IsLabelsLegendVisible = False;
	Else
		Form.Items["GroupHideableLegendPart"].Visible = True;
		Form.Items["MakeLegendVisible"].Picture = PictureLib.GreenRightArrow;
		IsLabelsLegendVisible = True;
	EndIf;
	
	SetPrivilegedMode(True);
	CurrentParameters = New Map(SessionParameters.ClientParametersAtServer);
	CurrentParameters.Insert("IsLabelsLegendVisible", IsLabelsLegendVisible);
	SessionParameters.ClientParametersAtServer = New FixedMap(CurrentParameters); 
	SetPrivilegedMode(False);
	Common.CommonSettingsStorageSave("Properties", "IsLabelsLegendVisible", IsLabelsLegendVisible);
	
EndProcedure

// 
//
// Parameters:
//  Form              - ClientApplicationForm - it is already configured in the procedure for joining the server.
//
//  Object             - Undefined - take an object from the props of the "Object" form.
//                     - CatalogObjectCatalogName
//                     - DocumentObjectDocumentName
//                     - ChartOfCharacteristicTypesObjectChartOfCharacteristicTypesName
//                     - BusinessProcessObjectNameOfBusinessProcess
//                     - TaskObjectTaskName
//                     - ChartOfCalculationTypesObjectChartOfCalculationTypesName
//                     - ChartOfAccountsObjectChartOfAccountsName
//                     - FormDataStructure
//
//  ArbitraryObject - Boolean -
//
Procedure FillObjectLabels(Form, Object = Undefined, ArbitraryObject = False) Export
	
	If Not Form.PropertiesUseProperties
	 Or Not Form.PropertiesUseAddlAttributes Then
		Return;
	EndIf;
	
	LabelsDestinationElementName = Form.Properties_LabelsDestinationElementName;
	If Not ValueIsFilled(LabelsDestinationElementName) Then
		Return;
	EndIf;
	
	If Object = Undefined Then
		If ArbitraryObject Then
			Return;
		EndIf;
		ObjectDetails = Form.Object;
	Else
		ObjectDetails = Object;
	EndIf;
	
	If Form.Items.Find("EditLabels") = Undefined Then
		NewItem = Form.Items.Add("EditLabels", Type("FormDecoration"),
			Form.Items[LabelsDestinationElementName]);
		NewItem.Type = FormDecorationType.Picture;
		NewItem.Hyperlink = True;
		NewItem.Picture = PictureLib.EditLabels;
		NewItem.SetAction("Click", "Attachable_PropertiesExecuteCommand");
		NewItem.ToolTip = NStr("en = 'Edit labels';");
	EndIf;
	
	Labels = PropertiesByAdditionalAttributesKind(
		ObjectDetails.AdditionalAttributes.Unload(),
		Enums.PropertiesKinds.Labels);
	If Form.Properties_LabelsApplied.Count() = 0 Then
		Form.Properties_LabelsApplied.LoadValues(Labels);
	EndIf;
	
	GroupLabels = Form.Items[LabelsDestinationElementName];
	ChildItems = GroupLabels.ChildItems;
	NamesOfLabelsForDeletion = New Array;
	For Each SubordinateItem In ChildItems Do
		If SubordinateItem = Form.Items["EditLabels"] Then
			Continue;
		EndIf;
		NamesOfLabelsForDeletion.Add(SubordinateItem.Name);
	EndDo;
	
	For Each Label In NamesOfLabelsForDeletion Do
		Form.Items.Delete(Form.Items[Label]);
	EndDo;
	
	LabelsToHideCount = 0;
	LabelCount = Labels.Count();
	MaxLabelsOnForm = Form.PropertiesParameters.MaxLabelsOnForm;
	If MaxLabelsOnForm <> Undefined And MaxLabelsOnForm < LabelCount Then
		LabelsToHideCount = LabelCount - MaxLabelsOnForm;
		LabelCount = MaxLabelsOnForm;
	EndIf;
	LabelsDisplayOption = Form.PropertiesParameters.LabelsDisplayOption;
	
	LabelsShownCount = 0;
	LabelsAttributes = Common.ObjectsAttributesValues(Labels,
		"Name, PropertiesColor, Description, DeletionMark, ToolTip");
	If LabelsDisplayOption = Enums.LabelsDisplayOptions.Label Then
		For IndexOf = 0 To LabelCount - 1 Do
			Label = LabelsAttributes.Get(Labels[IndexOf]);
			If Label = Undefined Or Label.DeletionMark Then
				Continue;
			EndIf;
			NewItem = Form.Items.Add("Label" + Label.Name, Type("FormDecoration"), GroupLabels);
			NewItem.Type = FormDecorationType.Label;
			NewItem.HorizontalAlign = ItemHorizontalLocation.Center;
			NewItem.Height = 1;
			NewItem.Title = Label.Description;
			NewItem.TextColor = Metadata.StyleItems.LabelTextColor_SSLym.Value;
			NewItem.BackColor = StyleItemByColor(Label.PropertiesColor);
			NewItem.Font = Metadata.StyleItems.LabelsFont.Value;
			NewItem.ToolTip = Label.ToolTip;
			If Not ArbitraryObject Then
				NewItem.Hyperlink = True;
				NewItem.SetAction("Click", "Attachable_PropertiesExecuteCommand");
			EndIf;
			DescriptionLength = StrLen(Label.Description);
			If DescriptionLength > 8 Then
				NewItem.Width = DescriptionLength;
			Else
				NewItem.Width = 8;
			EndIf;
			LabelsShownCount = LabelsShownCount + 1;
		EndDo;
	Else
		For IndexOf = 0 To LabelCount - 1 Do
			Label = LabelsAttributes.Get(Labels[IndexOf]);
			If Label = Undefined Or Label.DeletionMark Then
				Continue;
			EndIf;
			NewItem = Form.Items.Add("Label" + Label.Name, Type("FormDecoration"), GroupLabels);
			NewItem.Type = FormDecorationType.Picture;
			If Not ArbitraryObject Then
				NewItem.Hyperlink = True;
			EndIf;
			NewItem.Picture = PictureLabelsByColor(Label.PropertiesColor);
			NewItem.SetAction("Click", "Attachable_PropertiesExecuteCommand");
			NewItem.ToolTip = Label.Description;
			NewItem.Title = Label.Description;
			LabelsShownCount = LabelsShownCount + 1;
		EndDo;
	EndIf;
	
	If ValueIsFilled(LabelsToHideCount) Then
		NewItem = Form.Items.Add("OtherLabels", Type("FormDecoration"), GroupLabels);
		NewItem.Type = FormDecorationType.Label;
		NewItem.Hyperlink = True;
		NewItem.SetAction("Click", "Attachable_PropertiesExecuteCommand"); 
		NewItem.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'and %1 more';"), LabelsToHideCount);
		NewItem.ToolTip = NStr("en = 'Other labels';");
	EndIf;
	
	If ArbitraryObject Or LabelsShownCount <> 0 Then
		Form.Items["EditLabels"].Visible = False;
	Else
		Form.Items["EditLabels"].Visible = True;
	EndIf;
	
EndProcedure

// 
//
// Returns:
//  Structure:
//    
//    * LabelsDestinationElementName - String -
//    
//    * LabelsLegendDestinationElementName - String -
//    
//    * MaxLabelsOnForm - Number -
//    
//    * FilterLabelsCount - Boolean -
//    
//    * LabelsDisplayOption - EnumRef.LabelsDisplayOptions -
//            
//            
//            
//    
//    * ObjectsKind - String -
//
Function LabelsDisplayParameters() Export
	
	LabelsDisplayParameters = New Structure;
	LabelsDisplayParameters.Insert("LabelsDestinationElementName", "");
	LabelsDisplayParameters.Insert("LabelsLegendDestinationElementName", "");
	LabelsDisplayParameters.Insert("LabelsDisplayOption", Enums.LabelsDisplayOptions.Picture);
	LabelsDisplayParameters.Insert("MaxLabelsOnForm");
	LabelsDisplayParameters.Insert("FilterLabelsCount", False);
	LabelsDisplayParameters.Insert("ObjectsKind", "");
	
	Return LabelsDisplayParameters;
	
EndFunction

// 
//
// Parameters:
//  Properties   - ValueTable -
//
//  PropertyKind - EnumRef.PropertiesKinds -
//
// Returns:
//  Array     - 
//
Function PropertiesByAdditionalAttributesKind(Properties, PropertyKind) Export
	
	PropertiesByKind = New Array;
	ListOfProperties = Properties.UnloadColumn("Property");
	ObjectsPropertiesKinds = Common.ObjectsAttributesValues(ListOfProperties, "PropertyKind");
	If PropertyKind = Enums.PropertiesKinds.AdditionalAttributes Then
		For Each Property In ListOfProperties Do
			ObjectPropertiesKind = ObjectsPropertiesKinds.Get(Property).PropertyKind;
			If Not ValueIsFilled(ObjectPropertiesKind) Or ObjectPropertiesKind = PropertyKind Then
				PropertiesByKind.Add(Property);
			EndIf;
		EndDo;
	ElsIf PropertyKind = Enums.PropertiesKinds.Labels Then
		For Each Property In ListOfProperties Do
			ObjectPropertiesKind = ObjectsPropertiesKinds.Get(Property).PropertyKind;
			If ObjectPropertiesKind = PropertyKind Then
				PropertiesByKind.Add(Property);
			EndIf;
		EndDo;
	EndIf;
	
	Return PropertiesByKind;
	
EndFunction

// 
// 
// Returns:
//  Boolean     - 
//
Function HasLabelsOwners() Export
	
	LabelsOwners = Metadata.DefinedTypes.LabelsOwner.Type.Types();
	If LabelsOwners.Count() = 1 And LabelsOwners[0] = Type("String") Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

// 1. Updates descriptions of predefined property sets
// if they differ from the current presentations of matching
// metadata objects with properties.
// 2. Updates descriptions of not common properties if their
// adjustment is different from their set description.
// 3. Sets a deletion mark for not common properties
// if their sets are marked for deletion.
//
Procedure UpdatePropertyAndSetDescriptions() Export
	
	SetsQuery = New Query;
	SetsQuery.Text =
	"SELECT
	|	Sets.Ref AS Ref,
	|	Sets.Description AS Description
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets AS Sets
	|WHERE
	|	Sets.Predefined
	|	AND Sets.Parent = VALUE(Catalog.AdditionalAttributesAndInfoSets.EmptyRef)";
	
	SetsSelection = SetsQuery.Execute().Select();
	While SetsSelection.Next() Do
		
		BeginTransaction();
		Try
			Block = New DataLock;
			LockItem = Block.Add("Catalog.AdditionalAttributesAndInfoSets");
			LockItem.SetValue("Ref", SetsSelection.Ref);
			Block.Lock();
			
			Description = PropertyManagerInternal.PredefinedSetDescription(
				SetsSelection.Ref);
			
			If SetsSelection.Description <> Description Then
				Object = SetsSelection.Ref.GetObject();
				Object.Description = Description;
				InfobaseUpdate.WriteData(Object);
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndDo;
	
	PropertiesQuery = New Query;
	PropertiesQuery.Text =
	"SELECT
	|	Properties.Ref AS Ref,
	|	Properties.PropertiesSet.DeletionMark AS DeletionMarkOfSet
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
	|WHERE
	|	CASE
	|			WHEN Properties.PropertiesSet = VALUE(Catalog.AdditionalAttributesAndInfoSets.EmptyRef)
	|				THEN FALSE
	|			ELSE CASE
	|					WHEN Properties.Description <> Properties.Title
	|						THEN TRUE
	|					ELSE FALSE
	|				END
	|		END";
	
	PropertiesSelection = PropertiesQuery.Execute().Select();
	While PropertiesSelection.Next() Do
		
		BeginTransaction();
		Try
			Block = New DataLock;
			LockItem = Block.Add("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo");
			LockItem.SetValue("Ref", PropertiesSelection.Ref);
			Block.Lock();
		
			Object = PropertiesSelection.Ref.GetObject(); // ChartOfCharacteristicTypesObject.AdditionalAttributesAndInfo
			Object.Description = Object.Title;
			Object.DeletionMark = PropertiesSelection.DeletionMarkOfSet;
			InfobaseUpdate.WriteData(Object);
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
	EndDo;
	
EndProcedure

// Sets property set parameters.
//
// Parameters:
//  PropertiesSetName - String - a name of a predefined property set.
//  Parameters - See PropertySetParametersStructure
//
Procedure SetPropertySetParameters(PropertiesSetName, Parameters = Undefined) Export
	
	If Parameters = Undefined Then
		Parameters = PropertySetParametersStructure();
	EndIf;
	
	WriteObject = False;
	PropertiesSet = PropertiesSetByName(PropertiesSetName);
	If PropertiesSet = Undefined Then
		PropertiesSet = Catalogs.AdditionalAttributesAndInfoSets[PropertiesSetName];
	EndIf;
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("Catalog.AdditionalAttributesAndInfoSets");
		LockItem.SetValue("Ref", PropertiesSet);
		Block.Lock();
		
		PropertySetObject = PropertiesSet.GetObject();
		If PropertySetObject = Undefined Then
			RollbackTransaction();
			Return;
		EndIf;
		
		For Each Parameter In Parameters Do
			If PropertySetObject[Parameter.Key] = Parameter.Value Then
				Continue;
			EndIf;
			WriteObject = True;
		EndDo;
		
		If WriteObject Then
			FillPropertyValues(PropertySetObject, Parameters);
			InfobaseUpdate.WriteData(PropertySetObject);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Gets parameter structure for a property set.
//
// Returns: 
//  Structure:
//     * Used - Boolean - indicates whether a property set is used.
//                               It is set to False, for example, if
//                               the object is disabled by the functional option.
//
Function PropertySetParametersStructure() Export
	
	Parameters = New Structure;
	Parameters.Insert("Used", True);
	Return Parameters;
	
EndFunction

// 
// 
// 
// 
// 
//
Procedure RestoreSettingsOfFormsWithAdditionalAttributes() Export
	
	Sets = New Map;
	NamesOfPredefinedSets = Metadata.Catalogs.AdditionalAttributesAndInfoSets.GetPredefinedNames();
	ObsoletePredefinedItems = New Array;
	For Each PredefinedSetName In NamesOfPredefinedSets Do
		If Not StrStartsWith(PredefinedSetName, "Delete") Then
			Continue;
		EndIf;
		
		ObsoletePredefinedItems.Add(PredefinedSetName);
	EndDo;
	
	ChildSetsQuery = New Query;
	ChildSetsQuery.Text =
		"SELECT
		|	AdditionalAttributesAndInfoSets.Ref AS Ref,
		|	AdditionalAttributesAndInfoSets.Parent AS Parent
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets AS AdditionalAttributesAndInfoSets
		|WHERE
		|	AdditionalAttributesAndInfoSets.PredefinedSetName = """"
		|	AND AdditionalAttributesAndInfoSets.Parent <> VALUE(Catalog.AdditionalAttributesAndInfoSets.EmptyRef)";
	AllChildSets = ChildSetsQuery.Execute().Unload();
	AllChildSets.Indexes.Add("Ref");
	
	RequestPredefinedSets = New Query;
	RequestPredefinedSets.SetParameter("PredefinedDataName", ObsoletePredefinedItems);
	RequestPredefinedSets.Text =
		"SELECT
		|	AdditionalAttributesAndInfoSets.Ref AS Ref,
		|	AdditionalAttributesAndInfoSets.PredefinedDataName AS PredefinedDataName
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets AS AdditionalAttributesAndInfoSets
		|WHERE
		|	AdditionalAttributesAndInfoSets.IsFolder = FALSE
		|	AND AdditionalAttributesAndInfoSets.PredefinedDataName IN(&PredefinedDataName)";
	PredefinedDataTable = RequestPredefinedSets.Execute().Unload();
	For Each String In PredefinedDataTable Do
		Try
			PrefixLength = StrLen("Delete");
			SetName = Mid(String.PredefinedDataName, PrefixLength + 1, StrLen(String.PredefinedDataName) - PrefixLength);
			
			LinkID = String(String.Ref.UUID());
			If StrEndsWith(SetName, "_Overall") Then 
				Subsidiaries = New Array;
				SetName     = StrReplace(SetName, "_Overall", "");
				ParentSet = PropertiesSetByName(SetName);
				RowFilter = New Structure("Parent", ParentSet);
				ChildSets = AllChildSets.FindRows(RowFilter);
				For Each ChildSet In ChildSets Do
					ChildSetRefID = String(ChildSet.Ref.UUID());
					
					SetIDs = New ValueList;
					SetIDs.Add(LinkID);
					SetIDs.Add(ChildSetRefID);
					SetIDs.SortByValue();
					
					IDString1 = "";
					For Each ListItem In SetIDs Do
						IDString1 = IDString1 + StrReplace(ListItem.Value, "-", "");
					EndDo;
					
					Checksum = Common.CheckSumString(IDString1);
					Subsidiaries.Add("PropertySetsKey" + Checksum);
				EndDo;
				Sets.Insert(SetName, Subsidiaries);
			Else
				Checksum = Common.CheckSumString(StrReplace(LinkID, "-", ""));
				Sets.Insert(SetName, "PropertySetsKey" + Checksum + "," + LinkID);
			EndIf;
		Except
			// 
			Continue;
		EndTry;
	EndDo;
	
	Settings = PropertyManagerInternal.ReadSettingsFromStorage(SystemSettingsStorage);
	For Each Setting In Settings Do
		ObjectKey = Setting.ObjectKey;
		ObjectKeyParts = StrSplit(ObjectKey, ".", False);
		If ObjectKeyParts.Count() < 3 Then
			Continue;
		EndIf;
		SetName      = ObjectKeyParts[0] + "_" + ObjectKeyParts[1];
		AssignmentKey = Sets[SetName];
		If AssignmentKey = Undefined Then
			Continue;
		EndIf;
		
		If TypeOf(AssignmentKey) = Type("Array") Then
			For Each Item In AssignmentKey Do
				PropertyManagerInternal.MoveSetting(Setting, Item, SetName);
			EndDo;
		Else 
			PartialAssignmentKey = StrSplit(AssignmentKey, ",");
			PropertyManagerInternal.MoveSetting(Setting, PartialAssignmentKey[0], SetName, PartialAssignmentKey[1]);
		EndIf;
	EndDo;
	
EndProcedure

#Region ObsoleteProceduresAndFunctions

// Deprecated. Obsolete. Use PropertiesValues or PropertyValues.
// Returns a value of an additional object property.
//
// Parameters:
//  PropertiesOwner      - AnyRef - for example, CatalogRef.Products, DocumentRef.SalesOrder, …
//  GetAddlAttributes - Boolean - include additional attributes to the result.
//  GetAddlInfo  - Boolean - include additional info to the result.
//  PropertiesArray        - Array of ChartOfCharacteristicTypesRef - additional attributes
//                            whose values are to be received.
//                       - Undefined - 
// Returns:
//  ValueTable:
//    * Property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - an owner property.
//    * Value - Arbitrary - values of any type from metadata object property type details:
//                  "Metadata.ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Type".
//
Function GetValuesProperties(PropertiesOwner,
                                GetAddlAttributes = True,
                                GetAddlInfo = True,
                                PropertiesArray = Undefined) Export
	
	Return PropertiesValues(PropertiesOwner, GetAddlAttributes, GetAddlInfo, PropertiesArray);
	
EndFunction

// Deprecated. Obsolete. Use ObjectProperties.
// Returns owner properties.
//
// Parameters:
//  PropertiesOwner      - AnyRef - for example, CatalogRef.Products, DocumentRef.SalesOrder, …
//  GetAddlAttributes - Boolean - include additional attributes to the result.
//  GetAddlInfo  - Boolean - include additional info to the result.
//
// Returns:
//  Array of ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - 
//
Function GetPropertyList(PropertiesOwner, GetAddlAttributes = True, GetAddlInfo = True) Export
	Return ObjectProperties(PropertiesOwner, GetAddlAttributes, GetAddlInfo);
EndFunction

// Returns enum values of the specified property.
//
// Parameters:
//  Property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - a property for
//             which listed values are to be received.
// 
// Returns:
//  Array of CatalogRef.ObjectsPropertiesValues, CatalogRef.ObjectPropertyValueHierarchy - 
//      
//
Function GetPropertiesValuesList(Property) Export
	
	Return PropertyManagerInternal.AdditionalPropertyValues(Property);
	
EndFunction

#EndRegion

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// Creates main attributes, commands, and items in the property owner form.
Procedure NewMainFormObjects(Form, Context, CreateAdditionalAttributesDetails)
	
	ItemForPlacementName   = Context.ItemForPlacementName;
	CommandBarItemName = Context.CommandBarItemName;
	DeferredInitialization    = Context.DeferredInitialization;
	ArbitraryObject         = Context.ArbitraryObject;
	
	LabelsDestinationElementName        = Context.LabelsDisplayParameters.LabelsDestinationElementName;
	LabelsLegendDestinationElementName = Context.LabelsDisplayParameters.LabelsLegendDestinationElementName;
	LabelsDisplayOption              = Context.LabelsDisplayParameters.LabelsDisplayOption;
	MaxLabelsOnForm                 = Context.LabelsDisplayParameters.MaxLabelsOnForm;
	ObjectsKind                          = Context.LabelsDisplayParameters.ObjectsKind;
	FilterLabelsCount                           = Context.LabelsDisplayParameters.FilterLabelsCount;
	
	Attributes = New Array;
	
	// Checking a value of the Property usage functional option.
	OptionUseProperties = Form.GetFormFunctionalOption("UseAdditionalAttributesAndInfo");
	AttributeUseProperties = New FormAttribute("PropertiesUseProperties", New TypeDescription("Boolean"));
	Attributes.Add(AttributeUseProperties);
	AttributeHideDeleted = New FormAttribute("PropertiesHideDeleted", New TypeDescription("Boolean"));
	Attributes.Add(AttributeHideDeleted);
	// Additional parameters of the property subsystem.
	AddAttributesForPropertyParameters = True;
	For Each Attribute In Form.GetAttributes() Do
		If Attribute.Name = "PropertiesParameters" Then
			AddAttributesForPropertyParameters = False;
			Break;
		EndIf;
	EndDo;
	If AddAttributesForPropertyParameters Then
		AttributePropertiesParameters = New FormAttribute("PropertiesParameters", New TypeDescription());
		Attributes.Add(AttributePropertiesParameters);
	EndIf;
	If OptionUseProperties Then
		
		AttributeUseAdditionalAttributes = New FormAttribute("PropertiesUseAddlAttributes", New TypeDescription("Boolean"));
		Attributes.Add(AttributeUseAdditionalAttributes);
		
		If CreateAdditionalAttributesDetails Then
			
			// 
			Attributes.Add(New FormAttribute(
				"PropertiesObjectAdditionalAttributeSets", New TypeDescription("ValueList")));
			
			// Adding a details attribute for created attributes and form items.
			DetailsName = "PropertiesAdditionalAttributeDetails";
			
			Attributes.Add(New FormAttribute(
				DetailsName, New TypeDescription("ValueTable")));
			
			Attributes.Add(New FormAttribute(
				"ValueAttributeName", New TypeDescription("String"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"Property", New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo"),
					DetailsName));
			
			Attributes.Add(New FormAttribute(
				"AdditionalValuesOwner", New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo"),
					DetailsName));
			
			Attributes.Add(New FormAttribute(
				"ValueType", New TypeDescription("TypeDescription"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"MultilineInputField", New TypeDescription("Number"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"Deleted", New TypeDescription("Boolean"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"RequiredToFill", New TypeDescription("Boolean"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"Available", New TypeDescription("Boolean"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"isVisible", New TypeDescription("Boolean"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"Description", New TypeDescription("String"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"FormItemAdded", New TypeDescription("Boolean"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"OutputAsHyperlink", New TypeDescription("Boolean"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"RefTypeString", New TypeDescription("Boolean"), DetailsName));
			
			// Adding a details attribute for dependent attributes.
			DependentAttributesTable = "PropertiesDependentAdditionalAttributesDescription";
			
			Attributes.Add(New FormAttribute(
				DependentAttributesTable, New TypeDescription("ValueTable")));
			
			Attributes.Add(New FormAttribute(
				"ValueAttributeName", New TypeDescription("String"), DependentAttributesTable));
			
			Attributes.Add(New FormAttribute(
				"Available", New TypeDescription("Boolean"), DependentAttributesTable));
			
			Attributes.Add(New FormAttribute(
				"AvailabilityCondition", New TypeDescription(), DependentAttributesTable));
			
			Attributes.Add(New FormAttribute(
				"isVisible", New TypeDescription("Boolean"), DependentAttributesTable));
				
			Attributes.Add(New FormAttribute(
				"VisibilityCondition", New TypeDescription(), DependentAttributesTable));
			
			Attributes.Add(New FormAttribute(
				"RequiredToFill", New TypeDescription("Boolean"), DependentAttributesTable));
			
			Attributes.Add(New FormAttribute(
				"FillingRequiredCondition", New TypeDescription(), DependentAttributesTable));
			
			Attributes.Add(New FormAttribute(
				"OutputAsHyperlink", New TypeDescription("Boolean"), DependentAttributesTable));
			
			// 
			Attributes.Add(New FormAttribute(
				"PropertiesAdditionalAttributeGroupItems", New TypeDescription("ValueList")));
			
			// 
			Attributes.Add(New FormAttribute(
				"PropertiesItemNameForPlacement", New TypeDescription()));
			
			// Метки
			Attributes.Add(New FormAttribute("Properties_LabelsDestinationElementName",
				New TypeDescription("String")));
			
			Attributes.Add(New FormAttribute("Properties_LabelsApplied",
				New TypeDescription("ValueList")));
			
			If ArbitraryObject Then
				Attributes.Add(New FormAttribute("Properties_LabelsLegendDestinationElementName",
					New TypeDescription("String")));
				
				// 
				DetailsName = "Properties_LabelsLegendDetails";
				Attributes.Add(New FormAttribute(DetailsName, New TypeDescription("ValueTable")));
				
				Attributes.Add(New FormAttribute("Label",
					New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo"), DetailsName));
				
				Attributes.Add(New FormAttribute("NameOfLabel", New TypeDescription("String"), DetailsName));
				
				If FilterLabelsCount Then
					Attributes.Add(New FormAttribute("FilterByLabel", New TypeDescription("Boolean"), DetailsName));
				EndIf;
			EndIf;
			
			// 
			// 
			If AccessRight("Update", Metadata.Catalogs.AdditionalAttributesAndInfoSets) Then
				// Add a command.
				Command = Form.Commands.Add("EditAdditionalAttributesComposition");
				Command.Title = NStr("en = 'Edit additional attributes';");
				Command.Action = "Attachable_PropertiesExecuteCommand";
				Command.ToolTip = NStr("en = 'Edit additional attributes';");
				Command.Picture = PictureLib.ListSettings;
				
				Button = Form.Items.Add(
					"EditAdditionalAttributesComposition",
					Type("FormButton"),
					?(CommandBarItemName = "",
						Form.CommandBar,
						Form.Items[CommandBarItemName]));
				
				Button.LocationInCommandBar = ButtonLocationInCommandBar.InAdditionalSubmenu;
				Button.CommandName = "EditAdditionalAttributesComposition";
			EndIf;
			
			Command = Form.Commands.Add("EditAttributeHyperlink");
			Command.Title   = NStr("en = 'Start/finish editing';");
			Command.Action    = "Attachable_PropertiesExecuteCommand";
			Command.ToolTip   = NStr("en = 'Start/finish editing';");
			Command.Picture    = PictureLib.Change;
			Command.Representation = ButtonRepresentation.Picture;
		EndIf;
	EndIf;
	
	Form.ChangeAttributes(Attributes);
	
	Form.PropertiesUseProperties = OptionUseProperties;
	
	Form.PropertiesParameters = New Structure;
	If DeferredInitialization Then
		// 
		// 
		Value = ?(OptionUseProperties, False, True);
		Form.PropertiesParameters.Insert("DeferredInitializationExecuted", Value);
	EndIf;
	
	If OptionUseProperties Then
		Form.PropertiesUseAddlAttributes = CreateAdditionalAttributesDetails;
	EndIf;
	
	If OptionUseProperties And CreateAdditionalAttributesDetails Then
		Form.PropertiesItemNameForPlacement = ItemForPlacementName;
		
		Form.Properties_LabelsDestinationElementName = LabelsDestinationElementName;
		Form.PropertiesParameters.Insert("LabelsDisplayOption", LabelsDisplayOption);
		Form.PropertiesParameters.Insert("MaxLabelsOnForm", MaxLabelsOnForm);
		
		If ArbitraryObject Then
			Form.Properties_LabelsLegendDestinationElementName = LabelsLegendDestinationElementName;
			
			Form.PropertiesParameters.Insert("ObjectsKind", ObjectsKind);
			Form.PropertiesParameters.Insert("FilterLabelsCount", FilterLabelsCount);
			
			Command = Form.Commands.Add("LabelsLegend");
			Command.Action = "Attachable_SetLabelsLegendVisibility";
			Command.Picture = PictureLib.Label;
			Command.Representation = ButtonRepresentation.PictureAndText;
		EndIf;
	EndIf;
	
	// 
	// 
	// 
	// 
	If OptionUseProperties
		And DeferredInitialization
		And ItemForPlacementName <> "" Then
		Form.PropertiesParameters.Insert("DecorationCollections");
		Form.PropertiesParameters.DecorationCollections = New Array;
		
		Form.PropertiesParameters.Insert("EmptyDecorationAdded", True);
		If TypeOf(ItemForPlacementName ) = Type("ValueList") Then
			IndexOf = 0;
			For Each PlacementGroup In ItemForPlacementName Do
				PrepareFormForDeferredInitialization(Form, PlacementGroup.Presentation, IndexOf);
				IndexOf = IndexOf + 1;
			EndDo;
		Else
			PrepareFormForDeferredInitialization(Form, ItemForPlacementName, "");
		EndIf;
		
	EndIf;
	
EndProcedure

// Adds protection from transferring a group of additional attributes on the form
// when deferred initialization is enabled.
// 
// Parameters:
//  Form - ClientApplicationForm:
//     * PropertiesParameters - Structure:
//        ** DecorationCollections - Array
//  ItemForPlacementName - String
//  IndexOf - Number
//
Procedure PrepareFormForDeferredInitialization(Form, ItemForPlacementName, IndexOf)
	
	FormGroup = Form.Items[ItemForPlacementName];
	If FormGroup.Type <> FormGroupType.Page Then
		Parent = ParentPage(FormGroup);
	Else
		Parent = FormGroup;
	EndIf;
	
	If Parent <> Undefined
		And Not Form.PropertiesParameters.Property(Parent.Name) Then
		DecorationName1 = "PropertiesEmptyDecoration" + IndexOf;
		Form.PropertiesParameters.DecorationCollections.Add(DecorationName1);
		Decoration = Form.Items.Add(DecorationName1, Type("FormDecoration"), FormGroup);
		
		PagesGroup = Parent.Parent;
		PageHeader = ?(ValueIsFilled(Parent.Title), Parent.Title, Parent.Name);
		PageGroupHeader1 = ?(ValueIsFilled(PagesGroup.Title), PagesGroup.Title, PagesGroup.Name);
		
		PlacementWarning = NStr("en = 'To show additional attributes, display the ""%1"" group under any other item in the ""%2"" group. To do so, click More — Change form.';");
		PlacementWarning = StringFunctionsClientServer.SubstituteParametersToString(PlacementWarning,
			PageHeader, PageGroupHeader1);
		ToolTipText = NStr("en = 'To restore a form to the default settings, do the following:
			| • Select More — Change form.
			| • In the Customize form window that opens, select More actions — Restore default settings.';");
			
		Decoration.ToolTipRepresentation = ToolTipRepresentation.Button;
		Decoration.Title  = PlacementWarning;
		Decoration.ToolTip  = ToolTipText;
		Decoration.TextColor = StyleColors.ErrorNoteText;
		
		// 
		Form.PropertiesParameters.Insert(Parent.Name);
	EndIf;
	
	FormGroup.EnableContentChange = False;
	
EndProcedure

// 
//
// Parameters:
//  Form              - ClientApplicationForm - it is already configured in the procedure for joining the server.
//
//  Object             - Undefined - take an object from the props of the "Object" form.
//                     - CatalogObjectCatalogName
//                     - DocumentObjectDocumentName
//                     - ChartOfCharacteristicTypesObjectChartOfCharacteristicTypesName
//                     - BusinessProcessObjectNameOfBusinessProcess
//                     - TaskObjectTaskName
//                     - ChartOfCalculationTypesObjectChartOfCalculationTypesName
//                     - ChartOfAccountsObjectChartOfAccountsName
//                     - FormDataStructure
//
Procedure FillLabelsLegend(Form, Object)
	
	If Not Form.PropertiesUseProperties
	 Or Not Form.PropertiesUseAddlAttributes Then
		Return;
	EndIf;
	
	LabelsLegendDestinationElementName = Form.Properties_LabelsLegendDestinationElementName;
	If Not ValueIsFilled(LabelsLegendDestinationElementName) Then
		Return;
	EndIf;
	
	Labels = PropertyManagerInternal.PropertiesListForObjectsKind(
		Form.PropertiesParameters.ObjectsKind, "Labels").UnloadColumn("Property");
	If Labels.Count() = 0 Then
		Return;
	EndIf;
	
	IsLabelsLegendVisible = CommonSettingsStorage.Load("Properties", "IsLabelsLegendVisible");
	
	If IsLabelsLegendVisible = Undefined Then
		IsLabelsLegendVisible = False;
		Common.CommonSettingsStorageSave("Properties", "IsLabelsLegendVisible", IsLabelsLegendVisible);
	EndIf;
	
	NewItem = Form.Items.Add("MakeLegendVisible", Type("FormDecoration"),
		Form.Items[LabelsLegendDestinationElementName]);
	NewItem.Type = FormDecorationType.Picture;
	NewItem.Hyperlink = True;
	NewItem.SetAction("Click", "Attachable_SetLabelsLegendVisibility");
	If IsLabelsLegendVisible Then
		NewItem.Picture = PictureLib.GreenRightArrow;
	Else
		NewItem.Picture = PictureLib.GreenDownArrow;
	EndIf;
	
	GroupHideableLegendPart = Form.Items.Add("GroupHideableLegendPart", Type("FormGroup"),
		Form.Items[LabelsLegendDestinationElementName]);
	GroupHideableLegendPart.Type = FormGroupType.UsualGroup;
	GroupHideableLegendPart.Visible = IsLabelsLegendVisible; 
	GroupHideableLegendPart.ShowTitle = False;
	GroupHideableLegendPart.Group = Form.Items[LabelsLegendDestinationElementName].Group;
	
	FilterLabelsCount = Form.PropertiesParameters.FilterLabelsCount;
	LabelsAttributes = Common.ObjectsAttributesValues(Labels,
		"Ref, Name, Description, PropertiesColor, DeletionMark");
	If FilterLabelsCount Then
		Attributes = New Array;
		For Each Label In Labels Do
			LabelAttributes = LabelsAttributes.Get(Label);
			If LabelAttributes = Undefined Then
				Continue;
			EndIf;
			Attributes.Add(New FormAttribute("FilterLabel_" + LabelAttributes.Name,
				New TypeDescription("Boolean")));
		EndDo;
		Form.ChangeAttributes(Attributes);
	EndIf;
	
	For Each Label In Labels Do
		Label = LabelsAttributes.Get(Label);
		If Label = Undefined Or Label.DeletionMark Then
			Continue;
		EndIf;
		
		Group = Form.Items.Add("Group" + Label.Name, Type("FormGroup"), GroupHideableLegendPart);
		Group.Type = FormGroupType.UsualGroup;
		Group.ShowTitle = False;
		Group.Group = ChildFormItemsGroup.AlwaysHorizontal;
		
		LegendLabel = Form.Properties_LabelsLegendDetails.Add();
		LegendLabel.Label = Label.Ref;
		LegendLabel.NameOfLabel = Label.Name;
		
		If FilterLabelsCount Then
			NewItem = Form.Items.Add("FilterLabel_" + Label.Name, Type("FormField"), Group);
			NewItem.Type = FormFieldType.CheckBoxField;
			NewItem.DataPath = "FilterLabel_" + Label.Name;
			NewItem.TitleLocation = FormItemTitleLocation.None;
			NewItem.SetAction("OnChange", "Attachable_FilterByLabelsHandler");
		EndIf;
		
		NewItem = Form.Items.Add("Legend_" + Label.Name, Type("FormDecoration"), Group);
		NewItem.Type = FormDecorationType.Picture;
		NewItem.Picture = PictureLabelsByColor(Label.PropertiesColor);
		NewItem.ToolTip = Label.Description;
		NewItem.ToolTipRepresentation = ToolTipRepresentation.ShowRight;
	EndDo;
	
EndProcedure

Function ParentPage(FormGroup)
	
	Parent = FormGroup.Parent;
	If TypeOf(Parent) = Type("FormGroup") Then
		Parent.EnableContentChange = False;
		If Parent.Type = FormGroupType.Page Then
			Return Parent;
		Else
			Return ParentPage(Parent);
		EndIf;
	EndIf;
	
	Return Undefined;
	
EndFunction

Procedure UpdateFormAssignmentKey(Form, AssignmentKey)
	
	If AssignmentKey = Undefined Then
		AssignmentKey = PropertySetsKey(Form.PropertiesObjectAdditionalAttributeSets);
	EndIf;
	
	If IsBlankString(AssignmentKey) Then
		Return;
	EndIf;
	
	KeyBeginning = "PropertySetsKey";
	PropertySetsKey = KeyBeginning + Left(AssignmentKey + "00000000000000000000000000000000", 32);
	
	NewKey = NewAssignmentKey(Form.PurposeUseKey, KeyBeginning, PropertySetsKey);
	If NewKey <> Undefined Then
		Form.PurposeUseKey = NewKey;
	EndIf;
	
EndProcedure

Function ConditionCalculationResult(Form, ObjectDetails, Parameters)
	ConditionParameters = New Structure;
	ConditionParameters.Insert("ParameterValues", Parameters.ParameterValues);
	ConditionParameters.Insert("Form", Form);
	ConditionParameters.Insert("ObjectDetails", ObjectDetails);
	
	Return Common.CalculateInSafeMode(Parameters.ConditionCode, ConditionParameters);
EndFunction

Function NewAssignmentKey(CurrentKey, KeyBeginning, PropertySetsKey)
	
	Position = StrFind(CurrentKey, KeyBeginning);
	
	NewAssignmentKey = Undefined;
	
	If Position = 0 Then
		NewAssignmentKey = CurrentKey + PropertySetsKey;
	
	ElsIf StrFind(CurrentKey, PropertySetsKey) = 0 Then
		NewAssignmentKey = Left(CurrentKey, Position - 1) + PropertySetsKey
			+ Mid(CurrentKey, Position + StrLen(KeyBeginning) + 32);
	EndIf;
	
	Return NewAssignmentKey;
	
EndFunction

Function PropertySetsKey(Sets)
	
	SetIDs = New ValueList;
	
	For Each ListItem In Sets Do
		SetIDs.Add(String(ListItem.Value.UUID()));
	EndDo;
	
	SetIDs.SortByValue();
	IDString1 = "";
	
	For Each ListItem In SetIDs Do
		IDString1 = IDString1 + StrReplace(ListItem.Value, "-", "");
	EndDo;
	
	Return Common.CheckSumString(IDString1);
	
EndFunction

Function AttributeIsAvailableByFunctionalOptions(PropertyDetails)
	ObjectIsAvailable = True;
	For Each Type In PropertyDetails.ValueType.Types() Do
		MetadataObject = Metadata.FindByType(Type);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		ObjectIsAvailable = Common.MetadataObjectAvailableByFunctionalOptions(MetadataObject);
		If ObjectIsAvailable Then
			Break; // If at least one type is available, the attribute is not hidden.
		EndIf;
	EndDo;
	
	Return ObjectIsAvailable;
EndFunction

Function PropertiesUsed(Form, AdditionalParameters)
	
	If Not AccessRight("Read", Metadata.Catalogs.AdditionalAttributesAndInfoSets) Then
		DisableAdditionalAttributesOnForm(Form, AdditionalParameters);
		Return False;
	EndIf;
	
	If AdditionalParameters <> Undefined
		And AdditionalParameters.Property("ArbitraryObject")
		And AdditionalParameters.ArbitraryObject Then
		Return True;
	EndIf;
	
	If AdditionalParameters <> Undefined
		And AdditionalParameters.Property("Object") Then
		ObjectDetails = AdditionalParameters.Object;
	Else
		ObjectDetails = Form.Object;
	EndIf;
	ObjectType = TypeOf(ObjectDetails.Ref);
	
	ObjectMetadata = Metadata.FindByType(ObjectType);
	TabularSection = ObjectMetadata.TabularSections.Find("AdditionalAttributes");
	If TabularSection = Undefined Then
		DisableAdditionalAttributesOnForm(Form, AdditionalParameters);
		Return False;
	EndIf;
	
	If Common.ObjectKindByType(ObjectType) = "Catalog" Then
		If Not ObjectMetadata.Hierarchical
			Or ObjectMetadata.HierarchyType <> Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
			IsFolder = False;
		ElsIf ObjectDetails.Property("IsFolder") Then
			IsFolder = ObjectDetails.IsFolder;
		ElsIf ValueIsFilled(ObjectDetails.Ref) Then
			IsFolder = Common.ObjectAttributeValue(ObjectDetails.Ref, "IsFolder");
		Else
			IsFolder = False;
		EndIf;
		
		If IsFolder And TabularSection.Use = Metadata.ObjectProperties.AttributeUse.ForItem
			Or Not IsFolder And TabularSection.Use = Metadata.ObjectProperties.AttributeUse.ForFolder Then
			DisableAdditionalAttributesOnForm(Form, AdditionalParameters);
			Return False;
		EndIf;
	EndIf;
	
	FullName = ObjectMetadata.FullName();
	
	FormNameArray1 = StrSplit(FullName, ".");
	
	TagName = FormNameArray1[0] + "_" + FormNameArray1[1];
	PropertiesSet = PropertiesSetByName(TagName);
	If PropertiesSet = Undefined Then
		PropertiesSet = Catalogs.AdditionalAttributesAndInfoSets[TagName];
	EndIf;
	
	PropertiesUsed = Common.ObjectAttributeValue(PropertiesSet, "Used");
	
	If Not PropertiesUsed Then
		DisableAdditionalAttributesOnForm(Form, AdditionalParameters);
	EndIf;
	
	Return PropertiesUsed;
	
EndFunction

Procedure DisableAdditionalAttributesOnForm(Form, AdditionalParameters)
	
	AttributesArray = CommonClientServer.ValueInArray(
		New FormAttribute("PropertiesUseProperties", New TypeDescription("Boolean")));
	PropertiesParametersAdded = False;
	
	CheckStructure = New Structure("PropertiesParameters", "Validation");
	FillPropertyValues(CheckStructure, Form);
	If CheckStructure.PropertiesParameters <> "Validation" Then
		PropertiesParametersAdded = True;
	EndIf;
	
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		If AdditionalParameters.Property("ItemForPlacementName") Then
			If TypeOf(AdditionalParameters.ItemForPlacementName) = Type("ValueList") Then
				For Each ListItem In AdditionalParameters.ItemForPlacementName Do
					Form.Items[ListItem.Presentation].Visible = False;
				EndDo;
			Else
				Form.Items[AdditionalParameters.ItemForPlacementName].Visible = False;
			EndIf;
		EndIf;
		
		If AdditionalParameters.Property("DeferredInitialization") And Not PropertiesParametersAdded Then
			AttributePropertiesParameters = New FormAttribute("PropertiesParameters", New TypeDescription());
			AttributesArray.Add(AttributePropertiesParameters);
			PropertiesParametersAdded = True;
		EndIf;
	EndIf;
	
	Form.ChangeAttributes(AttributesArray);
	Form.PropertiesUseProperties = False;
	If PropertiesParametersAdded Then
		Form.PropertiesParameters = New Structure;
		Form.PropertiesParameters.Insert("DeferredInitializationExecuted", True);
	EndIf;
	
EndProcedure

Function ValuePresentation(Value, LanguageCode, FormatProperties)
	
	If Value = Undefined Then
		Return Value;
	EndIf;
	
	If TypeOf(Value) = Type("String") Then
		Presentation = Value;
	ElsIf TypeOf(Value) = Type("Boolean")
		Or TypeOf(Value) = Type("Date")
		Or TypeOf(Value) = Type("Number") Then
		If ValueIsFilled(FormatProperties) Then
			If StrFind(FormatProperties, "L=''") > 0 Then
				FormatProperties = StrReplace(FormatProperties, "L=''", "L=" + LanguageCode);
			ElsIf StrFind(FormatProperties, "L=") = 0 Then
				FormatProperties = "L=" + LanguageCode + ";" + FormatProperties;
			EndIf;
			Presentation = Format(Value, FormatProperties);
		Else
			Presentation = Format(Value, "L=" + LanguageCode);
		EndIf;
	Else
		Presentation = Common.ObjectAttributeValue(Value, "Description", , LanguageCode);
	EndIf;
	
	Return Presentation;
	
EndFunction

Function PropertiesFormat(Property)
	
	Query = New Query;
	Query.SetParameter("Property", Property);
	Query.Text =
		"SELECT
		|	AdditionalAttributesAndInfo.FormatProperties AS FormatProperties,
		|	AdditionalAttributesAndInfo.Ref AS Property
		|FROM
		|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
		|WHERE
		|	AdditionalAttributesAndInfo.Name IN(&Property)
		|	OR AdditionalAttributesAndInfo.Ref IN(&Property)";
	
	Result = Query.Execute().Unload();
	If Result.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	PropertiesFormat = New Map;
	For Each String In Result Do
		PropertiesFormat.Insert(String.Property, String.FormatProperties);
	EndDo;
	
	Return PropertiesFormat;
	
EndFunction

Procedure SetLabelsVisibility(Form, LabelsDestinationElementName)
	
	If Not ValueIsFilled(LabelsDestinationElementName) Then
		Return;
	EndIf;
	
	If Not Form.PropertiesUseProperties
	 Or Not Form.PropertiesUseAddlAttributes Then
		AreLabelsVisible = False;
	Else
		AreLabelsVisible = True;
	EndIf;
	
	Form.Items[LabelsDestinationElementName].Visible = AreLabelsVisible;
	
EndProcedure

Function PictureLabelsByColor(PropertiesColor)
	
	If PropertiesColor = Enums.PropertiesColors.LightBlue Then
		Picture = PictureLib.LabelLightBlue;
	ElsIf PropertiesColor = Enums.PropertiesColors.Yellow Then
		Picture = PictureLib.LabelYellow;
	ElsIf PropertiesColor = Enums.PropertiesColors.Green Then
		Picture = PictureLib.LabelGreen;
	ElsIf PropertiesColor = Enums.PropertiesColors.GreenLime Then
		Picture = PictureLib.LabelLime;
	ElsIf PropertiesColor = Enums.PropertiesColors.Red Then
		Picture = PictureLib.LabelRed;
	ElsIf PropertiesColor = Enums.PropertiesColors.Orange Then
		Picture = PictureLib.LabelOrange;
	ElsIf PropertiesColor = Enums.PropertiesColors.Pink Then
		Picture = PictureLib.LabelPink;
	ElsIf PropertiesColor = Enums.PropertiesColors.B Then
		Picture = PictureLib.LabelBlue;
	ElsIf PropertiesColor = Enums.PropertiesColors.Violet Then
		Picture = PictureLib.LabelPurple;
	Else
		Picture = PictureLib.LabelGray;
	EndIf;
	
	Return Picture;
	
EndFunction

Function StyleItemByColor(PropertiesColor)
	
	If PropertiesColor = Enums.PropertiesColors.GreenLime Then
		StyleItem = Metadata.StyleItems.LabelColorLime.Value;
	ElsIf PropertiesColor = Enums.PropertiesColors.Red Then
		StyleItem = Metadata.StyleItems.LabelColorRed.Value;
	ElsIf PropertiesColor = Enums.PropertiesColors.Orange Then
		StyleItem = Metadata.StyleItems.LabelColorOrange.Value;
	ElsIf PropertiesColor = Enums.PropertiesColors.Yellow Then
		StyleItem = Metadata.StyleItems.LabelColorYellow.Value;
	ElsIf PropertiesColor = Enums.PropertiesColors.Green Then
		StyleItem = Metadata.StyleItems.LabelColorGreen.Value;
	ElsIf PropertiesColor = Enums.PropertiesColors.B Then
		StyleItem = Metadata.StyleItems.LabelColorBlue.Value;
	ElsIf PropertiesColor = Enums.PropertiesColors.LightBlue Then
		StyleItem = Metadata.StyleItems.LabelColorLightBlue.Value;
	ElsIf PropertiesColor = Enums.PropertiesColors.Violet Then
		StyleItem = Metadata.StyleItems.LabelColorPurple.Value;
	ElsIf PropertiesColor = Enums.PropertiesColors.Pink Then
		StyleItem = Metadata.StyleItems.LabelColorPink.Value;
	Else
		StyleItem = Metadata.StyleItems.LabelColorGray.Value;
	EndIf;
	
	Return StyleItem;
	
EndFunction

#EndRegion
