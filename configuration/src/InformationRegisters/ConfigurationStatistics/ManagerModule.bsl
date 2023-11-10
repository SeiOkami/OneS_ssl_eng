///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

Function GetStatistics(StatisticsKind, NameTable = Undefined, StatisticsAreaID = Undefined) Export
	Query = New Query;
	
	If NameTable = Undefined Then
		Query.Text = "
		|SELECT
		|	StatisticsOperations.Description AS StatisticsOperation,
		|	ConfigurationStatistics.Value AS Value
		|FROM
		|	InformationRegister.ConfigurationStatistics AS ConfigurationStatistics
		|INNER JOIN
		|	InformationRegister.StatisticsOperations AS StatisticsOperations
		|ON
		|	ConfigurationStatistics.StatisticsOperation = StatisticsOperations.OperationID
		|WHERE
		|	ConfigurationStatistics.StatisticsKind = &StatisticsKind
		|";
		Query.SetParameter("StatisticsKind", StatisticsKind);
		QueryResult = Query.Execute();
	Else
		Query.Text = "
		|SELECT
		|	NameTable.StatisticsOperationDescription AS StatisticsOperationDescription,
		|	NameTable.RowIndex AS RowIndex
		|INTO
		|	NameTable
		|FROM
		|	&NameTable AS NameTable
		|INDEX BY
		|	StatisticsOperationDescription	
		|;
		|SELECT
		|	NameTable.RowIndex AS StatisticsOperationIndex,
		|	ConfigurationStatistics.Value AS Value
		|FROM
		|	InformationRegister.ConfigurationStatistics AS ConfigurationStatistics
		|INNER JOIN
		|	InformationRegister.StatisticsOperations AS StatisticsOperations
		|ON
		|	ConfigurationStatistics.StatisticsOperation = StatisticsOperations.OperationID
		|INNER JOIN
		|	NameTable
		|ON
		|	NameTable.StatisticsOperationDescription = StatisticsOperations.Description
		|WHERE
		|	ConfigurationStatistics.StatisticsKind = &StatisticsKind
		|	AND ConfigurationStatistics.StatisticsAreaID = &StatisticsAreaID
		|ORDER BY
		|	NameTable.RowIndex
		|";
		Query.SetParameter("StatisticsKind", StatisticsKind);
		Query.SetParameter("StatisticsAreaID", StatisticsAreaID);
		Query.SetParameter("NameTable", NameTable);
		QueryResult = Query.Execute();
	EndIf;
	
	Return QueryResult;
EndFunction

Function GetStatisticsNames(StatisticsKind) Export
	ZeroArea = InformationRegisters.StatisticsAreas.GetRef("0");
	
	Query = New Query;
	Query.Text = "
	|SELECT DISTINCT
	|	ConfigurationStatistics.StatisticsOperation AS StatisticsOperationRef,
	|	StatisticsOperations.Description AS StatisticsOperationDescription
	|FROM
	|	InformationRegister.ConfigurationStatistics AS ConfigurationStatistics
	|INNER JOIN
	|	InformationRegister.StatisticsOperations AS StatisticsOperations
	|ON
	|	ConfigurationStatistics.StatisticsOperation = StatisticsOperations.OperationID
	|WHERE
	|	ConfigurationStatistics.StatisticsKind = &StatisticsKind
	|ORDER BY
	|	StatisticsOperations.Description
	|";
	Query.SetParameter("StatisticsKind", StatisticsKind);
	Query.SetParameter("ZeroArea", ZeroArea);
	QueryResult = Query.Execute();
	
	Return QueryResult;
EndFunction

Procedure WriteConfigurationStatistics(Val MetadataNamesMap = Undefined) Export
	ConfigurationStatistics = NewConfigurationStatistics(MetadataNamesMap);
	Write(ConfigurationStatistics.NotSeparated, InformationRegisters.StatisticsAreas.GetRef("0", True));
	
	If ConfigurationStatistics.Separated <> Undefined Then
		WriteSeparated(ConfigurationStatistics.Separated);
	EndIf;
EndProcedure

Function NewConfigurationStatistics(MetadataNamesMap = Undefined)
	MetadataNamesMapResult = New Map;
		
	SeparationByDataAreasEnabled = MonitoringCenterInternal.SeparationByDataAreasEnabled();
	
	If MetadataNamesMap <> Undefined Then
		For Each NameOfMetadataObjects In MetadataNamesMap Do
			MetadataNamesMapResult.Insert(NameOfMetadataObjects.Key, NameOfMetadataObjects.Value);
		EndDo;
	EndIf;
	
	Tables = FillMetadataStorageAttributes();
	
	MetadataNamesMapByAreas = SeparateConfigurationByAreas(Tables, MetadataNamesMap, MetadataNamesMapResult, SeparationByDataAreasEnabled);
	
	Return MetadataNamesMapByAreas;
EndFunction

Function FillMetadataStorageAttributes()
	
	ValueTable = New ValueTable;
	ValueTable.Columns.Add("TableName", New TypeDescription("String"));
	ValueTable.Columns.Add("Purpose", New TypeDescription("String"));
	ValueTable.Columns.Add("MetadataObject");
	
	MetadataObjects = New Map;
	MetadataObjects.Insert("Catalogs", "Catalog");
	MetadataObjects.Insert("Documents", "Document");
	MetadataObjects.Insert("DocumentJournals", "DocumentJournal");
	MetadataObjects.Insert("ChartsOfAccounts", "ChartOfAccounts");
	MetadataObjects.Insert("ChartsOfCalculationTypes", "ChartOfCalculationTypes");
	MetadataObjects.Insert("InformationRegisters", "InformationRegister");
	MetadataObjects.Insert("AccumulationRegisters", "AccumulationRegister");
	MetadataObjects.Insert("AccountingRegisters", "AccountingRegister");
	MetadataObjects.Insert("CalculationRegisters", "CalculationRegister");
	MetadataObjects.Insert("BusinessProcesses", "BusinessProcess");
	MetadataObjects.Insert("Tasks", "Task");
	
	FillMetadataObjectStructure(ValueTable, MetadataObjects);
		
	Return ValueTable;
	
EndFunction

Procedure FillMetadataObjectStructure(ValueTable, MetadataObjects)
	
	NoTabularSections = New Map;
	NoTabularSections.Insert("DocumentJournals", True);
	NoTabularSections.Insert("InformationRegisters", True);
	NoTabularSections.Insert("AccumulationRegisters", True);
	NoTabularSections.Insert("AccountingRegisters", True);
	NoTabularSections.Insert("CalculationRegisters", True);
	
	For Each CurObject In MetadataObjects Do
		For Each CurMetadataObject In Metadata[CurObject.Key] Do
			FullTableName = New Array;
			FullTableName.Add(CurObject.Value);
			FullTableName.Add(CurMetadataObject.Name);
			
			NewString = ValueTable.Add();
			NewString.TableName = StrConcat(FullTableName, ".");
			NewString.Purpose = "Main";
			NewString.MetadataObject = CurMetadataObject;
			
			If NoTabularSections[CurObject.Key] = Undefined Then
				For Each CurTabularSection In CurMetadataObject.TabularSections Do // MetadataObjectTabularSection
					FullTableName.Add(CurTabularSection.Name);
					
					NewString = ValueTable.Add();
					NewString.TableName = StrConcat(FullTableName, ".");
					NewString.Purpose = "TabularSection";
					NewString.MetadataObject = CurTabularSection;
					
					FullTableName.Delete(FullTableName.UBound());
				EndDo;
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

Function SeparateConfigurationByAreas(Tables, MetadataNamesMap, MetadataNamesMapResult, SeparationByDataAreasEnabled)
	If SeparationByDataAreasEnabled Then
		MetadataNamesMapByAreas = New Structure("NotSeparated, Separated", New Map, New Map);
	Else
		MetadataNamesMapByAreas = New Structure("NotSeparated, Separated", New Map, Undefined);
	EndIf;
		
	CoreSaaSAvailable = Common.SubsystemExists("CloudTechnology.Core");
	If CoreSaaSAvailable Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		DataAreaMainDataContent = ModuleSaaSOperations.CommonAttributeContent(ModuleSaaSOperations.MainDataSeparator());
	EndIf;
	
	For Each CurRow In Tables Do
		If MetadataNamesMap <> Undefined Then
			If MetadataNamesMap[CurRow.Metadata] = Undefined Then
				Continue;
			EndIf;
		EndIf;
		
		If MetadataNamesMapResult[CurRow.TableName] = Undefined Then
			QueryText = DefaultQuery(CurRow.TableName);
		Else
			QueryText = MetadataNamesMapResult[CurRow.TableName]["Query"];
		EndIf;
		
		If CurRow.Purpose = "Main" Then
			If SeparationByDataAreasEnabled Then
				CommonAttributeContentItem = DataAreaMainDataContent.Find(CurRow.MetadataObject);
			EndIf;
		EndIf;
		
		If MetadataNamesMapResult[CurRow.TableName] = Undefined Then
			QueryText = DefaultQuery(CurRow.TableName);
		Else
			QueryText = MetadataNamesMapResult[CurRow.TableName]["Query"];
		EndIf;
		
		If SeparationByDataAreasEnabled Then
			If CommonAttributeContentItem <> Undefined Then
				If CommonAttributeContentItem.Use = Metadata.ObjectProperties.CommonAttributeUse.DontUse Then
					IsSeparation = False;
				Else
					IsSeparation = True;
				EndIf;
			Else
				MetadataArray1 = StrSplit(CurRow.TableName, ".");
				If MetadataArray1[0] = "DocumentJournal" Then
					IsSeparation = True;
				ElsIf MetadataArray1[0] = "Enum" Then
					IsSeparation = False;
				ElsIf MetadataArray1[0] = "Sequence" Then
					IsSeparation = True;
				Else
					IsSeparation = True;
				EndIf;
			EndIf;
		Else
			IsSeparation = False;
		EndIf;
		
		If IsSeparation Then
			MetadataNamesMapByAreas.Separated.Insert(CurRow.TableName, New Structure("Query, StatisticsOperations, StatisticsKind", QueryText, Undefined, 0));
		Else
			MetadataNamesMapByAreas.NotSeparated.Insert(CurRow.TableName, New Structure("Query, StatisticsOperations, StatisticsKind", QueryText, Undefined, 0));
		EndIf;
			
	EndDo;
		
	Return MetadataNamesMapByAreas;
	
EndFunction

Procedure WriteConfigurationSettings() Export
	ConfigurationSettings = BooleanFunctionalOptions();
	Write(ConfigurationSettings.NotSeparated, InformationRegisters.StatisticsAreas.GetRef("0", True));
	If ValueIsFilled(ConfigurationSettings.Separated) Then
		WriteSeparated(ConfigurationSettings.Separated);
	EndIf;
EndProcedure

Function BooleanFunctionalOptions()
	
	Result = New Structure("NotSeparated, Separated", New Map, New Map);
	
	DataSeparationEnabled = MonitoringCenterInternal.SeparationByDataAreasEnabled() 
		And Common.SubsystemExists("CloudTechnology.Core");
			
	For Each FunctionalOption In Metadata.FunctionalOptions Do
		FunctionalOptionTypesDetails = New TypeDescription(FunctionalOption.Location.Type);
		If Metadata.Constants.Contains(FunctionalOption.Location) And FunctionalOptionTypesDetails.ContainsType(Type("Boolean")) Then
			If DataSeparationEnabled Then
				FullConstantName = FunctionalOption.Location.FullName();
				
				If Common.SubsystemExists("CloudTechnology.Core") Then
					ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
					IsSeparatedMetadataObject = ModuleSaaSOperations.IsSeparatedMetadataObject(FullConstantName);
				Else
					IsSeparatedMetadataObject = False;
				EndIf;      
				
				IsSeparation = IsSeparatedMetadataObject;
			Else
				IsSeparation = False;
			EndIf;
            
			Collection = ?(IsSeparation, Result.Separated, Result.NotSeparated);
			Collection.Insert(FunctionalOption.FullName(), 
				New Structure("Query, StatisticsOperations, StatisticsKind", FunctionalOption.Location, Undefined, 1));
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Procedure ClearConfigurationStatistics() Export
	Query = New Query;
	Query.Text = 
		"SELECT DISTINCT
		|	ConfigurationStatistics.StatisticsAreaID AS StatisticsAreaID
		|FROM
		|	InformationRegister.ConfigurationStatistics AS ConfigurationStatistics";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	RecordSet = CreateRecordSet();
	While SelectionDetailRecords.Next() Do
		RecordSet.Filter.StatisticsAreaID.Set(SelectionDetailRecords.StatisticsAreaID);
		RecordSet.Write(True);
	EndDo;
EndProcedure

// Saves data to the information register
//
// Parameters:
//  ConfigurationStatistics - Map of KeyAndValue:
//    * Key - String - metadata object name.
//    * Value - Structure:
//      ** Query - String, MetadataObject - a query text or metadata object where the value is stored.
//      ** StatisticsOperations - Array - contains statistics operations.
//      ** StatisticsKind - Number - statistics flag.
//     * Area - UUID - statistics area UUID.
//
Procedure Write(ConfigurationStatistics, Area) Export
	
	RecordSet = CreateRecordSet(); 
	IsRecord = False;
	
	OperationsRefs = New Map;
	For Each CurObject In ConfigurationStatistics Do
		If CurObject.Value["StatisticsKind"] = 0 Then
			QueryResult = GetResult(CurObject.Value["Query"]);  // @skip-
			StatisticsOperations = GetStatisticsOperationResult(CurObject.Key, QueryResult);
		ElsIf CurObject.Value["StatisticsKind"] = 1 Then
			Value = ?(Constants[CurObject.Value["Query"].Name].Get(), 1, 0);
			StatisticsOperations = New Array;
			StatisticsOperation = New Structure("StatisticsOperationDescription, OperationsCount", CurObject.Key, Value);
			StatisticsOperations.Add(StatisticsOperation);
		EndIf;
		
		For Each StatisticsOperation In StatisticsOperations Do
			If OperationsRefs[StatisticsOperation.StatisticsOperationDescription] = Undefined Then
				OperationsRefs.Insert(StatisticsOperation.StatisticsOperationDescription, MonitoringCenterCached.GetStatisticsOperationRef(StatisticsOperation.StatisticsOperationDescription));
			EndIf;
            
            Value = Number(StrReplace(StatisticsOperation.OperationsCount,",","."));
            If Value <> 0 Then
                IsRecord = True;
                NewRecord1 = RecordSet.Add();
                NewRecord1.StatisticsAreaID = Area;
                NewRecord1.StatisticsOperation = OperationsRefs[StatisticsOperation.StatisticsOperationDescription];
                NewRecord1.StatisticsKind = CurObject.Value.StatisticsKind;
                NewRecord1.Value = Value;
            EndIf;
		EndDo;
	EndDo;
	
	If IsRecord Then
		RecordSet.Write(False);
	EndIf;
	
EndProcedure

Procedure WriteSeparated(ConfigurationStatistics)
	
	ModuleSaaSOperations = Undefined;
	CoreSaaSAvailable = Common.SubsystemExists("CloudTechnology.Core");
	If CoreSaaSAvailable Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
	EndIf;
	
	DataAreasResult = GetDataAreasQueryResult();
	Selection = DataAreasResult.Select();
	While Selection.Next() Do
		
		DataAreaRow = String(Selection.DataArea);
		DataAreaRef = InformationRegisters.StatisticsAreas.GetRef(DataAreaRow);
		If InformationRegisters.StatisticsAreas.ShouldCollectStatistics(DataAreaRow) Then
			Try
				
				If CoreSaaSAvailable Then
					ModuleSaaSOperations.SignInToDataArea(Selection.DataArea);
				EndIf;
				
			Except
				
				Info = ErrorInfo();
				WriteLogEvent(NStr("en = 'Monitoring center';", Common.DefaultLanguageCode()),
					EventLogLevel.Error,,,
					NStr("en = 'Cannot set the session separation. Data area';") + " = " + Format(Selection.DataArea, "NG=0")
						+ Chars.LF + ErrorProcessing.DetailErrorDescription(Info));
				
				If CoreSaaSAvailable Then
					ModuleSaaSOperations.SignOutOfDataArea();
				EndIf;
				
				Continue;
				
			EndTry;
			
			Write(ConfigurationStatistics, DataAreaRef); // 
			
			If CoreSaaSAvailable Then
				ModuleSaaSOperations.SignOutOfDataArea();
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns:
// - QueryResult
//
Function GetDataAreasQueryResult() Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		Result = ModuleSaaSOperations.DataAreasUsed();
	EndIf;
	
	Return Result;
	
EndFunction

Function GetStatisticsOperationResult(StatisticsOperationRoot, QueryResult)
	StatisticsOperations = New Array;
		
	If QueryResult <> Undefined Then
		Selection = QueryResult.Select();
		While Selection.Next() Do
			StatisticsOperationPresentation = StatisticsOperationRoot + ".";
 			Count = "0,000";
			
			StatisticsOperation = New Structure("StatisticsOperationDescription, OperationsCount");
			
			For Each CurColumn In QueryResult.Columns Do
				If CurColumn.Name <> "Count" Then
					StatisticsOperationPresentation = StatisticsOperationPresentation + Selection[CurColumn.Name] + ".";	
				Else
					Count = Format(Selection[CurColumn.Name], "NFD=3; NDS=,; NZ=0,000; NG=");
				EndIf;
			EndDo;
			StatisticsOperation.StatisticsOperationDescription = Left(StatisticsOperationPresentation, StrLen(StatisticsOperationPresentation) - 1);
			StatisticsOperation.OperationsCount = Count;
			
			StatisticsOperations.Add(StatisticsOperation);
		EndDo;
	EndIf;
		
	Return StatisticsOperations;
EndFunction

Function GetResult(QueryText)
	Result = Undefined;
	
	Query = New Query(QueryText);
	Result = Query.Execute();

	Return Result;
EndFunction
	
Function DefaultQuery(TableMetadata)
	QueryText = StrReplace("SELECT
	|	COUNT(*) AS Count
	|FROM
	|	&TableMetadata
	|", "&TableMetadata", TableMetadata);
	
	Return QueryText;
EndFunction

#EndRegion

#EndIf