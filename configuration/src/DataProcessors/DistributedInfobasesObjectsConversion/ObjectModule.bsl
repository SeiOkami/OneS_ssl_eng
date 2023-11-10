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

// Imports data from the exchange message file.
//
// Parameters:
//   Cancel - Boolean - a cancel flag appears on errors during exchange message processing.
//   ImportOnlyParameters - Boolean
//   ErrorMessage - String
// 
Procedure RunDataImport(Cancel, Val ImportOnlyParameters, ErrorMessage = "") Export
	
	If Not IsDistributedInfobaseNode() Then
		// 
		ErrorMessage = DataExchangeKindError();
		WriteExchangeFinish(Cancel, , DataExchangeKindError());
		Return;
	EndIf;
	
	ImportMetadata = ImportOnlyParameters
		And DataExchangeServer.IsSubordinateDIBNode()
		And (DataExchangeInternal.RetryDataExchangeMessageImportBeforeStart()
			Or Not DataExchangeInternal.DataExchangeMessageImportModeBeforeStart(
					"MessageReceivedFromCache")
			Or DataExchangeInternal.DataExchangeMessageImportModeBeforeStart(
					"DownloadingExtensions"));
					
	DataAnalysisResultToExport = DataExchangeServer.DataAnalysisResultToExport(ExchangeMessageFileName(), False, True);
	ExchangeMessageFileSize = DataAnalysisResultToExport.ExchangeMessageFileSize;
	ObjectsToImportCount = DataAnalysisResultToExport.ObjectsToImportCount;
	
	// Set session parameters.
	DataSynchronizationSessionParameters = New Map;
	SetPrivilegedMode(True);
	Try
		CurrentSessionParameter = SessionParameters.DataSynchronizationSessionParameters.Get();
	Except
		CurrentSessionParameter = Undefined;
	EndTry;
	
	If TypeOf(CurrentSessionParameter) = Type("Map") Then
		For Each Item In CurrentSessionParameter Do
			DataSynchronizationSessionParameters.Insert(Item.Key, Item.Value);
		EndDo;
	EndIf;
	
	DataSynchronizationSessionParameters.Insert(InfobaseNode, 
						New Structure("ExchangeMessageFileSize, ObjectsToImportCount",
						ExchangeMessageFileSize, ObjectsToImportCount));
	SessionParameters.DataSynchronizationSessionParameters = New ValueStorage(DataSynchronizationSessionParameters);
	SetPrivilegedMode(False);
	
	XMLReader = New XMLReader;
	Try
		XMLReader.OpenFile(ExchangeMessageFileName());
	Except
		// 
		ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		WriteExchangeFinish(Cancel, ErrorMessage, ErrorOpeningExchangeMessageFile());
		Return;
	EndTry;
	
	DataExchangeInternal.DisableAccessKeysUpdate(True);
	Try
		ReadExchangeMessageFile(Cancel, XMLReader, ImportOnlyParameters, ImportMetadata, ErrorMessage);
		DataExchangeInternal.DisableAccessKeysUpdate(False);
	Except
		DataExchangeInternal.DisableAccessKeysUpdate(False);
		Raise;
	EndTry;
	
	XMLReader.Close();
EndProcedure

// Exports data to the exchange message file.
//
// Parameters:
//  Cancel - Boolean - a cancel flag appears on errors during exchange message processing.
//  ErrorMessage - String - textual description of the data export error.
// 
Procedure RunDataExport(Cancel, ErrorMessage = "") Export
	
	If Not IsDistributedInfobaseNode() Then
		// 
		ErrorMessage = DataExchangeKindError();
		WriteExchangeFinish(Cancel, , ErrorMessage);
		Return;
	EndIf;
	
	XMLWriter = New XMLWriter;
	
	Try
		XMLWriter.OpenFile(ExchangeMessageFileName());
	Except
		// 
		ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		WriteExchangeFinish(Cancel, ErrorMessage, ErrorOpeningExchangeMessageFile());
		Return;
	EndTry;
	
	WriteChangesToExchangeMessageFile(Cancel, XMLWriter, ErrorMessage);
	
	XMLWriter.Close();
	
EndProcedure

// Passes the string with the full exchange message file name for data import or export to the ExchangeMessageFileNameField
// local variable.
// Usually, the exchange message file places 
// in the operating system user temporary directory.
//
// Parameters:
//  FileName - String - a full name of the exchange message file for data export or import.
// 
Procedure SetExchangeMessageFileName(Val FileName) Export
	
	ExchangeMessageFileNameField = FileName;
	
EndProcedure

//

Procedure ReadExchangeMessageFile(Cancel, XMLReader, Val ImportOnlyParameters, Val ImportMetadata, ErrorMessage = "")
	
	MessageReader = ExchangePlans.CreateMessageReader();
	
	Try
		MessageReader.BeginRead(XMLReader, AllowedMessageNo.Greater);
	Except
		// 
		// 
		// 
		ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		WriteExchangeFinish(Cancel, ErrorMessage, ErrorStartRedingTheExchangeMessageFile());
		Return;
	EndTry;
	
	CommonDataNode = Undefined;
	ReceivedNo = MessageReader.ReceivedNo;
	ExchangeNode = MessageReader.Sender;
	
	If ImportOnlyParameters Then
		
		If ImportMetadata Then
				
			Try
				
				SetPrivilegedMode(True);
				DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart(
					"ImportApplicationParameters", True);
				SetPrivilegedMode(False);
				
				// 
				ExchangePlans.ReadChanges(MessageReader, TransactionItemsCount);
				
				// Reading priority data (predefined items, metadata object IDs).
				ReadPriorityChangesFromExchangeMessage(MessageReader, CommonDataNode);
				
				// 
				MessageReader.CancelRead();
				
				SetPrivilegedMode(True);
				DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart(
					"ImportApplicationParameters", False);
				SetPrivilegedMode(False);
			Except
				SetPrivilegedMode(True);
				DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart(
					"ImportApplicationParameters", False);
				SetPrivilegedMode(False);
				
				MessageReader.CancelRead();
				ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
				WriteExchangeFinish(Cancel, ErrorMessage, ErrorReadingExchangeMessageFile());
				Return;
			EndTry;
			
		Else
			
			Try
				
				// 
				MessageReader.XMLReader.Skip(); // <Changes>...</Changes>
				
				MessageReader.XMLReader.Read(); // </Changes>
				
				// Reading priority data (predefined items, metadata object IDs).
				ReadPriorityChangesFromExchangeMessage(MessageReader, CommonDataNode);
				
				// 
				MessageReader.CancelRead();
			Except
				MessageReader.CancelRead();
				ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
				WriteExchangeFinish(Cancel, ErrorMessage, ErrorReadingExchangeMessageFile());
				Return
			EndTry;
			
		EndIf;
		
	Else
		
		If ThereIsAnExtensionInTheExchangeMessage(MessageReader) Then
			DataExchangeInternal.EnableLoadingExtensionsThatChangeTheDataStructure();
		EndIf;
		
		Try
				
			// 
			ExchangePlans.ReadChanges(MessageReader, TransactionItemsCount);
			
			// Reading priority data (predefined items, metadata object IDs).
			ReadPriorityChangesFromExchangeMessage(MessageReader, CommonDataNode);
			
			// 
			MessageReader.EndRead();
			
	        // 
			DataExchangeInternal.DisableLoadingExtensionsThatChangeTheDataStructure();
						
		Except
			
			// If the extensions were modified dynamically, reboot the session (not during the update process).
			If Catalogs.ExtensionsVersions.ExtensionsChangedDynamically() Then
				DataExchangeInternal.DisableLoadingExtensionsThatChangeTheDataStructure();
			EndIf;	
						
			MessageReader.CancelRead();
			ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
			WriteExchangeFinish(Cancel, ErrorMessage, ErrorReadingExchangeMessageFile());
			Return
		EndTry;
		
	EndIf;
			
	// Common data of nodes is written after the message is read.
	If CommonDataNode <> Undefined Then
		
		MasterNodeRef  = ExchangePlans.MasterNode();
		
		BeginTransaction();
		Try
		    Block = New DataLock;
			
		    LockItem = Block.Add(Common.TableNameByRef(MasterNodeRef));
		    LockItem.SetValue("Ref", MasterNodeRef);
			
			Block.Lock();
			
			CommonNodeData = DataExchangeCached.CommonNodeData(MasterNodeRef);
			CurrentNode = MasterNodeRef.GetObject();
			If DataExchangeEvents.DataDiffers1(CurrentNode, CommonDataNode, CommonNodeData) Then
				DataExchangeEvents.FillObjectPropertiesValues(CurrentNode, CommonDataNode, CommonNodeData);
				CurrentNode.Write();
			EndIf;

		    CommitTransaction();
		Except
		    RollbackTransaction();
			Raise;
		EndTry;
		
	EndIf;
	
	InformationRegisters.CommonNodeDataChanges.DeleteChangeRecords(ExchangeNode, ReceivedNo);
	
EndProcedure

Procedure WriteChangesToExchangeMessageFile(Cancel, XMLWriter, ErrorMessage = "")
	
	WriteMessage1 = ExchangePlans.CreateMessageWriter();
	
	Try
		WriteMessage1.BeginWrite(XMLWriter, InfobaseNode);
	Except
		ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		WriteExchangeFinish(Cancel, ErrorMessage, ErrorStartWritingTheExchangeMessageFile());
		Return;
	EndTry;
	
	// Set session parameters.
	ObjectsToExportCount = DataExchangeServer.CalculateRegisteredObjectsCount(InfobaseNode);
	DataSynchronizationSessionParameters = New Map;
	SetPrivilegedMode(True);
	Try
		CurrentSessionParameter = SessionParameters.DataSynchronizationSessionParameters.Get();
	Except
		CurrentSessionParameter = Undefined;
	EndTry;
	
	If TypeOf(CurrentSessionParameter) = Type("Map") Then
		For Each Item In CurrentSessionParameter Do
			DataSynchronizationSessionParameters.Insert(Item.Key, Item.Value);
		EndDo;
	EndIf;
	
	DataSynchronizationSessionParameters.Insert(InfobaseNode, 
						New Structure("ObjectsToExportCount",
						ObjectsToExportCount));
	SessionParameters.DataSynchronizationSessionParameters = New ValueStorage(DataSynchronizationSessionParameters);
	SetPrivilegedMode(False);
	
	Try
		DataExchangeInternal.ClearPriorityExchangeData();
		
		// 
		ExchangePlans.WriteChanges(WriteMessage1, TransactionItemsCount);
		
		// 
		// 
		WritePriorityChangesToExchangeMessage(WriteMessage1);
		
		WriteMessage1.EndWrite();
	Except
		WriteMessage1.CancelWrite();
		ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		WriteExchangeFinish(Cancel, ErrorMessage, ErrorSavingExchangeMessageFile());
		Return;
	EndTry;
	
EndProcedure

// Writes priority data (such as metadata object IDs) to the exchange message.
// For example, predefined items and metadata object IDs.
//
Procedure WritePriorityChangesToExchangeMessage(Val WriteMessage1)
	
	// 
	WriteMessage1.XMLWriter.WriteStartElement("Parameters");
	
	If WriteMessage1.Recipient <> ExchangePlans.MasterNode() Then
		
		// Exporting priority exchange data (predefined items.
		PriorityExchangeData = DataExchangeInternal.PriorityExchangeData();
		
		If PriorityExchangeData.Count() > 0 Then
			
			ChangesSelection = DataExchangeServer.SelectChanges(
				WriteMessage1.Recipient,
				WriteMessage1.MessageNo,
				PriorityExchangeData);
			
			BeginTransaction();
			Try
				
				While ChangesSelection.Next() Do
					
					WriteXML(WriteMessage1.XMLWriter, ChangesSelection.Get());
					
				EndDo;
				
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
			
		EndIf;
		
		If Not StandardSubsystemsCached.DisableMetadataObjectsIDs() Then
			
			// 
			ChangesSelection = DataExchangeServer.SelectChanges(
				WriteMessage1.Recipient,
				WriteMessage1.MessageNo,
				Metadata.Catalogs["MetadataObjectIDs"]);
			
			BeginTransaction();
			Try
				
				While ChangesSelection.Next() Do
					
					WriteXML(WriteMessage1.XMLWriter, ChangesSelection.Get());
					
				EndDo;
				
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
			
		EndIf;
		
		// Exporting common data of nodes.
		NodesChangesSelection = InformationRegisters.CommonNodeDataChanges.SelectChanges(WriteMessage1.Recipient, WriteMessage1.MessageNo);
		
		If NodesChangesSelection.Count() <> 0 Then
			
			CommonNodeData = DataExchangeCached.CommonNodeData(WriteMessage1.Recipient);
			
			If Not IsBlankString(CommonNodeData) Then
				
				ExchangePlanName = DataExchangeCached.GetExchangePlanName(WriteMessage1.Recipient);
				CommonNode = ExchangePlans[ExchangePlanName].CreateNode();
				DataExchangeEvents.FillObjectPropertiesValues(CommonNode, WriteMessage1.Recipient.GetObject(), CommonNodeData);
				WriteXML(WriteMessage1.XMLWriter, CommonNode);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	WriteMessage1.XMLWriter.WriteEndElement(); // Parameters
	
EndProcedure

// Reading first-priority data from the exchange message
// (predefined items, metadata object IDs).
//
Procedure ReadPriorityChangesFromExchangeMessage(Val MessageReader, CommonDataNode)
	
	If MessageReader.Sender = ExchangePlans.MasterNode() Then
		
		MessageReader.XMLReader.Read(); // <Parameters>
		
		BeginTransaction();
		Try
			
			DuplicatesOfPredefinedItems = "";
			Cancel = False;
			CancelDetails = "";
			IDObjects = New Array;
			ExchangePlanName = DataExchangeCached.GetExchangePlanName(MessageReader.Sender);
			TypeExchangePlanObject = Type("ExchangePlanObject." + ExchangePlanName);
			
			If NotUniqueRecordsFound("Catalog.MetadataObjectIDs") Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NotUniqueRecordErrorTemplate(),
					NStr("en = 'Duplicate catalog items were found
					           |before importing IDs of metadata objects.';"));
			EndIf;
			
			While CanReadXML(MessageReader.XMLReader) Do
				
				Data = ReadXML(MessageReader.XMLReader);
				
				Data.DataExchange.Load = True;
				
				If TypeOf(Data) = TypeExchangePlanObject Then // Node common data.
					
					CommonDataNode = Data;
					Continue;
					
				EndIf;
				
				Data.DataExchange.Sender = MessageReader.Sender;
				Data.DataExchange.Recipients.AutoFill = False;
				
				If TypeOf(Data) = Type("CatalogObject.MetadataObjectIDs") Then
					IDObjects.Add(Data);
					Continue;
					
				ElsIf TypeOf(Data) <> Type("ObjectDeletion") Then // This is a predefined item.
					
					If Not Data.Predefined Then
						Continue; // Process only predefined items.
					EndIf;
					
				Else // Type("ObjectDeletion")
					
					// 
					//    
					// 
					Continue;
				EndIf;
				
				WritePredefinedDataRef(Data);
				AddPredefinedItemDuplicateDetails(Data, DuplicatesOfPredefinedItems, Cancel, CancelDetails);
			EndDo;
			
			If Cancel Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot import priority data.
					           |Duplicate predefined items are found.
					           |Cannot continue the import due to the following reasons:
					           |%1';"),
					CancelDetails);
			EndIf;
			
			If ValueIsFilled(DuplicatesOfPredefinedItems) Then
				WriteLogEvent(
					NStr("en = 'Predefined items.Duplicates';",
						Common.DefaultLanguageCode()),
					EventLogLevel.Error,
					,
					,
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'When importing predefined items, duplicate records were found.
						           |%1';"),
						DuplicatesOfPredefinedItems));
			EndIf;
			
			UpdatePredefinedItemsDeletion();
			
			If Not StandardSubsystemsCached.DisableMetadataObjectsIDs() Then
				Catalogs.MetadataObjectIDs.ImportDataToSubordinateNode(IDObjects);
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			
			ErrorMessage = NStr("en = 'An error occurred when importing priority data: ""%1"" (type %2)';", Common.DefaultLanguageCode());
			ErrorMessage = StrTemplate(ErrorMessage, Data, TypeOf(Data));
			ErrorMessage = ErrorMessage + Chars.LF + ErrorInfo().Description; 
	
			WriteExchangeFinish(Cancel, ErrorMessage, ErrorReadingExchangeMessageFile());
			
			Raise;
		EndTry;
		
		MessageReader.XMLReader.Read(); // </Parameters>
		
	Else
		
		// 
		MessageReader.XMLReader.Skip(); // <Parameters>...</Parameters>
		
		MessageReader.XMLReader.Read(); // </Parameters>
		
	EndIf;
	
EndProcedure

Procedure WriteExchangeFinish(Cancel, ErrorDescription = "", ContextErrorDescription = "")
	
	Cancel = True;
	
	Comment = "[ContextErrorDescription]: [ErrorDescription]"; // 
	
	Comment = StrReplace(Comment, "[ContextErrorDescription]", ContextErrorDescription);
	Comment = StrReplace(Comment, "[ErrorDescription]", ErrorDescription);
	
	WriteLogEvent(EventLogMessageKey, EventLogLevel.Error,
		InfobaseNode.Metadata(), InfobaseNode, Comment);
	
EndProcedure

Function IsDistributedInfobaseNode()
	
	Return DataExchangeCached.IsDistributedInfobaseNode(InfobaseNode);
	
EndFunction

Procedure WritePredefinedDataRef(Data)
	
	ObjectMetadata = Metadata.FindByType(TypeOf(Data.Ref));
	If ObjectMetadata = Undefined Then
		Return;
	EndIf;
	
	ObjectManager = Common.ObjectManagerByRef(Data.Ref);
	
	If Data.IsNew() Then
		If Common.IsCatalog(ObjectMetadata) Then
			If ObjectMetadata.Hierarchical
				And ObjectMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems
				And Data.IsFolder Then
				Object = ObjectManager.CreateFolder();
			Else
				Object = ObjectManager.CreateItem();
			EndIf;
		ElsIf Common.IsChartOfCharacteristicTypes(ObjectMetadata) Then
			If ObjectMetadata.Hierarchical
				And Data.IsFolder Then
				Object = ObjectManager.CreateFolder();
			Else
				Object = ObjectManager.CreateItem();
			EndIf;
		ElsIf Common.IsChartOfAccounts(ObjectMetadata) Then
			Object = ObjectManager.CreateAccount();
		ElsIf Common.IsChartOfCalculationTypes(ObjectMetadata) Then
			Object = ObjectManager.CreateCalculationType();
		EndIf;
	Else
		Object = Data.Ref.GetObject();
	EndIf;
	
	If Data.IsNew() Then
		Object.SetNewObjectRef(Data.GetNewObjectRef());
		Object.PredefinedDataName = Data.PredefinedDataName;
		Object.AdditionalProperties.Insert("SkipObjectVersionRecord");
		Object.AdditionalProperties.Insert("PriorityDataImport");
		InfobaseUpdate.WriteData(Object, False);
		
	ElsIf Object.PredefinedDataName <> Data.PredefinedDataName Then
		Object.PredefinedDataName = Data.PredefinedDataName;
		Object.AdditionalProperties.Insert("SkipObjectVersionRecord");
		Object.AdditionalProperties.Insert("PriorityDataImport");
		InfobaseUpdate.WriteData(Object, False);
		
	Else
		// If the predefined item exists, preliminary import is not required
	EndIf;
	
	Data = Object;
	
EndProcedure

Procedure AddPredefinedItemDuplicateDetails(WrittenObject, DuplicatesOfPredefinedItems, Cancel, CancelDetails)
	
	ObjectMetadata = Metadata.FindByType(TypeOf(WrittenObject.Ref));
	If ObjectMetadata = Undefined Then
		Return;
	EndIf;
	
	Table = ObjectMetadata.FullName();
	PredefinedDataName = WrittenObject.PredefinedDataName;
	Ref = WrittenObject.Ref;
	
	Query = New Query;
	Query.SetParameter("PredefinedDataName", PredefinedDataName);
	Query.Text =
	"SELECT
	|	CurrentTable.Ref AS Ref,
	|	CurrentTable.PredefinedDataName AS PredefinedDataName
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	CurrentTable.PredefinedDataName = &PredefinedDataName";
	
	Query.Text = StrReplace(Query.Text, "&CurrentTable", Table);
	Selection = Query.Execute().Select();
	
	DuplicateRefIDs = "";
	DuplicateCount = 0;
	FoundRefs = New Map;
	RefToImportFound = False;
	
	While Selection.Next() Do
		// Searching for duplicate records that are relevant to predefined items
		If FoundRefs.Get(Selection.Ref) = Undefined Then
			FoundRefs.Insert(Selection.Ref, 1);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NotUniqueRecordErrorTemplate(),
				NStr("en = 'When importing predefined items, duplicate records were found.';"));
		EndIf;
		// Searching for duplicate predefined items
		If Ref = Selection.Ref And Not RefToImportFound Then
			RefToImportFound = True;
			Continue;
		EndIf;
		DuplicateCount = DuplicateCount + 1;
		If ValueIsFilled(DuplicateRefIDs) Then
			DuplicateRefIDs = DuplicateRefIDs + ",";
		EndIf;
		DuplicateRefIDs = DuplicateRefIDs
			+ String(Selection.Ref.UUID());
	EndDo;
	
	If DuplicateCount = 0 Then
		Return;
	EndIf;
	
	WriteToLog = True;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		
		LongDesc = "";
		ModuleAccessManagementInternal.OnFindNotUniquePredefinedItem(
			WrittenObject, WriteToLog, Cancel, LongDesc);
		
		If ValueIsFilled(LongDesc) Then
			CancelDetails = CancelDetails + Chars.LF + TrimAll(LongDesc) + Chars.LF;
		EndIf;
	EndIf;
	
	If WriteToLog Then
		If DuplicateCount = 1 Then
			Template = NStr("en = '(reference to import: %1, duplicate reference: %2)';");
		Else
			Template = NStr("en = '(reference to import: %1, duplicate references: %2)';");
		EndIf;
		DuplicatesOfPredefinedItems = DuplicatesOfPredefinedItems + Chars.LF
			+ Table + "." + PredefinedDataName + Chars.LF
			+ StringFunctionsClientServer.SubstituteParametersToString(
				Template,
				String(Ref.UUID()),
				DuplicateRefIDs)
			+ Chars.LF;
	EndIf;
	
EndProcedure

Function NotUniqueRecordsFound(Table)
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|
	|GROUP BY
	|	MetadataObjectIDs.Ref
	|
	|HAVING
	|	COUNT(MetadataObjectIDs.Ref) > 1";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Function NotUniqueRecordErrorTemplate()
	Return
		NStr("en = 'Cannot import priority data.
		           |%1
		           |An infobase repair is required.
		           |1. Open Designer. On the ""Administration"" menu,
		           | click ""Verify and repair"".
		           |2. In the ""Verify and repair infobase"" window:
		           |   - Select only the ""Check logical infobase integrity"" check box.
		           |   - Click ""Verify and repair"".
		           |   - Click ""Execute"".
		           |3. Then run 1C:Enterprise and synchronize the data again.';");
EndFunction

Procedure UpdatePredefinedItemsDeletion()
	
	SetPrivilegedMode(True);
	
	MetadataCollections = New Array;
	MetadataCollections.Add(Metadata.Catalogs);
	MetadataCollections.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataCollections.Add(Metadata.ChartsOfAccounts);
	MetadataCollections.Add(Metadata.ChartsOfCalculationTypes);
	
	For Each Collection In MetadataCollections Do
		For Each MetadataObject In Collection Do
			If MetadataObject = Metadata.Catalogs.MetadataObjectIDs Then
				Continue; // Metadata objects of this type are updated in the procedure that updates metadata object IDs
			EndIf;
			UpdatePredefinedItemDeletion(MetadataObject.FullName());
		EndDo;
	EndDo;
	
EndProcedure

Procedure UpdatePredefinedItemDeletion(Table)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CurrentTable.Ref AS Ref,
	|	CurrentTable.PredefinedDataName AS PredefinedDataName
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	CurrentTable.Predefined = TRUE";
	
	Query.Text = StrReplace(Query.Text, "&CurrentTable", Table);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If StrStartsWith(Selection.PredefinedDataName, "#") Then
			
			Object = Selection.Ref.GetObject();
			Object.PredefinedDataName = "";
			Object.DeletionMark = True;
			
			Object.AdditionalProperties.Insert("SkipObjectVersionRecord");
			InfobaseUpdate.WriteData(Object);
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local internal functions for retrieving properties.

Function ExchangeMessageFileName()
	
	If Not ValueIsFilled(ExchangeMessageFileNameField) Then
		
		ExchangeMessageFileNameField = "";
		
	EndIf;
	
	Return ExchangeMessageFileNameField;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Details of execution context errors.

Function ErrorOpeningExchangeMessageFile()
	
	Return NStr("en = 'Cannot open the exchange message file.';", Common.DefaultLanguageCode());
	
EndFunction

Function ErrorStartRedingTheExchangeMessageFile()
	
	Return NStr("en = 'Cannot start reading the exchange message file.';", Common.DefaultLanguageCode());
	
EndFunction

Function ErrorStartWritingTheExchangeMessageFile()
	
	Return NStr("en = 'Cannot start saving the exchange message file';", Common.DefaultLanguageCode());
	
EndFunction

Function ErrorReadingExchangeMessageFile()
	
	Return NStr("en = 'Cannot read the exchange message file.';", Common.DefaultLanguageCode());
	
EndFunction

Function ErrorSavingExchangeMessageFile()
	
	Return NStr("en = 'Failed to save data to the exchange message file.';");
	
EndFunction

Function DataExchangeKindError()
	
	Return NStr("en = 'The exchange must follow the conversion rules.';", Common.DefaultLanguageCode());
	
EndFunction

Function ThereIsAnExtensionInTheExchangeMessage(MessageReader)
	
	If Not DataExchangeServer.IsSubordinateDIBNode() 
		Or Common.DataSeparationEnabled() Then
		Return False;
	EndIf;
	
	HasExtensions = False;
	ThereAreExtensionsThatChangeDataStructure = False;
		
	ExchangeFile = New XMLReader;
	
	ExchangeFile.OpenFile(MessageReader.XMLReader.BaseURI);
	
	While ExchangeFile.Read() Do
		
		If ExchangeFile.Name = "v8de:Data"
			Or ExchangeFile.LocalName = "v8de:ConfigurationExtensions" 
			And ExchangeFile.NodeType = XMLNodeType.EndElement Then
			
			Break;
			
		EndIf;
		
		If ExchangeFile.Name = "v8de:ConfigurationExtensions" Then
			
			HasExtensions = True;
			Continue;
			
		EndIf;
		
		If HasExtensions And ExchangeFile.Name = "v8md:Metadata"
			Or ExchangeFile.Name = "v8de:ConfigurationExtensionDeletion" Then
			
			ThereAreExtensionsThatChangeDataStructure = True;
			Break;
			
		EndIf;
		
	EndDo;
	
	Return ThereAreExtensionsThatChangeDataStructure
		Or HasExtensions And Not InfobaseNode.Metadata().IncludeConfigurationExtensions;
	
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf