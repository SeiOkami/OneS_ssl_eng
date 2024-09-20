///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// Returns:
//  FixedStructure:
//    * NoSectionsAndObjects - Boolean
//    * AllSectionsWithoutObjects - Boolean
//    * ImportRestrictionDatesImplemented - Boolean
//    * SingleSection - ChartOfCharacteristicTypesRef.PeriodClosingDatesSections
//    * UseExternalUsers - Boolean
//    * ShowSections - Boolean
//    * EmptyExchangePlansNodesRefs - FixedArray
//    * Sections - FixedMap of KeyAndValue:
//        ** Key - String
//        ** Value - FixedStructure:
//             *** Name - String
//             *** Presentation - String
//             *** Ref - ChartOfCharacteristicTypesRef.PeriodClosingDatesSections
//             *** ObjectsTypes - FixedArray
//    * SectionsWithoutObjects - FixedArray
//
Function SectionsProperties() Export
	
	Return SessionParameters.ValidPeriodClosingDates.SectionsProperties;
	
EndFunction

// Shows that it is required to update a version of period-end closing dates after changing data
// in the import mode or updates the version (import upon the infobase update).
//
// Called from the OnWrite event of PeriodClosingDates and UserGroupCompositions registers.
//
// Parameters:
//  Object - InformationRegisterRecordSet.PeriodClosingDates
//         - InformationRegisterRecordSet.UserGroupCompositions
// 
Procedure UpdatePeriodClosingDatesVersionOnDataImport(Object) Export
	
	SetPrivilegedMode(True);
	
	If ValueIsFilled(Object.DataExchange.Sender) Then
		SessionParameters.UpdatePeriodClosingDatesVersionAfterImportData = True;
	Else
		UpdatePeriodClosingDatesVersion();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddSessionParameterSettingHandlers.
Procedure OnAddSessionParameterSettingHandlers(Handlers) Export
	
	Handlers.Insert("SkipPeriodClosingCheck",
		"PeriodClosingDatesInternal.SessionParametersSetting");
	
	Handlers.Insert("ValidPeriodClosingDates",
		"PeriodClosingDatesInternal.SessionParametersSetting");
	
	Handlers.Insert("UpdatePeriodClosingDatesVersionAfterImportData",
		"PeriodClosingDatesInternal.SessionParametersSetting");
	
	Handlers.Insert("AccessRightsToRestrictionDates",
		"PeriodClosingDatesInternal.SessionParametersSetting");
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.SharedData = True;
	Handler.Version = "*";
	Handler.Procedure = "PeriodClosingDatesInternal.UpdatePeriodClosingDatesSections";
	Handler.ExecutionMode = "Seamless";
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "PeriodClosingDatesInternal.SetInitialPeriodEndClosingDate";
	
	Handler = Handlers.Add();
	Handler.SharedData = True;
	Handler.Version = "2.4.1.1";
	Handler.Procedure = "PeriodClosingDatesInternal.ClearPredefinedItemsInClosingDatesSections";
	Handler.ExecutionMode = "Seamless";
	
	Handler = Handlers.Add();
	Handler.Version = "2.4.1.1";
	Handler.Procedure = "PeriodClosingDatesInternal.ReplaceClosingDatesSectionsWithNewOnes";
	
	Handler = Handlers.Add();
	Handler.Version = "3.1.8.75";
	Handler.Procedure = "PeriodClosingDatesInternal.AppendSettingsForGivenAddressees";
	
EndProcedure

// See StandardSubsystems.OnSendDataToMaster.
Procedure OnSendDataToMaster(DataElement, ItemSend, Recipient) Export
	
	If RecordSetOnlyWithImportRestrictionDates(DataElement) Then
		ItemSend = DataItemSend.Ignore;
	EndIf;
	
EndProcedure

// See StandardSubsystemsServer.OnSendDataToSlave.
Procedure OnSendDataToSlave(DataElement, ItemSend, InitialImageCreating, Recipient) Export
	
	If RecordSetOnlyWithImportRestrictionDates(DataElement) Then
		ItemSend = DataItemSend.Ignore;
	EndIf;
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromMaster.
Procedure OnReceiveDataFromMaster(DataElement, ItemReceive, SendBack, Sender) Export
	
	// Standard data processor cannot be overridden.
	If ItemReceive = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	If RecordSetOnlyWithImportRestrictionDates(DataElement) Then
		ItemReceive = DataItemReceive.Ignore;
	EndIf;
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromSlave.
Procedure OnReceiveDataFromSlave(DataElement, ItemReceive, SendBack, Sender) Export
	
	// Standard data processor cannot be overridden.
	If ItemReceive = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	If RecordSetOnlyWithImportRestrictionDates(DataElement) Then
		ItemReceive = DataItemReceive.Ignore;
	EndIf;
	
EndProcedure

// Event handlers of the ReportsOptions subsystem.

// See ReportsOptionsOverridable.CustomizeReportsOptions.
Procedure OnSetUpReportsOptions(Settings) Export
	
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.ImportRestrictionDates);
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.PeriodClosingDates);
	
EndProcedure

// Event handlers of the Users subsystem.

// See SSLSubsystemsIntegration.AfterUserGroupsUpdate.
Procedure AfterUserGroupsUpdate(ItemsToChange, ModifiedGroups) Export
	
	UpdatePeriodClosingDatesVersion();
	
EndProcedure

// Event handlers of the Access management subsystem.

// See AccessManagementOverridable.OnFillListsWithAccessRestriction.
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.InformationRegisters.PeriodClosingDates, True);
	
EndProcedure

// Events handlers of the SaaSTechnology library.

// See ExportImportDataOverridable.OnFillCommonDataTypesSupportingRefMappingOnExport
Procedure OnFillCommonDataTypesSupportingRefMappingOnExport(Types) Export
	
	// 
	// 
	// 
	Types.Add(Metadata.ChartsOfCharacteristicTypes.PeriodClosingDatesSections);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Main procedures and functions.

// Parameters:
//  ParameterName - String
//  SpecifiedParameters - Array of String
//
Procedure SessionParametersSetting(ParameterName, SpecifiedParameters) Export
	
	If ParameterName = "ValidPeriodClosingDates" Then
		Value = SessionParameterValueEffectivePeriodClosingDates();
		SessionParameters.ValidPeriodClosingDates = Value;
		SpecifiedParameters.Add("ValidPeriodClosingDates");
		LastCheck = PeriodClosingDatesInternalCached.LastCheckOfEffectiveClosingDatesVersion();
		LastCheck.Date = CurrentSessionDate();
		
	ElsIf ParameterName = "SkipPeriodClosingCheck" Then
		SessionParameters.SkipPeriodClosingCheck = False;
		SpecifiedParameters.Add("SkipPeriodClosingCheck");
		
	ElsIf ParameterName = "UpdatePeriodClosingDatesVersionAfterImportData" Then
		SessionParameters.UpdatePeriodClosingDatesVersionAfterImportData = False;
		SpecifiedParameters.Add("UpdatePeriodClosingDatesVersionAfterImportData");
		
	ElsIf ParameterName = "AccessRightsToRestrictionDates" Then
		Rights = New Array;
		// 
		If Users.RolesAvailable("ReadPeriodEndClosingDates, AddEditPeriodClosingDates",, False) Then
			Rights.Add("ReadPeriodEndClosingDates");
		EndIf;
		If Users.RolesAvailable("AddEditPeriodClosingDates",, False) Then
			Rights.Add("ChangeOfPeriodEndClosingDates");
		EndIf;
		If Users.RolesAvailable("ReadDataImportRestrictionDates, AddEditDataImportRestrictionDates",, False) Then
			Rights.Add("ReadDataImportRestrictionDates");
		EndIf;
		If Users.RolesAvailable("AddEditDataImportRestrictionDates",, False) Then
			Rights.Add("ChangeDataImportRestrictionDates");
		EndIf;
		// 
		If ValueIsFilled(Rights) Then
			AccessRightsToRestrictionDates = "," + StrConcat(Rights, "," + Chars.LF + ",") + ",";
		Else
			AccessRightsToRestrictionDates = "";
		EndIf;
		SessionParameters.AccessRightsToRestrictionDates = AccessRightsToRestrictionDates;
		SpecifiedParameters.Add("AccessRightsToRestrictionDates");
	EndIf;
	
EndProcedure

// Handler of the PeriodClosingDatesVersionUpdateAfterDataImport subscription
// to the OnWrite event of any exchange plan.
//
Procedure UpdatingVersionDatesPreventsChangesAfterLoadingDataOnWrite(Source, Cancel) Export
	
	// 
	// 
	
	SetPrivilegedMode(True);
	
	If SessionParameters.UpdatePeriodClosingDatesVersionAfterImportData Then
		UpdatePeriodClosingDatesVersion();
		SessionParameters.UpdatePeriodClosingDatesVersionAfterImportData = False;
	EndIf;
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
EndProcedure

// Updates a version of period-end closing dates after change.
Procedure UpdatePeriodClosingDatesVersion() Export
	
	SetPrivilegedMode(True);
	Constants.PeriodClosingDatesVersion.Set(New UUID);
	
	LastCheck = PeriodClosingDatesInternalCached.LastCheckOfEffectiveClosingDatesVersion();
	LastCheck.Date = '00010101';
	
EndProcedure

// Returns a period-end closing date calculated according to the details of a relative period-end closing date.
//
// Parameters:
//  PeriodEndClosingDateDetails - String - contains details of a relative period-end closing date.
//  PeriodEndClosingDate         - Date - an absolute date received from the register.
//  BegOfDay           - Date - a current session date as of the beginning of the day.
//                      - Undefined - 
//
// Returns:
//  Date
//
Function PeriodEndClosingDateByDetails(PeriodEndClosingDateDetails, PeriodEndClosingDate, BegOfDay = '00010101') Export
	
	If Not ValueIsFilled(PeriodEndClosingDateDetails) Then
		Return PeriodEndClosingDate;
	EndIf;
	
	If Not ValueIsFilled(BegOfDay) Then
		BegOfDay = BegOfDay(CurrentSessionDate());
	EndIf;
	
	Days1 = 60*60*24;
	PermissionDaysCount = 0;
	
	PeriodEndClosingDateOption    = StrGetLine(PeriodEndClosingDateDetails, 1);
	DaysCountAsString = StrGetLine(PeriodEndClosingDateDetails, 2);
	
	If ValueIsFilled(DaysCountAsString) Then
		TypeDetails = New TypeDescription("Number");
		PermissionDaysCount = TypeDetails.AdjustValue(DaysCountAsString);
	EndIf;
	
	If PeriodEndClosingDateOption = "EndOfLastYear" Then
		CurrentPeriodEndClosingDate    = BegOfYear(BegOfDay)          - Days1;
		PreviousPeriodEndClosingDate = BegOfYear(CurrentPeriodEndClosingDate) - Days1;
		
	ElsIf PeriodEndClosingDateOption = "EndOfLastQuarter" Then
		CurrentPeriodEndClosingDate    = BegOfQuarter(BegOfDay)          - Days1;
		PreviousPeriodEndClosingDate = BegOfQuarter(CurrentPeriodEndClosingDate) - Days1;
		
	ElsIf PeriodEndClosingDateOption = "EndOfLastMonth" Then
		CurrentPeriodEndClosingDate    = BegOfMonth(BegOfDay)          - Days1;
		PreviousPeriodEndClosingDate = BegOfMonth(CurrentPeriodEndClosingDate) - Days1;
		
	ElsIf PeriodEndClosingDateOption = "EndOfLastWeek" Then
		CurrentPeriodEndClosingDate    = BegOfWeek(BegOfDay)          - Days1;
		PreviousPeriodEndClosingDate = BegOfWeek(CurrentPeriodEndClosingDate) - Days1;
		
	ElsIf PeriodEndClosingDateOption = "PreviousDay" Then
		CurrentPeriodEndClosingDate    = BegOfDay(BegOfDay)          - Days1;
		PreviousPeriodEndClosingDate = BegOfDay(CurrentPeriodEndClosingDate) - Days1;
	Else
		Return '39990303'; // Unknown format.
	EndIf;
	
	If ValueIsFilled(CurrentPeriodEndClosingDate) Then
		PermissionPeriod = CurrentPeriodEndClosingDate + PermissionDaysCount * Days1;
		If Not BegOfDay > PermissionPeriod Then
			CurrentPeriodEndClosingDate = PreviousPeriodEndClosingDate;
		EndIf;
	EndIf;
	
	Return CurrentPeriodEndClosingDate;
	
EndFunction

// Returns:
//   Structure:
//    * PeriodClosingCheck    - Boolean - if you set it to False, period-end closing check for users 
//                                    will be skipped. Default value is True.
//    * ImportRestrictionCheckNode - Undefined - (initial value) check data change.
//                                  - ExchangePlanRef - 
//    * ErrorDescription              - Null      - if returning detected period-end closing details is not required (default).
//                                  - String    - 
//                                  - Structure - 
//                                                
//
Function PeriodEndClosingDatesCheckParameters() Export
	
	Result = New Structure;
	Result.Insert("PeriodClosingCheck",    False);
	Result.Insert("ImportRestrictionCheckNode", Undefined);
	Result.Insert("ErrorDescription",              Null);
	Return Result;

EndFunction

// Checks period-end closing dates or data import restriction dates for the object.
// If data changing/import is impossible, sets the Cancel parameter to True.
//
// Parameters:
//  Source        - CatalogObject
//                  - ChartOfCharacteristicTypesObject
//                  - ChartOfAccountsObject
//                  - ChartOfCalculationTypesObject
//                  - BusinessProcessObject
//                  - TaskObject
//                  - ExchangePlanObject
//                  - DocumentObject - data object.
//                  - InformationRegisterRecordSet
//                  - AccumulationRegisterRecordSet
//                  - AccountingRegisterRecordSet
//                  - CalculationRegisterRecordSet - 
//                  - ObjectDeletion - 
//
//  SourceRegister - Boolean - False - a source is a register, otherwise, an object.
//
//  Replacing       - Boolean - if a source is a register and adding is carried out,
//                    specify False.
//
//  Delete        - Boolean - if a source is an object and an object is being deleted,
//                    specify True.
//
//  AdditionalParameters - Undefined - the parameters have initial values.
//                          - See PeriodEndClosingDatesCheckParameters
//
// Returns:
//   Structure:
//    * DataChangesDenied - Boolean - True if the object fails period-end closing date check.
//    * ErrorDescription     - Null
//                         - String
//                         - Structure - 
//
Function CheckDataImportRestrictionDates1(Source, SourceRegister, Replacing, Delete, 
	AdditionalParameters = Undefined) Export
	
	Result = New Structure;
	Result.Insert("DataChangesDenied", False);
	Result.Insert("ErrorDescription", "");
	
	PeriodClosingCheck    = True;
	ImportRestrictionCheckNode = Undefined;
	
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		AdditionalParameters.Property("PeriodClosingCheck",    PeriodClosingCheck);
		AdditionalParameters.Property("ImportRestrictionCheckNode", ImportRestrictionCheckNode);
		AdditionalParameters.Property("ErrorDescription",              Result.ErrorDescription);
	EndIf;
	
	ObjectVersion = "";
	If SkipClosingDatesCheck(Source, PeriodClosingCheck,
			ImportRestrictionCheckNode, ObjectVersion) Then
		Return Result;
	EndIf;
	
	If Not SourceRegister And Not Delete And Not Source.IsNew() Then
	
		If DataChangesDenied(
				?(ObjectVersion <> "OldVersion", Source, Source.Metadata().FullName()),
				?(ObjectVersion <> "NewVersion",  Source.Ref, Undefined),
				Result.ErrorDescription,
				ImportRestrictionCheckNode) Then
			
			Result.DataChangesDenied = True;
		EndIf;
		
	ElsIf SourceRegister And Replacing Then
		
		If DataChangesDenied(
				?(ObjectVersion <> "OldVersion", Source, Source.Metadata().FullName()),
				?(ObjectVersion <> "NewVersion",  Source.Filter, Undefined),
				Result.ErrorDescription,
				ImportRestrictionCheckNode) Then
			
			Result.DataChangesDenied = True;
		EndIf;
		
	ElsIf TypeOf(Source) = Type("ObjectDeletion") Then
		
		If ObjectVersion <> "NewVersion"
		   And DataChangesDenied(Source.Ref.Metadata().FullName(), Source.Ref,
				Result.ErrorDescription, ImportRestrictionCheckNode) Then
			
			Result.DataChangesDenied = True;
		EndIf;
		
	Else
		// 
		//     
		// 
		// 
		If ObjectVersion <> "OldVersion"
		   And DataChangesDenied(Source, Undefined,	Result.ErrorDescription, ImportRestrictionCheckNode) Then
			
			Result.DataChangesDenied = True;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Checks whether period-end closing or data import restriction need to be checked.
//
// Returns:
//  Boolean - 
//
Function SkipClosingDatesCheck(Object, PeriodClosingCheck, ImportRestrictionCheckNode, 
	ObjectVersion) Export
	
	If TypeOf(Object) <> Type("ObjectDeletion")
	   And Object.AdditionalProperties.Property("SkipPeriodClosingCheck") Then
		
		Return True;
	EndIf;
	
	If PeriodEndClosingDatesCheckDisabled(PeriodClosingCheck, ImportRestrictionCheckNode) Then
		Return True;
	EndIf;
	
	PeriodClosingDatesOverridable.BeforeCheckPeriodClosing(
		Object, PeriodClosingCheck, ImportRestrictionCheckNode, ObjectVersion);
	
	Return PeriodClosingCheck    = False          // 
	      And ImportRestrictionCheckNode = Undefined; // 
	
EndFunction

Function PeriodEndClosingDatesCheckDisabled(PeriodClosingCheck, ImportRestrictionCheckNode) Export
	
	SetPrivilegedMode(True);
	If SessionParameters.SkipPeriodClosingCheck Then
		Return True;
	EndIf;
	SetPrivilegedMode(False);
	
	If PeriodEndClosingNotUsed(PeriodClosingCheck, ImportRestrictionCheckNode) Then
		Return True;
	EndIf;
	
	If InfobaseUpdate.InfobaseUpdateInProgress()
	 Or InfobaseUpdate.IsCallFromUpdateHandler() Then
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// See PeriodClosingDates.DataChangesDenied.
Function DataChangesDenied(Data, DataID, ErrorDescription, ImportRestrictionCheckNode) Export
	
	SetPrivilegedMode(True);
	
	PeriodEndFound = False;
	EffectiveDates = EffectiveClosingDates();
	
	// Check an old object version or a record set.
	If DataID <> Undefined Then
		PeriodEndMessageParameters = PeriodClosingDates.PeriodEndMessageParameters();
		PeriodEndMessageParameters.NewVersion = False;
		
		// 
		// 
		
		If TypeOf(DataID) = Type("Filter") Then
			FilterStructure = New Structure;
			FilterStructure.Insert("Register", Data);
			FilterStructure.Insert("Filter", DataID);
			PeriodEndMessageParameters.Data = FilterStructure;
		Else
			PeriodEndMessageParameters.Data = DataID;
		EndIf;
		
		DataToCheck = DataToCheckFromDatabase(Data,
			DataID, EffectiveDates, ImportRestrictionCheckNode);
		
		PeriodEndFound = PeriodEndClosingFound(DataToCheck,
			PeriodEndMessageParameters, ErrorDescription, ImportRestrictionCheckNode, EffectiveDates);
	EndIf;
	
	// Check a new object version or a record set.
	If Not PeriodEndFound And TypeOf(Data) <> Type("String") Then
		
		PeriodEndMessageParameters = PeriodClosingDates.PeriodEndMessageParameters();
		PeriodEndMessageParameters.NewVersion = True;
		PeriodEndMessageParameters.Data = Data;
		
		DataToCheck = DataForCheckFromObject(Data, EffectiveDates, ImportRestrictionCheckNode);
		
		PeriodEndFound = PeriodEndClosingFound(DataToCheck,
			PeriodEndMessageParameters, ErrorDescription, ImportRestrictionCheckNode, EffectiveDates);
	EndIf;
	
	Return PeriodEndFound;
	
EndFunction

// Finds period-end closing dates by data to be checked for a specified user or exchange plan node.
// See PeriodClosingDates.PeriodEndClosingFound.
//
// Parameters:
//  DataToCheck           - See PeriodClosingDates.DataToCheckTemplate
//  PeriodEndMessageParameters  - See PeriodClosingDates.PeriodEndMessageParameters
//  ErrorDescription              - See PeriodClosingDates.PeriodEndClosingFound.ErrorDescription
//  ImportRestrictionCheckNode - See PeriodClosingDates.PeriodEndClosingFound.ImportRestrictionCheckNode
//
//  EffectiveDates - See PeriodClosingDatesInternal.SessionParameterValueEffectivePeriodClosingDates
//
// Returns:
//  Boolean - 
//
Function PeriodEndClosingFound(Val DataToCheck, PeriodEndMessageParameters,
			ErrorDescription, ImportRestrictionCheckNode, EffectiveDates = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If EffectiveDates = Undefined Then
		EffectiveDates = EffectiveClosingDates();
	EndIf;
	
	RestrictionUsed = ?(ImportRestrictionCheckNode = Undefined,
		EffectiveDates.PeriodClosingUsed,
		EffectiveDates.ImportRestrictionUsed);
	
	If Not RestrictionUsed Then
		Return False;
	EndIf;
	
	SectionsProperties = EffectiveDates.SectionsProperties;
	BlankSection = EmptyRef(Type("ChartOfCharacteristicTypesRef.PeriodClosingDatesSections"));
	
	ErrorTitle = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Error in function ""%1"" of common module ""%2"".';"),
		"PeriodEndClosingFound",
		"PeriodClosingDates")
		+ Chars.LF
		+ Chars.LF;
	
	// Adjusting data to match the embedding option.
	For Each String In DataToCheck Do
		
		If String.Section = Undefined Then
			String.Section = BlankSection;
		EndIf;
		
		SectionProperties = SectionsProperties.Sections.Get(String.Section); // See ChartsOfCharacteristicTypes.PeriodClosingDatesSections.SectionProperties
		If SectionProperties = Undefined Then
			ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 parameter contains non-existent section: ""%2"".';"),
				"DataToCheck",
				String.Section);
			Raise ErrorText;
		EndIf;
		
		If SectionsProperties.NoSectionsAndObjects Then
			String.Section = BlankSection;
			String.Object = BlankSection;
		Else
			If ValueIsFilled(SectionsProperties.SingleSection) Then
				String.Section = SectionsProperties.SingleSection;
			Else
				String.Section = SectionProperties.Ref;
			EndIf;
			
			If SectionsProperties.AllSectionsWithoutObjects
			 Or Not ValueIsFilled(String.Object) Then
				
				String.Object = String.Section;
			EndIf;
		EndIf;
		
	EndDo;
	
	// Collapsing unnecessary rows to reduce the number of checks and messages.
	SectionsAndObjects = DataToCheck.Copy(, "Section, Object");
	SectionsAndObjects.GroupBy("Section, Object");
	Filter = New Structure("Section, Object");
	SectionsAndObjects.Columns.Add("Date",
		New TypeDescription("Date", , , New DateQualifiers(DateFractions.Date)));
	
	For Each SectionAndObject In SectionsAndObjects Do
		FillPropertyValues(Filter, SectionAndObject);
		Rows = DataToCheck.FindRows(Filter);
		MinDate = Undefined;
		For Each String In Rows Do
			CurrentDate = BegOfDay(String.Date);
			If MinDate = Undefined Then
				MinDate = CurrentDate;
			EndIf;
			If CurrentDate < MinDate Then
				MinDate = CurrentDate;
			EndIf;
		EndDo;
		SectionAndObject.Date = MinDate;
	EndDo;
	DataToCheck = SectionsAndObjects;
	
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
	
	PeriodEndClosing = DataToCheck.Copy(New Array);
	PeriodEndClosing.Columns.Add("Addressee");
	PeriodEndClosing.Columns.Add("Data");
	
	// Search for period-end closing.
	If ImportRestrictionCheckNode = Undefined Then
		SMSMessageRecipients = EffectiveDates.ForUsers.SMSMessageRecipients;
		Addressee = Users.AuthorizedUser();
		Sections = SMSMessageRecipients.Get(Addressee);
		If Sections = Undefined Then
			OpenUserGroups = EffectiveDates.UserGroups.Get(Addressee);
			If OpenUserGroups <> Undefined Then
				For Each Group In OpenUserGroups Do
					PeriodEndAddressee = Group;
					Sections = SMSMessageRecipients.Get(PeriodEndAddressee);
					Break;
				EndDo;
			EndIf;
			If Sections = Undefined Then
				PeriodEndAddressee = Enums.PeriodClosingDatesPurposeTypes.ForAllUsers;
				Sections = SMSMessageRecipients.Get(PeriodEndAddressee);
			EndIf;
		EndIf;
	Else
		SMSMessageRecipients = EffectiveDates.ForInfobases.SMSMessageRecipients;
		Addressee = ImportRestrictionCheckNode;
		Sections = SMSMessageRecipients.Get(Addressee);
		If Sections = Undefined Then
			PeriodEndAddressee = Common.ObjectManagerByRef(ImportRestrictionCheckNode).EmptyRef();
			Sections = SMSMessageRecipients.Get(PeriodEndAddressee);
			If Sections = Undefined Then
				PeriodEndAddressee = Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases;
				Sections = SMSMessageRecipients.Get(PeriodEndAddressee);
			EndIf;
		EndIf;
	EndIf;
	
	If Sections = Undefined Then
		Return False;
	EndIf;
	
	For Each Data In DataToCheck Do
		SearchResult = FindPeriodEndClosingDate(Sections, Data, BlankSection);
		If SearchResult = Undefined Then
			Continue;
		EndIf;
		
		If SearchResult.PeriodEndClosingDate < Data.Date Then
			Continue;
		EndIf;
		
		String = PeriodEndClosing.Add();
		String.Data  = Data;
		String.Section  = SearchResult.RestrictionSection;
		String.Object  = SearchResult.RestrictionObject;
		String.Addressee = Addressee;
		String.Date    = SearchResult.PeriodEndClosingDate;
	EndDo;
	
	If TypeOf(PeriodEndMessageParameters) = Type("Structure")
	   And TypeOf(ErrorDescription) <> Type("Null")
	   And PeriodEndClosing.Count() > 0 Then
		
		ErrorDescription = PeriodEndMessages(PeriodEndClosing, PeriodEndMessageParameters, SectionsProperties,
			ImportRestrictionCheckNode <> Undefined, TypeOf(ErrorDescription) = Type("Structure"));
	EndIf;
	
	Return PeriodEndClosing.Count() > 0;
	
EndFunction

// Returns effective period-end closing dates considering the version after changes.
//
// Returns:
//   See PeriodClosingDatesInternal.SessionParameterValueEffectivePeriodClosingDates
//
Function EffectiveClosingDates() Export
	
	LastCheck = PeriodClosingDatesInternalCached.LastCheckOfEffectiveClosingDatesVersion();
	
	EffectiveDates = SessionParameters.ValidPeriodClosingDates;
	
	If CurrentSessionDate() > (LastCheck.Date + 5) Then
		If EffectiveDates.BegOfDay <> BegOfDay(CurrentSessionDate())
		 Or EffectiveDates.Version <> Constants.PeriodClosingDatesVersion.Get() Then
			
			SetSafeModeDisabled(True);
			SetPrivilegedMode(True);
			
			ParametersToClear = New Array;
			ParametersToClear.Add("ValidPeriodClosingDates");
			SessionParameters.Clear(ParametersToClear);
			
			SetPrivilegedMode(False);
			SetSafeModeDisabled(False);
			
			EffectiveDates = SessionParameters.ValidPeriodClosingDates;
		EndIf;
		LastCheck.Date = CurrentSessionDate();
	EndIf;
	
	Return EffectiveDates;
	
EndFunction

// Returns data sources filled 
// in the PeriodClosingDatesOverridable.FillDataSourcesForPeriodClosingCheck procedure.
//
// Returns:
//   FixedMap
//
Function DataSourcesForPeriodClosingCheck() Export
	
	Return SessionParameters.ValidPeriodClosingDates.DataSources;
	
EndFunction

// Returns a null reference of the specified type.
Function EmptyRef(RefType)
	
	Types = New Array;
	Types.Add(RefType);
	TypeDescription = New TypeDescription(Types);
	
	Return TypeDescription.AdjustValue(Undefined);
	
EndFunction

Function ErrorTextImportRestrictionDatesNotImplemented() Export
	
	Return NStr("en = 'No exchange plan is subject to data import restrictions
	                   |from other applications for the past period.';");
	
EndFunction

Function IsPeriodClosingAddressee(PeriodEndAddressee) Export
	
	Return TypeOf(PeriodEndAddressee) = Type("CatalogRef.Users")
	    Or TypeOf(PeriodEndAddressee) = Type("CatalogRef.UserGroups")
	    Or TypeOf(PeriodEndAddressee) = Type("CatalogRef.ExternalUsers")
	    Or TypeOf(PeriodEndAddressee) = Type("CatalogRef.ExternalUsersGroups")
	    Or PeriodEndAddressee = Enums.PeriodClosingDatesPurposeTypes.ForAllUsers;
	
EndFunction

Function CalculatedPeriodClosingDates() Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	PeriodClosingDates.Section AS Section,
	|	PeriodClosingDates.Object AS Object,
	|	PeriodClosingDates.User AS User,
	|	PeriodClosingDates.PeriodEndClosingDate AS PeriodEndClosingDate,
	|	PeriodClosingDates.PeriodEndClosingDateDetails AS PeriodEndClosingDateDetails,
	|	PeriodClosingDates.Comment AS Comment
	|FROM
	|	InformationRegister.PeriodClosingDates AS PeriodClosingDates";
	Table = Query.Execute().Unload();
	
	BegOfDay = BegOfDay(CurrentSessionDate());
	For Each String In Table Do
		String.PeriodEndClosingDate = PeriodEndClosingDateByDetails(String.PeriodEndClosingDateDetails,
			String.PeriodEndClosingDate , BegOfDay);
	EndDo;
	
	Return Table;
	
EndFunction

// Updates chart of characteristic types PeriodClosingDatesSections according to the details in metadata.
Procedure UpdatePeriodClosingDatesSections() Export
	
	If Common.DataSeparationEnabled()
	   And Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	SectionsProperties = SectionsProperties();
	BlankSection = ChartsOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef();
	
	UpdatedSections = New Array;
	
	For Each SectionDetails In SectionsProperties.Sections Do
		If TypeOf(SectionDetails.Key) = Type("String")
		 Or Not ValueIsFilled(SectionDetails.Key) Then
			Continue;
		EndIf;
		SectionProperties = SectionDetails.Value; // See ChartsOfCharacteristicTypes.PeriodClosingDatesSections.SectionProperties
		UpdatedSections.Add(SectionProperties.Ref);
		
		BeginTransaction();
		Try
			DataLock = New DataLock;
			LockItem = DataLock.Add("ChartOfCharacteristicTypes.PeriodClosingDatesSections");
			LockItem.SetValue("Ref", SectionProperties.Ref);
			DataLock.Lock();
			
			Object = SectionProperties.Ref.GetObject();
			Write = False;
			
			If Object = Undefined Then
				Object = ChartsOfCharacteristicTypes.PeriodClosingDatesSections.CreateItem();
				Object.SetNewObjectRef(SectionProperties.Ref);
				Write = True;
			EndIf;
			
			If Object.Description <> SectionProperties.Presentation Then
				Object.Description = SectionProperties.Presentation;
				Write = True;
			EndIf;
			
			If Object.DeletionMark Then
				Object.DeletionMark = False;
				Write = True;
			EndIf;
			
			If ValueIsFilled(Object.DeleteNewRef) Then
				Object.DeleteNewRef = BlankSection;
				Write = True;
			EndIf;
			
			ObjectsTypes = New Array;
			If SectionProperties.ObjectsTypes.Count() = 0 Then
				ObjectsTypes.Add(TypeOf(BlankSection));
			Else
				For Each TypeProperties In SectionProperties.ObjectsTypes Do
					ObjectsTypes.Add(TypeOf(TypeProperties.EmptyRef));
				EndDo;
			EndIf;
			If Object.ValueType.Types().Count() <> ObjectsTypes.Count() Then
				Object.ValueType = New TypeDescription(ObjectsTypes);
				Write = True;
			Else
				For Each Type In ObjectsTypes Do
					If Not Object.ValueType.ContainsType(Type) Then
						Object.ValueType = New TypeDescription(ObjectsTypes);
						Write = True;
						Break;
					EndIf;
				EndDo;
			EndIf;
			If Write Then
				InfobaseUpdate.WriteObject(Object, False);
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndDo;
	
	// Mark not predefined obsolete sections for deletion.
	BeginTransaction();
	Try
		DataLock = New DataLock;
		LockItem = DataLock.Add("ChartOfCharacteristicTypes.PeriodClosingDatesSections");
		LockItem.Mode = DataLockMode.Shared;
		DataLock.Lock();

		Query = New Query;
		Query.SetParameter("Sections", UpdatedSections);
		Query.Text =
		"SELECT
		|	Sections.Ref AS Ref,
		|	Sections.PredefinedDataName AS PredefinedDataName,
		|	Sections.DeleteNewRef AS DeleteNewRef
		|FROM
		|	ChartOfCharacteristicTypes.PeriodClosingDatesSections AS Sections
		|WHERE
		|	NOT Sections.DeletionMark
		|	AND NOT Sections.Ref IN (&Sections)
		|	AND Sections.PredefinedDataName = """"";
		
		DeprecatedSections = Query.Execute().Unload();
		
		LockItem = DataLock.Add("ChartOfCharacteristicTypes.PeriodClosingDatesSections");
		LockItem.DataSource = DeprecatedSections;
		LockItem.UseFromDataSource("Ref", "Ref");  
		DataLock.Lock();
		
		For Each DeprecatedSection In DeprecatedSections Do
			If ValueIsFilled(DeprecatedSection.DeleteNewRef)
			   And Common.DataSeparationEnabled() Then
				Continue;
			EndIf;
			Object = DeprecatedSection.Ref.GetObject();
			Object.DeletionMark = True;
			InfobaseUpdate.WriteData(Object, False);
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

// Filling handler of the common initial period-end closing date before 1980.
Procedure SetInitialPeriodEndClosingDate() Export
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.PeriodClosingDates.CreateRecordSet();
	RecordSet.Read();
	
	If RecordSet.Count() <> 0 Then
		Return;
	EndIf;
	
	BlankSection = EmptyRef(Type("ChartOfCharacteristicTypesRef.PeriodClosingDatesSections"));
	
	Record = RecordSet.Add();
	Record.User = Enums.PeriodClosingDatesPurposeTypes.ForAllUsers;
	Record.Section       = BlankSection;
	Record.Object       = BlankSection;
	Record.PeriodEndClosingDate  = '19791231';
	
	InfobaseUpdate.WriteData(RecordSet);
	
EndProcedure

// Handler converts a chart of characteristic types to period-end closing date sections.
Procedure ClearPredefinedItemsInClosingDatesSections() Export
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	ChartOfCharacteristicTypes.PeriodClosingDatesSections AS Sections
	|WHERE
	|	Sections.PredefinedDataName <> """"";
	
	If Query.Execute().IsEmpty() Then
		Return;
	EndIf;
	
	SectionsProperties = SectionsProperties();
	PredefinedItemsNames =
		Metadata.ChartsOfCharacteristicTypes.PeriodClosingDatesSections.GetPredefinedNames();
	
	Block = New DataLock;
	Block.Add("ChartOfCharacteristicTypes.PeriodClosingDatesSections");
	
	Query.Text =
	"SELECT
	|	Sections.Ref AS Ref,
	|	Sections.PredefinedDataName AS PredefinedDataName
	|FROM
	|	ChartOfCharacteristicTypes.PeriodClosingDatesSections AS Sections
	|WHERE
	|	Sections.PredefinedDataName <> """"";
	
	BeginTransaction();
	Try
		Block.Lock();
		UpdatePeriodClosingDatesSections();
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			Object = Selection.Ref.GetObject();
			If PredefinedItemsNames.Find(Selection.PredefinedDataName) <> Undefined Then
				ObjectNamePrefix = "Delete";
				If Not StrStartsWith(Selection.PredefinedDataName, ObjectNamePrefix) Then
					Object.DeletionMark = True;
				Else
					SoughtName = Mid(Selection.PredefinedDataName, StrLen(ObjectNamePrefix) + 1);
					SectionProperties = SectionsProperties.Sections.Get(SoughtName); // See ChartsOfCharacteristicTypes.PeriodClosingDatesSections.SectionProperties
					
					If SectionProperties = Undefined Then
						Object.DeletionMark = True;
						
					ElsIf Selection.Ref <> SectionProperties.Ref Then
						Object.DeleteNewRef = SectionProperties.Ref;
						Object.Description = "(" + NStr("en = 'not applicable';") + ") " + SectionProperties.Presentation;
					EndIf;
				EndIf;
			ElsIf SectionsProperties.Sections.Get(Selection.Ref) = Undefined Then
				Object.DeletionMark = True;
			EndIf;
			Object.PredefinedDataName = "";
			InfobaseUpdate.WriteData(Object, False);
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Handler replaces sections of period-end closing dates in the register with the new ones.
Procedure ReplaceClosingDatesSectionsWithNewOnes() Export
	
	Block = New DataLock;
	Block.Add("InformationRegister.PeriodClosingDates");
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	Sections.Ref AS Ref,
	|	Sections.DeleteNewRef AS DeleteNewRef
	|FROM
	|	ChartOfCharacteristicTypes.PeriodClosingDatesSections AS Sections
	|		INNER JOIN InformationRegister.PeriodClosingDates AS PeriodClosingDates
	|		ON (PeriodClosingDates.Section = Sections.Ref)
	|			AND (Sections.DeleteNewRef <> VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef))";
	
	BeginTransaction();
	Try
		Block.Lock();
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			OldRecords = InformationRegisters.PeriodClosingDates.CreateRecordSet();
			OldRecords.Filter.Section.Set(Selection.Ref);
			OldRecords.Read();
			NewRecords = InformationRegisters.PeriodClosingDates.CreateRecordSet();
			NewRecords.Filter.Section.Set(Selection.DeleteNewRef);
			NewRecords.Read();
			If NewRecords.Count() > 0 Then
				OldRecords.Clear();
				InfobaseUpdate.WriteData(OldRecords, False);
			Else
				For Each OldRecord In OldRecords Do
					NewRecord = NewRecords.Add();
					FillPropertyValues(NewRecord, OldRecord);
					NewRecord.Section = Selection.DeleteNewRef;
					If OldRecord.Section = OldRecord.Object Then
						NewRecord.Object = Selection.DeleteNewRef;
					EndIf;
				EndDo;
				OldRecords.Clear();
				InfobaseUpdate.WriteData(OldRecords, False);
				InfobaseUpdate.WriteData(NewRecords, False);
			EndIf;
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// 
Procedure AppendSettingsForGivenAddressees() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PeriodClosingDates.User,
	|	MAX(PeriodClosingDates.Comment) AS Comment
	|FROM
	|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
	|
	|GROUP BY
	|	PeriodClosingDates.User
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	UserGroupCompositions.User AS User,
	|	UserGroupCompositions.UsersGroup AS UsersGroup
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		INNER JOIN InformationRegister.PeriodClosingDates AS PeriodClosingDates
	|		ON UserGroupCompositions.UsersGroup = PeriodClosingDates.User
	|			AND (UserGroupCompositions.UsersGroup <> UserGroupCompositions.User)
	|;
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PeriodClosingDates.User AS User,
	|	PeriodClosingDates.Section AS Section,
	|	PeriodClosingDates.Object AS Object,
	|	PeriodClosingDates.PeriodEndClosingDate AS PeriodEndClosingDate,
	|	PeriodClosingDates.PeriodEndClosingDateDetails AS PeriodEndClosingDateDetails
	|FROM
	|	InformationRegister.PeriodClosingDates AS PeriodClosingDates";
	
	Block = New DataLock;
	Block.Add("InformationRegister.PeriodClosingDates");
	
	BeginTransaction();
	Try
		Block.Lock();
		QueryResults = Query.ExecuteBatch();
		SettingsAddressees    = QueryResults[0].Unload();
		UserGroups = QueryResults[1].Unload();
		Settings           = QueryResults[2].Unload();
		RecordSet = InformationRegisters.PeriodClosingDates.CreateRecordSet();
		AddSettings(RecordSet, Settings, SettingsAddressees, UserGroups, True);
		AddSettings(RecordSet, Settings, SettingsAddressees, UserGroups, False);
		InfobaseUpdate.WriteRecordSet(RecordSet, False);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// For the PeriodEndClosingDatesCheckDisabled function.
Function PeriodEndClosingNotUsed(PeriodClosingCheck, ImportRestrictionCheckNode)
	
	If InfobaseUpdate.InfobaseUpdateRequired() Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	
	EffectiveClosingDates = EffectiveClosingDates();
	
	If (Not EffectiveClosingDates.PeriodClosingUsed
	      Or PeriodClosingCheck = False)
	   And (Not EffectiveClosingDates.ImportRestrictionUsed
	      Or ImportRestrictionCheckNode = Undefined) Then
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// For the ChangeOrImportRestricted function.
Function DataToCheckFromDatabase(Data, DataID, EffectiveDates, ImportRestrictionCheckNode)
	
	If TypeOf(DataID) = Type("Filter") Then
		If TypeOf(Data) = Type("String") Then
			MetadataObject = Common.MetadataObjectByFullName(Data);
		Else
			MetadataObject = Data.Metadata();
		EndIf;
	Else
		MetadataObject = DataID.Metadata();
	EndIf;
	
	Table = MetadataObject.FullName();
	
	DataToCheck = PeriodClosingDates.DataToCheckTemplate();
	PeriodClosingDatesOverridable.BeforeCheckOldDataVersion(MetadataObject, DataID,
		ImportRestrictionCheckNode, DataToCheck);
		
	If DataToCheck.Count() > 0 Then
		Return DataToCheck;
	EndIf;
	
	NoObject = ?(ImportRestrictionCheckNode = Undefined,
		EffectiveDates.ForUsers.ClosingDatesByObjectsNotSpecified,
		EffectiveDates.ForInfobases.ClosingDatesByObjectsNotSpecified);
		
	DataSources = ReceiveDataSources(EffectiveDates, Table);
	
	DataToCheck = PeriodClosingDates.DataToCheckTemplate();
	Query = New Query;
	If NoObject Then
		Query.Text = DataSources.QueryTextDatesOnly;
	Else
		Query.Text = DataSources.QueryText;
	EndIf;
	If DataSources.IsRegister Then
		InsertParametersAndFilterCriterion(Query, DataID);
	Else
		Query.SetParameter("Ref", DataID);
	EndIf;
	QueryResults = Query.ExecuteBatch();
	For Each DataSource In DataSources.Content Do
		Selection = QueryResults[DataSources.Content.Find(DataSource)].Select();
		While Selection.Next() Do
			// 
			AddDataStringFromDatabase(Selection, DataSource, DataToCheck, NoObject);
		EndDo;
	EndDo;
	
	Return DataToCheck;
	
EndFunction

// For the DataToCheckFromDatabase procedure.
// Converts Filter to the condition of query language and inserts into the query.
//
// Parameters:
//  Query - Query
//  Filter  - Filter
//
Procedure InsertParametersAndFilterCriterion(Query, Filter)
	
	Condition = "";
	For Each FilterElement In Filter Do
		If FilterElement.Use Then
			If Not IsBlankString(Condition) Then
				Condition = Condition + Chars.LF + "And ";
			EndIf;
			Query.SetParameter(FilterElement.Name, FilterElement.Value);
			Condition = Condition
				+ "CurrentTable." + FilterElement.Name + " = &" + FilterElement.Name;
		EndIf;
	EndDo;
	Condition = ?(ValueIsFilled(Condition), Condition, "True");
	Query.Text = StrReplace(Query.Text, "&FilterCriterion", Condition);
	
EndProcedure

// For the ChangeOrImportRestricted function.
Function DataForCheckFromObject(Data, EffectiveDates, ImportRestrictionCheckNode)
	
	FieldValues = New Structure;
	MetadataObject = Data.Metadata();
	
	DataToCheck = PeriodClosingDates.DataToCheckTemplate();
	PeriodClosingDatesOverridable.BeforeCheckNewDataVersion(MetadataObject, Data,
		ImportRestrictionCheckNode, DataToCheck);
	
	If DataToCheck.Count() > 0 Then
		Return DataToCheck;
	EndIf;
	
	NoObject = ?(ImportRestrictionCheckNode = Undefined,
		EffectiveDates.ForUsers.ClosingDatesByObjectsNotSpecified,
		EffectiveDates.ForInfobases.ClosingDatesByObjectsNotSpecified);
	
	Table = MetadataObject.FullName();
	DataSources = ReceiveDataSources(EffectiveDates, Table);
	
	DataToCheck = PeriodClosingDates.DataToCheckTemplate();
	
	If DataSources.IsRegister Then
		FieldValues = Data.Unload(, DataSources.RegisterFields); //  ValueTable
		FieldValues.GroupBy(DataSources.RegisterFields);
		If FieldValues.Columns.Find("Recorder") <> Undefined
		   And Data.Filter.Find("Recorder") <> Undefined
		   And Common.IsInformationRegister(MetadataObject) Then
			FieldValues.FillValues(Data.Filter.Recorder.Value, "Recorder");
		EndIf;
		For Each String In FieldValues Do
			For Each DataSource In DataSources.Content Do
				// 
				AddDataString(String, String, DataSource, DataToCheck, NoObject);
			EndDo;
		EndDo;
	Else
		For Each DataSource In DataSources.Content Do
			
			If Not ValueIsFilled(DataSource.DateField.TabularSection)
			   And Not ValueIsFilled(DataSource.ObjectField.TabularSection) Then
				// 
				AddDataString(Data, Data, DataSource, DataToCheck, NoObject);
				
			ElsIf Not ValueIsFilled(DataSource.DateField.TabularSection) Then
				
				If NoObject Then
					// 
					AddDataString(Data, Undefined, DataSource, DataToCheck, NoObject);
				Else
					// 
					DateString = New Structure("Value", Simple(Data, DataSource.DateField));
					Field = DataSource.ObjectField.Name;
					ObjectValues = Data[DataSource.ObjectField.TabularSection].Unload(, Field); // ValueTable
					ObjectValues.GroupBy(Field);
					For Each ObjectString In ObjectValues Do
						// 
						AddDataString(DateString, ObjectString, DataSource, DataToCheck);
					EndDo;
				EndIf;
				
			ElsIf Not ValueIsFilled(DataSource.ObjectField.TabularSection) Then
				
				If Not NoObject Then
					// @skip-
					ObjectString = New Structure("Value", Simple(Data, DataSource.ObjectField));
				EndIf;
				Field = DataSource.DateField.Name;
				DateValues = Data[DataSource.DateField.TabularSection].Unload(, Field); // ValueTable
				DateValues.GroupBy(Field);
				For Each DateString In DateValues Do
					// 
					AddDataString(DateString, ObjectString, DataSource, DataToCheck, NoObject);
				EndDo;
			
			ElsIf DataSource.DateField.TabularSection = DataSource.ObjectField.TabularSection Then
				
				If NoObject Then
					Fields = DataSource.DateField.Name;
				Else
					Fields = DataSource.DateField.Name + "," + DataSource.ObjectField.Name;
				EndIf;
				Values = Data[DataSource.DateField.TabularSection].Unload(, Fields); // ValueTable
				Values.GroupBy(Fields);
				For Each String In Values Do
					// 
					AddDataString(String, String, DataSource, DataToCheck, NoObject);
				EndDo;
			Else
				Field = DataSource.DateField.Name;
				DateValues = Data[DataSource.DateField.TabularSection].Unload(, Field); // ValueTable
				DateValues.GroupBy(Field);
				
				If Not NoObject Then
					Field = DataSource.ObjectField.Name;
					ObjectValues = Data[DataSource.ObjectField.TabularSection].Unload(, Field); // ValueTable
					ObjectValues.GroupBy(Field);
				EndIf;
				
				For Each DateString In DateValues Do
					// @skip-
					DateString = New Structure("Value", Simple(DateString, DataSource.DateField));
					If NoObject Then
						// 
						AddDataString(DateString, Undefined, DataSource, DataToCheck, NoObject);
					Else
						For Each ObjectString In ObjectValues Do
							// 
							AddDataString(DateString, ObjectString, DataSource, DataToCheck);
						EndDo;
					EndIf;
				EndDo;
			EndIf;
		EndDo;
	EndIf;
	
	Return DataToCheck;
	
EndFunction

// For procedures DataToCheckFromDatabase, DataForCheckFromObject.
// 
// Parameters:
//  EffectiveDates - FixedStructure
//  Table - String
// Returns:
//  FixedStructure:
//    * Content - FixedArray of See DataSourceDescription
//    * QueryText - String
//    * QueryTextDatesOnly - String
//    * IsRegister - Boolean
// 
Function ReceiveDataSources(EffectiveDates, Table)
	
	DataSources = EffectiveDates.DataSources.Get(Table);
	
	If DataSources = Undefined
	 Or DataSources.Count() = 0 Then
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'In procedure ""%2""
			           |of common module ""%3"",
			           |table ""%1"" is missing the data source
			           |required for checking restriction dates.';"),
			Table,
			"FillDataSourcesForPeriodClosingCheck",
			"PeriodClosingDatesOverridable");
		Raise ErrorText;
	EndIf;
	
	Return DataSources;
	
EndFunction

// For the DataToCheckFromDatabase function.
Procedure AddDataStringFromDatabase(String, DataSource, DataToCheck, NoObject)
	
	NewRow = DataToCheck.Add();
	NewRow.Section = DataSource.Section;
	DateField = New Structure("Name, Path", "Date", DataSource.DateField.Path);
	NewRow.Date = Simple(String, DateField);
	
	If NoObject Or Not ValueIsFilled(DataSource.ObjectField.Name) Then
		Return;
	EndIf;
	
	ObjectField = New Structure("Name, Path", "Object", DataSource.ObjectField.Path);
	NewRow.Object = Simple(String, ObjectField);
	
EndProcedure

// For the DataForCheckFromObject procedure.
Procedure AddDataString(DateString, ObjectString, DataSource, DataToCheck, NoObject = False)
	
	NewRow = DataToCheck.Add();
	NewRow.Section = DataSource.Section;
	NewRow.Date = Simple(DateString, DataSource.DateField);
	
	If NoObject Or Not ValueIsFilled(DataSource.ObjectField.Name) Then
		Return;
	EndIf;
	
	NewRow.Object = Simple(ObjectString, DataSource.ObjectField);
	
EndProcedure

// For the AddDataString procedure.
Function Simple(FieldValues, Field)
	
	If TypeOf(FieldValues) = Type("Structure") Then
		Return FieldValues.Value;
	EndIf;
	
	If Not ValueIsFilled(Field.Path) Then
		Return FieldValues[Field.Name];
	EndIf;
	
	QueryText =
	"SELECT
	|	CurrentTable.PathsField AS Value
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	CurrentTable.Ref = &CurrentRef";
	
	PathFields = StrSplit(Field.Path, ".", False);
	CurrentRef = FieldValues[Field.Name];
	
	For Each PathsField In PathFields Do
		RefMetadata = Metadata.FindByType(TypeOf(CurrentRef));
		If RefMetadata = Undefined Then
			Return Undefined;
		EndIf;
		Table = RefMetadata.FullName();
		HeaderFields = PeriodClosingDatesInternalCached.HeaderFields(Table);
		If Not HeaderFields.Property(PathsField) Then
			Return Undefined;
		EndIf;
		Query = New Query;
		Query.Text = StrReplace(QueryText, "PathsField", PathsField);
		Query.Text = StrReplace(Query.Text, "&CurrentTable", Table);
		Query.SetParameter("CurrentRef", CurrentRef);
		// 
		Selection = Query.Execute().Select();
		If Not Selection.Next() Then
			Return Undefined;
		EndIf;
		CurrentRef = Selection.Value;
	EndDo;
	
	Return Selection.Value;
	
EndFunction

// For the SessionParametersSetting procedure.
// 
// Returns:
//  FixedStructure:
//    * Version - UUID
//    * UserGroups - FixedMap
//    * ForInfobases - See SetDates
//    * ForUsers - See SetDates
//    * ImportRestrictionUsed - Boolean
//    * PeriodClosingUsed - Boolean
//    * DataSources - FixedMap
//    * BegOfDay - Date
//    * SectionsProperties - See SectionsProperties
// 
Function SessionParameterValueEffectivePeriodClosingDates() Export
	
	// 
	// 
	
	BegOfDay = BegOfDay(CurrentSessionDate());
	
	EffectiveDates = New Structure;
	EffectiveDates.Insert("BegOfDay", BegOfDay);
	
	AddresseesTypes = Metadata.DefinedTypes.PeriodClosingTarget.Type.Types();
	NodesAddresseesTypes = New Array;
	UsersAddresseesTypes = New Array;
	For Each AddresseesType In AddresseesTypes Do
		MetadataObject = Metadata.FindByType(AddresseesType);
		If Metadata.ExchangePlans.Contains(MetadataObject) Then
			NodesAddresseesTypes.Add(AddresseesType);
		ElsIf AddresseesType <> Type("EnumRef.PeriodClosingDatesPurposeTypes") Then
			UsersAddresseesTypes.Add(AddresseesType);
		EndIf;
	EndDo;
	
	EffectiveDates.Insert("SectionsProperties", CurrentSectionsProperties(NodesAddresseesTypes));
	
	If Common.SeparatedDataUsageAvailable() Then
		QueryResults = PeriodClosingDatesRequest().ExecuteBatch();
		
		ConstantValues = QueryResults[0].Unload()[0];
		EffectiveDates.Insert("Version",                      ConstantValues.PeriodClosingDatesVersion);
		EffectiveDates.Insert("PeriodClosingUsed", ConstantValues.UsePeriodClosingDates);
		EffectiveDates.Insert("ImportRestrictionUsed",  ConstantValues.UseImportForbidDates);
		
		Upload0 = QueryResults[1].Unload(QueryResultIteration.ByGroups);
		UserGroups = New Map;
		For Each String In Upload0.Rows Do
			UserGroups.Insert(String.User,
				New FixedArray(String.Rows.UnloadColumn("UsersGroup")));
		EndDo;
		EffectiveDates.Insert("UserGroups", New FixedMap(UserGroups));
		
		EffectiveDates.Insert("ForUsers",     SetDates(QueryResults[2], BegOfDay));
		EffectiveDates.Insert("ForInfobases", SetDates(QueryResults[3], BegOfDay));
	Else
		EffectiveDates.Insert("Version", CommonClientServer.BlankUUID());
		EffectiveDates.Insert("PeriodClosingUsed", False);
		EffectiveDates.Insert("ImportRestrictionUsed",  False);
		EffectiveDates.Insert("UserGroups", New FixedMap(New Map));
		SetDates = New Structure;
		SetDates.Insert("SMSMessageRecipients", New FixedMap(New Map));
		SetDates.Insert("ClosingDatesByObjectsNotSpecified", True);
		EffectiveDates.Insert("ForUsers",     New FixedStructure(SetDates));
		EffectiveDates.Insert("ForInfobases", New FixedStructure(SetDates));
	EndIf;
	
	If EffectiveDates.ForUsers.SMSMessageRecipients.Count() = 0 Then
		EffectiveDates.PeriodClosingUsed = False;
	EndIf;
	
	If EffectiveDates.ForInfobases.SMSMessageRecipients.Count() = 0
	 Or NodesAddresseesTypes.Count() = 0 Then
		
		EffectiveDates.ImportRestrictionUsed = False;
	EndIf;
	
	EffectiveDates.Insert("DataSources", 
		CurrentDataSourceForPeriodClosingCheck(EffectiveDates.SectionsProperties));
	
	Return New FixedStructure(EffectiveDates);
	
EndFunction

// For the PeriodEndClosingFound function.

Function FindPeriodEndClosingDate(Sections, Data, BlankSection)
	
	RestrictionSection = Data.Section;
	RestrictionObject = Data.Object;
	PeriodEndClosingDate = Undefined;
	
	Objects = Sections.Get(RestrictionSection);
	If Objects <> Undefined Then
		// 
		PeriodEndClosingDate = Objects.Get(RestrictionObject);
		If PeriodEndClosingDate = Undefined Then
			RestrictionObject = RestrictionSection;
			// 
			PeriodEndClosingDate = Objects.Get(RestrictionObject);
		EndIf;
	EndIf;
	
	If PeriodEndClosingDate = Undefined Then
		RestrictionSection = BlankSection;
		RestrictionObject = BlankSection;
		Objects = Sections.Get(RestrictionSection);
		If Objects <> Undefined Then
			// 
			PeriodEndClosingDate = Objects.Get(RestrictionObject);
		EndIf;
	EndIf;
	
	If PeriodEndClosingDate = Undefined Then
		Return Undefined;
	EndIf;
	
	SearchResult = New Structure;
	SearchResult.Insert("RestrictionSection", RestrictionSection);
	SearchResult.Insert("RestrictionObject", RestrictionObject);
	SearchResult.Insert("PeriodEndClosingDate", PeriodEndClosingDate);
	
	Return SearchResult;
	
EndFunction

Function PeriodEndMessages(PeriodEnds, PeriodEndMessageParameters, SectionsProperties, SearchImportRestrictions, StructuralDetails)
	
	NewVersion = PeriodEndMessageParameters.NewVersion;
	Text = DataPresentation(PeriodEndMessageParameters.Data);
	
	If StructuralDetails Then
		ErrorDescription = New Structure;
		ErrorDescription.Insert("DataPresentation", Text);
		ErrorDescription.Insert("PeriodEnds", New ValueTable);
		Columns = ErrorDescription.PeriodEnds.Columns;
		Columns.Add("Date",            New TypeDescription("Date",,,,,New DateQualifiers(DateFractions.Date)));
		Columns.Add("Section",          New TypeDescription("String",,,,New StringQualifiers(100, AllowedLength.Variable)));
		Columns.Add("Object",          Metadata.ChartsOfCharacteristicTypes.PeriodClosingDatesSections.Type);
		Columns.Add("PeriodEndClosingDate",     New TypeDescription("Date",,,,,New DateQualifiers(DateFractions.Date)));
		Columns.Add("SingleDate",       New TypeDescription("Boolean"));
		Columns.Add("ForAllObjects", New TypeDescription("Boolean"));
		Columns.Add("Addressee",         Metadata.DefinedTypes.PeriodClosingTarget.Type);
		Columns.Add("LongDesc",        New TypeDescription("String",,,,New StringQualifiers(1000,AllowedLength.Variable)));
	EndIf;
	
	If ValueIsFilled(Text) Then
		If SearchImportRestrictions Then
			If NewVersion Then
				Template = NStr("en = 'Cannot import %1 after period-end closing date.';");
			Else
				Template = NStr("en = 'Imported data cannot replace %1 after period-end closing date.';");
			EndIf;
		Else
			If NewVersion Then
				Template = NStr("en = 'Cannot store %1 after period-end closing date.';");
			ElsIf IsDataSetDeletion(PeriodEndMessageParameters.Data) Then
				Template = NStr("en = 'Cannot delete %1 after period-end closing date.';");
			Else
				Template = NStr("en = 'Cannot change %1 after period-end closing date.';");
			EndIf;
		EndIf;
		Text = StringFunctionsClientServer.SubstituteParametersToString(Template, Text) + Chars.LF;
		If Not StructuralDetails Then
			Text = Text + "[HeaderSeparator]";
		EndIf;
		
	EndIf;
	
	BlankSection = EmptyRef(Type("ChartOfCharacteristicTypesRef.PeriodClosingDatesSections"));
	
	If StructuralDetails Then
		ErrorDescription.Insert("ErrorTitle", TrimAll(Text));
	Else
		ErrorText = Text;
	EndIf;
	
	AddedTexts = New Map;
	For Each Prohibition In PeriodEnds Do
		Text = PeriodEndMessage(Prohibition, SearchImportRestrictions, SectionsProperties, BlankSection);
		
		If StructuralDetails Then
			Text = StrReplace(Text, "[SeparatorReadMore]", "");
			
			Validation = Prohibition.Data;
			SectionProperties = SectionsProperties.Sections.Get(Validation.Section); // See ChartsOfCharacteristicTypes.PeriodClosingDatesSections.SectionProperties
			
			ErrorDescriptionString = ErrorDescription.PeriodEnds.Add();
			ErrorDescriptionString.Date        = Validation.Date;
			ErrorDescriptionString.Section      = SectionProperties.Name;
			ErrorDescriptionString.Object      = ?(Validation.Object = Validation.Section, Undefined, Validation.Object);
			ErrorDescriptionString.PeriodEndClosingDate = Prohibition.Date;
			ErrorDescriptionString.SingleDate   = ?(ValueIsFilled(Prohibition.Section), False, True);
			ErrorDescriptionString.ForAllObjects = (Prohibition.Section = Prohibition.Object);
			ErrorDescriptionString.Addressee  = Prohibition.Addressee;
			ErrorDescriptionString.LongDesc = Text;
		ElsIf AddedTexts.Get(Text) = Undefined Then
			AddedTexts.Insert(Text, True);
			ErrorText = ErrorText + Text + "[MessageSeparator]";
		EndIf;
	EndDo;
	
	If Not StructuralDetails Then
		
		HeaderSeparator     = "";
		SeparatorReadMore = "";
		MessageSeparator  = "";
		
		If AddedTexts.Count() > 1 Then
			HeaderSeparator    = Chars.LF;
			MessageSeparator = Chars.LF + Chars.LF;
		Else
			SeparatorReadMore = Chars.LF;
		EndIf;
		
		ErrorText = StrReplace(ErrorText, "[HeaderSeparator]",     HeaderSeparator);
		ErrorText = StrReplace(ErrorText, "[SeparatorReadMore]", SeparatorReadMore);
		ErrorText = StrReplace(ErrorText, "[MessageSeparator]",  MessageSeparator);
		
		ErrorDescription = TrimR(ErrorText);
	EndIf;
	
	Return ErrorDescription;
	
EndFunction

Function PeriodEndMessage(Val Prohibition, Val SearchImportRestrictions, Val SectionsProperties, Val BlankSection)
	
	If Prohibition.Section = Prohibition.Object Then
		ByObject = False;
		BySection = Prohibition.Section <> BlankSection;
	Else
		ByObject = True;
		BySection = Not ValueIsFilled(SectionsProperties.SingleSection);
	EndIf;
	
	ForUnspecifiedOne = False;
	ForUser = False;
	ForUsersGroup = False;
	ForAllUsers = False;
	ForInfobase = False;
	ForAllPlanIBs = False;
	ForAllIBs = False;
	
	If Prohibition.Addressee = Enums.PeriodClosingDatesPurposeTypes.ForAllUsers Then
		ForAllUsers = True;
		
	ElsIf Prohibition.Addressee = Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases Then
		ForAllIBs = True;
		
	ElsIf TypeOf(Prohibition.Addressee) = Type("CatalogRef.UserGroups")
		Or TypeOf(Prohibition.Addressee) = Type("CatalogRef.ExternalUsersGroups") Then
		
		ForUsersGroup = True;
		
	ElsIf TypeOf(Prohibition.Addressee) = Type("CatalogRef.Users") Then
		
		If Prohibition.Addressee = Users.UnspecifiedUserRef() Then
			ForUnspecifiedOne = True;
		Else
			ForUser = True;
		EndIf;
		
	ElsIf TypeOf(Prohibition.Addressee) = Type("CatalogRef.ExternalUsers") Then
		ForUser = True;
		
	ElsIf ValueIsFilled(Prohibition.Addressee) Then
		ForInfobase = True;
	Else
		ForAllPlanIBs = True;
	EndIf;
	
	If Not SearchImportRestrictions Then
		If      Not BySection And Not ByObject And ForUnspecifiedOne Then
			
			Text = NStr("en = 'Cannot change data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|Change is not available since date %1 falls within the closed period for %5';");
			
		ElsIf    BySection And Not ByObject And ForUnspecifiedOne Then
			
			Text = NStr("en = 'Cannot change data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|Change is not available for the ""%2"" section
			|since date %1 falls within the closed period for %5';");
			
		ElsIf Not BySection And    ByObject And ForUnspecifiedOne Then
			
			Text = NStr("en = 'Cannot change data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|Change is not available for the ""%3"" object
			|since date %1 falls within the closed period for %5';");
			
		ElsIf    BySection And    ByObject And ForUnspecifiedOne Then
			
			Text = NStr("en = 'Cannot change data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|Change is not available for the ""%3"" object of the ""%2"" section
			|since date %1 falls within the closed period for %5';");
		
		ElsIf Not BySection And Not ByObject And ForUser Then
			
			Text = NStr("en = 'Cannot change data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|Change is not available for the ""%4"" user
			|since date %1 falls within the closed period for %5';");
			
		ElsIf    BySection And Not ByObject And ForUser Then
			
			Text = NStr("en = 'Cannot change data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|The ""%4"" user cannot change the ""%2"" section
			|since date %1 falls within the closed period for %5';");
			
		ElsIf Not BySection And    ByObject And ForUser Then
			
			Text = NStr("en = 'Cannot change data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|The ""%4"" user cannot change the ""%3"" object
			|since date %1 falls within the closed period for %5';");
			
		ElsIf    BySection And    ByObject And ForUser Then
			
			Text = NStr("en = 'Cannot change data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|The ""%4"" user cannot change the ""%3"" object of the ""%2"" section
			|since date %1 falls within the closed period for %5';");
		
		ElsIf Not BySection And Not ByObject And ForUsersGroup Then
			
			Text = NStr("en = 'Cannot change data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|Change is not available for the ""%4"" user group
			|since date %1 falls within the closed period for %5';");
			
		ElsIf    BySection And Not ByObject And ForUsersGroup Then
			
			Text = NStr("en = 'Cannot change data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|The ""%4"" user group cannot change the ""%2"" section
			|since date %1 falls within the closed period for %5';");
			
		ElsIf Not BySection And    ByObject And ForUsersGroup Then
			
			Text = NStr("en = 'Cannot change data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|The ""%4"" user group cannot change the ""%3"" object
			|since date %1 falls within the closed period for %5';");
			
		ElsIf    BySection And    ByObject And ForUsersGroup Then
			
			Text = NStr("en = 'Cannot change data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|The ""%4"" user group cannot change the ""%3"" object of the ""%2"" section
			|since date %1 falls within the closed period for %5';");
			
		ElsIf Not BySection And Not ByObject And ForAllUsers Then
			
			Text = NStr("en = 'Cannot change data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|Change is not available for all users
			|since date %1 falls within the closed period for %5';");
			
		ElsIf    BySection And Not ByObject And ForAllUsers Then
			
			Text = NStr("en = 'Cannot change data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|All users cannot change the ""%2"" section
			|since date %1 falls within the closed period for %5';");
			
		ElsIf Not BySection And    ByObject And ForAllUsers Then
			
			Text = NStr("en = 'Cannot change data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|All users cannot change the ""%3"" object
			|since date %1 falls within the closed period for %5';");
			
		ElsIf    BySection And    ByObject And ForAllUsers Then
			
			Text = NStr("en = 'Cannot change data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|All users cannot change the ""%3"" object of the ""%2"" section
			|since date %1 falls within the closed period for %5';");
			
		EndIf;
	Else
		If      Not BySection And Not ByObject And ForInfobase Then
			
			Text = NStr("en = 'Cannot import data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|Data import is not allowed for the ""%4"" infobase
			|since date %1 falls within the closed period for %5';");
			
		ElsIf    BySection And Not ByObject And ForInfobase Then
			
			Text = NStr("en = 'Cannot import data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|Importing data on the ""%2"" section is not allowed for the ""%4"" infobase
			|since date %1 falls within the closed period for %5';");
			
		ElsIf Not BySection And    ByObject And ForInfobase Then
			
			Text = NStr("en = 'Cannot import data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|Importing data on the ""%3"" object is not allowed for the ""%4"" infobase
			|since date %1 falls within the closed period for %5';");
			
		ElsIf    BySection And    ByObject And ForInfobase Then
			
			Text = NStr("en = 'Cannot import data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|Importing data on the ""%3"" object of the ""%2"" section is not allowed for the ""%4"" infobase
			|since date %1 falls within the closed period for %5';");
		
		ElsIf Not BySection And Not ByObject And ForAllPlanIBs Then
			
			Text = NStr("en = 'Cannot import data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|Data import is not allowed for all ""%6"" infobases
			|since date %1 falls within the closed period for %5';");
			
		ElsIf    BySection And Not ByObject And ForAllPlanIBs Then
			
			Text = NStr("en = 'Cannot import data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|Importing data on the ""%2"" section is not allowed for all ""%6"" infobases
			|since date %1 falls within the closed period for %5';");
			
		ElsIf Not BySection And    ByObject And ForAllPlanIBs Then
			
			Text = NStr("en = 'Cannot import data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|Importing data on the ""%3"" object is not allowed for all ""%6"" infobases
			|since date %1 falls within the closed period for %5';");
			
		ElsIf    BySection And    ByObject And ForAllPlanIBs Then
			
			Text = NStr("en = 'Cannot import data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|Importing data on the ""%3"" object of the ""%2"" section is not allowed for all ""%6"" infobases
			|since date %1 falls within the closed period for %5';");
			
		
		ElsIf Not BySection And Not ByObject And ForAllIBs Then
			
			Text = NStr("en = 'Cannot import data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|Data import is not allowed for all infobases
			|since date %1 falls within the closed period for %5';");
			
		ElsIf    BySection And Not ByObject And ForAllIBs Then
			
			Text = NStr("en = 'Cannot import data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|Importing data on the ""%2"" section is not allowed for all infobases
			|since date %1 falls within the closed period for %5';");
			
		ElsIf Not BySection And    ByObject And ForAllIBs Then
			
			Text = NStr("en = 'Cannot import data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|Importing data on the ""%3"" object is not allowed for all infobases
			|since date %1 falls within the closed period for %5';");
			
		ElsIf    BySection And    ByObject And ForAllIBs Then
			
			Text = NStr("en = 'Cannot import data with a date earlier than %5 (inclusive).
			|[SeparatorReadMore]Details:
			|Importing data on the ""%3"" object of the ""%2"" section is not allowed for all infobases
			|since date %1 falls within the closed period for %5';");
			
		EndIf;
	EndIf;
	
	If Not SectionsProperties.NoSectionsAndObjects Then
		If ValueIsFilled(Prohibition.Section) Then
			If Prohibition.Object = Prohibition.Section Then
				Text = Text + " " + NStr("en = 'The restriction is applied to section %2.';");
			ElsIf ValueIsFilled(SectionsProperties.SingleSection) Then
				Text = Text + " " + NStr("en = 'The restriction is applied to object %3.';");
			Else
				Text = Text + " " + NStr("en = 'The restriction is applied to object %3 of section %2.';");
			EndIf;
		Else
			Text = Text + " " + NStr("en = 'Common-date restriction is applied.';");
		EndIf;
	EndIf;
	
	Validation = Prohibition.Data;
	Text = StrReplace(Text, "%1", Format(Validation.Date, "DLF=D"));
	Text = StrReplace(Text, "%2", Validation.Section);
	Text = StrReplace(Text, "%3", Validation.Object);
	Text = StrReplace(Text, "%4", Prohibition.Addressee);
	Text = StrReplace(Text, "%5", Format(Prohibition.Date, "DLF=D"));
	Text = StrReplace(Text, "%6", Prohibition.Addressee.Metadata().Presentation());
	Return Text;

EndFunction

// For the PeriodEndMessage function.
Function DataPresentation(Data)
	
	If TypeOf(Data) = Type("String") Then
		Return TrimAll(Data);
	EndIf;
	
	If TypeOf(Data) = Type("Structure") Then
		IsRegister = True;
		If TypeOf(Data.Register) = Type("String") Then
			MetadataObject = Common.MetadataObjectByFullName(Data.Register);
		Else
			MetadataObject = Metadata.FindByType(TypeOf(Data.Register));
		EndIf;
	Else
		MetadataObject = Metadata.FindByType(TypeOf(Data));
		IsRegister = Common.IsRegister(MetadataObject);
	EndIf;
	
	If MetadataObject = Undefined Then
		Return "";
	EndIf;
	
	If IsRegister Then
		DataPresentation = MetadataObject.Presentation();
		
		FieldsCount = 0;
		For Each FilterElement In Data.Filter Do
			If FilterElement.Use Then
				FieldsCount = FieldsCount + 1;
			EndIf;
		EndDo;
		
		If FieldsCount = 1 Then
			DataPresentation = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 with field %2';"),
				DataPresentation, String(Data.Filter));
			
		ElsIf FieldsCount > 1 Then
			DataPresentation = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 with fields %2';"),
				DataPresentation, String(Data.Filter));
		EndIf;
	Else
		DataPresentation = Common.SubjectString(Data);
	EndIf;
		
	Return DataPresentation;
	
EndFunction

// For the PeriodEndMessage function.
Function IsDataSetDeletion(Data)
	
	If TypeOf(Data) = Type("Structure") And TypeOf(Data.Register) <> Type("String") Then
		Return Data.Register.Count() = 0; // 
	EndIf;
	Return False;
	
EndFunction

// For the SessionParameterValueEffectivePeriodClosingDates procedure.

Function PeriodClosingDatesRequest()
	
	// 
	// 
	Query = New Query;
	Query.Text =
	"SELECT
	|	Constants.PeriodClosingDatesVersion AS PeriodClosingDatesVersion,
	|	Constants.UseImportForbidDates AS UseImportForbidDates,
	|	Constants.UsePeriodClosingDates AS UsePeriodClosingDates
	|FROM
	|	Constants AS Constants
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	UserGroupCompositions.User AS User,
	|	UserGroupCompositions.UsersGroup AS UsersGroup,
	|	PeriodClosingDates.Comment AS Comment,
	|	ISNULL(UserGroupCompositions.UsersGroup.Description, """") AS GroupDescription
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		INNER JOIN InformationRegister.PeriodClosingDates AS PeriodClosingDates
	|		ON UserGroupCompositions.UsersGroup = PeriodClosingDates.User
	|			AND (UserGroupCompositions.UsersGroup <> UserGroupCompositions.User)
	|
	|ORDER BY
	|	User,
	|	Comment DESC,
	|	GroupDescription DESC
	|TOTALS BY
	|	User
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PeriodClosingDates.User AS User,
	|	PeriodClosingDates.Section AS Section,
	|	PeriodClosingDates.Object AS Object,
	|	PeriodClosingDates.PeriodEndClosingDateDetails AS PeriodEndClosingDateDetails,
	|	PeriodClosingDates.PeriodEndClosingDate AS PeriodEndClosingDate
	|FROM
	|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
	|WHERE
	|	(PeriodClosingDates.User = VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllUsers)
	|			OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.Users)
	|			OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.UserGroups)
	|			OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsers)
	|			OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsersGroups))
	|TOTALS BY
	|	User,
	|	Section
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PeriodClosingDates.User AS User,
	|	PeriodClosingDates.Section AS Section,
	|	PeriodClosingDates.Object AS Object,
	|	PeriodClosingDates.PeriodEndClosingDateDetails AS PeriodEndClosingDateDetails,
	|	PeriodClosingDates.PeriodEndClosingDate AS PeriodEndClosingDate
	|FROM
	|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
	|WHERE
	|	PeriodClosingDates.User <> UNDEFINED
	|	AND PeriodClosingDates.User <> VALUE(Enum.PeriodClosingDatesPurposeTypes.EmptyRef)
	|	AND PeriodClosingDates.User <> VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllUsers)
	|	AND VALUETYPE(PeriodClosingDates.User) <> TYPE(Catalog.Users)
	|	AND VALUETYPE(PeriodClosingDates.User) <> TYPE(Catalog.UserGroups)
	|	AND VALUETYPE(PeriodClosingDates.User) <> TYPE(Catalog.ExternalUsers)
	|	AND VALUETYPE(PeriodClosingDates.User) <> TYPE(Catalog.ExternalUsersGroups)
	|TOTALS BY
	|	User,
	|	Section";
	// ACC:1377-
	
	Return Query;
	
EndFunction

// Returns:
//  FixedStructure:
//   * ClosingDatesByObjectsNotSpecified - Boolean
//   * SMSMessageRecipients - FixedMap of KeyAndValue:
//      ** Key     - DefinedType.PeriodClosingTarget -
//      ** Value - FixedMap of KeyAndValue:
//          *** Key     - String -
//          *** Value - FixedMap of KeyAndValue:
//               **** Key     - Characteristic.PeriodClosingDatesSections - object.
//               **** Value - Date -
//  
Function SetDates(QueryResult, BegOfDay)
	
	Upload0 = QueryResult.Unload(QueryResultIteration.ByGroups);
	
	SMSMessageRecipients = New Map;
	ClosingDatesByObjectsNotSpecified = True;
	
	For Each Addressee In Upload0.Rows Do
		Sections = New Map;
		For Each Section In Addressee.Rows Do
			Objects = New Map;
			For Each Object In Section.Rows Do
				If Section.Section <> Object.Object Then
					ClosingDatesByObjectsNotSpecified = False;
				EndIf;
				Objects.Insert(Object.Object, PeriodEndClosingDateByDetails(
					Object.PeriodEndClosingDateDetails, Object.PeriodEndClosingDate, BegOfDay));
			EndDo;
			Sections.Insert(Section.Section, New FixedMap(Objects));
		EndDo;
		SMSMessageRecipients.Insert(Addressee.User, New FixedMap(Sections));
	EndDo;
	
	SetDates = New Structure;
	SetDates.Insert("SMSMessageRecipients", New FixedMap(SMSMessageRecipients));
	SetDates.Insert("ClosingDatesByObjectsNotSpecified", ClosingDatesByObjectsNotSpecified);
	
	Return New FixedStructure(SetDates);
	
EndFunction

Function CurrentSectionsProperties(NodesAddresseesTypes)
	
	Properties = New Structure;
	Properties.Insert("UseExternalUsers", False);
	
	PeriodClosingDatesOverridable.InterfaceSetup(Properties);
	
	Properties.Insert("ImportRestrictionDatesImplemented", NodesAddresseesTypes.Count() > 0);
	
	EmptyNodesRefs = New Array;
	
	For Each NodesAddresseesType In NodesAddresseesTypes Do
		EmptyNodeRef = EmptyRef(NodesAddresseesType);
		EmptyNodesRefs.Add(EmptyNodeRef);
	EndDo;
	
	Properties.Insert("EmptyExchangePlansNodesRefs", New FixedArray(EmptyNodesRefs));
	
	SectionsProperties = ChartsOfCharacteristicTypes.PeriodClosingDatesSections.ClosingDatesSectionsProperties();
	
	For Each KeyAndValue In SectionsProperties Do
		Properties.Insert(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	Return New FixedStructure(Properties);
	
EndFunction

// Parameters:
//  SectionsProperties - See SectionsProperties
//
// Returns:
//  FixedMap of KeyAndValue:
//   * Key - String -
//   * Value - See ReceiveDataSources
//
Function CurrentDataSourceForPeriodClosingCheck(SectionsProperties)
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return New FixedMap(New Map);
	EndIf;
	
	DataSources = New ValueTable;
	DataSources.Columns.Add("Table",     New TypeDescription("String"));
	DataSources.Columns.Add("DateField",    New TypeDescription("String"));
	DataSources.Columns.Add("Section",      New TypeDescription("String"));
	DataSources.Columns.Add("ObjectField", New TypeDescription("String"));
	DataSources.Indexes.Add("Table");
	
	SSLSubsystemsIntegration.OnFillDataSourcesForPeriodClosingCheck(DataSources);
	PeriodClosingDatesOverridable.FillDataSourcesForPeriodClosingCheck(DataSources);
	
	Sources = New Map;
	Tables = DataSources.Copy(, "Table");
	Tables.GroupBy("Table");
	
	ErrorTitle = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Error in procedure %1
		           |of common module %2.';"),
		"FillDataSourcesForPeriodClosingCheck",
		"PeriodClosingDatesOverridable")
		+ Chars.LF
		+ Chars.LF;
	
	For Each String In Tables Do
		TableSources = New Structure;
		MetadataObject = Common.MetadataObjectByFullName(String.Table);
		If MetadataObject = Undefined Then
			ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Period-end closing date check error. Data source contains invalid table:
				           |%1.';"),
				String.Table);
			Raise ErrorText;
		EndIf;
		IsRegister = StandardSubsystemsServer.IsRegisterTable(String.Table);
		TableSources.Insert("IsRegister", IsRegister);
		
		TableDataSources = DataSources.FindRows(New Structure("Table", String.Table));
		SourcesContent = New Array;
		RegisterFields = New Map;
		QueryText = "";
		QueryTextDatesOnly = "";
		Table = MetadataObject.FullName();
		
		For Each String In TableDataSources Do
			SectionProperties = SectionsProperties.Sections.Get(String.Section);
			If SectionProperties = Undefined Then
				ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Non-existent section ""%1"" for table ""%2"" is specified
					           |for checking period-end closing dates in data source.
					           | See %3.';"),
					String.Section,
					String.Table,
					"PeriodClosingDatesOverridable.FillDataSourcesForPeriodClosingCheck");
				Raise ErrorText;
			EndIf;
			
			Source = DataSourceDescription();
			Source.Section = String.Section;
			Source.DateField    = TableField(String, "DateField",    MetadataObject, IsRegister);
			Source.ObjectField = TableField(String, "ObjectField", MetadataObject, IsRegister);
			
			If IsRegister Then
				RegisterFields.Insert(Source.DateField.Name, True);
				If ValueIsFilled(Source.ObjectField.Name) Then
					AddQueryTextForRegister(QueryText, Table, Source);
					RegisterFields.Insert(Source.ObjectField.Name, True);
				Else
					AddQueryTextDatesOnlyForRegister(QueryText, Table, Source);
				EndIf;
				AddQueryTextDatesOnlyForRegister(QueryTextDatesOnly, Table, Source);
			Else
				If ValueIsFilled(Source.ObjectField.Name) Then
					AddQueryText(QueryText, Table, Source);
				Else
					AddQueryTextDatesOnly(QueryText, Table, Source);
				EndIf;
				AddQueryTextDatesOnly(QueryTextDatesOnly, Table, Source);
			EndIf;
			SourcesContent.Add(New FixedStructure(Source));
		EndDo;
		TableSources.Insert("Content", New FixedArray(SourcesContent));
		TableSources.Insert("QueryText", QueryText);
		TableSources.Insert("QueryTextDatesOnly", QueryTextDatesOnly);
		If IsRegister Then
			Fields = "";
			For Each KeyAndValue In RegisterFields Do
				Fields = Fields + "," + KeyAndValue.Key;
			EndDo;
			TableSources.Insert("RegisterFields", Mid(Fields, 2));
		EndIf;
		Sources.Insert(Table, New FixedStructure(TableSources));
	EndDo;
	
	Return New FixedMap(Sources);
	
EndFunction

// Returns:
//   Structure:
//     * Section - Arbitrary
//     * DateField - Structure:
//         ** Name - String
//         ** Path - String
//         ** TabularSection - String
//     * ObjectField - Structure:
//         ** Name - String
//         ** Path - String
//         ** TabularSection - String
// 
Function DataSourceDescription()
	
	DateField    = New Structure("Name, Path, TabularSection");
	ObjectField = New Structure("Name, Path, TabularSection");
	
	Source = New Structure;
	Source.Insert("Section",      Undefined);
	Source.Insert("DateField",    DateField);
	Source.Insert("ObjectField", ObjectField);
	
	Return Source;
	
EndFunction

// For the CurrentDataSourcesForPeriodClosingCheck function.

Function TableField(Source, FieldKind, MetadataObject, IsRegister)
	
	Properties = New Structure("Name, Path, TabularSection");
	
	Field = Source[FieldKind];
	Fields = StrSplit(Field, ".", False);
	
	If Fields.Count() = 0 Then
		If FieldKind = "DateField" Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Period-end closing date check error.
				           |Data source contains table with empty Date field:
				           |%1.';"),
				Source.Table);
			Raise ErrorText;
		Else
			Return New FixedStructure(Properties);
		EndIf;
		
	ElsIf Not ValueIsFilled(Fields[0]) Then
		If FieldKind = "DateField" Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Period-end closing date check error.
				           |Data source contains table %1 with invalid Date field:
				           |%2.';"),
				Source.Table, Field);
			Raise ErrorText;
		Else
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Period-end closing date check error.
				           |Data source contains table %1 with invalid Object field:
				           |%2.';"),
				Source.Table, Field);
			Raise ErrorText;
		EndIf;
	EndIf;
	
	If IsRegister
	 Or MetadataObject.TabularSections.Find(Fields[0]) = Undefined Then
		
		Properties.Name = Fields[0];
		PointPosition = StrFind(Field, ".");
		If PointPosition > 0 Then
			Properties.Path = Mid(Field, PointPosition + 1);
		EndIf;
		Return New FixedStructure(Properties);
	EndIf;
	
	If Fields.Count() = 1 Then
		If FieldKind = "DateField" Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Period-end closing date check error.
				           |Data source contains table %1 with invalid Date field:
				           |No field specified for tabular section:
				           |%2.';"),
				Source.Table, Fields[0]);
			Raise ErrorText;
		Else
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Period-end closing date check error.
				           |Data source contains table %1 with invalid Object field:
				           |No field specified for tabular section:
				           |%2.';"),
				Source.Table, Fields[0]);
			Raise ErrorText;
		EndIf;
	ElsIf Not ValueIsFilled(Fields[1]) Then
		If FieldKind = "DateField" Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Period-end closing date check error.
				           |Data source contains table %1 with invalid Date field:
				           |Tabular section contains invalid field:
				           |%2.';"),
				Source.Table, Fields[0]);
			Raise ErrorText;
		Else
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Period-end closing date check error.
				           |Data source contains table %1 with invalid Object field:
				           |Tabular section contains invalid field:
				           |%2.';"),
				Source.Table, Fields[0]);
			Raise ErrorText;
		EndIf;
	EndIf;
	
	Properties.TabularSection = Fields[0];
	Properties.Name = Fields[1];
	
	PointPosition = StrFind(Field, ".");
	NameAndPath = Mid(Field, PointPosition + 1);
	
	PointPosition = StrFind(NameAndPath, ".");
	If PointPosition > 0 Then
		Properties.Path = Mid(NameAndPath, PointPosition + 1);
	EndIf;
	
	Return New FixedStructure(Properties);
	
EndFunction

Procedure AddQueryText(QueryText, Table, Source)
	
	If Not ValueIsFilled(Source.DateField.TabularSection)
	   And Not ValueIsFilled(Source.ObjectField.TabularSection)
	 Or Source.DateField.TabularSection = Source.ObjectField.TabularSection Then
		
		If Source.DateField.TabularSection = Source.ObjectField.TabularSection Then
			CurrentTable = Table + "." + Source.DateField.TabularSection;
		Else
			CurrentTable = Table;
		EndIf;
		
		Text =
		"SELECT DISTINCT
		|	&DateField AS Date,
		|	&ObjectField AS Object
		|FROM
		|	&Table AS CurrentTable
		|WHERE
		|	CurrentTable.Ref = &Ref";
		Text = StrReplace(Text, "&Table",     CurrentTable);
		Text = StrReplace(Text, "&DateField",    "CurrentTable." + Source.DateField.Name);
		Text = StrReplace(Text, "&ObjectField", "CurrentTable." + Source.ObjectField.Name);
	Else
		If ValueIsFilled(Source.DateField.TabularSection) Then
			DateFieldsTable = Table + "." + Source.DateField.TabularSection;
		Else
			DateFieldsTable = Table;
		EndIf;
		
		If ValueIsFilled(Source.ObjectField.TabularSection) Then
			ObjectFieldsTable = Table + "." + Source.ObjectField.TabularSection;
		Else
			ObjectFieldsTable = Table;
		EndIf;
		
		Text =
		"SELECT DISTINCT
		|	&DateField AS Date,
		|	&ObjectField AS Object
		|FROM
		|	DateTable AS DateFieldsTable
		|		INNER JOIN ObjectTable AS ObjectFieldsTable
		|		ON (DateFieldsTable.Ref = &Ref)
		|			AND (ObjectFieldsTable.Ref = &Ref)";
		Text = StrReplace(Text, "DateTable",    DateFieldsTable);
		Text = StrReplace(Text, "ObjectTable", ObjectFieldsTable);
		Text = StrReplace(Text, "&DateField",    "DateFieldsTable."    + Source.DateField.Name);
		Text = StrReplace(Text, "&ObjectField", "ObjectFieldsTable." + Source.ObjectField.Name);
	EndIf;
	
	AddQueryTextToPackage(QueryText, Text);
	
EndProcedure

Procedure AddQueryTextDatesOnly(QueryText, Table, Source)
	
	If Not ValueIsFilled(Source.DateField.TabularSection) Then
		Text =
		"SELECT
		|	&DateField AS Date
		|FROM
		|	&Table AS CurrentTable
		|WHERE
		|	CurrentTable.Ref = &Ref";
		Text = StrReplace(Text, "&Table", Table);
		Text = StrReplace(Text, "&DateField", "CurrentTable." + Source.DateField.Name);
	Else
		If ValueIsFilled(Source.DateField.Path) Then
			Text =
			"SELECT DISTINCT
			|	&DateField AS Date
			|FROM
			|	&Table AS CurrentTable
			|WHERE
			|	CurrentTable.Ref = &Ref";
		Else
			Text =
			"SELECT TOP 1
			|	CAST(&DateField AS DATE) AS Date
			|FROM
			|	&Table AS CurrentTable
			|WHERE
			|	CurrentTable.Ref = &Ref
			|
			|ORDER BY
			|	Date";
		EndIf;
		Text = StrReplace(Text, "&Table", Table + "." + Source.DateField.TabularSection);
		Text = StrReplace(Text, "&DateField", "CurrentTable." + Source.DateField.Name);
	EndIf;
	
	AddQueryTextToPackage(QueryText, Text);
	
EndProcedure

Procedure AddQueryTextForRegister(QueryText, Table, Source)
	
	Text =
	"SELECT DISTINCT
	|	&DateField AS Date,
	|	&ObjectField AS Object
	|FROM
	|	&Table AS CurrentTable
	|WHERE
	|	&FilterCriterion";
	
	Text = StrReplace(Text, "&Table", Table);
	Text = StrReplace(Text, "&DateField",    "CurrentTable." + Source.DateField.Name);
	Text = StrReplace(Text, "&ObjectField", "CurrentTable." + Source.ObjectField.Name);
	
	AddQueryTextToPackage(QueryText, Text);
	
EndProcedure

Procedure AddQueryTextDatesOnlyForRegister(QueryText, Table, Source)
	
	If ValueIsFilled(Source.DateField.Path) Then
		Text =
		"SELECT DISTINCT
		|	&DateField AS Date
		|FROM
		|	&Table AS CurrentTable
		|WHERE
		|	&FilterCriterion";
	Else
		Text =
		"SELECT TOP 1
		|	CAST(&DateField AS DATE) AS Date
		|FROM
		|	&Table AS CurrentTable
		|WHERE
		|	&FilterCriterion
		|
		|ORDER BY
		|	Date";
	EndIf;
	
	Text = StrReplace(Text, "&Table", Table);
	Text = StrReplace(Text, "&DateField", "CurrentTable." + Source.DateField.Name);
	
	AddQueryTextToPackage(QueryText, Text);
	
EndProcedure

Procedure AddQueryTextToPackage(QueriesPackageText, QueryText)
	
	If Not ValueIsFilled(QueriesPackageText) Then
		QueriesPackageText = QueryText;
		Return;
	EndIf;
	
	QueriesPackageText = QueriesPackageText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|" + QueryText;
	
EndProcedure

// For procedures OnSendDataToMaster, OnSendDataToMaster.
// OnReceiveDataFromMaster, OnReceiveDataFromSlave.
//
Function RecordSetOnlyWithImportRestrictionDates(DataElement)
	
	If TypeOf(DataElement) <> Type("InformationRegisterRecordSet.PeriodClosingDates") Then
		Return False;
	EndIf;
	
	If Not DataElement.Filter.User.Use Then
		ErrorText =
			NStr("en = 'Period-end closing dates information register supports
			           |record import and export only by User dimension.';");
		Raise ErrorText;
	EndIf;
	
	Return Not IsPeriodClosingAddressee(DataElement.Filter.User.Value);
	
EndFunction

// 
Procedure AddSettings(RecordSet, Settings, SettingsAddressees, UserGroups, GroupsSettings)
	
	For Each SettingsAddressee In SettingsAddressees Do
		Addressee = SettingsAddressee.User;
		DestinationType = TypeOf(Addressee);
		AddresseeMetadataObject = Metadata.FindByType(DestinationType);
		IsExchangePlan = TypeOf(AddresseeMetadataObject) = Type("MetadataObject")
			And Metadata.ExchangePlans.Contains(AddresseeMetadataObject);
		If DestinationType = Type("EnumRef.PeriodClosingDatesPurposeTypes")
		 Or Not ValueIsFilled(Addressee)
		   And Not IsExchangePlan
		 Or GroupsSettings
		   And Not (    TypeOf(Addressee) = Type("CatalogRef.Users")
		         Or TypeOf(Addressee) = Type("CatalogRef.ExternalUsers")
		         Or IsExchangePlan
		           And ValueIsFilled(Addressee)) Then
			Continue;
		EndIf;
		
		If Not GroupsSettings Then
			Filter = New Structure("User", ?(IsExchangePlan,
				Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases,
				Enums.PeriodClosingDatesPurposeTypes.ForAllUsers));
			AdditionalSettings = Settings.FindRows(Filter);
			
		ElsIf TypeOf(Addressee) <> Type("CatalogRef.Users")
		        And TypeOf(Addressee) <> Type("CatalogRef.ExternalUsers") Then
			
			Types = CommonClientServer.ValueInArray(DestinationType);
			TypeDescription = New TypeDescription(Types);
			EmptyNode = TypeDescription.AdjustValue(Undefined);
			Filter = New Structure("User", EmptyNode);
			AdditionalSettings = Settings.FindRows(Filter);
		Else
			Filter = New Structure("User", Addressee);
			Rows = UserGroups.FindRows(Filter);
			AdditionalSettings = Settings.Copy(New Array);
			For Each String In Rows Do
				Filter = New Structure("User", String.UsersGroup);
				SettingsOfGroup = Settings.FindRows(Filter);
				For Each GroupSetting In SettingsOfGroup Do
					Filter = New Structure("Section, Object", GroupSetting.Section, GroupSetting.Object);
					ExistingSettings1 = AdditionalSettings.FindRows(Filter);
					If ExistingSettings1.Count() > 0 Then
						ExistingSetting = ExistingSettings1[0];
						If IsRestrictionDateEarlier(GroupSetting, ExistingSetting) Then
							Continue;
						Else
							AdditionalSettings.Delete(ExistingSetting);
						EndIf;
					EndIf;
					FillPropertyValues(AdditionalSettings.Add(), GroupSetting);
				EndDo;
			EndDo;
		EndIf;
		
		For Each String In AdditionalSettings Do
			Filter = New Structure("User, Section, Object",
				SettingsAddressee.User, String.Section, String.Object);
			If Settings.FindRows(Filter).Count() > 0 Then
				Continue;
			EndIf;
			NewRow = RecordSet.Add();
			FillPropertyValues(NewRow, String);
			FillPropertyValues(NewRow, SettingsAddressee);
			FillPropertyValues(Settings.Add(), NewRow);
		EndDo;
	EndDo;
	
EndProcedure

// 
Function IsRestrictionDateEarlier(FirstSetting, SecondSetting)
	
	If ValueIsFilled(FirstSetting.PeriodEndClosingDateDetails)
	   And ValueIsFilled(SecondSetting.PeriodEndClosingDateDetails) Then
		
		Return IntervalOfRelativeClosingDate(FirstSetting.PeriodEndClosingDateDetails)
		      > IntervalOfRelativeClosingDate(SecondSetting.PeriodEndClosingDateDetails);
	EndIf;
	
	Return PeriodEndClosingDateByDetails(FirstSetting.PeriodEndClosingDateDetails, FirstSetting.PeriodEndClosingDate)
	      < PeriodEndClosingDateByDetails(SecondSetting.PeriodEndClosingDateDetails, SecondSetting.PeriodEndClosingDate);
	
EndFunction

// 
Function IntervalOfRelativeClosingDate(PeriodEndClosingDateDetails)
	
	PeriodEndClosingDateOption    = StrGetLine(PeriodEndClosingDateDetails, 1);
	DaysCountAsString = StrGetLine(PeriodEndClosingDateDetails, 2);
	
	If ValueIsFilled(DaysCountAsString) Then
		TypeDetails = New TypeDescription("Number");
		PermissionDaysCount = TypeDetails.AdjustValue(DaysCountAsString);
	Else
		PermissionDaysCount = 0;
	EndIf;
	
	Interval = 10;
	
	If PeriodEndClosingDateOption = "EndOfLastYear" Then
		Interval = 5;
		
	ElsIf PeriodEndClosingDateOption = "EndOfLastQuarter" Then
		Interval = 4;
		
	ElsIf PeriodEndClosingDateOption = "EndOfLastMonth" Then
		Interval = 3;
		
	ElsIf PeriodEndClosingDateOption = "EndOfLastWeek" Then
		Interval = 2;
		
	ElsIf PeriodEndClosingDateOption = "PreviousDay" Then
		Interval = 1;
	EndIf;
	
	Return Interval * 1000 + PermissionDaysCount;
	
EndFunction

#EndRegion
