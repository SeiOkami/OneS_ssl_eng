///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

////////////////////////////////////////////////////////////////////////////////
//                          
//
// 
// 
//
// 
// 
//				
//				
//					
//					
//					
//				
// 
//				
//				
//				
// 
// 				 
//  
//				
// 
//              
//              
// 
//              
//

#Region Variables

&AtServer
Var SubordinateCatalogs;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	SelectCollectionsWhenAllObjectsSelected = Parameters.SelectCollectionsWhenAllObjectsSelected;
	RememberSelectedObjectsSections      = Parameters.RememberSelectedObjectsSections;
	MetadataObjectsToSelectCollection   = Parameters.MetadataObjectsToSelectCollection;
	ParentSubsystems                  = Parameters.ParentSubsystems;
	FilterByMetadataObjects              = Parameters.FilterByMetadataObjects;
	UUIDSource         = Parameters.UUIDSource;
	ObjectsGroupMethod               = Parameters.ObjectsGroupMethod;
	SelectedMetadataObjects              = Common.CopyRecursive(Parameters.SelectedMetadataObjects);
	
	ChooseRefs          = CommonClientServer.StructureProperty(Parameters, "ChooseRefs", False);
	SubsystemsWithCIOnly     = CommonClientServer.StructureProperty(Parameters, "SubsystemsWithCIOnly", False);
	SelectSingle      = CommonClientServer.StructureProperty(Parameters, "SelectSingle", False);
	ChoiceInitialValue = CommonClientServer.StructureProperty(Parameters, "ChoiceInitialValue", False);
	
	FillSelectedMetadataObjects();
	
	If FilterByMetadataObjects.Count() > 0 Then
		MetadataObjectsToSelectCollection.Clear();
		For Each MetadataObjectFullName In FilterByMetadataObjects Do
			BaseTypeName = Common.BaseTypeNameByMetadataObject(
				Common.MetadataObjectByFullName(MetadataObjectFullName.Value));
			If MetadataObjectsToSelectCollection.FindByValue(BaseTypeName) = Undefined Then
				MetadataObjectsToSelectCollection.Add(BaseTypeName);
			EndIf;
		EndDo;
	ElsIf ChooseRefs Then
		ModuleMetadataObjectIds = Common.CommonModule(
			"Catalogs.MetadataObjectIDs");
		ValidCollections = ModuleMetadataObjectIds.ValidCollections();
		If Not ValueIsFilled(MetadataObjectsToSelectCollection) Then
			For Each ValidCollection In ValidCollections Do
				MetadataObjectsToSelectCollection.Add(ValidCollection);
			EndDo;
		Else
			SuitableCollections = New ValueList;
			For Each ListItem In MetadataObjectsToSelectCollection Do
				If ValidCollections.Find(ListItem.Value) <> Undefined Then
					SuitableCollections.Add().Value = ListItem.Value;
				EndIf;
			EndDo;
			If SuitableCollections.Count() = 0 Then
				SuitableCollections.Add().Value = ValidCollections[0];
			EndIf;
			MetadataObjectsToSelectCollection = SuitableCollections;
		EndIf;
	EndIf;
	
	If SubsystemsWithCIOnly Then
		SubsystemsList = Metadata.Subsystems;
		FillSubsystemList(SubsystemsList);
	EndIf;
	
	If SelectSingle Then
		Items.Check.Visible = False;
	EndIf;
	
	If ValueIsFilled(Parameters.Title) Then
		AutoTitle = False;
		Title = Parameters.Title;
	EndIf;
	
	If Not ValueIsFilled(ChoiceInitialValue)
		And SelectSingle
		And Parameters.SelectedMetadataObjects.Count() = 1 Then
		ChoiceInitialValue = Parameters.SelectedMetadataObjects[0].Value;
	EndIf;
	
	If Not ValueIsFilled(ObjectsGroupMethod) Then
		ObjectsGroupMethod = "BySections";
		
	ElsIf ObjectsGroupMethod = "ByKinds"
	      Or ObjectsGroupMethod = "BySections" Then
		
		Items.ObjectsGroupMethod.Visible = False;
	Else
		GroupingMethods = StrSplit(Parameters.ObjectsGroupMethod, ",", False);
		If GroupingMethods[0] = "ByKinds" Then
			ObjectsGroupMethod = "ByKinds";
		Else
			ObjectsGroupMethod = "BySections";
		EndIf;
	EndIf;
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Top;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FillObjectsTree(True);
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	
	If Not Items.ObjectsGroupMethod.Visible
	 Or Settings["ObjectsGroupMethod"] <> "ByKinds"
	   And Settings["ObjectsGroupMethod"] <> "BySections" Then
		
		Settings.Insert("ObjectsGroupMethod", ObjectsGroupMethod);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

// Form tree "Mark" field click event handler procedure.
&AtClient
Procedure CheckOnChange(Item)
	
	FlagDone = True;
	OnMarkTreeItem(CurrentItem.CurrentData);
	
EndProcedure

&AtClient
Procedure SelectionModeOnChange(Item)
	
	If FlagDone Then
		SelectedObjectsAddresses.Clear();
		UpdateSelectedMetadataObjectsCollection();
	EndIf;
	
	FillObjectsTree();
	
EndProcedure

#EndRegion

#Region MetadataObjectsTreeFormTableItemEventHandlers

&AtClient
Procedure MetadataObjectsTreeSelection(Item, RowSelected, Field, StandardProcessing)

	If SelectSingle Then
		
		SelectExecute();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SelectExecute()
	
	If SelectSingle Then
		
		curData = Items.MetadataObjectsTree.CurrentData;
		If curData <> Undefined
			And curData.IsMetadataObject Then
			
			SelectedMetadataObjects.Clear();
			SelectedMetadataObjects.Add(curData.FullName, curData.Presentation);
			
		Else
			Return;
		EndIf;
	Else
		UpdateSelectedMetadataObjectsCollection();
	EndIf;
	
	If ChooseRefs Then
		SelectRefs(SelectedMetadataObjects);
	EndIf;
	
	If OnCloseNotifyDescription = Undefined Then
		Notify("SelectMetadataObjects", SelectedMetadataObjects, UUIDSource);
	EndIf;
	
	Close(SelectedMetadataObjects);
	
EndProcedure

&AtClient
Procedure CloseExecute()
	
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillSelectedMetadataObjects()
	
	MetadataObjects = SelectedMetadataObjects.UnloadValues();
	
	If RememberSelectedObjectsSections
		And SelectedMetadataObjects.Count() > 0 And StrStartsWith(SelectedMetadataObjects[0].Presentation, "./") Then
		For Each Item In SelectedMetadataObjects Do
			SelectedObjectsAddresses.Add(Item.Presentation, Item.Value);
		EndDo;
	EndIf;
	
	If Not ChooseRefs Then
		Return;
	EndIf;
	
	References = New Array;
	
	For Each MetadataObject In MetadataObjects Do 
		
		If TypeOf(MetadataObject) = Type("CatalogRef.MetadataObjectIDs")
			Or TypeOf(MetadataObject) = Type("CatalogRef.ExtensionObjectIDs") Then 
			
			References.Add(MetadataObject);
		EndIf;
		
	EndDo;
	
	If References.Count() = 0 Then 
		Return;
	EndIf;
	
	MetadataObjectNames = Common.ObjectsAttributeValue(References, "FullName");
	
	For Each ListItem In SelectedMetadataObjects Do 
		
		MetadataObjectName = MetadataObjectNames[ListItem.Value];
		If MetadataObjectName <> Undefined Then 
			ListItem.Value = MetadataObjectName;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillSubsystemList(SubsystemsList) 
	For Each Subsystem In SubsystemsList Do
		If Subsystem.IncludeInCommandInterface Then
			ItemsOfSubsystemsWithCommandInterface.Add(Subsystem.FullName());
		EndIf;
		
		If Subsystem.Subsystems.Count() > 0 Then
			FillSubsystemList(Subsystem.Subsystems);
		EndIf;
	EndDo;
EndProcedure

// Populates the tree of configuration object values.
// If value list MetadataObjectsToSelectCollection is not empty, pass a metadata object collection list.
// If metadata objects from the tree are found in the "SelectedMetadataObjects", they are marked as selected.
//  
// 
//
&AtServer
Procedure MetadataObjectTreeFill()
	
	MetadataObjectsTree.GetItems().Clear();
	
	MetadataObjectsCollections = New ValueTable;
	MetadataObjectsCollections.Columns.Add("Name");
	MetadataObjectsCollections.Columns.Add("Synonym");
	MetadataObjectsCollections.Columns.Add("Picture");
	MetadataObjectsCollections.Columns.Add("IsCommonCollection");
	MetadataObjectsCollections.Columns.Add("FullName");
	MetadataObjectsCollections.Columns.Add("Parent");
	
	MetadataObjectCollectionsNewRow("Subsystems",                   NStr("en = 'Subsystems';"),                     PictureLib.MetadataSubsystems,                   True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("CommonModules",                  NStr("en = 'Common modules';"),                   PictureLib.MetadataCommonModules,                  True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("SessionParameters",              NStr("en = 'Session parameters';"),               PictureLib.MetadataSessionParameters,              True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("Roles",                         NStr("en = 'Roles';"),                           PictureLib.RoleMetadata,                         True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("CommonAttributes",               NStr("en = 'Common attributes';"),                PictureLib.MetadataCommonAttributes,               True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("ExchangePlans",                  NStr("en = 'Exchange plans';"),                   PictureLib.MetadataExchangePlans,                  True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("FilterCriteria",               NStr("en = 'Filter criteria';"),                PictureLib.MetadataFilterCriteria,               True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("EventSubscriptions",            NStr("en = 'Event subscriptions';"),            PictureLib.MetadataEventSubscriptions,            True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("ScheduledJobs",          NStr("en = 'Scheduled jobs';"),           PictureLib.MetadataScheduledJobs,          True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("FunctionalOptions",          NStr("en = 'Functional options';"),           PictureLib.MetadataFunctionalOptions,          True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("FunctionalOptionsParameters", NStr("en = 'Functional option parameters';"), PictureLib.MetadataFunctionalOptionsParameters, True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("SettingsStorages",            NStr("en = 'Settings storages';"),             PictureLib.MetadataSettingsStorage,            True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("CommonForms",                   NStr("en = 'Common forms';"),                    PictureLib.MetadataCommonForms,                   True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("CommonCommands",                 NStr("en = 'Common commands';"),                  PictureLib.MetadataCommonCommands,                 True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("CommandGroups",                 NStr("en = 'Command groups';"),                  PictureLib.MetadataCommandGroups,                 True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("Interfaces",                   NStr("en = 'Interfaces';"),                     Undefined,                                              True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("CommonTemplates",                  NStr("en = 'Common templates';"),                   PictureLib.MetadataCommonTemplates,                  True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("CommonPictures",                NStr("en = 'Common pictures';"),                 PictureLib.MetadataCommonPictures,                True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("XDTOPackages",                   NStr("en = 'XDTO packages';"),                    PictureLib.MetadataXDTOPackages,                   True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("WebServices",                   NStr("en = 'Web services';"),                    PictureLib.MetadataWebServices,                   True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("HTTPServices",                  NStr("en = 'HTTP services';"),                   PictureLib.MetadataHTTPServices,                  True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("WSReferences",                     NStr("en = 'WS references';"),                      PictureLib.MetadataWSReferences,                     True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("Styles",                        NStr("en = 'Styles';"),                          PictureLib.MetadataStyles,                        True, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("Languages",                        NStr("en = 'Languages';"),                          PictureLib.MetadataLanguages,                        True, MetadataObjectsCollections);
	
	MetadataObjectCollectionsNewRow("Constants",                    NStr("en = 'Constants';"),                      PictureLib.MetadataConstants,               False, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("Catalogs",                  NStr("en = 'Catalogs';"),                    PictureLib.MetadataCatalogs,             False, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("Documents",                    NStr("en = 'Documents';"),                      PictureLib.MetadataDocuments,               False, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("DocumentJournals",            NStr("en = 'Document journals';"),             PictureLib.MetadataDocumentJournals,       False, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("Enums",                 NStr("en = 'Enumerations';"),                   PictureLib.EnumerationMetadata,            False, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("Reports",                       NStr("en = 'Reports';"),                         PictureLib.MetadataReports,                  False, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("DataProcessors",                    NStr("en = 'Data processors';"),                      PictureLib.MetadataDataProcessors,               False, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("ChartsOfCharacteristicTypes",      NStr("en = 'Charts of characteristic types';"),      PictureLib.MetadataChartsOfCharacteristicTypes, False, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("ChartsOfAccounts",                  NStr("en = 'Charts of accounts';"),                   PictureLib.MetadataChartsOfAccounts,             False, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("ChartsOfCalculationTypes",            NStr("en = 'Charts of calculation types';"),            PictureLib.MetadataChartsOfCalculationTypes,       False, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("InformationRegisters",             NStr("en = 'Information registers';"),              PictureLib.MetadataInformationRegisters,        False, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("AccumulationRegisters",           NStr("en = 'Accumulation registers';"),            PictureLib.MetadataAccumulationRegisters,      False, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("AccountingRegisters",          NStr("en = 'Accounting registers';"),           PictureLib.MetadataAccountingRegisters,     False, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("CalculationRegisters",              NStr("en = 'Calculation registers';"),               PictureLib.MetadataCalculationRegisters,         False, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("BusinessProcesses",               NStr("en = 'Business processes';"),                PictureLib.MetadataBusinessProcesses,          False, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("Tasks",                       NStr("en = 'Tasks';"),                         PictureLib.MetadataTasks,                  False, MetadataObjectsCollections);
	MetadataObjectCollectionsNewRow("ExternalDataSources",       NStr("en = 'External data sources';"),       PictureLib.MetadataExternalDataSources,  False, MetadataObjectsCollections);
	
	// Create predefined items.
	ItemParameters = MetadataObjectTreeItemParameters();
	ItemParameters.Name = Metadata.Name;
	ItemParameters.Synonym = Metadata.Synonym;
	ItemParameters.Picture = PictureLib.MetadataConfiguration;
	ItemParameters.Parent = MetadataObjectsTree;
	ConfigurationItem = NewTreeRow(ItemParameters);
	
	ItemParameters = MetadataObjectTreeItemParameters();
	ItemParameters.Name = "Overall";
	ItemParameters.Synonym = NStr("en = 'Common';");
	ItemParameters.Picture = PictureLib.MetadataCommon;
	ItemParameters.Parent = ConfigurationItem;
	ItemCommon = NewTreeRow(ItemParameters);
	
	// FIlling the metadata object tree.
	For Each String In MetadataObjectsCollections Do
		If MetadataObjectsToSelectCollection.Count() = 0
			Or MetadataObjectsToSelectCollection.FindByValue(String.Name) <> Undefined Then
			String.Parent = ?(String.IsCommonCollection, ItemCommon, ConfigurationItem);
			AddMetadataObjectTreeItem(String, ?(String.Name = "Subsystems", Metadata.Subsystems, Undefined));
		EndIf;
	EndDo;
	
	If ItemCommon.GetItems().Count() = 0 Then
		ConfigurationItem.GetItems().Delete(ItemCommon);
	EndIf;
	
EndProcedure

// Returns a new metadata object tree item parameter structure.
//
// Returns:
//   Structure:
//     Name - String - Name of the parent item.
//     Synonym - String - Synonym of the parent item.
//     Mark - Boolean - Initial mark of a collection or metadata object.
//     Picture - Picture - Code of the parent item picture.
//     Parent - Reference to the value tree item that is a root of the item to be added.
//                       
//
&AtServer
Function MetadataObjectTreeItemParameters()
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Name", "");
	ParametersStructure.Insert("FullName", "");
	ParametersStructure.Insert("Synonym", "");
	ParametersStructure.Insert("Check", 0);
	ParametersStructure.Insert("Picture", Undefined);
	ParametersStructure.Insert("Parent", Undefined);
	
	Return ParametersStructure;
	
EndFunction

// Adds a new row to the form value tree
// and fills the full row set from metadata by the passed parameter.
//
// If the Subsystems parameter is filled, the function is called recursively for all child subsystems.
//
// Parameters:
//   ItemParameters - Structure:
//     * Name           - String - Parent item name.
//     * Synonym       - String - Parent item synonym.
//     * Check       - Boolean - Initial mark of a collection or metadata object.
//     * Picture      - Picture - Parent item picture.
//     * Parent      - FormDataTreeItem:
//         ** Name - String
//         ** Presentation - String
//         ** Picture - Picture
//         ** FullName - String
//         ** IsMetadataObject - Boolean
//         ** Check - Boolean
//   Subsystems - MetadataObjectCollection - If filled, it contains Metadata.Subsystems value (an item collection).
//   Check       - Boolean - Flag indicating whether a check for subordination to parent subsystems is required.
// 
// Returns:
//  FormDataTreeItem
//
&AtServer
Function AddMetadataObjectTreeItem(ItemParameters, Subsystems = Undefined, Check = True)
	
	// Checking whether command interface is available in tree leaves only.
	If Subsystems <> Undefined  And Parameters.Property("SubsystemsWithCIOnly") 
		And Not IsBlankString(ItemParameters.FullName) 
		And ItemsOfSubsystemsWithCommandInterface.FindByValue(ItemParameters.FullName) = Undefined Then
		Return Undefined;
	EndIf;
	
	If Subsystems = Undefined Then
		
		If Metadata[ItemParameters.Name].Count() = 0 Then
			
			//  
			// 
			// 
			Return Undefined;
			
		EndIf;
		
		NewRow = NewTreeRow(ItemParameters, Subsystems <> Undefined And Subsystems <> Metadata.Subsystems);
		NewRow.ThisCollectionObjects = True;
		
		For Each MetadataCollectionItem In Metadata[ItemParameters.Name] Do
			
			If FilterByMetadataObjects.Count() > 0
				And FilterByMetadataObjects.FindByValue(MetadataCollectionItem.FullName()) = Undefined Then
				Continue;
			EndIf;
			
			ItemParameters = MetadataObjectTreeItemParameters();
			ItemParameters.Name = MetadataCollectionItem.Name;
			ItemParameters.FullName = MetadataCollectionItem.FullName();
			ItemParameters.Synonym = MetadataCollectionItem.Synonym;
			ItemParameters.Parent = NewRow;
			ItemParameters.Picture = ?(ItemParameters.Parent.Picture <> Undefined,
				ItemParameters.Parent.Picture, PictureInDesigner(MetadataCollectionItem));
			NewTreeRow(ItemParameters, True);
		EndDo;
		
		Return NewRow;
		
	EndIf;
		
	If Subsystems.Count() = 0 And ItemParameters.Name = "Subsystems" Then
		// 
		Return Undefined;
	EndIf;
	
	NewRow = NewTreeRow(ItemParameters, Subsystems <> Undefined And Subsystems <> Metadata.Subsystems);
	NewRow.ThisCollectionObjects = (Subsystems = Metadata.Subsystems);
	
	For Each MetadataCollectionItem In Subsystems Do
		
		If Not Check
			Or ParentSubsystems.Count() = 0
			Or ParentSubsystems.FindByValue(MetadataCollectionItem.Name) <> Undefined Then
			
			ItemParameters = MetadataObjectTreeItemParameters();
			ItemParameters.Name = MetadataCollectionItem.Name;
			ItemParameters.FullName = MetadataCollectionItem.FullName();
			ItemParameters.Synonym = MetadataCollectionItem.Synonym;
			ItemParameters.Parent = NewRow;
			ItemParameters.Picture = PictureInDesigner(MetadataCollectionItem);
			AddMetadataObjectTreeItem(ItemParameters, MetadataCollectionItem.Subsystems, False);
		EndIf;
	EndDo;
	
	Return NewRow;
	
EndFunction

&AtServer
Function NewTreeRow(RowParameters, IsMetadataObject = False)
	
	Collection = RowParameters.Parent.GetItems();
	NewRow = Collection.Add();
	NewRow.Name                 = RowParameters.Name;
	NewRow.Presentation       = ?(ValueIsFilled(RowParameters.Synonym), RowParameters.Synonym, RowParameters.Name);
	NewRow.Picture            = RowParameters.Picture;
	NewRow.FullName           = RowParameters.FullName;
	NewRow.IsMetadataObject = IsMetadataObject;
	NewRow.Check = ?(SelectedMetadataObjects.FindByValue(RowParameters.FullName) <> Undefined
		Or IsMetadataObject And SelectedMetadataObjects.FindByValue(RowParameters.Parent.Name) <> Undefined, 1, 0);
	
	If NewRow.Check
	   And NewRow.IsMetadataObject
	   And Not ValueIsFilled(RowIdoftheFirstSelectedObject) Then
	
		RowIdoftheFirstSelectedObject = NewRow.GetID();
		If Not ValueIsFilled(CurrentLineIDOnOpen) Then
			CurrentLineIDOnOpen = RowIdoftheFirstSelectedObject;
		EndIf;
	EndIf;
	
	If NewRow.IsMetadataObject 
		And NewRow.FullName = ChoiceInitialValue Then
		CurrentLineIDOnOpen = NewRow.GetID();
	EndIf;
	
	Return NewRow;
	
EndFunction

// Adds a new row to configuration metadata object type
// value table.
//
// Parameters:
//   Name  - String - a metadata object name, or a metadata object kind name.
//   Synonym - String - a metadata object synonym.
//   Picture - Number - picture referring to the metadata object
//                      or to the metadata object type.
//   IsCommonCollection - Boolean - Flag indicating whether the current item has subitems.
//   Tab - ValueTable
//
&AtServer
Procedure MetadataObjectCollectionsNewRow(Name, Synonym, Picture, IsCommonCollection, Tab)
	
	NewRow = Tab.Add();
	NewRow.Name               = Name;
	NewRow.Synonym           = Synonym;
	NewRow.Picture          = Picture;
	NewRow.IsCommonCollection = IsCommonCollection;
	
EndProcedure

&AtClient
Function ItemMarkValues(ParentItems1)
	
	HasMarkedItems    = False;
	HasUnmarkedItems = False;
	
	For Each ParentItem1 In ParentItems1 Do
		
		If ParentItem1.Check = 2 Or (HasMarkedItems And HasUnmarkedItems) Then
			HasMarkedItems    = True;
			HasUnmarkedItems = True;
			Break;
		ElsIf ParentItem1.IsMetadataObject Then
			HasMarkedItems    = HasMarkedItems    Or    ParentItem1.Check;
			HasUnmarkedItems = HasUnmarkedItems Or Not ParentItem1.Check;
		Else
			NestedItems = ParentItem1.GetItems();
			If NestedItems.Count() = 0 Then
				Continue;
			EndIf;
			NestedItemMarkValue = ItemMarkValues(NestedItems);
			HasMarkedItems    = HasMarkedItems    Or    ParentItem1.Check Or    NestedItemMarkValue;
			HasUnmarkedItems = HasUnmarkedItems Or Not ParentItem1.Check Or Not NestedItemMarkValue;
		EndIf;
	EndDo;
	
	If HasMarkedItems Then
		If HasUnmarkedItems Then
			Return 2;
		Else
			If SubsystemsWithCIOnly Then
				Return 2;
			Else
				Return 1;
			EndIf;
		EndIf;
	Else
		Return 0;
	EndIf;
	
EndFunction

&AtServer
Procedure MarkParentItemsAtServer(Item)

	Parent = Item.GetParent();
	
	If Parent = Undefined Then
		Return;
	EndIf;
	
	ParentItems1 = Parent.GetItems();
	If ParentItems1.Count() = 0 Then
		Parent.Check = 0;
	ElsIf Item.Check = 2 Then
		Parent.Check = 2;
	Else
		Parent.Check = ItemMarkValuesAtServer(ParentItems1);
	EndIf;
	
	MarkParentItemsAtServer(Parent);

EndProcedure

&AtServer
Function ItemMarkValuesAtServer(ParentItems1)
	
	HasMarkedItems    = False;
	HasUnmarkedItems = False;
	
	For Each ParentItem1 In ParentItems1 Do
		
		If ParentItem1.Check = 2 Or (HasMarkedItems And HasUnmarkedItems) Then
			HasMarkedItems    = True;
			HasUnmarkedItems = True;
			Break;
		ElsIf ParentItem1.IsMetadataObject Then
			HasMarkedItems    = HasMarkedItems    Or    ParentItem1.Check;
			HasUnmarkedItems = HasUnmarkedItems Or Not ParentItem1.Check;
		Else
			NestedItems = ParentItem1.GetItems();
			If NestedItems.Count() = 0 Then
				Continue;
			EndIf;
			NestedItemMarkValue = ItemMarkValuesAtServer(NestedItems);
			HasMarkedItems    = HasMarkedItems    Or    ParentItem1.Check Or    NestedItemMarkValue;
			HasUnmarkedItems = HasUnmarkedItems Or Not ParentItem1.Check Or Not NestedItemMarkValue;
		EndIf;
	EndDo;
	
	Return ?(HasMarkedItems And HasUnmarkedItems, 2, ?(HasMarkedItems, 1, 0));
	
EndFunction

// Selects a mark of the metadata object
// collections that does not have metadata objects 
// or whose metadata object marks are selected.
//
// Parameters:
//   Element      - FormDataTreeItemCollection.
//
&AtServer
Procedure SetInitialCollectionMark(Parent)
	
	NestedItems = Parent.GetItems();
	
	For Each NestedItem In NestedItems Do
		If NestedItem.Check Then
			MarkParentItemsAtServer(NestedItem);
		EndIf;
		SetInitialCollectionMark(NestedItem);
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure SelectRefs(SelectedMetadataObjects)
	
	If SelectedMetadataObjects.Count() = 0 Then 
		Return;
	EndIf;
	
	MetadataObjectsDetails = SelectedMetadataObjects.UnloadValues();
	References = Common.MetadataObjectIDs(MetadataObjectsDetails, False);
	
	CurrentIndex = SelectedMetadataObjects.Count() - 1;
	While CurrentIndex >= 0 Do
		ListItem = SelectedMetadataObjects[CurrentIndex];
		Ref = References[ListItem.Value];
		If Ref <> Undefined Then 
			ListItem.Value = Ref;
		Else
			SelectedMetadataObjects.Delete(ListItem);
		EndIf;
		CurrentIndex = CurrentIndex - 1;
	EndDo;
	
EndProcedure

&AtServer
Procedure MetadataObjectsTreeFillBySections()
	
	MetadataObjectsTree.GetItems().Clear();
	
	Branch1 = MetadataObjectsTree.GetItems().Add();
	Branch1.Name = Metadata.Name;
	Branch1.Presentation = Metadata.Synonym;
	Branch1.Address = ".";
	
	OutputCollection(Branch1, Metadata.Subsystems);
	
EndProcedure

&AtServer
Procedure OutputCollection(Val Branch1, Val MetadataObjectCollection)
	
	For Each MetadataObject In MetadataObjectCollection Do
		If TypeOf(Branch1) = Type("FormDataTreeItem") And MetadataObject.FullName() = Branch1.FullName Then
			Continue;
		EndIf;
		If Not MetadataObjectAvailable(MetadataObject) Then
			Continue;
		EndIf;
		
		NewBranch = Branch1.GetItems().Add();
		NewBranch.Name = MetadataObject.Name;
		NewBranch.FullName = MetadataObject.FullName();
		NewBranch.Presentation = MetadataObject.Presentation();
		NewBranch.Picture = PictureInInterface(MetadataObject);
		NewBranch.Address = ?(TypeOf(Branch1) = Type("FormDataTreeItem"), Branch1.Address + "/", "") + NewBranch.Presentation;
		If ValueIsFilled(SelectedObjectsAddresses) Then
			NewBranch.Check = ?(SelectedObjectsAddresses.FindByValue(NewBranch.Address) = Undefined, 0, 1);
		Else
			NewBranch.Check = ?(SelectedMetadataObjects.FindByValue(NewBranch.FullName) = Undefined, 0, 1);
		EndIf;
		
		If IsSubsystem(MetadataObject) Then
			OutputCollection(NewBranch, MetadataObject.Content);
			OutputCollection(NewBranch, MetadataObject.Subsystems);
			NewBranch.IsSubsection = MetadataObjectCollection <> Metadata.Subsystems;
		Else
			NewBranch.IsMetadataObject = True;
			
			If Common.IsDocumentJournal(MetadataObject) Then
				OutputCollection(NewBranch, MetadataObject.RegisteredDocuments);
			ElsIf Common.IsCatalog(MetadataObject) Then 
				OutputCollection(NewBranch, SubordinateCatalogs(MetadataObject));
			EndIf;
		EndIf;
		
		If IsSubsystem(MetadataObject) And NewBranch.GetItems().Count() = 0 Then
			IndexOf = Branch1.GetItems().IndexOf(NewBranch);
			Branch1.GetItems().Delete(IndexOf);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Function PictureInInterface(MetadataObject)
	
	ObjectProperties = New Structure("Picture");
	FillPropertyValues(ObjectProperties, MetadataObject);
	If ValueIsFilled(ObjectProperties.Picture) Then
		Return ObjectProperties.Picture;
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtServer
Function PictureInDesigner(MetadataObject)
	
	ObjectKind = StrSplit(MetadataObject.FullName(), ".")[0];
	Images = New Structure(ObjectKind);
	FillPropertyValues(Images, PictureLib);
	
	Return Images[ObjectKind];
	
EndFunction

&AtServerNoContext
Function IsSubsystem(MetadataObject)
	Return StrStartsWith(MetadataObject.FullName(), "Subsystem");
EndFunction

&AtServer
Function MetadataObjectAvailable(MetadataObject)
	
	If Not IsSubsystem(MetadataObject) Then
		IsObjectToSelect = Not ValueIsFilled(MetadataObjectsToSelectCollection);
		For Each ObjectKind In MetadataObjectsToSelectCollection.UnloadValues() Do
			If Metadata[ObjectKind].Contains(MetadataObject) Then
				IsObjectToSelect = True;
				Break;
			EndIf;
		EndDo;
		
		If Not IsObjectToSelect Then
			Return False;
		EndIf;
	EndIf;
	
	If Not Common.IsCatalog(MetadataObject)
		And Not Common.IsDocument(MetadataObject)
		And Not Common.IsDocumentJournal(MetadataObject)
		And Not Common.IsChartOfCharacteristicTypes(MetadataObject)
		And Not Common.IsInformationRegister(MetadataObject)
		And Not Common.IsAccountingRegister(MetadataObject)
		And Not Common.IsAccumulationRegister(MetadataObject)
		And Not Common.IsCalculationRegister(MetadataObject)
		And Not Common.IsChartOfCharacteristicTypes(MetadataObject)
		And Not Common.IsChartOfAccounts(MetadataObject)
		And Not Common.IsChartOfCalculationTypes(MetadataObject)
		And Not Common.IsBusinessProcess(MetadataObject)
		And Not Common.IsTask(MetadataObject)
		And Not IsSubsystem(MetadataObject) Then
		Return False;
	EndIf;
	
	AvailableByRights = AccessRight("View", MetadataObject);
	AvailableByFunctionalOptions = Common.MetadataObjectAvailableByFunctionalOptions(MetadataObject);
	
	MetadataProperties = New Structure("FullTextSearch, IncludeInCommandInterface");
	FillPropertyValues(MetadataProperties, MetadataObject);
	
	If MetadataProperties.FullTextSearch = Undefined Then 
		FullTextSearchUsing = True; // Если свойства нет - 
	Else 
		FullTextSearchUsing = (MetadataProperties.FullTextSearch = 
			Metadata.ObjectProperties.FullTextSearchUsing.Use);
	EndIf;
	
	If MetadataProperties.IncludeInCommandInterface = Undefined Then 
		IncludeInCommandInterface = True; // Если свойства нет - 
	Else 
		IncludeInCommandInterface = MetadataProperties.IncludeInCommandInterface;
	EndIf;
	
	Return AvailableByRights And AvailableByFunctionalOptions 
		And FullTextSearchUsing And IncludeInCommandInterface;
	
EndFunction

&AtServer
Function SubordinateCatalogs(MetadataObject)
	
	If SubordinateCatalogs = Undefined Then
		SubordinateCatalogs = New Map;
		
		For Each Catalog In Metadata.Catalogs Do
			If SubordinateCatalogs[Catalog] = Undefined Then
				SubordinateCatalogs[Catalog] = New Array;
			EndIf;
			For Each OwnerOfTheDirectory In Catalog.Owners Do
				If SubordinateCatalogs[OwnerOfTheDirectory] = Undefined Then
					SubordinateCatalogs[OwnerOfTheDirectory] = New Array;
				EndIf;
				ListOfReferenceBooks = SubordinateCatalogs[OwnerOfTheDirectory]; // Array
				ListOfReferenceBooks.Add(Catalog);
			EndDo;
		EndDo;
	EndIf;
	
	Return SubordinateCatalogs[MetadataObject];
	
EndFunction

&AtClient
Procedure FillObjectsTree(OnOpen = False)
	
	ExpandableRowIds = New Array;
	PopulateObjectTreeOnServer(OnOpen, ExpandableRowIds);
	
	If OnOpen
	   And (ParentSubsystems.Count() > 0
	      Or MetadataObjectsToSelectCollection.Count() = 1) Then
		
		Items.MetadataObjectsTree.Expand(ExpandableRowIds[0], True);
		Return;
	EndIf;
	
	For Each RowID In ExpandableRowIds Do
		Items.MetadataObjectsTree.Expand(RowID);
	EndDo;
	
EndProcedure

&AtServer
Procedure PopulateObjectTreeOnServer(OnOpen, ExpandableRowIds)
	
	CurrentLineIDOnOpen = 0;
	RowIdoftheFirstSelectedObject = 0;
	
	If ObjectsGroupMethod = "BySections" Then
		MetadataObjectsTreeFillBySections();
	Else
		MetadataObjectTreeFill();
	EndIf;
	
	SetInitialCollectionMark(MetadataObjectsTree);
	
	If MetadataObjectsTree.GetItems().Count() < 1 Then
		Return;
	EndIf;
	
	If ValueIsFilled(RowIdoftheFirstSelectedObject) Then
		String = MetadataObjectsTree.FindByID(RowIdoftheFirstSelectedObject);
		While String <> Undefined Do
			ExpandableRowIds.Insert(0, String.GetID());
			String = String.GetParent();
		EndDo;
	Else
		RootId = MetadataObjectsTree.GetItems()[0].GetID();
		ExpandableRowIds.Add(RootId);
	EndIf;
	
	// Settings the initial selection value.
	If (OnOpen Or Not FlagDone)
	   And CurrentLineIDOnOpen > 0 Then
		
		Items.MetadataObjectsTree.CurrentRow = CurrentLineIDOnOpen;
		
	ElsIf ValueIsFilled(RowIdoftheFirstSelectedObject) Then
		
		Items.MetadataObjectsTree.CurrentRow = RowIdoftheFirstSelectedObject;
	EndIf;
	
EndProcedure

#Region ItemsMark

// Parameters:
//  TreeItem - FormDataTreeItem:
//      * Check             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Procedure OnMarkTreeItem(TreeItem)
	
	TreeItem.Check = NextItemCheckMarkValue(TreeItem);
	
	If RequiredToMarkNestedItems(TreeItem) Then 
		MarkNestedItemsRecursively(TreeItem);
	EndIf;
	
	If TreeItem.Check = MarkCheckBoxIsNotSelected() Then 
		TreeItem.Check = CheckMarkValueRelativeToNestedItems(TreeItem);
	EndIf;
	
	MarkParentsItemsRecursively(TreeItem);
	
EndProcedure

&AtClientAtServerNoContext
Function MarkCheckBoxIsNotSelected()
	
	Return 0;
	
EndFunction

&AtClientAtServerNoContext
Function MarkCheckBoxIsSelected()
	
	Return 1;
	
EndFunction

&AtClientAtServerNoContext
Function MarkSquare()
	
	Return 2;
	
EndFunction

// Parameters:
//  TreeItem - FormDataTreeItem:
//      * Check             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Function NextItemCheckMarkValue(TreeItem)
	
	// 
	// 
	// 
	//
	// 
	//
	// 
	// 
	// 
	//
	//    
	//   
	//  
	//
	// 
	//
	// 
	// 
	//
	// 
	//
	// 
	//
	// 
	// 
	// 
	//
	//      
	// 
	//
	// 
	//
	// 
	// 
	// 
	//
	//      
	// 
	//
	// 
	
	// At the time of checking, the platform has already changed the check box value.
	
	If TreeItem.IsMetadataObject Then
		// Previous check box value = 2: Square is selected.
		If TreeItem.Check = 0 Then
			Return MarkCheckBoxIsSelected();
		EndIf;
	EndIf;
	
	// Previous check box value = 1: Check box is selected.
	If TreeItem.Check = 2 Then 
		Return MarkCheckBoxIsNotSelected();
	EndIf;
	
	// Во всех остальных случаях - 
	Return TreeItem.Check;
	
EndFunction

// Parameters:
//  TreeItem - FormDataTreeItem:
//      * Check             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Procedure MarkParentsItemsRecursively(TreeItem)
	
	Parent = TreeItem.GetParent();
	
	If Parent = Undefined Then
		Return;
	EndIf;
	
	ParentItems1 = Parent.GetItems();
	If ParentItems1.Count() = 0 Then
		Parent.Check = MarkCheckBoxIsSelected();
	ElsIf TreeItem.Check = MarkSquare() Then
		Parent.Check = MarkSquare();
	Else
		Parent.Check = CheckMarkValueRelativeToNestedItems(Parent);
	EndIf;
	
	MarkParentsItemsRecursively(Parent);
	
EndProcedure

// Parameters:
//  TreeItem - FormDataTreeItem:
//      * Check             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Function CheckMarkValueRelativeToNestedItems(TreeItem)
	
	NestedItemsState = NestedItemsState(TreeItem);
	
	HasMarkedItems   = NestedItemsState.HasMarkedItems;
	HasUnmarkedItems = NestedItemsState.HasUnmarkedItems;
	
	If TreeItem.IsMetadataObject Then 
		
		// 
		// 
		// 
		
		If TreeItem.Check = MarkCheckBoxIsSelected() Then 
			// 
			Return MarkCheckBoxIsSelected();
		EndIf;
		
		If TreeItem.Check = MarkCheckBoxIsNotSelected()
			Or TreeItem.Check = MarkSquare() Then 
			
			If HasMarkedItems Then
				Return MarkSquare();
			Else 
				Return MarkCheckBoxIsNotSelected();
			EndIf;
		EndIf;
		
	Else 
		
		//  
		// 
		
		If HasMarkedItems Then
			
			If HasUnmarkedItems Then
				Return MarkSquare();
			Else
				Return MarkCheckBoxIsSelected();
			EndIf;
			
		EndIf;
		
		Return MarkCheckBoxIsNotSelected();
		
	EndIf;
	
EndFunction

// Parameters:
//  TreeItem - FormDataTreeItem:
//      * Check             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Function NestedItemsState(TreeItem)
	
	NestedItems = TreeItem.GetItems();
	
	HasMarkedItems   = False;
	HasUnmarkedItems = False;
	
	For Each NestedItem In NestedItems Do
		
		If NestedItem.Check = MarkCheckBoxIsNotSelected() Then 
			HasUnmarkedItems = True;
			Continue;
		EndIf;
		
		If NestedItem.Check = MarkCheckBoxIsSelected() Then 
			HasMarkedItems = True;
			
			If NestedItem.IsMetadataObject Then 
				
				// 
				// 
				// 
				
				State = NestedItemsState(NestedItem);
				HasMarkedItems   = HasMarkedItems   Or State.HasMarkedItems;
				HasUnmarkedItems = HasUnmarkedItems Or State.HasUnmarkedItems;
			EndIf;
			
			Continue;
		EndIf;
		
		If NestedItem.Check = MarkSquare() Then 
			HasMarkedItems   = True;
			HasUnmarkedItems = True;
			Continue;
		EndIf;
		
	EndDo;
	
	Result = New Structure;
	Result.Insert("HasMarkedItems",   HasMarkedItems);
	Result.Insert("HasUnmarkedItems", HasUnmarkedItems);
	
	Return Result;
	
EndFunction

// Parameters:
//  TreeItem - FormDataTreeItem:
//      * Check             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Function RequiredToMarkNestedItems(TreeItem)
	
	If TreeItem.IsMetadataObject Then 
		
		// 
		// 
		
		NestedItemsState = NestedItemsState(TreeItem);
		
		HasMarkedItems   = NestedItemsState.HasMarkedItems;
		HasUnmarkedItems = NestedItemsState.HasUnmarkedItems;
		
		If HasMarkedItems And HasUnmarkedItems Then 
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

// Parameters:
//  TreeItem - FormDataTreeItem:
//      * Check             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Procedure MarkNestedItemsRecursively(TreeItem)
	
	NestedItems = TreeItem.GetItems();
	
	For Each NestedItem In NestedItems Do
		
		NestedItem.Check = TreeItem.Check;
		MarkNestedItemsRecursively(NestedItem);
		
	EndDo;
	
EndProcedure

// Parameters:
//  ItemSearchSectionsTree - FormDataTreeItem:
//      * Check             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//  CheckMarkValue - Number - a value being set.
//
&AtClientAtServerNoContext
Procedure MarkAllTreeItemsRecursively(ItemSearchSectionsTree, CheckMarkValue)
	
	TreeItemsCollection = ItemSearchSectionsTree.GetItems();
	
	For Each TreeItem In TreeItemsCollection Do
		TreeItem.Check = CheckMarkValue;
		MarkAllTreeItemsRecursively(TreeItem, CheckMarkValue);
	EndDo;
	
EndProcedure

#EndRegion

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("MetadataObjectsTree");
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue  = New DataCompositionField("MetadataObjectsTree.IsSubsection");
	ItemFilter.ComparisonType   = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.FunctionsPanelSectionColor);
	
EndProcedure

&AtClient
Function SelectedItems(Branch1)
	
	Result = New Map;
	
	For Each Item In Branch1.GetItems() Do
		If ObjectsGroupMethod = "ByKinds"
		   And SelectCollectionsWhenAllObjectsSelected
		   And Item.Check = 1
		   And (Item.ThisCollectionObjects
		      Or Branch1 = MetadataObjectsTree) Then
			
			If Item.ThisCollectionObjects Then
				Result.Insert(Item.Name, Item.Presentation);
			Else
				Result.Insert("Configuration", NStr("en = 'Configuration';"));
			EndIf;
			Continue;
		EndIf;
		If Item.Check = 1 And Not IsBlankString(Item.FullName) And Item.IsMetadataObject Then
			Result.Insert(Item.FullName, ?(RememberSelectedObjectsSections
				And ObjectsGroupMethod = "BySections", Item.Address, Item.Presentation));
		EndIf;
		For Each SelectedElement In SelectedItems(Item) Do
			Result.Insert(SelectedElement.Key, SelectedElement.Value);
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure UpdateSelectedMetadataObjectsCollection()
	
	SelectedMetadataObjects.Clear();
	For Each SelectedElement In SelectedItems(MetadataObjectsTree) Do
		SelectedMetadataObjects.Add(SelectedElement.Key, SelectedElement.Value, True);
	EndDo;
	
EndProcedure

#EndRegion
