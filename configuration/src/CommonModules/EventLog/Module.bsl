///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Handles bunch message writing to the event log.
// The EventsForEventLog variable is cleared after writing.
//
// Parameters:
//  EventsForEventLog - ValueList - where Value is structure with the following properties:
//              * EventName  - String - a name of the event to write.
//              * LevelPresentation  - String - a presentation of the EventLogLevel collection values.
//                                       Possible values: Information, Error, Warning, and Note.
//              * Comment - String - an event comment.
//              * EventDate - Date   - the event date that is added to the comment when writing.
//
Procedure WriteEventsToEventLog(EventsForEventLog) Export
	
	If TypeOf(EventsForEventLog) <> Type("ValueList") Then
		Return;
	EndIf;	
	
	If EventsForEventLog.Count() = 0 Then
		Return;
	EndIf;
	
	For Each LogMessage In EventsForEventLog Do
		MessageValue = LogMessage.Value;
		EventName = MessageValue.EventName;
		EventLevel = EventLevelByPresentation(MessageValue.LevelPresentation);
		EventDate = CurrentSessionDate();
		If MessageValue.Property("EventDate") And ValueIsFilled(MessageValue.EventDate) Then
			EventDate = MessageValue.EventDate;
		EndIf;
		Comment = String(EventDate) + " " + MessageValue.Comment;
		WriteLogEvent(EventName, EventLevel,,, Comment);
	EndDo;
	EventsForEventLog.Clear();
	
EndProcedure

#EndRegion

#Region Internal

// Write the message to the event log.
//
//  Parameters: 
//   EventName       - String - an event name for the event log.
//   Level          - EventLogLevel - events importance level of the log event.
//   MetadataObject - MetadataObject - metadata object that the event refers to.
//   Data           - AnyRef
//                    - Number
//                    - String
//                    - Date
//                    - Boolean
//                    - Undefined
//                    - Type - 
//                      
//                      
//   Comment      - String - the comment to the log event.
//
Procedure AddMessageForEventLog(Val EventName, Val Level,
		Val MetadataObject = Undefined, Val Data = Undefined, Val Comment = "") Export
		
	If IsBlankString(EventName) Then
		EventName = "Event"; // 
	EndIf;

	WriteLogEvent(EventName, Level, MetadataObject, Data, Comment, EventLogEntryTransactionMode.Independent);
	
EndProcedure

// Reads event log message texts taking into account the filter settings.
//
// Parameters:
//
//     ReportParameters - Structure - contains parameters for reading events from the event log. Contains fields:
//      *  Log                  - ValueTable         - contains records of the event log.
//      *  EventLogFilter   - Structure             - filter settings used to read the event log records:
//          ** StartDate - Date - start date of events (optional).
//          ** EndDate - Date - end date of events (optional).
//      *  EventCount1       - Number                   - maximum number of records that can be read from the event log.
//      *  UUID - UUID - a form UUID.
//      *  OwnerManager       - Arbitrary            - event
//                                                             log is displayed in the form of this object. The manager is used to call back appearance
//                                                             functions.
//      *  AddAdditionalColumns - Boolean           - determines whether callback is needed to add
//                                                             additional columns.
//     StorageAddress - String
//                    - UUID - 
//
// 
//     
//
Procedure ReadEventLogEvents(ReportParameters, StorageAddress) Export
	
	EventLogFilterAtClient          = ReportParameters.EventLogFilter;
	EventCount1              = ReportParameters.EventsCountLimit;
	OwnerManager              = ReportParameters.OwnerManager;
	AddAdditionalColumns = ReportParameters.AddAdditionalColumns;
	
	// Verifying the parameters.
	StartDate    = Undefined;
	EndDate = Undefined;
	FilterDatesSpecified = EventLogFilterAtClient.Property("StartDate", StartDate) And EventLogFilterAtClient.Property("EndDate", EndDate)
		And ValueIsFilled(StartDate) And ValueIsFilled(EventLogFilterAtClient.EndDate);
		
	If FilterDatesSpecified And StartDate > EndDate Then
		Raise NStr("en = 'Invalid event log filter settings. The start date is later than the end date.';");
	EndIf;
	ServerTimeOffset = ServerTimeOffset();
	
	// Prepare the filter.
	Filter = New Structure;
	For Each FilterElement In EventLogFilterAtClient Do
		Filter.Insert(FilterElement.Key, FilterElement.Value);
	EndDo;
	FilterTransformation(Filter, ServerTimeOffset);
	
	// Exporting the selected events and generating the table structure.
	LogEvents = New ValueTable;
	UnloadEventLog(LogEvents, Filter, , , EventCount1);
	
	LogEvents.Columns.Date.Name = "DateAtServer";
	LogEvents.Columns.Add("Date", New TypeDescription("Date"));
	
	LogEvents.Columns.Add("PicNumber", New TypeDescription("Number"));
	LogEvents.Columns.Add("DataAddress",  New TypeDescription("String"));
	
	If Common.SeparatedDataUsageAvailable() Then
		LogEvents.Columns.Add("SessionDataSeparation", New TypeDescription("String"));
		LogEvents.Columns.Add("SessionDataSeparationPresentation", New TypeDescription("String"));
	EndIf;
	
	If AddAdditionalColumns Then
		OwnerManager.AddAdditionalEventColumns(LogEvents);
	EndIf;
	
	If Common.DataSeparationEnabled()
	   And Common.SeparatedDataUsageAvailable()
	   And Common.SubsystemExists("CloudTechnology.Core") Then
		
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		UserAliases    = New Map();
	Else
		ModuleSaaSOperations = Undefined;
		UserAliases    = Undefined;
	EndIf;
	
	For Each LogEvent In LogEvents Do
		LogEvent.Date = LogEvent.DateAtServer - ServerTimeOffset;
		
		// 
		OwnerManager.SetPictureNumber(LogEvent);
		
		If AddAdditionalColumns Then
			// 
			OwnerManager.FillInAdditionalEventColumns(LogEvent);
		EndIf;
		
		// Converting the array of metadata into a value list.
		MetadataPresentationList = New ValueList;
		If TypeOf(LogEvent.MetadataPresentation) = Type("Array") Then
			MetadataPresentationList.LoadValues(LogEvent.MetadataPresentation);
			LogEvent.MetadataPresentation = MetadataPresentationList;
		Else
			LogEvent.MetadataPresentation = String(LogEvent.MetadataPresentation);
		EndIf;
		
		// Converting the SessionDataSeparationPresentation array into a value list.
		If Common.DataSeparationEnabled()
			And Not Common.SeparatedDataUsageAvailable() Then
			FullSessionDataSeparationPresentation = "";
			
			SessionDataSeparation = LogEvent.SessionDataSeparation;
			SeparatedDataAttributeList = New ValueList;
			For Each SessionSeparator In SessionDataSeparation Do
				SeparatorPresentation = Metadata.CommonAttributes.Find(SessionSeparator.Key).Synonym;
				SeparatorPresentation = SeparatorPresentation + " = " + SessionSeparator.Value;
				SeparatorValue = SessionSeparator.Key + "=" + SessionSeparator.Value;
				SeparatedDataAttributeList.Add(SeparatorValue, SeparatorPresentation);
				FullSessionDataSeparationPresentation = ?(Not IsBlankString(FullSessionDataSeparationPresentation),
				                                            FullSessionDataSeparationPresentation + "; ", "")
				                                            + SeparatorPresentation;
			EndDo;
			LogEvent.SessionDataSeparation = SeparatedDataAttributeList;
			LogEvent.SessionDataSeparationPresentation = FullSessionDataSeparationPresentation;
		EndIf;
		
		// Processing special event data.
		If LogEvent.Event = "_$Access$_.Access" Then
			SetDataAddressString(LogEvent);
			
			If LogEvent.Data <> Undefined Then
				LogEvent.Data = ?(LogEvent.Data.Data = Undefined, "", "...");
			EndIf;
			
		ElsIf LogEvent.Event = "_$Access$_.AccessDenied" Then
			SetDataAddressString(LogEvent);
			
			If LogEvent.Data <> Undefined Then
				If LogEvent.Data.Property("Right") Then
					LogEvent.Data = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Right: %1';"), 
						LogEvent.Data.Right);
				Else
					LogData = LogEvent.Data; // Structure
					LogEvent.Data = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Action: %1%2';"), 
						LogData.Action, ?(Not LogEvent.Data.Property("Data") Or LogEvent.Data.Data = Undefined, "", ", ...") );
				EndIf;
			EndIf;
			
		ElsIf LogEvent.Event = "_$Session$_.Authentication"
		      Or LogEvent.Event = "_$Session$_.AuthenticationError" Then
			
			SetDataAddressString(LogEvent);
			
			LogEventData = "";
			If LogEvent.Data <> Undefined Then
				For Each KeyAndValue In LogEvent.Data Do
					If ValueIsFilled(LogEventData) Then
						LogEventData = LogEventData + ", ...";
						Break;
					EndIf;
					LogEventData = KeyAndValue.Key + ": " + KeyAndValue.Value;
				EndDo;
			EndIf;
			LogEvent.Data = LogEventData;
			
		ElsIf LogEvent.Event = "_$User$_.Delete" Then
			SetDataAddressString(LogEvent);
			
			LogEventData = "";
			If LogEvent.Data <> Undefined Then
				For Each KeyAndValue In LogEvent.Data Do
					LogEventData = KeyAndValue.Key + ": " + KeyAndValue.Value;
					Break;
				EndDo;
			EndIf;
			LogEvent.Data = LogEventData;
			
		ElsIf LogEvent.Event = "_$User$_.New"
		      Or LogEvent.Event = "_$User$_.Update" Then
			SetDataAddressString(LogEvent);
			
			IBUserName = "";
			If LogEvent.Data <> Undefined Then
				LogEvent.Data.Property("Name", IBUserName);
			EndIf;
			LogEvent.Data = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Name: %1, …';"), IBUserName);
			
		EndIf;
		
		SetPrivilegedMode(True);
		// Refine the user name.
		If LogEvent.User = New UUID("00000000-0000-0000-0000-000000000000") Then
			LogEvent.UserName = NStr("en = '<Undefined>';");
			
		ElsIf LogEvent.UserName = "" Then
			LogEvent.UserName = Users.UnspecifiedUserFullName();
			
		ElsIf InfoBaseUsers.FindByUUID(LogEvent.User) = Undefined Then
			LogEvent.UserName = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 <Deleted>';"), LogEvent.UserName);
		EndIf;
		
		If ModuleSaaSOperations <> Undefined Then
			If UserAliases.Get(LogEvent.User) = Undefined Then
				UserAlias = ModuleSaaSOperations.AliasOfUserOfInformationBase(LogEvent.User);
				UserAliases.Insert(LogEvent.User, UserAlias);
			Else
				UserAlias = UserAliases.Get(LogEvent.User);
			EndIf;
			
			If ValueIsFilled(UserAlias) Then
				LogEvent.UserName = UserAlias;
			EndIf;
		EndIf;
		
		// Converting the UUID into a name. Further this name will be used in filter settings.
		IBUser = InfoBaseUsers.FindByUUID(LogEvent.User);
		If IBUser <> Undefined Then
			LogEvent.User = IBUser.Name;
		EndIf;
		SetPrivilegedMode(False);
	EndDo;
	
	// Completed successfully.
	Result = New Structure;
	Result.Insert("LogEvents", LogEvents);
	
	PutToTempStorage(Result, StorageAddress);
EndProcedure

// Creates a custom event log presentation.
//
// Parameters:
//  FilterPresentation - String - the string that contains custom presentation of the filter.
//  EventLogFilter - Structure - values of the event log filter.
//  DefaultEventLogFilter - Structure - default values of the event log filter 
//     (not included in the user presentation).
//
Procedure GenerateFilterPresentation(FilterPresentation, EventLogFilter, 
		DefaultEventLogFilter = Undefined) Export
	
	FilterPresentation = "";
	// Interval.
	PeriodStartDate    = Undefined;
	PeriodEndDate = Undefined;
	If Not EventLogFilter.Property("StartDate", PeriodStartDate)
		Or PeriodStartDate = Undefined Then
		PeriodStartDate    = '00010101000000';
	EndIf;
	
	If Not EventLogFilter.Property("EndDate", PeriodEndDate)
		Or PeriodEndDate = Undefined Then
		PeriodEndDate = '00010101000000';
	EndIf;
	
	If Not (PeriodStartDate = '00010101000000' And PeriodEndDate = '00010101000000') Then
		FilterPresentation = PeriodPresentation(PeriodStartDate, PeriodEndDate);
	EndIf;
	
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation, "User");
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation,
		"Event", DefaultEventLogFilter);
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation,
		"ApplicationName", DefaultEventLogFilter);
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation, "Session");
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation, "Level");
	
	// All other restrictions are specified by presentations without values.
	For Each FilterElement In EventLogFilter Do
		RestrictionName = FilterElement.Key;
		If Upper(RestrictionName) = Upper("StartDate")
			Or Upper(RestrictionName) = Upper("EndDate")
			Or Upper(RestrictionName) = Upper("Event")
			Or Upper(RestrictionName) = Upper("ApplicationName")
			Or Upper(RestrictionName) = Upper("User")
			Or Upper(RestrictionName) = Upper("Session")
			Or Upper(RestrictionName) = Upper("Level") Then
			Continue; // Interval and special restrictions are already displayed.
		EndIf;
		
		// Changing restrictions for some of presentations.
		If Upper(RestrictionName) = Upper("ApplicationName") Then
			RestrictionName = NStr("en = 'Application';");
		ElsIf Upper(RestrictionName) = Upper("TransactionStatus") Then
			RestrictionName = NStr("en = 'Transaction status';");
		ElsIf Upper(RestrictionName) = Upper("DataPresentation") Then
			RestrictionName = NStr("en = 'Data presentation';");
		ElsIf Upper(RestrictionName) = Upper("ServerName") Then
			RestrictionName = NStr("en = 'Working server';");
		ElsIf Upper(RestrictionName) = Upper("PrimaryIPPort") Then
			RestrictionName = NStr("en = 'IP port';");
		ElsIf Upper(RestrictionName) = Upper("SyncPort") Then
			RestrictionName = NStr("en = 'Auxiliary IP port';");
		ElsIf Upper(RestrictionName) = Upper("SessionDataSeparation") Then
			RestrictionName = NStr("en = 'Session data separation';");
		EndIf;
		
		If Not IsBlankString(FilterPresentation) Then 
			FilterPresentation = FilterPresentation + "; ";
		EndIf;
		FilterPresentation = FilterPresentation + RestrictionName;
		
	EndDo;
	
	If IsBlankString(FilterPresentation) Then
		FilterPresentation = NStr("en = 'Not set';");
	EndIf;
	
EndProcedure

// For internal use only.
//
Procedure PutDataInTempStorage(LogEvents, DataStorage) Export
	
	Map = GetFromTempStorage(DataStorage);
	For Each EventRow In LogEvents Do
		If IsBlankString(EventRow.DataAddress) Then
			DataAddress = "";
		ElsIf StrStartsWith(EventRow.DataAddress, "e1cib") Then
			DataAddress = GetFromTempStorage(EventRow.DataAddress);
		Else
			XMLReader = New XMLReader();
			XMLReader.SetString(EventRow.DataAddress);
			DataAddress = XDTOSerializer.ReadXML(XMLReader);
		EndIf;
		EventIdentifier = String(New UUID);
		Map.Insert(EventIdentifier, DataAddress);
		EventRow.DataAddress = EventIdentifier;
	EndDo;
	PutToTempStorage(Map, DataStorage);
	
EndProcedure

// Determines the server time offset relative to the application time.
//
// Returns:
//   Number - 
//       
//       
//
Function ServerTimeOffset() Export
	
	ServerTimeOffset = CurrentDate() - CurrentSessionDate(); // 
	If ServerTimeOffset >= -1 And ServerTimeOffset <= 1 Then
		ServerTimeOffset = 0;
	EndIf;
	Return ServerTimeOffset;
	
EndFunction

#EndRegion

#Region Private

// Filter transformation.
//
// Parameters:
//  Filter - Filter - the filter to be passed.
//
Procedure FilterTransformation(Filter, ServerTimeOffset)
	
	For Each FilterElement In Filter Do
		If TypeOf(FilterElement.Value) = Type("ValueList") Then
			FilterItemTransform(Filter, FilterElement);
		ElsIf Upper(FilterElement.Key) = Upper("Transaction") Then
			If StrFind(FilterElement.Value, "(") = 0 Then
				Filter.Insert(FilterElement.Key, "(" + FilterElement.Value);
			EndIf;
		ElsIf ServerTimeOffset <> 0
			And (Upper(FilterElement.Key) = Upper("StartDate") Or Upper(FilterElement.Key) = Upper("EndDate")) Then
			Filter.Insert(FilterElement.Key, FilterElement.Value + ServerTimeOffset);
		EndIf;
	EndDo;
	
EndProcedure

// Filter item transformation.
//
// Parameters:
//  Filter - Filter - the filter to be passed.
//  Filter - FilterElement - an item of the filter to be passed.
//
Procedure FilterItemTransform(Filter, FilterElement)
	
	FilterStructureKey = FilterElement.Key;
	// 
	// 
	If Upper(FilterStructureKey) = Upper("SessionDataSeparation") Then
		NewValue = New Structure;
	Else
		NewValue = New Array;
	EndIf;
	
	FilterStructureKey = FilterElement.Key;
	
	For Each ValueFromList In FilterElement.Value Do
		If Upper(FilterStructureKey) = Upper("Level") Then
			// 
			NewValue.Add(DataProcessors.EventLog.EventLogLevelValueByName(ValueFromList.Value));
		ElsIf Upper(FilterStructureKey) = Upper("TransactionStatus") Then
			// 
			NewValue.Add(DataProcessors.EventLog.EventLogEntryTransactionStatusValueByName(ValueFromList.Value));
		ElsIf Upper(FilterStructureKey) = Upper("SessionDataSeparation") Then
			SeparatorValueArray = New Array;
			FilterStructureKey = "SessionDataSeparation";
			DataSeparationArray = StrSplit(ValueFromList.Value, "=", True);
			
			SeparatorValues = StrSplit(DataSeparationArray[1], ",", True);
			For Each SeparatorValue In SeparatorValues Do
				SeparatorFilterItem = New Structure("Value, Use", Number(SeparatorValue), True);
				SeparatorValueArray.Add(SeparatorFilterItem);
			EndDo;
			
			NewValue.Insert(DataSeparationArray[0], SeparatorValueArray);
			
		Else
			If TypeOf(ValueFromList.Value) = Type("Number") Then
				NewValue.Add(ValueFromList.Value);
				Continue;
			Else
				FilterValues = StrSplit(ValueFromList.Value, Chars.LF, False);
			EndIf;
			For Each FilterValue In FilterValues Do
				If Upper(FilterStructureKey) = Upper("User") Then
					Try
						SetPrivilegedMode(True);
						NewValue.Add(InfoBaseUsers.FindByUUID(
							New UUID(FilterValue)));
						SetPrivilegedMode(False);
					Except
						NewValue.Add(FilterValue);
					EndTry;
				Else
					NewValue.Add(FilterValue);
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	Filter.Insert(FilterElement.Key, NewValue);
	
EndProcedure

// Adds a restriction to the filter presentation.
//
// Parameters:
//  EventLogFilter - Filter - the event log filter.
//  FilterPresentation - String - filter presentation.
//  RestrictionName - String - the name of the restriction.
//  DefaultEventLogFilter - Filter - the default event log filter.
//
Procedure AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation, RestrictionName,
	DefaultEventLogFilter = Undefined)
	
	If Not EventLogFilter.Property(RestrictionName) Then
		Return;
	EndIf;
	
	RestrictionList = EventLogFilter[RestrictionName];
	Restriction       = "";
	
	// If filter value is a default value there is no need to get a presentation of it.
	If DefaultEventLogFilter <> Undefined Then
		DefaultRestrictionList = "";
		If DefaultEventLogFilter.Property(RestrictionName, DefaultRestrictionList) Then
			If DefaultRestrictionList.Count() = RestrictionList.Count() Then
				Return;
			EndIf;
		EndIf;
	EndIf;
	
	If RestrictionName = "Event" And RestrictionList.Count() > 5 Then
		
		Restriction = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Events (%1)';"), RestrictionList.Count());
		
	ElsIf RestrictionName = "Session" And RestrictionList.Count() > 3 Then
		
		Restriction = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Sessions (%1)';"), RestrictionList.Count());
		
	Else
		
		For Each ListItem In RestrictionList Do
			If Not IsBlankString(Restriction) Then
				Restriction = Restriction + ", ";
			EndIf;
			
			If Not ValueIsFilled(ListItem.Presentation) Then
				RestrictionValue = ListItem.Value;
			Else
				RestrictionValue = ListItem.Presentation;
			EndIf;
			
			If (Upper(RestrictionName) = Upper("Session")
				Or Upper(RestrictionName) = Upper("Level"))
				And IsBlankString(Restriction) Then
				
				If RestrictionName = "Session" Then
					RestrictionPresentation = NStr("en = 'Session';");
				Else
					RestrictionPresentation = NStr("en = 'Level';");
				EndIf;
				
				Restriction = NStr("en = '%1: %2';");
				Restriction = StringFunctionsClientServer.SubstituteParametersToString(Restriction, RestrictionPresentation, RestrictionValue);
			Else
				Restriction = Restriction + RestrictionValue;
			EndIf;
		EndDo;
		
	EndIf;
	
	If Not IsBlankString(FilterPresentation) Then 
		FilterPresentation = FilterPresentation + "; ";
	EndIf;
	
	FilterPresentation = FilterPresentation + Restriction;
	
EndProcedure

Function TechnicalSupportLog(EventLogFilter, EventCount1, UUID = Undefined) Export
	
	Filter = New Structure;
	For Each FilterElement In EventLogFilter Do
		Filter.Insert(FilterElement.Key, FilterElement.Value);
	EndDo;
	ServerTimeOffset = ServerTimeOffset();
	FilterTransformation(Filter, ServerTimeOffset);
	
	// Exporting the selected events and generating the table structure.
	TempFile = GetTempFileName("xml");
	UnloadEventLog(TempFile, Filter, , , EventCount1);
	BinaryData = New BinaryData(TempFile);
	DeleteFiles(TempFile);
	
	Return PutToTempStorage(BinaryData, UUID);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// For internal use only.
//
Procedure SetDataAddressString(LogEvent)
	
	XMLWriter = New XMLWriter();
	XMLWriter.SetString();
	XDTOSerializer.WriteXML(XMLWriter, LogEvent.Data); 
	LogEvent.DataAddress = XMLWriter.Close();
	
EndProcedure

Function EventLevelByPresentation(LevelPresentation)
	If LevelPresentation = "Information" Then
		Return EventLogLevel.Information;
	ElsIf LevelPresentation = "Error" Then
		Return EventLogLevel.Error;
	ElsIf LevelPresentation = "Warning" Then
		Return EventLogLevel.Warning; 
	ElsIf LevelPresentation = "Note" Then
		Return EventLogLevel.Note;
	EndIf;	
EndFunction

#EndRegion
