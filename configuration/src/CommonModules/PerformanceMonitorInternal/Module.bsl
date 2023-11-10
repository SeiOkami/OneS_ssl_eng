///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// Gets N worst performance measurements over a period.
// 
// Parameters:
//  StartDate - Date - sampling start date.
//  EndDate - Date - sampling end date.
//  TopApdexCount - Number - number of worst measurements. If zero, returns all measurements.
//
Function GetAPDEXTop(StartDate, EndDate, AggregationPeriod, TopApdexCount) Export
	Return InformationRegisters.TimeMeasurements.GetAPDEXTop(StartDate, EndDate, AggregationPeriod, TopApdexCount);
EndFunction

// Gets N worst technological performance measurements over a period.
// 
// Parameters:
//  StartDate - Date - sampling start date.
//  EndDate - Date - sampling end date.
//  TopApdexCount - Number - number of worst measurements. If zero, returns all measurements.
//
Function GetTopTechnologicalAPDEX(StartDate, EndDate, AggregationPeriod, TopApdexCount) Export
	Return InformationRegisters.TimeMeasurementsTechnological.GetAPDEXTop(StartDate, EndDate, AggregationPeriod, TopApdexCount);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "PerformanceMonitorInternal.InitialFilling1";
	
	Handler = Handlers.Add();
	Handler.ExecutionMode = "Seamless";
	Handler.SharedData = True;
	Handler.Version = "3.1.3.38";
	Handler.Procedure = "PerformanceMonitorInternal.SetConstantValues31338";
	
EndProcedure

// See CommonOverridable.OnAddSessionParameterSettingHandlers.
Procedure OnAddSessionParameterSettingHandlers(Handlers) Export
	
	Handlers.Insert("TimeMeasurementComment", "PerformanceMonitorInternal.SessionParametersSetting");
	
EndProcedure

// See UsersOverridable.OnDefineRoleAssignment
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	// ТолькоДляПользователейСистемы.
	RolesAssignment.ForSystemUsersOnly.Add(
		Metadata.Roles.PerformanceSetupAndMonitoring.Name);
	
EndProcedure

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings
Procedure OnDefineScheduledJobSettings(Settings) Export
	Dependence = Settings.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.PerformanceMonitorDataExport;
	Dependence.FunctionalOption = Metadata.FunctionalOptions.RunPerformanceMeasurements;
	Dependence.UseExternalResources = True;
	Dependence = Settings.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.ClearTimeMeasurements;
	Dependence.FunctionalOption = Metadata.FunctionalOptions.RunPerformanceMeasurements;
	Dependence.UseExternalResources = True;
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources.
Procedure OnFillPermissionsToAccessExternalResources(PermissionsRequests) Export
	
	If SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSOperations = CommonModule("SaaSOperations");
		If ModuleSaaSOperations.DataSeparationEnabled() And ModuleSaaSOperations.SeparatedDataUsageAvailable() Then
			Return;
		EndIf;
	EndIf;
		
	DirectoriesForExport = PerformanceMonitorDataExportDirectories();
	If DirectoriesForExport = Undefined Then
		Return;
	EndIf;
	
	URIStructure = PerformanceMonitorClientServer.URIStructure(DirectoriesForExport.FTPExportDirectory);
	DirectoriesForExport.Insert("FTPExportDirectory", URIStructure.ServerName);
	If ValueIsFilled(URIStructure.Port) Then
		DirectoriesForExport.Insert("FTPExportDirectoryPort", URIStructure.Port);
	EndIf;
    
    CoreAvailable = SubsystemExists("StandardSubsystems.Core");
	SafeModeManagerAvailable = SubsystemExists("StandardSubsystems.SecurityProfiles");
	
	If CoreAvailable And SafeModeManagerAvailable Then
		ModuleSafeModeManager = CommonModule("SafeModeManager");
		ModuleCommon = CommonModule("Common");
		PermissionsRequests.Add(
			ModuleSafeModeManager.RequestToUseExternalResources(
				PermissionsToUseServerResources(DirectoriesForExport), 
				ModuleCommon.MetadataObjectID("Constant.RunPerformanceMeasurements")));
	EndIf;
			
EndProcedure

// See CommonOverridable.OnAddClientParametersOnStart.
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	ClientRunParameters = New Structure("RecordPeriod, RunPerformanceMeasurements");
	
	SetPrivilegedMode(True);
	ClientRunParameters.RecordPeriod = PerformanceMonitor.RecordPeriod();
	ClientRunParameters.RunPerformanceMeasurements = Constants.RunPerformanceMeasurements.Get();

	Parameters.Insert("PerformanceMonitor", New FixedStructure(ClientRunParameters));
	
	If ClientRunParameters.RunPerformanceMeasurements
	   And SessionParameters.TimeMeasurementComment <> Undefined Then
		Return; // 
	EndIf;
	
EndProcedure

// See ReportsOptionsOverridable.CustomizeReportsOptions.
Procedure OnSetUpReportsOptions(Settings) Export
	ModuleReportsOptions = CommonModule("ReportsOptions");
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.PerformanceMonitor);
EndProcedure

// See CommonOverridable.OnReceiptRecurringClientDataOnServer
Procedure OnReceiptRecurringClientDataOnServer(Parameters, Results) Export
	
	MeasurementsToWrite = Parameters.Get("StandardSubsystems.PerformanceMonitor.MeasurementsToWrite");
	If MeasurementsToWrite = Undefined Then
		Return;
	EndIf;
	
	PerformanceMonitorServerCall.RecordKeyOperationsDuration(MeasurementsToWrite);
	
EndProcedure

#EndRegion

#Region Private

// Parameters:
//  ParameterName - String
//  SpecifiedParameters - Array of String
//
Procedure SessionParametersSetting(ParameterName, SpecifiedParameters) Export
	
	// Session parameters must be initialized without using application parameters.
	
	If ParameterName = "TimeMeasurementComment" Then
		SessionParameters.TimeMeasurementComment = GetTimeMeasurementComment();
		SpecifiedParameters.Add("TimeMeasurementComment");
		Return;
	EndIf;
EndProcedure

Procedure InitialFilling1() Export
	
	If SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSOperations = CommonModule("SaaSOperations");
		If ModuleSaaSOperations.DataSeparationEnabled() Then
			Return;
		EndIf;
	EndIf;
	
	Constants.MeasurementsCountInExportPackage.Set(1000);
	Constants.PerformanceMonitorRecordPeriod.Set(300);
	Constants.KeepMeasurementsPeriod.Set(100);
		
EndProcedure

// Sets the "TimeMeasurementComment" session parameter
// at startup.
//
Function GetTimeMeasurementComment()
	
	TimeMeasurementComment = New Map;
	
	SystemInfo = New SystemInfo();
	AppVersion = SystemInfo.AppVersion;
		
	TimeMeasurementComment.Insert("Platform0", AppVersion);
	TimeMeasurementComment.Insert("Conf", Metadata.Synonym);
	TimeMeasurementComment.Insert("ConfVer", Metadata.Version);
	
	DataSeparation = InfoBaseUsers.CurrentUser().DataSeparation;
	DataSeparationValues = New Array;
	If DataSeparation.Count() <> 0 Then
		For Each CurSeparator In DataSeparation Do
			DataSeparationValues.Add(CurSeparator.Value);
		EndDo;
	Else
		DataSeparationValues.Add(0);
	EndIf;
	TimeMeasurementComment.Insert("Separation", DataSeparationValues);
	
	JSONWriter = New JSONWriter;
	JSONWriter.SetString(New JSONWriterSettings(JSONLineBreak.None));
	WriteJSON(JSONWriter, TimeMeasurementComment);
		
	Return JSONWriter.Close();
	
EndFunction

// For internal use only.
Function RequestToUseExternalResources(Directories) Export
	If SubsystemExists("StandardSubsystems.SecurityProfiles") 
		And SubsystemExists("StandardSubsystems.Core") Then
		ModuleSafeModeManager = CommonModule("SafeModeManager");
		ModuleCommon = CommonModule("Common");
		Return ModuleSafeModeManager.RequestToUseExternalResources(
					PermissionsToUseServerResources(Directories),
					ModuleCommon.MetadataObjectID("Constant.RunPerformanceMeasurements"));
	EndIf;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Finds and returns the scheduled job for exporting time measurements.
//
// Returns:
//  ScheduledJob - 
//
Function PerformanceMonitorDataExportScheduledJob() Export
	
	SetPrivilegedMode(True);
	Jobs = ScheduledJobs.GetScheduledJobs(
		New Structure("Metadata", "PerformanceMonitorDataExport"));
	If Jobs.Count() = 0 Then
		Job = ScheduledJobs.CreateScheduledJob(
			Metadata.ScheduledJobs.PerformanceMonitorDataExport);
		Job.Write();
		Return Job;
	Else
		Return Jobs[0];
	EndIf;
		
EndFunction

// Returns directories containing measurement export files.
//
// Parameters:
//  No
//
// Returns:
//    Structure:
//        "ExecuteExportToFTPDirectory"              - Boolean - indicates whether export to an FTP directory was performed
//        "FTPExportDirectory"                - String - an FTP directory
//        "ExecuteExportToLocalDirectory" - Boolean - indicates whether export to a local directory was performed
//        "LocalExportDirectory"          - String - a local export directory.
//
Function PerformanceMonitorDataExportDirectories() Export
	
	Job = PerformanceMonitorDataExportScheduledJob();
	Directories = New Structure;
	If Job.Parameters.Count() > 0 Then
		Directories = Job.Parameters[0];
	EndIf;
	
	If TypeOf(Directories) <> Type("Structure") Or Directories.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	ReturnValue = New Structure;
	ReturnValue.Insert("DoExportToFTPDirectory");
	ReturnValue.Insert("FTPExportDirectory");
	ReturnValue.Insert("DoExportToLocalDirectory");
	ReturnValue.Insert("LocalExportDirectory");
	
	JobKeyToItems = New Structure;
	FTPItems = New Array;
	FTPItems.Add("DoExportToFTPDirectory");
	FTPItems.Add("FTPExportDirectory");
	
	LocalItems = New Array;
	LocalItems.Add("DoExportToLocalDirectory");
	LocalItems.Add("LocalExportDirectory");
	
	JobKeyToItems.Insert(PerformanceMonitorClientServer.FTPExportDirectoryJobKey(), FTPItems);
	JobKeyToItems.Insert(PerformanceMonitorClientServer.LocalExportDirectoryJobKey(), LocalItems);
	DoExport = False;
	For Each ItemsKeyName In JobKeyToItems Do
		KeyName = ItemsKeyName.Key;
		ItemsToEdit = ItemsKeyName.Value;
		ItemNumber = 0;
		For Each ItemName In ItemsToEdit Do
			Value = Directories[KeyName][ItemNumber];
			ReturnValue[ItemName] = Value;
			If ItemNumber = 0 Then 
				DoExport = DoExport Or Value;
			EndIf;
			ItemNumber = ItemNumber + 1;
		EndDo;
	EndDo;
	
	Return ReturnValue;
	
EndFunction

// Returns a reference to the "Overall performance" item,
// i.e. the predefined OverallSystemPerformance item, if it exists,
// or an empty reference otherwise.
//
// Parameters:
//  No
// Returns:
//  CatalogRef.KeyOperations
//
Function GetOverallSystemPerformanceItem() Export
	
	PredefinedKO = Metadata.Catalogs.KeyOperations.GetPredefinedNames();
	HasPredefinedItem = ?(PredefinedKO.Find("OverallSystemPerformance") <> Undefined, True, False);
	
	QueryText = 
	"SELECT TOP 1
	|	KeyOperations.Ref,
	|	2 AS Priority
	|FROM
	|	Catalog.KeyOperations AS KeyOperations
	|WHERE
	|	KeyOperations.Name = ""OverallSystemPerformance""
	|	AND NOT KeyOperations.DeletionMark
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	VALUE(Catalog.KeyOperations.EmptyRef),
	|	3
	|
	|ORDER BY
	|	Priority";
	
	If HasPredefinedItem Then
		QueryTextPredefinedItem = 
		"SELECT TOP 1
		|	KeyOperations.Ref,
		|	1 AS Priority
		|FROM
		|	Catalog.KeyOperations AS KeyOperations
		|WHERE
		|	KeyOperations.PredefinedDataName = ""OverallSystemPerformance""
		|	AND NOT KeyOperations.DeletionMark";
		QueryText = StrTemplate("%1 UNION ALL %2", QueryTextPredefinedItem, QueryText); 
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText; 
	Query.SetParameter("KeyOperations", PredefinedKO);
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	Selection.Next();
	
	Return Selection.Ref;
	
EndFunction

Procedure SetConstantValues31338() Export
	
	If Constants.KeepMeasurementsPeriod.Get() = 3650 Then
		Constants.KeepMeasurementsPeriod.Set(100);
	EndIf;
				
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

// Creates an array of permissions to export measurement data.
//
// Parameters - DirectoriesForExport - Structure
//
// Returns:
//  Array
//
Function PermissionsToUseServerResources(Directories)
	
	Permissions = New Array;
	
	CoreAvailable = SubsystemExists("StandardSubsystems.Core");
	If CoreAvailable Then
		ModuleSafeModeManager = CommonModule("SafeModeManager");
		If Directories <> Undefined Then
			If Directories.Property("DoExportToLocalDirectory") And Directories.DoExportToLocalDirectory = True Then
				If Directories.Property("LocalExportDirectory") And ValueIsFilled(Directories.LocalExportDirectory) Then
					Item = ModuleSafeModeManager.PermissionToUseFileSystemDirectory(
						Directories.LocalExportDirectory,
						True,
						True,
						NStr("en = 'A network directory to import samples to.';"));
					Permissions.Add(Item);
				EndIf;
			EndIf;
			
			If Directories.Property("DoExportToFTPDirectory") And Directories.DoExportToFTPDirectory = True Then
				If Directories.Property("FTPExportDirectory") And ValueIsFilled(Directories.FTPExportDirectory) Then
					Item = ModuleSafeModeManager.PermissionToUseInternetResource(
						"FTP",
						Directories.FTPExportDirectory,
						?(Directories.Property("FTPExportDirectoryPort"), Directories.FTPExportDirectoryPort, Undefined),
						NStr("en = 'A FTP directory to import samples to.';"));
					Permissions.Add(Item);
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	Return Permissions;
EndFunction

#Region CommonCopy

// Returns True if the "functional" subsystem exists in the configuration.
// Intended for calling optional subsystems (conditional calls).
//
// A subsystem is considered functional if its "Include in command interface" check box is cleared.
//
// Parameters:
//  FullSubsystemName - String - the full name of the subsystem metadata object
//                        without the "Subsystem." part, case-sensitive.
//                        Example: "StandardSubsystems.ReportsOptions".
//
// Example:
//
//  If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
//  	ModuleReportOptions = Common.CommonModule("ReportsOptions");
//  	ModuleReportOptions.<Method name>();
//  EndIf;
//
// Returns:
//  Boolean
//
Function SubsystemExists(FullSubsystemName) Export
	
	If CoreAvailable() Then
		ModuleCommon = CalculateInSafeMode("Common");
		Return ModuleCommon.SubsystemExists(FullSubsystemName);
	Else
		SubsystemsNames = PerformanceMonitorCached.SubsystemsNames();
		Return SubsystemsNames.Get(FullSubsystemName) <> Undefined;
	EndIf;
	
EndFunction

// Returns common basic functionality parameters.
//
// Returns: 
//  Structure:
//      * PersonalSettingsFormName            - String - Name of the user settings edit form.
//      * MinPlatformVersion1    - String - Full platform version required to start the application.
//                                                           For example, "8.3.4.365".
//      * MustExit               - Boolean - the initial value is False.
//      * AskConfirmationOnExit - Boolean - True by default. If False, 
//                                                                  the exit confirmation is not
//                                                                  requested when exiting the application, if it is not clearly enabled in
//                                                                  the personal application settings.
//      * DisableMetadataObjectsIDs - Boolean - disables completing the MetadataObjectIDs
//              and ExtensionObjectIDs catalogs, as well as the export/import procedure for DIB nodes.
//              For partial embedding certain library functions into the configuration without enabling support.
//      * DisabledSubsystems                     - Map of KeyAndValue - use to disable
//                                                                  certain subsystems virtually for testing purposes.
//                                                                  If the subsystem is disabled, Common.SubsystemExists
//                                                                  returns False. Set the map's key to the name of the subsystem to be disabled
//                                                                  and value to True.
//
Function CommonCoreParameters() Export
	
	CommonParameters = New Structure;
	CommonParameters.Insert("DisabledSubsystems", New Map);
	
	Return CommonParameters;
	
EndFunction

Function CoreAvailable()
	
	StandardSubsystemsAvailable = Metadata.Subsystems.Find("StandardSubsystems");
	
	If StandardSubsystemsAvailable = Undefined Then
		Return False;
	Else
		If StandardSubsystemsAvailable.Subsystems.Find("Core") = Undefined Then
			Return False;
		Else
			Return True;
		EndIf;
	EndIf;
	
EndFunction

// Generates and displays the message that can relate to a form item.
//
// Parameters:
//  MessageToUserText - String - message text.
//  DataKey - AnyRef - the infobase record key or object that message refers to.
//  Field - String - a form attribute description.
//  DataPath - String - a data path (a path to a form attribute).
//  Cancel - Boolean - an output parameter. Always True.
//
// Example:
//
//  1. Showing the message associated with the object attribute near the managed form field:
//  CommonClient.InformUser(
//   NStr("en = 'Error message.'"), ,
//   "FieldInFormAttributeObject",
//   "Object");
//
//  An alternative variant of using in the object form module:
//  CommonClient.InformUser(
//   NStr("en = 'Error message.'"), ,
//   "Object.FieldInFormAttributeObject");
//
//  2. Showing a message for the form attribute, next to the managed form field:
//  CommonClient.InformUser(
//   NStr("en = 'Error message.'"), ,
//   "FormAttributeName");
//
//  3. To display a message associated with an infobase object:
//  CommonClient.InformUser(
//   NStr("en = 'Error message.'"), InfobaseObject, "Responsible person",,Cancel);
//
//  4. To display a message from a link to an infobase object:
//  CommonClient.InformUser(
//   NStr("en = 'Error message.'"), Reference, , , Cancel);
//
//  Scenarios of incorrect using:
//   1. Passing DataKey and DataPath parameters at the same time.
//   2. Passing a value of an illegal type to the DataKey parameter.
//   3. Specifying a reference without specifying a field (and/or a data path).
//
Procedure MessageToUser( 
	Val MessageToUserText,
	Val DataKey = Undefined,
	Val Field = "",
	Val DataPath = "",
	Cancel = False) Export
	
	IsObject = False;
	
	If DataKey <> Undefined
		And XMLTypeOf(DataKey) <> Undefined Then
		
		ValueTypeAsString = XMLTypeOf(DataKey).TypeName;
		IsObject = StrFind(ValueTypeAsString, "Object.") > 0;
	EndIf;
	
	Message = New UserMessage;
	Message.Text = MessageToUserText;
	Message.Field = Field;
	
	If IsObject Then
		Message.SetData(DataKey);
	Else
		Message.DataKey = DataKey;
	EndIf;
	
	If Not IsBlankString(DataPath) Then
		Message.DataPath = DataPath;
	EndIf;
	
	Message.Message();
	
	Cancel = True;
	
EndProcedure

// Returns a reference to the common module by the name.
//
// Parameters:
//  Name          - String - a common module name, for example:
//                 "Common",
//                 "CommonClient".
//
// Returns:
//  CommonModule
//
Function CommonModule(Name) Export
	
	If CoreAvailable() Then
		ModuleCommon = CalculateInSafeMode("Common");
		Module = ModuleCommon.CommonModule(Name);
	Else
		If Metadata.CommonModules.Find(Name) <> Undefined Then
			Module = CalculateInSafeMode(Name);
		ElsIf StrOccurrenceCount(Name, ".") = 1 Then
			Return ServerManagerModule(Name);
		Else
			Module = Undefined;
		EndIf;
		
		If TypeOf(Module) <> Type("CommonModule") Then
			ExceptionMessage = NStr("en = 'Common module %1 is not found.';");
			Raise StrReplace(ExceptionMessage, "%1", Name);
		EndIf;
	EndIf;
	
	Return Module;
	
EndFunction

// Returns a server manager module by object name.
Function ServerManagerModule(Name)
	ObjectFound = False;
	
	NameParts = StrSplit(Name, ".");
	If NameParts.Count() = 2 Then
		
		KindName = Upper(NameParts[0]);
		ObjectName = NameParts[1];
		
		If KindName = Upper(ConstantsTypeName()) Then
			If Metadata.Constants.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(InformationRegistersTypeName()) Then
			If Metadata.InformationRegisters.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(AccumulationRegistersTypeName()) Then
			If Metadata.AccumulationRegisters.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(AccountingRegistersTypeName()) Then
			If Metadata.AccountingRegisters.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(CalculationRegistersTypeName()) Then
			If Metadata.CalculationRegisters.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(CatalogsTypeName()) Then
			If Metadata.Catalogs.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(DocumentsTypeName()) Then
			If Metadata.Documents.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(ReportsTypeName()) Then
			If Metadata.Reports.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(DataProcessorsTypeName()) Then
			If Metadata.DataProcessors.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(BusinessProcessesTypeName()) Then
			If Metadata.BusinessProcesses.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(DocumentJournalsTypeName()) Then
			If Metadata.DocumentJournals.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(TasksTypeName()) Then
			If Metadata.Tasks.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(ChartsOfAccountsTypeName()) Then
			If Metadata.ChartsOfAccounts.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(ExchangePlansTypeName()) Then
			If Metadata.ExchangePlans.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(ChartsOfCharacteristicTypesTypeName()) Then
			If Metadata.ChartsOfCharacteristicTypes.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(ChartsOfCalculationTypesTypeName()) Then
			If Metadata.ChartsOfCalculationTypes.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		EndIf;
		
	EndIf;
	
	If Not ObjectFound Then
		ExceptionMessage = NStr("en = 'Metadata object %1 not found.
			|It might be missing or it does not support getting the manager module.';");
		Raise StrReplace(ExceptionMessage, "%1", Name);
	EndIf;
	
	Module = CalculateInSafeMode(Name);
	
	Return Module;
EndFunction

// Returns a value for identification of the Information registers type.
//
// Returns:
//  String
//
Function InformationRegistersTypeName()
	
	Return "InformationRegisters";
	
EndFunction

// Returns a value for identification of the Accumulation registers type.
//
// Returns:
//  String
//
Function AccumulationRegistersTypeName()
	
	Return "AccumulationRegisters";
	
EndFunction

// Returns a value for identification of the Accounting registers type.
//
// Returns:
//  String
//
Function AccountingRegistersTypeName()
	
	Return "AccountingRegisters";
	
EndFunction

// Returns a value for identification of the Calculation registers type.
//
// Returns:
//  String
//
Function CalculationRegistersTypeName()
	
	Return "CalculationRegisters";
	
EndFunction

// Returns a value for identification of the Documents type.
//
// Returns:
//  String
//
Function DocumentsTypeName()
	
	Return "Documents";
	
EndFunction

// Returns a value for identification of the Catalogs type.
//
// Returns:
//  String
//
Function CatalogsTypeName()
	
	Return "Catalogs";
	
EndFunction

// Returns a value for identification of the Reports type.
//
// Returns:
//  String
//
Function ReportsTypeName()
	
	Return "Reports";
	
EndFunction

// Returns a value for identification of the Data processors type.
//
// Returns:
//  String
//
Function DataProcessorsTypeName()
	
	Return "DataProcessors";
	
EndFunction

// Returns a value for identification of the Exchange plans type.
//
// Returns:
//  String
//
Function ExchangePlansTypeName()
	
	Return "ExchangePlans";
	
EndFunction

// Returns a value for identification of the Charts of characteristic types type.
//
// Returns:
//  String
//
Function ChartsOfCharacteristicTypesTypeName()
	
	Return "ChartsOfCharacteristicTypes";
	
EndFunction

// Returns a value for identification of the Business processes type.
//
// Returns:
//  String
//
Function BusinessProcessesTypeName()
	
	Return "BusinessProcesses";
	
EndFunction

// Returns a value for identification of the Tasks type.
//
// Returns:
//  String
//
Function TasksTypeName()
	
	Return "Tasks";
	
EndFunction

// Checks whether the metadata object belongs to the Charts of accounts type.
//
// Returns:
//  String
//
Function ChartsOfAccountsTypeName()
	
	Return "ChartsOfAccounts";
	
EndFunction

// Returns a value for identification of the Charts of calculation types type.
//
// Returns:
//  String
//
Function ChartsOfCalculationTypesTypeName()
	
	Return "ChartsOfCalculationTypes";
	
EndFunction

// Returns a value for identification of the Constants type.
//
// Returns:
//  String
//
Function ConstantsTypeName()
	
	Return "Constants";
	
EndFunction

// Returns a value for identification of the Document journals type.
//
// Returns:
//  String
//
Function DocumentJournalsTypeName()
	
	Return "DocumentJournals";
	
EndFunction

Function DefaultLanguageCode() Export
	If SubsystemExists("StandardSubsystems.Core") Then
		ModuleCommon = CommonModule("Common");
		Return ModuleCommon.DefaultLanguageCode();
	EndIf;	
	Return Metadata.DefaultLanguage.LanguageCode;
EndFunction

// Parameters:
//  CatalogManager - CatalogManager.KeyOperations
//  Ref - CatalogRef.KeyOperations
//
// Returns:
//  CatalogObject.KeyOperations
//
Function ServiceItem(CatalogManager, Ref = Undefined) Export
	
	If Ref = Undefined Then
		CatalogItem = CatalogManager.CreateItem();
	Else
		CatalogItem = Ref.GetObject();
		If CatalogItem = Undefined Then
			Return Undefined;
		EndIf;
	EndIf;
	
	CatalogItem.AdditionalProperties.Insert("DontControlObjectsToDelete");
	CatalogItem.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
	CatalogItem.DataExchange.Recipients.AutoFill = False;
	CatalogItem.DataExchange.Load = True;
	
	Return CatalogItem;
	
EndFunction

// Parameters:
//  RegisterManager - InformationRegisterManager.TimeMeasurements
//                   - InformationRegisterManager.TimeMeasurementsTechnological
//
// Returns:
//  InformationRegisterRecordSet.TimeMeasurements
//  
//
Function ServiceRecordSet(RegisterManager) Export
	
	RecordSet = RegisterManager.CreateRecordSet();
	RecordSet.AdditionalProperties.Insert("DontControlObjectsToDelete");
	RecordSet.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
	RecordSet.DataExchange.Recipients.AutoFill = False;
	RecordSet.DataExchange.Load = True;
	
	Return RecordSet;
	
EndFunction

#EndRegion

#Region SafeModeCopy

// Evaluates the passed expression, setting the safe mode of script execution
//  and the safe mode of data separation for all separators of the configuration.
//  Thus, when evaluating the expression:
//   - attempts to set the privileged mode are ignored;
//   - all external (relative to the 1C:Enterprise platform) actions (COM,
//       add-in loading, external application startup, operating system command execution,
//       file system and Internet resource access) are prohibited;
//   - session separators cannot be disabled;
//   - session separator values cannot be changed (if data separation is
//       not disabled conditionally);
//   - objects that manage the conditional separation state cannot be changed.
//
// Parameters:
//  Expression - String - an expression to be calculated. For example, "MyModule.MyFunction(Parameters)".
//  Parameters - Arbitrary - any value as might be required for
//    evaluating the expression. The expression must refer to this
//    value as the Parameters variable.
//
// Returns: 
//   Arbitrary - 
//
Function CalculateInSafeMode(Val Expression, Val Parameters = Undefined)
	
	SetSafeMode(True);
	
	SeparatorArray = PerformanceMonitorCached.ConfigurationSeparators();
	
	For Each SeparatorName In SeparatorArray Do
		
		SetDataSeparationSafeMode(SeparatorName, True);
		
	EndDo;
	
	Return Eval(Expression);
	
EndFunction

#EndRegion

#EndRegion
