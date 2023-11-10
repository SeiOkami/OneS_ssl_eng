///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

Function ConfigurationDataModelDetails() Export
	
	Model = New Map();
	
	FillModelBySubsystems(Model);
	FillModelByMetadataCollection(Model, "SessionParameters");
	FillModelByMetadataCollection(Model, "CommonAttributes");
	FillModelByMetadataCollection(Model, "ExchangePlans");
	FillModelByMetadataCollection(Model, "ScheduledJobs");
	FillModelByMetadataCollection(Model, "Constants");
	FillModelByMetadataCollection(Model, "Catalogs");
	FillModelByMetadataCollection(Model, "Documents");
	FillModelByMetadataCollection(Model, "Sequences");
	FillModelByMetadataCollection(Model, "DocumentJournals");
	FillModelByMetadataCollection(Model, "Enums");
	FillModelByMetadataCollection(Model, "ChartsOfCharacteristicTypes");
	FillModelByMetadataCollection(Model, "ChartsOfAccounts");
	FillModelByMetadataCollection(Model, "ChartsOfCalculationTypes");
	FillModelByMetadataCollection(Model, "InformationRegisters");
	FillModelByMetadataCollection(Model, "AccumulationRegisters");
	FillModelByMetadataCollection(Model, "AccountingRegisters");
	FillModelByMetadataCollection(Model, "CalculationRegisters");
	FillModelByRecalculations(Model);
	FillModelByMetadataCollection(Model, "BusinessProcesses");
	FillModelByMetadataCollection(Model, "Tasks");
	FillModelByMetadataCollection(Model, "ExternalDataSources");
	FillModelByFunctionalOptions(Model);
	FillModelBySeparators(Model);
	
	Return FixModel(Model);
	
EndFunction

Function MetadataClassesInConfigurationModel() Export
	
	CurrentMetadataClasses = New Structure();
	CurrentMetadataClasses.Insert("Subsystems", 1);
	CurrentMetadataClasses.Insert("SessionParameters", 2);
	CurrentMetadataClasses.Insert("CommonAttributes", 3);
	CurrentMetadataClasses.Insert("Constants", 4);
	CurrentMetadataClasses.Insert("Catalogs", 5);
	CurrentMetadataClasses.Insert("Documents", 6);
	CurrentMetadataClasses.Insert("Enums", 7);
	CurrentMetadataClasses.Insert("ChartsOfCharacteristicTypes", 8);
	CurrentMetadataClasses.Insert("ChartsOfAccounts", 9);
	CurrentMetadataClasses.Insert("ChartsOfCalculationTypes", 10);
	CurrentMetadataClasses.Insert("BusinessProcesses", 11);
	CurrentMetadataClasses.Insert("Tasks", 12);
	CurrentMetadataClasses.Insert("ExchangePlans", 13);
	CurrentMetadataClasses.Insert("DocumentJournals", 14);
	CurrentMetadataClasses.Insert("Sequences", 15);
	CurrentMetadataClasses.Insert("InformationRegisters", 16);
	CurrentMetadataClasses.Insert("AccumulationRegisters", 17);
	CurrentMetadataClasses.Insert("AccountingRegisters", 18);
	CurrentMetadataClasses.Insert("CalculationRegisters", 19);
	CurrentMetadataClasses.Insert("Recalculations", 20);
	CurrentMetadataClasses.Insert("ScheduledJobs", 21);
	CurrentMetadataClasses.Insert("ExternalDataSources", 22);
	
	Return New FixedStructure(CurrentMetadataClasses);
	
EndFunction

Function MetadataClasses()
	
	Return MetadataClassesInConfigurationModel();
	
EndFunction

Function DataModelsGroup(Val Model, Val Class)
	
	Group = Model.Get(Class);
	
	If Group = Undefined Then
		Group = New Map();
		Model.Insert(Class, Group);
	EndIf;
	
	Return Group;
	
EndFunction

Procedure FillModelBySubsystems(Val Model)
	
	SubsystemsGroup = DataModelsGroup(Model, MetadataClasses().Subsystems);
	
	For Each Subsystem In Metadata.Subsystems Do
		FillModelBySubsystem(SubsystemsGroup, Subsystem);
	EndDo;
	
EndProcedure

Procedure FillModelBySubsystem(Val ModelGroup, Val Subsystem)
	
	FillModelByMetadataObject(ModelGroup, Subsystem, MetadataClasses().Subsystems);
	
	For Each NestedSubsystem In Subsystem.Subsystems Do
		FillModelBySubsystem(ModelGroup, NestedSubsystem);
	EndDo;
	
EndProcedure

Procedure FillModelByRecalculations(Val Model)
	
	ModelGroup = DataModelsGroup(Model, MetadataClasses().Recalculations);
	
	For Each CalculationRegister In Metadata.CalculationRegisters Do
		
		For Each Recalculation In CalculationRegister.Recalculations Do
			
			FillModelByMetadataObject(ModelGroup, Recalculation, MetadataClasses().Recalculations);
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure FillModelByMetadataCollection(Val Model, Val CollectionName)
	
	Class = MetadataClasses()[CollectionName];
	ModelGroup = DataModelsGroup(Model, Class);
	
	MetadataCollection = Metadata[CollectionName];
	For Each MetadataObject In MetadataCollection Do
		FillModelByMetadataObject(ModelGroup, MetadataObject, Class);
	EndDo;
	
EndProcedure

Procedure FillModelByMetadataObject(Val ModelGroup, Val MetadataObject, Val Class)
	
	ObjectDetails = New Structure();
	ObjectDetails.Insert("FullName", MetadataObject.FullName());
	ObjectDetails.Insert("Presentation", MetadataObject.Presentation());
	ObjectDetails.Insert("Dependencies", New Map());
	ObjectDetails.Insert("FunctionalOptions", New Array());
	ObjectDetails.Insert("DataSeparation", New Structure());
	
	ModelGroup.Insert(MetadataObject.Name, ObjectDetails);
	
	FillModelByMetadataObjectDependencies(ObjectDetails.Dependencies, MetadataObject, Class);
	
EndProcedure

Procedure FillModelByMetadataObjectDependencies(Val ObjectDependencies, Val MetadataObject, Val Class)
	
	If Class = MetadataClasses().Constants Then
		
		FillModelByMetadataObjectDependenciesTypes(ObjectDependencies, MetadataObject.Type);
		
	ElsIf (Class = MetadataClasses().Catalogs
			Or Class = MetadataClasses().Documents
			Or Class = MetadataClasses().ChartsOfCharacteristicTypes
			Or Class = MetadataClasses().ChartsOfAccounts
			Or Class = MetadataClasses().ChartsOfCalculationTypes
			Or Class = MetadataClasses().BusinessProcesses
			Or Class = MetadataClasses().Tasks
			Or Class = MetadataClasses().ExchangePlans) Then
		
		// Standard attributes.
		For Each StandardAttribute In MetadataObject.StandardAttributes Do
			FillModelByMetadataObjectDependenciesTypes(ObjectDependencies, StandardAttribute.Type);
		EndDo;
		
		// Standard tables.
		If (Class = MetadataClasses().ChartsOfAccounts Or Class = MetadataClasses().ChartsOfCalculationTypes) Then
			
			For Each StandardTabularSection In MetadataObject.StandardTabularSections Do
				For Each StandardAttribute In StandardTabularSection.StandardAttributes Do
					FillModelByMetadataObjectDependenciesTypes(ObjectDependencies, StandardAttribute.Type);
				EndDo;
			EndDo;
			
		EndIf;
		
		// Attributes.
		For Each Attribute In MetadataObject.Attributes Do
			FillModelByMetadataObjectDependenciesTypes(ObjectDependencies, Attribute.Type);
		EndDo;
		
		// Tables.
		For Each TabularSection In MetadataObject.TabularSections Do
			// 
			For Each StandardAttribute In TabularSection.StandardAttributes Do
				FillModelByMetadataObjectDependenciesTypes(ObjectDependencies, StandardAttribute.Type);
			EndDo;
			// Реквизиты
			For Each Attribute In TabularSection.Attributes Do
				FillModelByMetadataObjectDependenciesTypes(ObjectDependencies, Attribute.Type);
			EndDo;
		EndDo;
		
		If Class = MetadataClasses().Tasks Then
			
			// Addressing attributes.
			For Each AddressingAttribute In MetadataObject.AddressingAttributes Do
				FillModelByMetadataObjectDependenciesTypes(ObjectDependencies, AddressingAttribute.Type);
			EndDo;
			
		EndIf;
		
		If Class = MetadataClasses().Documents Then
			
			// Register records.
			For Each Register In MetadataObject.RegisterRecords Do
				ObjectDependencies.Insert(Register.FullName(), True);
			EndDo;
			
		EndIf;
		
		If Class = MetadataClasses().ChartsOfCharacteristicTypes Then
			
			// Characteristic types.
			FillModelByMetadataObjectDependenciesTypes(ObjectDependencies, MetadataObject.Type);
			
			// Additional characteristic values.
			If MetadataObject.CharacteristicExtValues <> Undefined Then
				ObjectDependencies.Insert(MetadataObject.CharacteristicExtValues.FullName(), True);
			EndIf;
			
		EndIf;
		
		If Class = MetadataClasses().ChartsOfAccounts Then
			
			// Accounting flags.
			For Each AccountingFlag In MetadataObject.AccountingFlags Do
				FillModelByMetadataObjectDependenciesTypes(ObjectDependencies, AccountingFlag.Type);
			EndDo;
			
			// Extra dimension types.
			If MetadataObject.ExtDimensionTypes <> Undefined Then
				ObjectDependencies.Insert(MetadataObject.ExtDimensionTypes.FullName(), True);
			EndIf;
			
			// Extra dimension accounting flags.
			For Each ExtDimensionAccountingFlag In MetadataObject.ExtDimensionAccountingFlags Do
				FillModelByMetadataObjectDependenciesTypes(ObjectDependencies, ExtDimensionAccountingFlag.Type);
			EndDo;
			
		EndIf;
		
		If Class = MetadataClasses().ChartsOfCalculationTypes Then
			
			// Baseline calculation types.
			For Each BaseCalculationType In MetadataObject.BaseCalculationTypes Do
				ObjectDependencies.Insert(BaseCalculationType.FullName(), True);
			EndDo;
			
		EndIf;
		
	ElsIf Class = MetadataClasses().Sequences Then
		
		// Dimensions.
		For Each Dimension In MetadataObject.Dimensions Do
			FillModelByMetadataObjectDependenciesTypes(ObjectDependencies, Dimension.Type);
		EndDo;
		
		// Incoming documents.
		For Each IncomingDocument In MetadataObject.Documents Do
			ObjectDependencies.Insert(IncomingDocument.FullName(), True);
		EndDo;
		
		// Register records.
		For Each Register In MetadataObject.RegisterRecords Do
			ObjectDependencies.Insert(Register.FullName(), True);
		EndDo;
		
	ElsIf (Class = MetadataClasses().InformationRegisters
			Or Class = MetadataClasses().AccumulationRegisters
			Or Class = MetadataClasses().AccountingRegisters
			Or Class = MetadataClasses().CalculationRegisters) Then
		
		// Standard attributes.
		For Each StandardAttribute In MetadataObject.StandardAttributes Do
			FillModelByMetadataObjectDependenciesTypes(ObjectDependencies, StandardAttribute.Type);
		EndDo;
		
		// Dimensions.
		For Each Dimension In MetadataObject.Dimensions Do
			FillModelByMetadataObjectDependenciesTypes(ObjectDependencies, Dimension.Type);
		EndDo;
		
		// Resources.
		For Each Resource In MetadataObject.Resources Do
			FillModelByMetadataObjectDependenciesTypes(ObjectDependencies, Resource.Type);
		EndDo;
		
		// Attributes.
		For Each Attribute In MetadataObject.Attributes Do
			FillModelByMetadataObjectDependenciesTypes(ObjectDependencies, Attribute.Type);
		EndDo;
		
		If Class = MetadataClasses().AccountingRegisters Then
			
			// Chart of accounts.
			If MetadataObject.ChartOfAccounts <> Undefined Then
				ObjectDependencies.Insert(MetadataObject.ChartOfAccounts.FullName(), True);
			EndIf;
			
		EndIf;
		
		If Class = MetadataClasses().CalculationRegisters Then
			
			// Chart of calculation types.
			If MetadataObject.ChartOfCalculationTypes <> Undefined Then
				ObjectDependencies.Insert(MetadataObject.ChartOfCalculationTypes.FullName(), True);
			EndIf;
			
			// Timetable.
			If MetadataObject.Schedule <> Undefined Then
				ObjectDependencies.Insert(MetadataObject.Schedule.FullName(), True);
			EndIf;
			
		EndIf;
		
	ElsIf Class = MetadataClasses().DocumentJournals Then
		
		For Each Document In MetadataObject.RegisteredDocuments Do
			ObjectDependencies.Insert(Document.FullName(), True);
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillModelByMetadataObjectDependenciesTypes(Val Result, Val TypeDescription)
	
	If ODataInterfaceInternal.IsRefsTypesSet(TypeDescription) Then
		Return;
	EndIf;
	
	For Each Type In TypeDescription.Types() Do
		
		If ODataInterfaceInternal.IsReferenceType(Type) Then
			
			Dependence = ODataInterfaceInternal.MetadataObjectByRefType(Type);
			
			If Result.Get(Dependence.FullName()) = Undefined Then
				
				Result.Insert(Dependence.FullName(), True);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure FillModelByFunctionalOptions(Val Model)
	
	For Each FunctionalOption In Metadata.FunctionalOptions Do
		
		For Each CompositionItem In FunctionalOption.Content Do
			
			If CompositionItem.Object = Undefined Then
				Continue;
			EndIf;
			
			ObjectDetails = ODataInterfaceInternal.ConfigurationModelObjectProperties(Model, CompositionItem.Object);
			
			If ObjectDetails <> Undefined Then
				FunctionalObjectOptions = ObjectDetails.FunctionalOptions; // Array
				FunctionalObjectOptions.Add(FunctionalOption.Name);
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure FillModelBySeparators(Val Model)
	
	// Filling by the common attribute content
	
	For Each CommonAttribute In Metadata.CommonAttributes Do
		
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
			
			UseCommonAttribute = Metadata.ObjectProperties.CommonAttributeUse.Use;
				AutoUseCommonAttribute = Metadata.ObjectProperties.CommonAttributeUse.Auto;
				CommonAttributeAutoUse = 
					(CommonAttribute.AutoUse = Metadata.ObjectProperties.CommonAttributeAutoUse.Use);
			
			For Each CompositionItem In CommonAttribute.Content Do
				
				If (CommonAttributeAutoUse And CompositionItem.Use = AutoUseCommonAttribute)
						Or CompositionItem.Use = UseCommonAttribute Then
					
					ObjectDetails = ODataInterfaceInternal.ConfigurationModelObjectProperties(Model, CompositionItem.Metadata);
					
					If CompositionItem.ConditionalSeparation <> Undefined Then
						ConditionalSeparationItem = CompositionItem.ConditionalSeparation.FullName();
					Else
						ConditionalSeparationItem = "";
					EndIf;
					
					ObjectDetails.DataSeparation.Insert(CommonAttribute.Name, ConditionalSeparationItem);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	// Make an assumption that sequences that contain separated documents are separated sequences.
	
	For Each Sequence In Metadata.Sequences Do
		
		If Sequence.Documents.Count() > 0 Then
			
			SequenceDetails = ODataInterfaceInternal.ConfigurationModelObjectProperties(Model, Sequence);
			
			For Each Document In Sequence.Documents Do
				
				DocumentDetails = ODataInterfaceInternal.ConfigurationModelObjectProperties(Model, Document);
				
				For Each KeyAndValue In DocumentDetails.DataSeparation Do
					
					SequenceDetails.DataSeparation.Insert(KeyAndValue.Key, KeyAndValue.Value);
					
				EndDo;
				
				Break;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	// Make an assumption that document journals that contain separated documents are separated document journals.
	
	For Each DocumentJournal In Metadata.DocumentJournals Do
		
		If DocumentJournal.RegisteredDocuments.Count() > 0 Then
			
			JournalDetails = ODataInterfaceInternal.ConfigurationModelObjectProperties(Model, DocumentJournal);
			
			For Each Document In DocumentJournal.RegisteredDocuments Do
				
				DocumentDetails = ODataInterfaceInternal.ConfigurationModelObjectProperties(Model, Document);
				
				For Each KeyAndValue In DocumentDetails.DataSeparation Do
					
					JournalDetails.DataSeparation.Insert(KeyAndValue.Key, KeyAndValue.Value);
					
				EndDo;
				
				Break;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	// Make an assumption that recalculations that are subordinate to separated calculation registers are separated recalculations.
	
	For Each CalculationRegister In Metadata.CalculationRegisters Do
		
		If CalculationRegister.Recalculations.Count() > 0 Then
			
			CalculationRegisterDetails = ODataInterfaceInternal.ConfigurationModelObjectProperties(Model, CalculationRegister);
			
			For Each Recalculation In CalculationRegister.Recalculations Do
				
				RecalculationDetails = ODataInterfaceInternal.ConfigurationModelObjectProperties(Model, Recalculation);
				
				For Each KeyAndValue In CalculationRegisterDetails.DataSeparation Do
					
					RecalculationDetails.DataSeparation.Insert(KeyAndValue.Key, KeyAndValue.Value);
					
				EndDo;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function FixModel(Val Model)
	
	If TypeOf(Model) = Type("Array") Then
		
		Result = New Array();
		For Each Item In Model Do
			Result.Add(FixModel(Item));
		EndDo;
		Return New FixedArray(Result);
		
	ElsIf TypeOf(Model) = Type("Structure") Then
		
		Result = New Structure();
		For Each KeyAndValue In Model Do
			Result.Insert(KeyAndValue.Key, FixModel(KeyAndValue.Value));
		EndDo;
		Return New FixedStructure(Result);
		
	ElsIf  TypeOf(Model) = Type("Map") Then
		
		Result = New Map();
		For Each KeyAndValue In Model Do
			Result.Insert(KeyAndValue.Key, FixModel(KeyAndValue.Value));
		EndDo;
		Return New FixedMap(Result);
		
	Else
		
		Return Model;
		
	EndIf;
	
EndFunction

#EndRegion
