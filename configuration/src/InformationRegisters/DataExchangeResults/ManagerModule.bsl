///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Procedure RecordIssueResolved(Source, IssueType, InfobaseNode = Undefined) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Source.IsNew() Then
		Return;
	EndIf;
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	ObjectMetadata = Source.Metadata();
	
	If Common.IsRegister(ObjectMetadata) Then
		Return;
	EndIf;
	
	If ObjectMetadata.ConfigurationExtension() <> Undefined Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If DataExchangeCached.ExchangePlansInUse().Count() > 0
		And (SafeMode() = False Or Users.IsFullUser()) Then
		
		RefToSource = Source.Ref;
		
		BeginTransaction();
		Try
			Block = New DataLock;
		
			LockItem = Block.Add("InformationRegister.DataExchangeResults");
			LockItem.SetValue("IssueType", IssueType);
			If ValueIsFilled(InfobaseNode) Then
				LockItem.SetValue("InfobaseNode", InfobaseNode);				
			EndIf;
			LockItem.SetValue("ObjectWithIssue", RefToSource);
			
			Block.Lock();
			
			ConflictRecordSet = CreateRecordSet();
			ConflictRecordSet.Filter.IssueType.Set(IssueType);
			If ValueIsFilled(InfobaseNode) Then
				ConflictRecordSet.Filter.InfobaseNode.Set(InfobaseNode);			
			EndIf;
			ConflictRecordSet.Filter.ObjectWithIssue.Set(RefToSource);
			
			ConflictRecordSet.Read();
			
			If ConflictRecordSet.Count() > 0 Then
				
				DeletionMarkNewValue = Source.DeletionMark;
				If DeletionMarkNewValue <> Common.ObjectAttributeValue(RefToSource, "DeletionMark") Then
					For Each ConflictRecord In ConflictRecordSet Do
						ConflictRecord.DeletionMark = DeletionMarkNewValue;
					EndDo;
					ConflictRecordSet.Write();
				Else
					ConflictRecordSet.Clear();
					ConflictRecordSet.Write();
				EndIf;
				
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
	EndIf;
	
EndProcedure

Procedure RecordDocumentCheckError(ObjectWithIssue, InfobaseNode, Cause, IssueType) Export
	
	ObjectMetadata                   = ObjectWithIssue.Metadata();
	MetadataObjectID      = Common.MetadataObjectID(ObjectMetadata);
	Ref                              = Undefined;
	IndependentRegisterFiltersValues = Undefined;
	
	If ObjectMetadata.ConfigurationExtension() <> Undefined Then
		Return;
	EndIf;
	
	If Common.IsRefTypeObject(ObjectMetadata) Then
		Ref = ObjectWithIssue;
	ElsIf Common.IsRegister(ObjectMetadata) Then
		
		If Common.IsInformationRegister(ObjectMetadata)
			And ObjectMetadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
			
			IndependentRegisterFiltersValues = New Structure();
			
			For Each FilterElement In ObjectWithIssue.Filter Do
				IndependentRegisterFiltersValues.Insert(FilterElement.Name, FilterElement.Value);
			EndDo;
			
		Else
			Ref = ObjectWithIssue.Filter.Recorder.Value;
		EndIf;	
	Else
		Return;
	EndIf;
	
	ConflictRecordSet = CreateRecordSet();
	ConflictRecordSet.Filter.IssueType.Set(IssueType);
	ConflictRecordSet.Filter.InfobaseNode.Set(InfobaseNode);
	ConflictRecordSet.Filter.MetadataObject.Set(MetadataObjectID);
	ConflictRecordSet.Filter.ObjectWithIssue.Set(ObjectWithIssue);
	
	SerializedFiltersValues = Undefined;
	If IndependentRegisterFiltersValues <> Undefined Then
		SerializedFiltersValues = SerializeFilterValues(IndependentRegisterFiltersValues, ObjectMetadata);
		ConflictRecordSet.Filter.UniqueKey.Set(
			CalculateIndependentRegisterHash(SerializedFiltersValues));
	EndIf;
	
	ConflictRecord = ConflictRecordSet.Add();
	ConflictRecord.IssueType            = IssueType;
	ConflictRecord.InfobaseNode = InfobaseNode;
	ConflictRecord.MetadataObject       = MetadataObjectID;
	ConflictRecord.ObjectWithIssue       = Ref;
	ConflictRecord.OccurrenceDate      = CurrentSessionDate();
	ConflictRecord.Cause                = TrimAll(Cause);
	ConflictRecord.ObjectPresentation   = String(ObjectWithIssue); 
	ConflictRecord.IsSkipped              = False;
	
	If IndependentRegisterFiltersValues <> Undefined Then
		ConflictRecord.UniqueKey = CalculateIndependentRegisterHash(SerializedFiltersValues);
		ConflictRecord.IndependentRegisterFiltersValues = SerializedFiltersValues;
	EndIf;
	
	If Common.IsRefTypeObject(ObjectMetadata) Then
		
		If IssueType = Enums.DataExchangeIssuesTypes.UnpostedDocument Then
			
			If Ref.Metadata().NumberLength > 0 Then
				AttributesValues = Common.ObjectAttributesValues(ObjectWithIssue, "DeletionMark, Number, Date");
				ConflictRecord.DocumentNumber = AttributesValues.Number;
			Else
				AttributesValues = Common.ObjectAttributesValues(ObjectWithIssue, "DeletionMark, Date");
			EndIf;
			
			ConflictRecord.DocumentDate   = AttributesValues.Date;
			ConflictRecord.DeletionMark = AttributesValues.DeletionMark;
			
		Else
			
			ConflictRecord.DeletionMark = Common.ObjectAttributeValue(ObjectWithIssue, "DeletionMark");
			
		EndIf;
		
	EndIf;
	
	ConflictRecordSet.Write();
	
EndProcedure

Procedure LogAdministratorError(InfobaseNode, WarningDetails) Export
	
	// 
	// 
	
	IssueType = Enums.DataExchangeIssuesTypes.ApplicationAdministrativeError;
	
	RecordSetWarnings = CreateRecordSet();
	RecordSetWarnings.Filter.IssueType.Set(IssueType);
	RecordSetWarnings.Filter.InfobaseNode.Set(InfobaseNode);
	
	SetRecord = RecordSetWarnings.Add();
	SetRecord.IssueType = IssueType;
	SetRecord.InfobaseNode = InfobaseNode;
	SetRecord.OccurrenceDate = CurrentSessionDate();
	SetRecord.Cause = TrimAll(WarningDetails);
	SetRecord.IsSkipped = False;
	
	RecordSetWarnings.Write(True);
	
EndProcedure

Procedure AddAnEntryAboutTheResultsOfTheExchange(WriteParameters) Export
	
	Var ObjectWithIssue, InfobaseNode, Cause, IssueType, ObjectMetadata, MetadataObjectID, Ref, IndependentRegisterFiltersValues;
	
	WriteParameters.Property("ObjectWithIssue", ObjectWithIssue);
	WriteParameters.Property("InfobaseNode", InfobaseNode);
	WriteParameters.Property("Cause", Cause);
	WriteParameters.Property("IssueType", IssueType);
	
	If ValueIsFilled(ObjectWithIssue) Then
		
		ObjectMetadata = ObjectWithIssue.Metadata();
		MetadataObjectID = Common.MetadataObjectID(ObjectMetadata);
		If ObjectMetadata.ConfigurationExtension() <> Undefined Then
			
			Return;
			
		EndIf;
		
	EndIf;
	
	If ObjectWithIssue = Undefined Then
		
		Ref = Undefined;
	
	ElsIf Common.IsRefTypeObject(ObjectMetadata) Then
		
		Ref = ObjectWithIssue;
		
	ElsIf Common.IsRegister(ObjectMetadata) Then
		
		If Common.IsInformationRegister(ObjectMetadata)
			And ObjectMetadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
			
			IndependentRegisterFiltersValues = New Structure();
			
			For Each FilterElement In ObjectWithIssue.Filter Do
				IndependentRegisterFiltersValues.Insert(FilterElement.Name, FilterElement.Value);
			EndDo;
			
		Else
			
			Ref = ObjectWithIssue.Filter.Recorder.Value;
			
		EndIf;
		
	Else
		
		Return;
		
	EndIf;
	
	ConflictRecordSet = CreateRecordSet();
	ConflictRecordSet.Filter.IssueType.Set(IssueType);
	ConflictRecordSet.Filter.InfobaseNode.Set(InfobaseNode);
	ConflictRecordSet.Filter.MetadataObject.Set(MetadataObjectID);
	ConflictRecordSet.Filter.ObjectWithIssue.Set(ObjectWithIssue);
	
	SerializedFiltersValues = Undefined;
	If IndependentRegisterFiltersValues <> Undefined Then
		
		SerializedFiltersValues = SerializeFilterValues(IndependentRegisterFiltersValues, ObjectMetadata);
		ConflictRecordSet.Filter.UniqueKey.Set(CalculateIndependentRegisterHash(SerializedFiltersValues));
		
	EndIf;
	
	ConflictRecord = ConflictRecordSet.Add();
	ConflictRecord.IssueType            = IssueType;
	ConflictRecord.InfobaseNode = InfobaseNode;
	ConflictRecord.MetadataObject       = MetadataObjectID;
	ConflictRecord.ObjectWithIssue       = Ref;
	ConflictRecord.OccurrenceDate      = CurrentSessionDate();
	ConflictRecord.Cause                = TrimAll(Cause);
	ConflictRecord.ObjectPresentation   = String(ObjectWithIssue); 
	ConflictRecord.IsSkipped              = False;
	
	If IndependentRegisterFiltersValues <> Undefined Then
		
		ConflictRecord.UniqueKey = CalculateIndependentRegisterHash(SerializedFiltersValues);
		ConflictRecord.IndependentRegisterFiltersValues = SerializedFiltersValues;
		
	EndIf;
	
	If ObjectMetadata <> Undefined
		And Common.IsRefTypeObject(ObjectMetadata) Then
		
		If IssueType = Enums.DataExchangeIssuesTypes.UnpostedDocument Then
			
			If Ref.Metadata().NumberLength > 0 Then
				
				AttributesValues = Common.ObjectAttributesValues(ObjectWithIssue, "DeletionMark, Number, Date");
				ConflictRecord.DocumentNumber = AttributesValues.Number;
				
			Else
				
				AttributesValues = Common.ObjectAttributesValues(ObjectWithIssue, "DeletionMark, Date");
				
			EndIf;
			
			ConflictRecord.DocumentDate   = AttributesValues.Date;
			ConflictRecord.DeletionMark = AttributesValues.DeletionMark;
			
		Else
			
			ConflictRecord.DeletionMark = Common.ObjectAttributeValue(ObjectWithIssue, "DeletionMark");
			
		EndIf;
		
	EndIf;
	
	ConflictRecordSet.Write();
	
EndProcedure

Procedure ClearIssuesOnSend(InfobaseNodes = Undefined) Export

	IssuesTypes = New Array;
	IssuesTypes.Add(Enums.DataExchangeIssuesTypes.ApplicationAdministrativeError);
	IssuesTypes.Add(Enums.DataExchangeIssuesTypes.ConvertedObjectValidationError);
	IssuesTypes.Add(Enums.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnSendData);
	
	If ValueIsFilled(InfobaseNodes) Then
		NodesCollection = ?(TypeOf(InfobaseNodes) = Type("Array"),
			InfobaseNodes,
			CommonClientServer.ValueInArray(InfobaseNodes));
			
		For Each Node In NodesCollection Do
			FilterParameters = New Structure("InfobaseNode", Node);
			For Each IssueType In IssuesTypes Do
				FilterParameters.Insert("IssueType", IssueType);
				ClearRegisterRecords(FilterParameters);
			EndDo;
		EndDo;
	Else
		For Each IssueType In IssuesTypes Do
			FilterParameters = New Structure("IssueType", IssueType);
			ClearRegisterRecords(FilterParameters);
		EndDo;
	EndIf;
	
EndProcedure	

Procedure ClearIssuesOnGet(InfobaseNodes = Undefined) Export

	IssuesTypes = New Array();
	IssuesTypes.Add(Enums.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnGetData);
	
	For Each Issue1 In IssuesTypes Do
		
		FilterFields = RegisterFiltersParameters();
		
		If ValueIsFilled(InfobaseNodes) Then
			
			If TypeOf(InfobaseNodes) = Type("Array") Then
				For Each InfobaseNode In InfobaseNodes Do
					
					FilterFields.IssueType            = Issue1;
					FilterFields.InfobaseNode = InfobaseNode;
					ClearRegisterRecords(FilterFields);
					
				EndDo;
			Else
				
				FilterFields.IssueType            = Issue1;
				FilterFields.InfobaseNode = InfobaseNodes;
				ClearRegisterRecords(FilterFields);
				
			EndIf;
			
		Else	
			FilterFields.IssueType = Issue1;
			ClearRegisterRecords(FilterFields);
		EndIf;
	
	EndDo;

EndProcedure	

Procedure ClearSynchronizationWarnings(TimeConsumingOperationParameters, StorageAddress = Undefined) Export
	
	DeletionParameters = TimeConsumingOperationParameters.DeletionParameters;
	
	If DeletionParameters.SelectionOfTypesOfExchangeWarnings.Count() > 0 Then
		
		ClearBypassExchangeWarnings(DeletionParameters);
		
	EndIf;
	
	If DeletionParameters.SelectingTheTypesOfVersionWarnings.Count() > 0
		And Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		
		EventName = NStr("en = 'Data exchange';", Common.DefaultLanguageCode());
		InformationRegisters["ObjectsVersions"].ClearVersionWarnings(DeletionParameters, EventName);
		
	EndIf;
	
	ProgressText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Deleted %1 of %1';", Common.DefaultLanguageCode()),
			DeletionParameters.MaximumNumberOfOperations);
			
	TimeConsumingOperations.ReportProgress(100, ProgressText);	
	
EndProcedure

Function IssueSearchParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("IssueType",                Undefined);
	Parameters.Insert("IncludingIgnored", False);
	Parameters.Insert("Period",                     Undefined);
	Parameters.Insert("ExchangePlanNodes",            Undefined);
	Parameters.Insert("SearchString",               "");
	Parameters.Insert("ObjectWithIssue",           Undefined);	
	
	Return Parameters;
	
EndFunction

Function IssuesCount(SearchParameters = Undefined) Export
	
	Count = 0;
	
	If SearchParameters = Undefined Then
		SearchParameters = IssueSearchParameters();
	EndIf;
	
	Query = New Query(
	"SELECT
	|	COUNT(DataExchangeResults.ObjectWithIssue) AS IssuesCount
	|FROM
	|	InformationRegister.DataExchangeResults AS DataExchangeResults
	|WHERE
	|	TRUE
	|	AND &FilterBySkipped
	|	AND &FilterByExchangePlanNode
	|	AND &FilterByProblemType
	|	AND &FilterByPeriod
	|	AND &FilterByReason
	|	AND &FilterByObject");

	// Filter by ignored issues.
	FIlterRow = "";
	IncludingIgnored = Undefined;
	If Not SearchParameters.Property("IncludingIgnored", IncludingIgnored)
		Or IncludingIgnored = False Then
		FIlterRow = "AND NOT DataExchangeResults.IsSkipped";
	EndIf;
	Query.Text = StrReplace(Query.Text, "AND &FilterBySkipped", FIlterRow);
	
	// 
	FIlterRow = "";
	ExchangePlanNodes = Undefined;
	If SearchParameters.Property("ExchangePlanNodes", ExchangePlanNodes) 
		And ValueIsFilled(ExchangePlanNodes) Then
		FIlterRow = "AND DataExchangeResults.InfobaseNode IN (&ExchangeNodes)";
		Query.SetParameter("ExchangeNodes", SearchParameters.ExchangePlanNodes);
	EndIf;
	Query.Text = StrReplace(Query.Text, "AND &FilterByExchangePlanNode", FIlterRow);
	
	// 
	FIlterRow = "";
	IssueType = Undefined;
	If SearchParameters.Property("IssueType", IssueType)
		And ValueIsFilled(IssueType) Then
		FIlterRow = "AND DataExchangeResults.IssueType IN (&ProblemType)";
		Query.SetParameter("ProblemType", IssueType);
	EndIf;
	Query.Text = StrReplace(Query.Text, "AND &FilterByProblemType", FIlterRow);
	
	// 
	FIlterRow = "";
	Period = Undefined;
	If SearchParameters.Property("Period", Period) 
		And ValueIsFilled(Period)
		And TypeOf(Period) = Type("StandardPeriod") Then
		FIlterRow = "AND (DataExchangeResults.OccurrenceDate >= &StartDate
		|		AND DataExchangeResults.OccurrenceDate <= &EndDate)";
		Query.SetParameter("StartDate",    Period.StartDate);
		Query.SetParameter("EndDate", Period.EndDate);
	EndIf;
	Query.Text = StrReplace(Query.Text, "AND &FilterByPeriod", FIlterRow);
	
	// 
	FIlterRow = "";
	SearchString = Undefined;
	If SearchParameters.Property("SearchString", SearchString) 
		And ValueIsFilled(SearchString) Then
		FIlterRow = "AND DataExchangeResults.Cause LIKE &Cause";
		Query.SetParameter("Cause", "%" + SearchString + "%");
	EndIf;
	Query.Text = StrReplace(Query.Text, "AND &FilterByReason", FIlterRow);
	
	// 
	FIlterRow = "";
	ObjectsWithIssues = Undefined;
	If SearchParameters.Property("ObjectsWithIssues", ObjectsWithIssues)
		And ValueIsFilled(ObjectsWithIssues) Then
		FIlterRow = "AND DataExchangeResults.ObjectWithIssue IN (&ObjectsWithIssues)";
		Query.SetParameter("ObjectsWithIssues", ObjectsWithIssues);
	EndIf;
	Query.Text = StrReplace(Query.Text, "AND &FilterByObject", FIlterRow);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Count = Selection.IssuesCount;
	EndIf;
	
	Return Count;
	
EndFunction

// Returns the number of unreviewed synchronization warnings. 
//
// Parameters:
//   Nodes - Array from ExchangePlanRef - exchange nodes.
//
// Returns:
//  Structure:
//   * ExchangeWarnings - Number - a number of warnings recorded in the DataExchangeResults information register;
//   * VersionWarnings - Number - Warning count in the ObjectsVersions information register.
// 
Function TheNumberOfWarningsInDetail(SynchronizationNodes = Undefined) Export
	
	TheStructureOfTheHeaders = New Structure;
	TheStructureOfTheHeaders.Insert("TheNumberOfWarningsSent", 0);
	TheStructureOfTheHeaders.Insert("HeaderOfSendingWarnings", "");
	TheStructureOfTheHeaders.Insert("PictureOfSendingWarnings", Undefined);
	TheStructureOfTheHeaders.Insert("NumberOfWarningsReceived", 0);
	TheStructureOfTheHeaders.Insert("TheHeaderOfTheReceiptWarnings", "");
	TheStructureOfTheHeaders.Insert("PictureOfTheReceiptWarnings", Undefined);
	
	Query = New Query;
	Query.SetParameter("SynchronizationNodes", SynchronizationNodes);
	
	Query.Text =
	"SELECT TOP 101
	|	COUNT(1) AS NumberOfWarningsSent
	|FROM
	|	InformationRegister.DataExchangeResults AS DataExchangeResults
	|WHERE
	|	NOT DataExchangeResults.IsSkipped
	|	AND DataExchangeResults.InfobaseNode IN (&SynchronizationNodes)
	|	AND DataExchangeResults.IssueType IN (VALUE(Enum.DataExchangeIssuesTypes.ApplicationAdministrativeError),
	|											VALUE(Enum.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnSendData),
	|											VALUE(Enum.DataExchangeIssuesTypes.ConvertedObjectValidationError));
	|
	|//////////////////////////////////////////////////////////////
	|SELECT TOP 101
	|	COUNT(1) AS NumberWarningsReceived
	|FROM
	|	InformationRegister.DataExchangeResults AS DataExchangeResults
	|WHERE
	|	NOT DataExchangeResults.IsSkipped
	|	AND DataExchangeResults.InfobaseNode IN(&SynchronizationNodes)
	|	AND DataExchangeResults.IssueType IN (VALUE(Enum.DataExchangeIssuesTypes.BlankAttributes),
	|											VALUE(Enum.DataExchangeIssuesTypes.UnpostedDocument),
	|											VALUE(Enum.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnGetData))";
	
	QueryResult = Query.ExecuteBatch();
	If Not QueryResult[0].IsEmpty() Then
		
		SamplingTheProblemOfGetting = QueryResult[0].Select();
		If SamplingTheProblemOfGetting.Next() Then
			
			TheStructureOfTheHeaders.TheNumberOfWarningsSent = SamplingTheProblemOfGetting.NumberOfWarningsSent;
			
		EndIf;
		
	EndIf;
	
	If Not QueryResult[1].IsEmpty() Then
		
		SamplingTheProblemOfGetting = QueryResult[1].Select();
		If SamplingTheProblemOfGetting.Next() Then
			
			TheStructureOfTheHeaders.NumberOfWarningsReceived = SamplingTheProblemOfGetting.NumberWarningsReceived;
			
		EndIf;
		
	EndIf;
	
	If TheStructureOfTheHeaders.NumberOfWarningsReceived < 101 Then
		
		If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
			
			ModuleObjectsVersioning = Common.CommonModule("ObjectsVersioning");
			TheStructureOfTheHeaders.NumberOfWarningsReceived = 
				TheStructureOfTheHeaders.NumberOfWarningsReceived + ModuleObjectsVersioning.UpdateInformationAboutProblemsWithDataSynchronizationVersions(SynchronizationNodes);
			
		EndIf;
		
	EndIf;
	
	TheStructureOfTheHeaders.HeaderOfSendingWarnings = TitleOfWarningsByNumber(TheStructureOfTheHeaders.TheNumberOfWarningsSent);
	TheStructureOfTheHeaders.PictureOfSendingWarnings = PictureOfWarningsByNumber(TheStructureOfTheHeaders.TheNumberOfWarningsSent);
	TheStructureOfTheHeaders.TheHeaderOfTheReceiptWarnings = TitleOfWarningsByNumber(TheStructureOfTheHeaders.NumberOfWarningsReceived);
	TheStructureOfTheHeaders.PictureOfTheReceiptWarnings = PictureOfWarningsByNumber(TheStructureOfTheHeaders.NumberOfWarningsReceived);
	
	Return TheStructureOfTheHeaders;
	
EndFunction

// Returns the structure that includes synchronization warning details.
// 
// Parameters:
//   Nodes - Array of ExchangePlanRef - exchange nodes.
//
// Returns:
//   Structure:
//     * Title - String   - a hyperlink title.
//     * Picture  - Picture - a picture for the hyperlink.
//     * Count  - Number - a number of warnings, .
//
Function TheNumberOfWarningsForTheFormElement(Nodes = Undefined) Export
	
	StructureOfData = TheNumberOfWarningsInDetail(Nodes);
	Count = StructureOfData.TheNumberOfWarningsSent + StructureOfData.NumberOfWarningsReceived;
	
	TitleStructure = New Structure;
	TitleStructure.Insert("Title", TitleOfWarningsByNumber(Count));
	TitleStructure.Insert("Picture", PictureOfWarningsByNumber(Count));
	TitleStructure.Insert("Count", Count);
	
	Return TitleStructure;
	
EndFunction

#EndRegion

#Region Private

Function SerializeFilterValues(FilterParameters, ObjectMetadata)
	
	RecordSet = RegisterRecordSetByFilterParameters(FilterParameters, ObjectMetadata);
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
    WriteXML(XMLWriter, RecordSet);
	
	Return XMLWriter.Close();

EndFunction

Function CalculateIndependentRegisterHash(SerializedFilterValues)
	
	MD5FilterHash = New DataHashing(HashFunction.MD5);
	MD5FilterHash.Append(SerializedFilterValues);
	
	FilterHashsum = MD5FilterHash.HashSum;
	FilterHashsum = StrReplace(FilterHashsum, " ", "");
	
	Return FilterHashsum;

EndFunction

Function RegisterFiltersParameters()
	
	FilterFields = New Structure();
	FilterFields.Insert("IssueType",            Enums.DataExchangeIssuesTypes.EmptyRef());
	FilterFields.Insert("InfobaseNode", Undefined);
	FilterFields.Insert("MetadataObject",       Catalogs.MetadataObjectIDs.EmptyRef());
	FilterFields.Insert("ObjectWithIssue",       Undefined);
	FilterFields.Insert("UniqueKey",       "");
	
	Return FilterFields;
	
EndFunction

Function TitleOfWarningsByNumber(NumberOfWarnings)
	
	WarningTitle = "";
	If NumberOfWarnings > 100 Then
		
		WarningTitle = NStr("en = 'more than 100 warnings';", Common.DefaultLanguageCode());
		
	ElsIf NumberOfWarnings = 0 Then
		
		WarningTitle = "";
		
	Else
			
		WarningTitle = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 warnings';", Common.DefaultLanguageCode()),
			NumberOfWarnings);
		
	EndIf;
	
	Return WarningTitle;
	
EndFunction

Function PictureOfWarningsByNumber(NumberOfWarnings)
	
	Return ?(NumberOfWarnings = 0, New Picture, PictureLib.Warning);
	
EndFunction

Function RegisterRecordSetByFilterParameters(FilterParameters, ObjectMetadata)
	
	RecordSet = Common.ObjectManagerByFullName(ObjectMetadata.FullName()).CreateRecordSet();
	
	For Each FilterElement In RecordSet.Filter Do
		FilterValue = Undefined;
		If FilterParameters.Property(FilterElement.Name, FilterValue) Then
			FilterElement.Set(FilterValue);
		EndIf;
	EndDo;	
	
	Return RecordSet;
	
EndFunction

Procedure Ignore(Ref, IssueType, Ignore, InfobaseNode = Undefined, UniqueKey = "") Export
	
	ConflictRecordSet = CreateRecordSet();
	
	If Ref <> Undefined Then
		
		ObjectMetadata              = Ref.Metadata();
		MetadataObjectID = Common.MetadataObjectID(ObjectMetadata);
		
		ConflictRecordSet.Filter.MetadataObject.Set(MetadataObjectID);	
		
	EndIf;
	
	ConflictRecordSet.Filter.ObjectWithIssue.Set(Ref);
	ConflictRecordSet.Filter.IssueType.Set(IssueType);
	
	If ValueIsFilled(InfobaseNode) Then
		
		ConflictRecordSet.Filter.InfobaseNode.Set(InfobaseNode);	
		
	EndIf;
	
	If Not IsBlankString(UniqueKey) Then
		
		ConflictRecordSet.Filter.UniqueKey.Set(UniqueKey);
		
	EndIf;
	
	ConflictRecordSet.Read();
	If ConflictRecordSet.Count() > 0 Then
		
		ConflictRecordSet[0].IsSkipped = Ignore;
		ConflictRecordSet.Write();
	
	EndIf;
	
EndProcedure

Procedure ProgressDeletingSyncAlerts(Val CurrentStep, Maximum, SampleIterator = 0)
	
	CurrentStep = ?(CurrentStep = 0, 1, CurrentStep);
	
	If SampleIterator = 0 Then
		
		ProgressText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 out of %2 iterations completed';",  Common.DefaultLanguageCode()),
			CurrentStep, Maximum);
		
	Else
				
		ProgressText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 out of %2 iterations completed (%3)';",  Common.DefaultLanguageCode()),
			CurrentStep, Maximum, SampleIterator);
		
	EndIf;
	
	ProgressPercent = Round(CurrentStep * 100 / Maximum, 0);
	TimeConsumingOperations.ReportProgress(ProgressPercent, ProgressText);
	
EndProcedure

Procedure ClearRegisterRecords(FilterParameters)
	
	ConflictRecordSet = RegisterRecordSetByFilterParameters(FilterParameters, Metadata.InformationRegisters.DataExchangeResults);
	ConflictRecordSet.Write();
	
EndProcedure

Procedure ClearBypassExchangeWarnings(DeletionParameters)
	
	Query = New Query;
	Query.SetParameter("SelectionOfTypesOfExchangeWarnings", DeletionParameters.SelectionOfTypesOfExchangeWarnings);
	
	QueryText =
	"SELECT
	|	DataExchangeResults.IssueType AS IssueType,
	|	DataExchangeResults.InfobaseNode AS InfobaseNode,
	|	DataExchangeResults.MetadataObject AS MetadataObject,
	|	DataExchangeResults.ObjectWithIssue AS ObjectWithIssue,
	|	DataExchangeResults.UniqueKey AS UniqueKey,
	|	DataExchangeResults.OccurrenceDate AS OccurrenceDate,
	|	DataExchangeResults.IsSkipped AS IsSkipped
	|FROM
	|	InformationRegister.DataExchangeResults AS DataExchangeResults
	|WHERE
	|	DataExchangeResults.IssueType IN(&SelectionOfTypesOfExchangeWarnings)
	|
	|ORDER BY
	|	DataExchangeResults.OccurrenceDate,
	|	DataExchangeResults.InfobaseNode,
	|	DataExchangeResults.IssueType";
	
	QuerySchema = New QuerySchema;
	QuerySchema.SetQueryText(QueryText);
	
	TheOperatorOfTheRequestSchema = QuerySchema.QueryBatch[0].Operators[0];
	
	If DeletionParameters.SelectionOfExchangePlanNodes.Count() > 0 Then
		
		TheOperatorOfTheRequestSchema.Filter.Add("InfobaseNode IN(&SelectionOfExchangePlanNodes)");
		Query.SetParameter("SelectionOfExchangePlanNodes", DeletionParameters.SelectionOfExchangePlanNodes);
		
	EndIf;
	
	If ValueIsFilled(DeletionParameters.SelectionByDateOfOccurrence) Then
		
		SelectionByDateOfOccurrence = DeletionParameters.SelectionByDateOfOccurrence; // StandardPeriod
		
		TheOperatorOfTheRequestSchema.Filter.Add("OccurrenceDate BETWEEN &StartDate AND &EndDate");
		Query.SetParameter("StartDate", SelectionByDateOfOccurrence.StartDate);
		Query.SetParameter("EndDate", SelectionByDateOfOccurrence.EndDate);
		
	EndIf;
	
	If DeletionParameters.OnlyHiddenRecords Then
		
		TheOperatorOfTheRequestSchema.Filter.Add("IsSkipped = TRUE");
		
	EndIf;
	
	Query.Text = QuerySchema.GetQueryText();
	QuerySelection = Query.Execute().Select();
	
	Proportion = DeletionParameters.SelectionOfTypesOfExchangeWarnings.Count() / Max(QuerySelection.Count(), 1);
	SampleIterator = 0;
	
	While QuerySelection.Next() Do
		
		// 1. Start a transaction for a package of two operations: register read and write.
		BeginTransaction();
		Try
			
			 // 
			 // 
			DataLock = New DataLock;
			DataLockItem = DataLock.Add("InformationRegister.DataExchangeResults");
			DataLockItem.Mode = DataLockMode.Exclusive;
			DataLockItem.SetValue("IssueType", QuerySelection.IssueType);
			DataLockItem.SetValue("InfobaseNode", QuerySelection.InfobaseNode);
			DataLockItem.SetValue("MetadataObject", QuerySelection.MetadataObject);
			DataLockItem.SetValue("ObjectWithIssue", QuerySelection.ObjectWithIssue);
			DataLockItem.SetValue("UniqueKey", QuerySelection.UniqueKey);
			DataLock.Lock();
			
			// 3. Delete records.
			RecordManager = InformationRegisters.DataExchangeResults.CreateRecordManager();
			RecordManager.IssueType = QuerySelection.IssueType;
			RecordManager.InfobaseNode = QuerySelection.InfobaseNode;
			RecordManager.MetadataObject = QuerySelection.MetadataObject;
			RecordManager.ObjectWithIssue = QuerySelection.ObjectWithIssue;
			RecordManager.UniqueKey = QuerySelection.UniqueKey;
			RecordManager.Delete();
			
			SampleIterator = SampleIterator + 1;
			If Round(SampleIterator * Proportion, 0) <> Round((SampleIterator - 1) * Proportion, 0) Then 
				
				// 
				DeletionParameters.NumberOfOperationsCurrentStep = DeletionParameters.NumberOfOperationsCurrentStep + 1;
				
			EndIf;
			
			ProgressDeletingSyncAlerts(DeletionParameters.NumberOfOperationsCurrentStep, DeletionParameters.MaximumNumberOfOperations, SampleIterator);
			
			CommitTransaction();
			
		Except
			
			// 
			// 
			RollbackTransaction();
			
			EventName = NStr("en = 'Data exchange';", Common.DefaultLanguageCode());
			WriteLogEvent(EventName, EventLogLevel.Error,,,
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			Raise;
			
		EndTry;
		
	EndDo;
	
	DeletionParameters.NumberOfOperationsCurrentStep = DeletionParameters.SelectionOfTypesOfExchangeWarnings.Count();
	
EndProcedure

#Region UpdateHandlers

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	AdditionalParameters = InfobaseUpdate.AdditionalProcessingMarkParameters();
	AdditionalParameters.IsIndependentInformationRegister = True;
	AdditionalParameters.FullRegisterName             = "InformationRegister.DeleteDataExchangeResults";
	
	Query = New Query(
	"SELECT
	|	DeleteDataExchangeResults.ObjectWithIssue AS ObjectWithIssue,
	|	DeleteDataExchangeResults.IssueType AS IssueType
	|FROM
	|	InformationRegister.DeleteDataExchangeResults AS DeleteDataExchangeResults");
	
	Result = Query.Execute().Unload();
	
	InfobaseUpdate.MarkForProcessing(Parameters, Result, AdditionalParameters);
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	ProcessingCompleted = True;
	
	RegisterMetadata    = Metadata.InformationRegisters.DeleteDataExchangeResults;
	FullRegisterName     = RegisterMetadata.FullName();
	RegisterPresentation = RegisterMetadata.Presentation();
	
	AdditionalProcessingDataSelectionParameters = InfobaseUpdate.AdditionalProcessingDataSelectionParameters();
	
	Selection = InfobaseUpdate.SelectStandaloneInformationRegisterDimensionsToProcess(
		Parameters.Queue, FullRegisterName, AdditionalProcessingDataSelectionParameters);
	
	Processed = 0;
	RecordsWithIssuesCount = 0;
	
	While Selection.Next() Do
		
		Try
			
			TransferRegisterRecords(Selection);
			Processed = Processed + 1;
			
		Except
			
			RecordsWithIssuesCount = RecordsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process the register record set ""%1"" due to:
				|%2';"), RegisterPresentation, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
				
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				RegisterMetadata, , MessageText);
			
		EndTry;
		
	EndDo;
	
	If Not InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, FullRegisterName) Then
		ProcessingCompleted = False;
	EndIf;
	
	If Processed = 0 And RecordsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Procedure InformationRegisters.DataExchangeResults.ProcessDataForMigrationToNewVersion failed to process (skipped) some records: %1';"), 
			RecordsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			, ,
			StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The InformationRegisters.DataExchangeResults.ProcessDataForMigrationToNewVersion procedure processed records: %1';"),
			Processed));
	EndIf;
	
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

Procedure TransferRegisterRecords(RegisterRecord) 
	
	If Not ValueIsFilled(RegisterRecord.ObjectWithIssue) Then
		RecordSetOld = InformationRegisters.DeleteDataExchangeResults.CreateRecordSet();
		RecordSetOld.Filter.ObjectWithIssue.Set(RegisterRecord.ObjectWithIssue);
		RecordSetOld.Filter.IssueType.Set(RegisterRecord.IssueType);
		
		InfobaseUpdate.WriteRecordSet(RecordSetOld);
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		
		MetadataObjectID = Common.MetadataObjectID(RegisterRecord.ObjectWithIssue.Metadata());
		
		Block = New DataLock;
		
		LockItem = Block.Add("InformationRegister.DeleteDataExchangeResults");
		LockItem.SetValue("ObjectWithIssue", RegisterRecord.ObjectWithIssue);
		LockItem.SetValue("IssueType",      RegisterRecord.IssueType);		
		
		LockItem = Block.Add("InformationRegister.DataExchangeResults");
		LockItem.SetValue("IssueType",      RegisterRecord.IssueType);
		LockItem.SetValue("MetadataObject", MetadataObjectID);
		LockItem.SetValue("ObjectWithIssue", RegisterRecord.ObjectWithIssue);
		
		Block.Lock();
		
		RecordSetOld = InformationRegisters.DeleteDataExchangeResults.CreateRecordSet();
		RecordSetOld.Filter.ObjectWithIssue.Set(RegisterRecord.ObjectWithIssue);
		RecordSetOld.Filter.IssueType.Set(RegisterRecord.IssueType);
		
		RecordSetOld.Read();
		
		If RecordSetOld.Count() = 0 Then
			InfobaseUpdate.MarkProcessingCompletion(RecordSetOld);
		Else
			
			RecordSetNew = CreateRecordSet();
			RecordSetNew.Filter.IssueType.Set(RegisterRecord.IssueType);		
			RecordSetNew.Filter.MetadataObject.Set(MetadataObjectID);
			RecordSetNew.Filter.ObjectWithIssue.Set(RegisterRecord.ObjectWithIssue);
			
			Record_New = RecordSetNew.Add();
			FillPropertyValues(Record_New, RecordSetOld[0]);
			
			Record_New.MetadataObject = MetadataObjectID;
			
			InfobaseUpdate.WriteRecordSet(RecordSetNew);
			
			RecordSetOld.Clear();
			InfobaseUpdate.WriteRecordSet(RecordSetOld);
			
		EndIf;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry	
	
EndProcedure

#EndRegion

#EndRegion

#EndIf