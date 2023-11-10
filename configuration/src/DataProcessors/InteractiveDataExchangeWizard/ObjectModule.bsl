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

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Gets object mapping statistics for the StatisticsInformation table rows.
//
// Parameters:
//      Cancel        - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
//      RowIndexes - Array - indexes of StatisticsInformation table rows.
//                              Data is imported to these rows.
//                              If the parameter is not specified, statistics data is retrieved for all table rows.
// 
Procedure GetObjectMappingByRowStats(Cancel, RowIndexes = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If RowIndexes = Undefined Then
		
		RowIndexes = New Array;
		
		For Each TableRow In StatisticsInformation Do
			
			RowIndexes.Add(StatisticsInformation.IndexOf(TableRow));
			
		EndDo;
		
	EndIf;
	
	// Importing data from the exchange message into the cache for several tables at the same time
	ExecuteDataImportFromExchangeMessagesIntoCache(Cancel, RowIndexes);
	
	If Cancel Then
		Return;
	EndIf;
	
	InfobasesObjectsMapping = DataProcessors.InfobasesObjectsMapping.Create();
	
	// Getting mapping digest data separately for each table.
	For Each RowIndex In RowIndexes Do
		
		TableRow = StatisticsInformation[RowIndex];
		
		If Not TableRow.SynchronizeByID Then
			Continue;
		EndIf;
		
		// 
		InfobasesObjectsMapping.DestinationTableName            = TableRow.DestinationTableName;
		InfobasesObjectsMapping.SourceTableObjectTypeName = TableRow.ObjectTypeString;
		InfobasesObjectsMapping.InfobaseNode         = InfobaseNode;
		InfobasesObjectsMapping.ExchangeMessageFileName        = ExchangeMessageFileName;
		
		InfobasesObjectsMapping.SourceTypeString = TableRow.SourceTypeString;
		InfobasesObjectsMapping.DestinationTypeString = TableRow.DestinationTypeString;
		
		// конструктор
		InfobasesObjectsMapping.Designer();
		
		// 
		InfobasesObjectsMapping.GetObjectMappingDigestInfo(Cancel);
		
		// 
		TableRow.ObjectCountInSource       = InfobasesObjectsMapping.ObjectCountInSource();
		TableRow.ObjectCountInDestination       = InfobasesObjectsMapping.ObjectCountInDestination();
		TableRow.MappedObjectCount   = InfobasesObjectsMapping.MappedObjectCount();
		TableRow.UnmappedObjectsCount = InfobasesObjectsMapping.UnmappedObjectsCount();
		TableRow.MappedObjectPercentage       = InfobasesObjectsMapping.MappedObjectPercentage();
		TableRow.PictureIndex                     = DataExchangeServer.StatisticsTablePictureIndex(TableRow.UnmappedObjectsCount, TableRow.DataImportedSuccessfully);
		TableRow.IsMasterData                             = IsMasterDataTypeName(TableRow.DestinationTypeString);

	EndDo;
	
EndProcedure

// Maps infobase objects automatically
//  with default values and gets statistics of objects mapping
//  after mapping them automatically.
//
// Parameters:
//      Cancel        - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
//      RowIndexes - Array - indexes of StatisticsInformation table rows.
//                              Data is mapped automatically for these
//                              rows.
//                              If the parameter is not specified, statistics data is retrieved for all table rows.
// 
Procedure ExecuteDefaultAutomaticMappingAndGetMappingStatistics(Cancel, RowIndexes = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If RowIndexes = Undefined Then
		
		RowIndexes = New Array;
		
		For Each TableRow In StatisticsInformation Do
			
			RowIndexes.Add(StatisticsInformation.IndexOf(TableRow));
			
		EndDo;
		
	EndIf;
	
	// Importing data from the exchange message into the cache for several tables at the same time
	ExecuteDataImportFromExchangeMessagesIntoCache(Cancel, RowIndexes);
	
	If Cancel Then
		Return;
	EndIf;
	
	InfobasesObjectsMapping = DataProcessors.InfobasesObjectsMapping.Create();
	
	// 
	// 
	For Each RowIndex In RowIndexes Do
		
		TableRow = StatisticsInformation[RowIndex];
		
		If Not TableRow.SynchronizeByID Then
			Continue;
		EndIf;
		
		// 
		InfobasesObjectsMapping.DestinationTableName            = TableRow.DestinationTableName;
		InfobasesObjectsMapping.SourceTableObjectTypeName = TableRow.ObjectTypeString;
		InfobasesObjectsMapping.DestinationTableFields           = TableRow.TableFields;
		InfobasesObjectsMapping.DestinationTableSearchFields     = TableRow.SearchFields;
		InfobasesObjectsMapping.InfobaseNode         = InfobaseNode;
		InfobasesObjectsMapping.ExchangeMessageFileName        = ExchangeMessageFileName;
		
		InfobasesObjectsMapping.SourceTypeString = TableRow.SourceTypeString;
		InfobasesObjectsMapping.DestinationTypeString = TableRow.DestinationTypeString;
		
		// конструктор
		InfobasesObjectsMapping.Designer();
		
		// 
		InfobasesObjectsMapping.ExecuteDefaultAutomaticMapping(Cancel);
		
		// 
		InfobasesObjectsMapping.GetObjectMappingDigestInfo(Cancel);
		
		// 
		TableRow.ObjectCountInSource       = InfobasesObjectsMapping.ObjectCountInSource();
		TableRow.ObjectCountInDestination       = InfobasesObjectsMapping.ObjectCountInDestination();
		TableRow.MappedObjectCount   = InfobasesObjectsMapping.MappedObjectCount();
		TableRow.UnmappedObjectsCount = InfobasesObjectsMapping.UnmappedObjectsCount();
		TableRow.MappedObjectPercentage       = InfobasesObjectsMapping.MappedObjectPercentage();
		TableRow.PictureIndex                     = DataExchangeServer.StatisticsTablePictureIndex(TableRow.UnmappedObjectsCount, TableRow.DataImportedSuccessfully);
		TableRow.IsMasterData                             = IsMasterDataTypeName(TableRow.DestinationTypeString);
	EndDo;
	
EndProcedure

// Imports data into the infobase for StatisticsInformation table rows.
//  If all exchange message data is imported, the incoming exchange message
//  number is stored in the exchange node.
//  It implies that all data is imported to the infobase.
//  The repeat import of this message will be canceled.
//
// Parameters:
//       Cancel        - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
//       RowIndexes - Array - indexes of StatisticsInformation table rows.
//                               Data is imported to these rows.
//                               If the parameter is not specified, statistics data is retrieved for all table rows.
// 
Procedure RunDataImport(Cancel, RowIndexes = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If RowIndexes = Undefined Then
		
		RowIndexes = New Array;
		
		For Each TableRow In StatisticsInformation Do
			
			RowIndexes.Add(StatisticsInformation.IndexOf(TableRow));
			
		EndDo;
		
	EndIf;
	
	TablesToImport = New Array;
	
	For Each RowIndex In RowIndexes Do
		
		TableRow = StatisticsInformation[RowIndex];
		
		DataTableKey = DataExchangeServer.DataTableKey(TableRow.SourceTypeString, TableRow.DestinationTypeString, TableRow.IsObjectDeletion);
		
		TablesToImport.Add(DataTableKey);
		
	EndDo;
	
	// Initialize data processor properties.
	InfobasesObjectsMapping = DataProcessors.InfobasesObjectsMapping.Create();
	InfobasesObjectsMapping.ExchangeMessageFileName = ExchangeMessageFileName;
	InfobasesObjectsMapping.InfobaseNode  = InfobaseNode;
	
	// 
	InfobasesObjectsMapping.ExecuteDataImportForInfobase(Cancel, TablesToImport);
	
	DataImportedSuccessfully = Not Cancel;
	
	For Each RowIndex In RowIndexes Do
		
		TableRow = StatisticsInformation[RowIndex];
		
		TableRow.DataImportedSuccessfully = DataImportedSuccessfully;
		TableRow.PictureIndex = DataExchangeServer.StatisticsTablePictureIndex(TableRow.UnmappedObjectsCount, TableRow.DataImportedSuccessfully);
	
	EndDo;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

// Imports data (tables) to the cache from the exchange message.
// Only tables not imported before are imported.
// The DataExchangeDataProcessor variable contains (caches) the tables imported before.
//
// Parameters:
//       Cancel        - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
//       RowIndexes - Array - indexes of StatisticsInformation table rows.
//                               Data is imported to these rows.
//                               If the parameter is not specified, statistics data is retrieved for all table rows.
// 
Procedure ExecuteDataImportFromExchangeMessagesIntoCache(Cancel, RowIndexes)
	
	ExchangeSettingsStructure = DataExchangeServer.ExchangeSettingsStructureForInteractiveImportSession(InfobaseNode, ExchangeMessageFileName);
	
	If ExchangeSettingsStructure.Cancel Then
		Return;
	EndIf;
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	DataExchangeDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
	
	// Getting the array of tables to be batchly imported into the platform cache
	TablesToImport = New Array;
	
	For Each RowIndex In RowIndexes Do
		
		TableRow = StatisticsInformation[RowIndex];
		
		If Not TableRow.SynchronizeByID Then
			Continue;
		EndIf;
		
		DataTableKey = DataExchangeServer.DataTableKey(TableRow.SourceTypeString, TableRow.DestinationTypeString, TableRow.IsObjectDeletion);
		
		// Perhaps the data table is already imported and is placed in the DataExchangeDataProcessor data processor cache
		DataTable = DataExchangeDataProcessor.DataTablesExchangeMessages().Get(DataTableKey);
		
		If DataTable = Undefined Then
			
			TablesToImport.Add(DataTableKey);
			
		EndIf;
		
	EndDo;
	
	// Importing tables into the cache batchly
	If TablesToImport.Count() > 0 Then
		
		DataExchangeDataProcessor.ExecuteDataImportIntoValueTable(TablesToImport);
		
		If DataExchangeDataProcessor.FlagErrors() Then
			Cancel = True;
			NString = NStr("en = 'Errors occurred while importing the exchange message: %1';");
			NString = StringFunctionsClientServer.SubstituteParametersToString(NString, DataExchangeDataProcessor.ErrorMessageString());
			DataExchangeServer.WriteExchangeFinishWithError(ExchangeSettingsStructure.InfobaseNode,
												ExchangeSettingsStructure.ActionOnExchange, 
												ExchangeSettingsStructure.StartDate,
												NString);
			Return;
		EndIf;
		
	EndIf;
	
EndProcedure

Function IsMasterDataTypeName(DestinationTypeString)
	If Documents.AllRefsType().ContainsType(Type(DestinationTypeString)) Then
		Return False;
	EndIf;
	Return True;
EndFunction
////////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

// Data of the StatisticsInformation tabular section.
//
// Returns:
//  ValueTable - 
//
Function StatisticsTable() Export
	
	Return StatisticsInformation.Unload();
	
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf