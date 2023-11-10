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

// Checks whether the update or configuration of the infobase is required
// before you start using it.
//
// Parameters:
//  SubordinateDIBNodeSetup - Boolean - (return value), it is set to True
//                                 if the update is required due to the subordinate DIB node setup.
//
// Returns:
//  Boolean - 
//
Function UpdateRequired1(SubordinateDIBNodeSetup = False) Export
	
	If Common.DataSeparationEnabled() Then
		// Updating in SaaS.
		If Common.SeparatedDataUsageAvailable() Then
			If InfobaseUpdate.InfobaseUpdateRequired() Then
				// 
				Return True;
			EndIf;
			
		ElsIf InfobaseUpdateInternal.SharedInfobaseDataUpdateRequired() Then
			// 
			Return True;
		EndIf;
	Else
		// Updating in the local mode.
		If InfobaseUpdate.InfobaseUpdateRequired() Then
			Return True;
		EndIf;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		
		// 
		// 
		If ModuleDataExchangeServer.SubordinateDIBNodeSetup() Then
			SubordinateDIBNodeSetup = True;
			Return True;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

// Calls forced filling of all application parameters.
Procedure UpdateAllApplicationParameters() Export
	
	ImportUpdateApplicationParameters();
	
EndProcedure

// Returns the date of a successful check or update of application parameters.
//
// Returns:
//  Date
//
Function AllApplicationParametersUpdateDate() Export
	
	ParameterName = "StandardSubsystems.Core.AllApplicationParametersUpdateDate";
	UpdateDate = StandardSubsystemsServer.ApplicationParameter(ParameterName);
	
	If TypeOf(UpdateDate) <> Type("Date") Then
		UpdateDate = '00010101';
	EndIf;
	
	Return UpdateDate;
	
EndFunction


// See StandardSubsystemsServer.ApplicationParameter.
Function ApplicationParameter(ParameterName) Export
	
	ValueDescription = ApplicationParameterValueDescription(ParameterName);
	
	If StandardSubsystemsServer.ApplicationVersionUpdatedDynamically() Then
		Return ValueDescription.Value;
	EndIf;
	
	If ValueDescription.Version <> Metadata.Version Then
		Value = Undefined;
		CheckIfCanUpdateSaaS(ParameterName, Value, "Receive");
		Return Value;
	EndIf;
	
	Return ValueDescription.Value;
	
EndFunction

// See StandardSubsystemsServer.SetApplicationParameter.
Procedure SetApplicationParameter(ParameterName, Value) Export
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	CheckIfCanUpdateSaaS(ParameterName, Value, "Set");
	
	ValueDescription = New Structure;
	ValueDescription.Insert("Version", Metadata.Version);
	ValueDescription.Insert("Value", Value);
	
	SetApplicationParameterStoredData(ParameterName, ValueDescription);
	
EndProcedure

// See StandardSubsystemsServer.UpdateApplicationParameter.
Procedure UpdateApplicationParameter(ParameterName, Value, HasChanges = False, PreviousValue2 = Undefined) Export
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	
	ValueDescription = ApplicationParameterValueDescription(ParameterName, False);
	PreviousValue2 = ValueDescription.Value;
	
	If Not Common.DataMatch(Value, PreviousValue2) Then
		HasChanges = True;
	ElsIf ValueDescription.Version = Metadata.Version Then
		Return;
	EndIf;
	
	SetApplicationParameter(ParameterName, Value);
	
EndProcedure


// See StandardSubsystemsServer.ApplicationParameterChanges.
Function ApplicationParameterChanges(ParameterName) Export
	
	If Common.DataSeparationEnabled()
	   And Not Common.SeparatedDataUsageAvailable() Then
		
		// 
		// 
		// 
		
		// Version of shared (common) data.
		IBVersion = InfobaseUpdateInternal.IBVersion(Metadata.Name, True);
	Else
		IBVersion = InfobaseUpdateInternal.IBVersion(Metadata.Name);
	EndIf;
	
	// In case of initial filling, application parameter changes are not defined.
	If CommonClientServer.CompareVersions(IBVersion, "0.0.0.0") = 0 Then
		Return Undefined;
	EndIf;
	
	ChangeStorageParameterName = ParameterName + ChangeStorageParameterNameClarification();
	LastChanges = ApplicationParameter(ChangeStorageParameterName);
	
	If Not IsApplicationParameterChanges(LastChanges) Then
		CheckIfCanUpdateSaaS(ParameterName, Undefined, "GettingChanges");
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'No changes are found for application parameter ""%1.""';"), ParameterName)
			+ StandardSubsystemsServer.ApplicationRunParameterErrorClarificationForDeveloper();
		Raise ErrorText;
	EndIf;
	
	Version = Metadata.Version;
	NextVersion = NextVersion(Version);
	UpdateOutsideIBUpdate = CommonClientServer.CompareVersions(IBVersion, Version) = 0;
	
	// 
	// 
	// 
	// 
	
	IndexOf = LastChanges.Count()-1;
	While IndexOf >= 0 Do
		RevisionVersion = LastChanges[IndexOf].ConfigurationVersion;
		
		If CommonClientServer.CompareVersions(IBVersion, RevisionVersion) >= 0
		   And Not (  UpdateOutsideIBUpdate
		         And CommonClientServer.CompareVersions(NextVersion, RevisionVersion) = 0) Then
			
			LastChanges.Delete(IndexOf);
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	Return LastChanges.UnloadColumn("Changes");
	
EndFunction

// See StandardSubsystemsServer.AddApplicationParameterChanges.
Procedure AddApplicationParameterChanges(ParameterName, Val Changes) Export
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	
	// Retrieving the infobase or shared data version.
	IBVersion = InfobaseUpdateInternal.IBVersion(Metadata.Name);
	
	// When you migrate to another application, the current configuration version is used.
	If Not Common.DataSeparationEnabled()
	   And InfobaseUpdateInternal.DataUpdateMode() = "MigrationFromAnotherApplication" Then
		
		IBVersion = Metadata.Version;
	EndIf;
	
	// In case of initial filling, parameter changes are not added.
	If CommonClientServer.CompareVersions(IBVersion, "0.0.0.0") = 0 Then
		Changes = Undefined;
	EndIf;
	
	ChangeStorageParameterName = ParameterName + ChangeStorageParameterNameClarification();
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ApplicationRuntimeParameters");
	LockItem.SetValue("ParameterName", ChangeStorageParameterName);
	
	BeginTransaction();
	Try
		Block.Lock();
		
		ValueDescription = ApplicationParameterValueDescription(ChangeStorageParameterName, False);
		LastChanges = ValueDescription.Value;
		UpdateChangesComposition = ValueDescription.Version <> Metadata.Version;
		
		If Not IsApplicationParameterChanges(LastChanges) Then
			LastChanges = ApplicationParameterStoredData(ChangeStorageParameterName);
			If IsApplicationParameterChanges(LastChanges) Then
				UpdateChangesComposition = True;
			Else
				LastChanges = Undefined;
			EndIf;
		EndIf;
		
		If LastChanges = Undefined Then
			UpdateChangesComposition = True;
			LastChanges = ApplicationParameterChangesCollection();
		EndIf;
		
		If ValueIsFilled(Changes) Then
			
			// 
			// 
			// 
			// 
			Version = Metadata.Version;
			
			UpdateOutsideIBUpdate =
				CommonClientServer.CompareVersions(IBVersion , Version) = 0;
			
			If UpdateOutsideIBUpdate Then
				Version = NextVersion(Version);
			EndIf;
			
			UpdateChangesComposition = True;
			String = LastChanges.Add();
			String.Changes          = Changes;
			String.ConfigurationVersion = Version;
		EndIf;
		
		EarliestIBVersion = InfobaseUpdateInternalCached.EarliestIBVersion();
		
		// 
		// 
		// 
		IndexOf = LastChanges.Count()-1;
		While IndexOf >=0 Do
			RevisionVersion = LastChanges[IndexOf].ConfigurationVersion;
			
			If CommonClientServer.CompareVersions(EarliestIBVersion, RevisionVersion) > 0 Then
				LastChanges.Delete(IndexOf);
				UpdateChangesComposition = True;
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
		
		If UpdateChangesComposition Then
			CheckIfCanUpdateSaaS(ParameterName, Changes, "AddChanges");
			SetApplicationParameter(ChangeStorageParameterName, LastChanges);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure


// This method is required for call from the ExecuteInfobaseUpdate procedure.
Procedure ImportUpdateApplicationParameters() Export
	
	If Common.DataSeparationEnabled()
	   And Common.SeparatedDataUsageAvailable() Then
		
		UpdateParametersOfExtensionVersionsTakingIntoAccountExecutionMode(False);
		Return;
	EndIf;
	
	Try
		If NeedToImportApplicationParameters() Then
			LoadProgramOperationParametersTakingIntoAccountExecutionMode(False);
		EndIf;
	Except
		If Common.SubsystemExists("StandardSubsystems.DataExchange")
		   And Common.IsSubordinateDIBNode() Then
			ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
			ModuleDataExchangeServer.EnableDataExchangeMessageImportRecurrenceBeforeStart();
		EndIf;
		Raise;
	EndTry;
	
	If ValueIsFilled(SessionParameters.AttachedExtensions)
		And Not UpdateWithoutBackgroundJob() Then
		// Run a background job to update the parameters.
		Result = UpdateApplicationParametersInBackground(Undefined, Undefined, False);
		ProcessedResult = ProcessedTimeConsumingOperationResult(Result, False);
		
		If ValueIsFilled(ProcessedResult.BriefErrorDescription) Then
			Raise ProcessedResult.DetailErrorDescription;
		EndIf;
	Else
		Try
			UpdateProgramOperationParametersBasedOnExecutionMode(False);
		Except
			If Common.SubsystemExists("StandardSubsystems.DataExchange")
			   And Common.IsSubordinateDIBNode() Then
				ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
				ModuleDataExchangeServer.EnableDataExchangeMessageImportRecurrenceBeforeStart();
			EndIf;
			Raise;
		EndTry;
	EndIf;
	
	UpdateParametersOfExtensionVersionsTakingIntoAccountExecutionMode(False);
	
EndProcedure

// Intended for procedure ImportUpdateApplicationParameters and for calling from the ApplicationVersionUpdate form.
//
// Returns:
//  Boolean
//
Function NeedToImportApplicationParameters() Export
	
	Return UpdateRequired1() And Common.IsSubordinateDIBNode();
	
EndFunction

// Intended to be called from form ApplicationVersionUpdate.
//
// Returns:
//   See TimeConsumingOperations.ExecuteInBackground
//
Function ImportApplicationParametersInBackground(WaitCompletion, FormIdentifier, ReportProgress) Export
	
	OperationParametersList = TimeConsumingOperations.BackgroundExecutionParameters(FormIdentifier);
	OperationParametersList.BackgroundJobDescription = NStr("en = 'Background import of application parameters';");
	// 
	// 
	// 
	OperationParametersList.RunInBackground = True;
	OperationParametersList.WaitCompletion = WaitCompletion;
	
	If Common.DebugMode() Then
		ReportProgress = False;
	EndIf;
	
	Return TimeConsumingOperations.ExecuteInBackground(
		"InformationRegisters.ApplicationRuntimeParameters.ApplicationParametersImportLongRunningOperationHandler",
		ReportProgress,
		OperationParametersList);
	
EndFunction

// Intended to be called from form ApplicationVersionUpdate.
// 
// Returns:
//   See TimeConsumingOperations.ExecuteInBackground
//
Function UpdateApplicationParametersInBackground(WaitCompletion, FormIdentifier, ReportProgress) Export
	
	OperationParametersList = TimeConsumingOperations.BackgroundExecutionParameters(FormIdentifier);
	OperationParametersList.BackgroundJobDescription = NStr("en = 'Update application parameters in background';");
	OperationParametersList.NoExtensions = True;
	OperationParametersList.WaitCompletion = WaitCompletion;
	
	If Common.DebugMode()
	   And Not ValueIsFilled(SessionParameters.AttachedExtensions) Then
		ReportProgress = False;
	EndIf;
	
	If ValueIsFilled(SessionParameters.AttachedExtensions)
	   And Not CanExecuteBackgroundJobs() Then
		
		ErrorText =
			NStr("en = 'Application parameters with attached configuration extensions
			           |can be updated only in a background job without configuration extensions
			           |
			           |In a file infobase, a background job cannot be started
			           |from another background job, or from a COM connection.
			           |
			           |To update, you need either to update interactively
			           |starting up 1C:Enterprise or temporarily disable configuration extensions.';");
		Raise ErrorText;
	EndIf;
	
	Return TimeConsumingOperations.ExecuteInBackground(
		"InformationRegisters.ApplicationRuntimeParameters.ApplicationParametersUpdateLongRunningOperationHandler",
		ReportProgress, OperationParametersList);
	
EndFunction

// Intended to be called from form ApplicationVersionUpdate.
//
// Returns:
//   See TimeConsumingOperations.ExecuteInBackground
//
Function UpdateExtensionVersionParametersInBackground(WaitCompletion, FormIdentifier, ReportProgress) Export
	
	OperationParametersList = TimeConsumingOperations.BackgroundExecutionParameters(FormIdentifier);
	OperationParametersList.BackgroundJobDescription = NStr("en = 'Update extension version parameters in background';");
	// 
	// 
	// 
	OperationParametersList.RunInBackground = True;
	OperationParametersList.WaitCompletion = WaitCompletion;
	
	If Common.DebugMode()
	   And Not StandardSubsystemsServer.ThisIsSplitSessionModeWithNoDelimiters() Then
		
		ReportProgress = False;
	EndIf;
	
	Return TimeConsumingOperations.ExecuteInBackground(
		"InformationRegisters.ApplicationRuntimeParameters.ExtensionsVersionsParametersUpdateLongRunningOperationHandler",
		ReportProgress,
		OperationParametersList);
	
EndFunction

// Intended to be called from form ApplicationVersionUpdate.
//
// Returns:
//  Structure:
//    * BriefErrorDescription - String
//    * DetailErrorDescription - String
//
Function ProcessedTimeConsumingOperationResult(Result, Operation) Export
	
	BriefErrorDescription   = Undefined;
	DetailErrorDescription = Undefined;
	
	If Result = Undefined Or Result.Status = "Canceled" Then
		
		If Operation = "ImportApplicationParameters" Then
			BriefErrorDescription =
				NStr("en = 'Cannot import application parameters. Reason:
				           |The import background job is canceled.';");
			
		ElsIf Operation = "ApplicationParametersUpdate" Then
			BriefErrorDescription =
				NStr("en = 'Cannot update application parameters. Reason:
				           |The update background job is canceled.';");
			
		Else // ОбновлениеПараметровРаботыВерсийРасширений.
			BriefErrorDescription =
				NStr("en = 'Cannot update extension version parameters. Reason:
				           |The update background job is canceled.';");
		EndIf;
		
	ElsIf Result.Status = "Completed2" Then
		ExecutionResult = GetFromTempStorage(Result.ResultAddress);
		DeleteFromTempStorage(Result.ResultAddress);
		
		If TypeOf(ExecutionResult) = Type("Structure") Then
			BriefErrorDescription   = ExecutionResult.BriefErrorDescription;
			DetailErrorDescription = ExecutionResult.DetailErrorDescription;
			
		ElsIf Operation = "ImportApplicationParameters" Then
			BriefErrorDescription =
				NStr("en = 'Cannot import application parameters. Reason:
				           |The import background job has not returned the result.';");
			
		ElsIf Operation = "ApplicationParametersUpdate" Then
			BriefErrorDescription =
				NStr("en = 'Cannot update application parameters. Reason:
				           |The update background job has not returned the result.';");
			
		Else // ОбновлениеПараметровРаботыВерсийРасширений.
			BriefErrorDescription =
				NStr("en = 'Cannot update extension version parameters. Reason:
				           |The update background job has not returned the result.';");
		EndIf;
		
	ElsIf Result.Status <> "ImportApplicationParametersNotRequired"
	        And Result.Status <> "ApplicationParametersImportAndUpdateNotRequired"
	        And Result.Status <> "ExtensionVersionParametersUpdateNotRequired" Then
		
		// 
		BriefErrorDescription   = Result.BriefErrorDescription;
		DetailErrorDescription = Result.DetailErrorDescription;
	EndIf;
	
	If Not ValueIsFilled(DetailErrorDescription)
	   And    ValueIsFilled(BriefErrorDescription) Then
		
		DetailErrorDescription = BriefErrorDescription;
	EndIf;
	
	If Not ValueIsFilled(BriefErrorDescription)
	   And    ValueIsFilled(DetailErrorDescription) Then
		
		BriefErrorDescription = DetailErrorDescription;
	EndIf;
	
	ProcessedResult = New Structure;
	ProcessedResult.Insert("BriefErrorDescription",   BriefErrorDescription);
	ProcessedResult.Insert("DetailErrorDescription", DetailErrorDescription);
	
	Return ProcessedResult;
	
EndFunction

#Region DeveloperToolUpdateAuxiliaryData

// Parameters:
//  ShouldUpdate - Boolean - The initial value is False.
//
// Returns:
//  Structure:
//   * Core - Structure:
//      ** MetadataObjectIDs  - 
//      ** ClearAPIsCache - See UpdateParameterProperties.
//   * AttachableCommands - Structure:
//      ** PluginCommandsConfig - See UpdateParameterProperties.
//   * Users - Structure:
//      ** CheckRoleAssignment - See UpdateParameterProperties.
//   * AccessManagement - Structure:
//      ** RolesRights                                    - 
//      ** RightsDependencies                               - 
//      ** AccessKindsProperties                          - 
//      ** SuppliedAccessGroupProfilesDescription      - 
//      ** AvailableRightsForObjectsRightSettingsDetails - See UpdateParameterProperties.
//   * ReportsOptions - Structure:
//      ** ParametersReportsConfiguration              - 
//      ** ParametersIndexSearchReportsConfiguration - See UpdateParameterProperties.
//   * InformationOnStart - Structure:
//      ** InformationPackagesOnStart - See UpdateParameterProperties.
//   * AccountingAudit - Structure:
//      ** SystemChecksAccounting - See UpdateParameterProperties.
//
Function ParametersOfUpdate(ShouldUpdate = False) Export
	
	Parameters = New Structure;
	
	// StandardSubsystems Core
	ParametersSubsystems = New Structure;
	ParametersSubsystems.Insert("MetadataObjectIDs",  NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("ClearAPIsCache", NewUpdateParameterProperties(ShouldUpdate));
	Parameters.Insert("Core", ParametersSubsystems);
	
	// 
	ParametersSubsystems = New Structure;
	ParametersSubsystems.Insert("PluginCommandsConfig", NewUpdateParameterProperties(ShouldUpdate));
	Parameters.Insert("AttachableCommands", ParametersSubsystems);
	
	// 
	ParametersSubsystems = New Structure;
	ParametersSubsystems.Insert("CheckRoleAssignment", NewUpdateParameterProperties(ShouldUpdate));
	Parameters.Insert("Users", ParametersSubsystems);
	
	// 
	ParametersSubsystems.Insert("RolesRights",                                    NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("RightsDependencies",                               NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("AccessKindsProperties",                          NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("SuppliedAccessGroupProfilesDescription",      NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("AvailableRightsForObjectsRightSettingsDetails", NewUpdateParameterProperties(ShouldUpdate));
	Parameters.Insert("AccessManagement", ParametersSubsystems);
	
	// 
	ParametersSubsystems.Insert("ParametersReportsConfiguration", NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("ParametersIndexSearchReportsConfiguration", NewUpdateParameterProperties(ShouldUpdate));
	Parameters.Insert("ReportsOptions", ParametersSubsystems);
	
	// 
	ParametersSubsystems.Insert("InformationPackagesOnStart", NewUpdateParameterProperties(ShouldUpdate));
	Parameters.Insert("InformationOnStart", ParametersSubsystems);
	
	// 
	ParametersSubsystems.Insert("SystemChecksAccounting", NewUpdateParameterProperties(ShouldUpdate));
	Parameters.Insert("AccountingAudit", ParametersSubsystems);
	
	Return Parameters;
	
EndFunction

// Parameters:
//  Parameters - See ParametersOfUpdate
//  FormIdentifier - UUID
//
Procedure ExecuteUpdateUnsharedDataInBackground(Parameters, FormIdentifier) Export
	
	OperationParametersList = TimeConsumingOperations.BackgroundExecutionParameters(FormIdentifier);
	OperationParametersList.BackgroundJobDescription = NStr("en = 'Update shared service data';");
	OperationParametersList.NoExtensions = True;
	OperationParametersList.WaitCompletion = Undefined;
	
	ProcedureName = "InformationRegisters.ApplicationRuntimeParameters.LongOperationHandlerPerformUpdateUnsharedData";
	TimeConsumingOperation = TimeConsumingOperations.ExecuteInBackground(ProcedureName, Parameters, OperationParametersList);
	
	If TimeConsumingOperation.Status <> "Completed2" Then
		If TimeConsumingOperation.Status = "Error" Then
			ErrorText = TimeConsumingOperation.DetailErrorDescription;
		ElsIf TimeConsumingOperation.Status = "Canceled" Then
			ErrorText = NStr("en = 'The background job is canceled';");
		Else
			ErrorText = NStr("en = 'Background job error';");
		EndIf;
		Raise ErrorText;
	EndIf;
	
	Result = GetFromTempStorage(TimeConsumingOperation.ResultAddress);
	If TypeOf(Result) <> Type("Structure") Then
		ErrorText = NStr("en = 'Background job did not return the result';");
		Raise ErrorText;
	EndIf;
	
	Parameters = Result;
	
EndProcedure

// Parameters:
//  Parameters - See ParametersOfUpdate
//  ResultAddress - String
//
Procedure LongOperationHandlerPerformUpdateUnsharedData(Parameters, ResultAddress) Export
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	
	If ValueIsFilled(SessionParameters.AttachedExtensions) Then
		ErrorText =
			NStr("en = 'Cannot update application parameters. Reason:
			           |Attached configuration extensions are found.';");
		Raise ErrorText;
	EndIf;
	
	If Common.DataSeparationEnabled()
	   And Common.SeparatedDataUsageAvailable() Then
		ErrorText =
			NStr("en = 'Cannot update application parameters. Reason:
			           |Cannot perform the update in the data area.';");
		Raise ErrorText;
	EndIf;
	
	SetPrivilegedMode(True);
	
	// StandardSubsystems Core
	If Parameters.Core.MetadataObjectIDs.ShouldUpdate Then
		Catalogs.MetadataObjectIDs.UpdateCatalogData(
			Parameters.Core.MetadataObjectIDs.HasChanges);
	EndIf;
	If Parameters.Core.ClearAPIsCache.ShouldUpdate Then
		ClearAPIsCache(
			Parameters.Core.ClearAPIsCache.HasChanges);
	EndIf;
	
	// StandardSubsystems AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		If Parameters.AttachableCommands.PluginCommandsConfig.ShouldUpdate Then
			Parameters.AttachableCommands.PluginCommandsConfig.HasChanges =
				ModuleAttachableCommands.ConfigurationCommonDataNonexclusiveUpdate().HasChanges;
		EndIf;
	EndIf;
	
	// StandardSubsystems Users
	If Parameters.Users.CheckRoleAssignment.ShouldUpdate Then
		Users.CheckRoleAssignment(True);
	EndIf;
	
	// StandardSubsystems AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		If Parameters.AccessManagement.RolesRights.ShouldUpdate Then
			ModulePermissionsRoles = Common.CommonModule("InformationRegisters.RolesRights");
			ModulePermissionsRoles.UpdateRegisterData(Parameters.AccessManagement.RolesRights.HasChanges);
		EndIf;
		If Parameters.AccessManagement.RightsDependencies.ShouldUpdate Then
			AccessRightDependencyModule = Common.CommonModule("InformationRegisters.AccessRightsDependencies");
			AccessRightDependencyModule.UpdateRegisterData(Parameters.AccessManagement.RightsDependencies.HasChanges);
		EndIf;
		If Parameters.AccessManagement.AccessKindsProperties.ShouldUpdate Then
			ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
			ModuleAccessManagementInternal.UpdateAccessKindsPropertiesDetails(
				Parameters.AccessManagement.AccessKindsProperties.HasChanges);
		EndIf;
		If Parameters.AccessManagement.SuppliedAccessGroupProfilesDescription.ShouldUpdate Then
			ModuleAccessGroupsProfiles = Common.CommonModule("Catalogs.AccessGroupProfiles");
			ModuleAccessGroupsProfiles.UpdatePredefinedProfileComposition(
				Parameters.AccessManagement.SuppliedAccessGroupProfilesDescription.HasChanges);
			ModuleAccessGroupsProfiles.UpdateSuppliedProfilesDescription(
				Parameters.AccessManagement.SuppliedAccessGroupProfilesDescription.HasChanges);
		EndIf;
		If Parameters.AccessManagement.AvailableRightsForObjectsRightSettingsDetails.ShouldUpdate Then
			ModuleSettingsRightsObjects = Common.CommonModule("InformationRegisters.ObjectsRightsSettings");
			ModuleSettingsRightsObjects.UpdateAvailableRightsForObjectsRightsSettings(
				Parameters.AccessManagement.AvailableRightsForObjectsRightSettingsDetails.HasChanges);
		EndIf;
	EndIf;
	
	// StandardSubsystems ReportsOptions
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		Settings = ModuleReportsOptions.SettingsUpdateParameters();
		Settings.SharedData = True; // Предопределенные.
		Settings.SeparatedData = False;
		If Parameters.ReportsOptions.ParametersReportsConfiguration.ShouldUpdate Then
			Settings.Configuration = True;
			Settings.Extensions = False;
			Settings.Nonexclusive = True; // 
			Settings.Deferred2 = False;
			Parameters.ReportsOptions.ParametersReportsConfiguration.HasChanges =
				ModuleReportsOptions.Refresh(Settings).HasChanges;
		EndIf;
		If Parameters.ReportsOptions.ParametersIndexSearchReportsConfiguration.ShouldUpdate
		   And ModuleReportsOptions.SharedDataIndexingAllowed() Then
			Settings.Configuration = True;
			Settings.Extensions = False;
			Settings.Nonexclusive = False;
			Settings.Deferred2 = True; // 
			Settings.IndexSchema = True; // 
			Parameters.ReportsOptions.ParametersIndexSearchReportsConfiguration.HasChanges =
				ModuleReportsOptions.Refresh(Settings).HasChanges;
		EndIf;
	EndIf;
	
	// StandardSubsystems NotificationAtStartup
	If Common.SubsystemExists("StandardSubsystems.InformationOnStart") Then
		ModuleInformationOnStart = Common.CommonModule("InformationOnStart");
		If Parameters.InformationOnStart.InformationPackagesOnStart.ShouldUpdate Then
			Parameters.InformationOnStart.InformationPackagesOnStart.HasChanges =
				ModuleInformationOnStart.Refresh().HasChanges;
		EndIf;
	EndIf;
	
	// StandardSubsystems AccountingAudit
	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternal = Common.CommonModule("AccountingAuditInternal");
		If Parameters.AccountingAudit.SystemChecksAccounting.ShouldUpdate Then
			ModuleAccountingAuditInternal.UpdateAccountingChecksParameters(
				Parameters.AccountingAudit.SystemChecksAccounting.HasChanges);
		EndIf;
	EndIf;
	
	PutToTempStorage(Parameters, ResultAddress);
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

// To call from the background job with the current configuration extensions.
Procedure ApplicationParametersImportLongRunningOperationHandler(ReportProgress, StorageAddress) Export
	
	ExecutionResult = New Structure;
	ExecutionResult.Insert("BriefErrorDescription",   Undefined);
	ExecutionResult.Insert("DetailErrorDescription", Undefined);
	
	Try
		LoadProgramOperationParametersTakingIntoAccountExecutionMode(ReportProgress);
	Except
		ErrorInfo = ErrorInfo();
		ExecutionResult.BriefErrorDescription   = ErrorProcessing.BriefErrorDescription(ErrorInfo);
		ExecutionResult.DetailErrorDescription = ErrorProcessing.DetailErrorDescription(ErrorInfo);
		// 
		// 
		If Common.SubsystemExists("StandardSubsystems.DataExchange")
		   And Common.IsSubordinateDIBNode() Then
			ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
			ModuleDataExchangeServer.EnableDataExchangeMessageImportRecurrenceBeforeStart();
		EndIf;
	EndTry;
	
	PutToTempStorage(ExecutionResult, StorageAddress);
	
EndProcedure

// To call from the background job without attached configuration extensions.
Procedure ApplicationParametersUpdateLongRunningOperationHandler(ReportProgress, StorageAddress) Export
	
	ExecutionResult = New Structure;
	ExecutionResult.Insert("BriefErrorDescription",   Undefined);
	ExecutionResult.Insert("DetailErrorDescription", Undefined);
	
	Try
		UpdateProgramOperationParametersBasedOnExecutionMode(ReportProgress);
	Except
		ErrorInfo = ErrorInfo();
		ExecutionResult.BriefErrorDescription   = ErrorProcessing.BriefErrorDescription(ErrorInfo);
		ExecutionResult.DetailErrorDescription = ErrorProcessing.DetailErrorDescription(ErrorInfo);
		// 
		// 
		If Common.SubsystemExists("StandardSubsystems.DataExchange")
		   And Common.IsSubordinateDIBNode() Then
			ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
			ModuleDataExchangeServer.EnableDataExchangeMessageImportRecurrenceBeforeStart();
		EndIf;
	EndTry;
	
	PutToTempStorage(ExecutionResult, StorageAddress);
	
EndProcedure

// To call from the background job with the current configuration extensions.
Procedure ExtensionsVersionsParametersUpdateLongRunningOperationHandler(ReportProgress, StorageAddress) Export
	
	ExecutionResult = New Structure;
	ExecutionResult.Insert("BriefErrorDescription",   Undefined);
	ExecutionResult.Insert("DetailErrorDescription", Undefined);
	
	Try
		UpdateParametersOfExtensionVersionsTakingIntoAccountExecutionMode(ReportProgress);
	Except
		ErrorInfo = ErrorInfo();
		ExecutionResult.BriefErrorDescription   = ErrorProcessing.BriefErrorDescription(ErrorInfo);
		ExecutionResult.DetailErrorDescription = ErrorProcessing.DetailErrorDescription(ErrorInfo);
		// 
		// 
		If Common.SubsystemExists("StandardSubsystems.DataExchange")
		   And Common.IsSubordinateDIBNode() Then
			ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
			ModuleDataExchangeServer.EnableDataExchangeMessageImportRecurrenceBeforeStart();
		EndIf;
	EndTry;
	
	PutToTempStorage(ExecutionResult, StorageAddress);
	
EndProcedure

Procedure LoadProgramOperationParametersTakingIntoAccountExecutionMode(ReportProgress)
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	
	If Common.DataSeparationEnabled()
	   And Common.SeparatedDataUsageAvailable() Then
		ErrorText =
			NStr("en = 'Cannot import application parameters. Reason:
			           |Cannot perform the import in the data area.';");
		Raise ErrorText;
	EndIf;
	
	SubordinateDIBNodeSetup = False;
	If Not UpdateRequired1(SubordinateDIBNodeSetup)
	 Or Not Common.IsSubordinateDIBNode() Then
		Return;
	EndIf;
	
	// 
	ModulePerformanceMonitor = Undefined;
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not SubordinateDIBNodeSetup Then
		StandardProcessing = True;
		CommonOverridable.BeforeImportPriorityDataInSubordinateDIBNode(
			StandardProcessing);
		
		If StandardProcessing = True
		   And Common.SubsystemExists("StandardSubsystems.DataExchange") Then
			
			// 
			ModuleDataExchangeServer.ImportPriorityDataToSubordinateDIBNode();
		EndIf;
		
	ElsIf Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleStandaloneModeInternal = Common.CommonModule("StandaloneModeInternal");
		If ModuleStandaloneModeInternal.MustPerformStandaloneWorkstationSetupOnFirstStart() Then
			ModuleStandaloneModeInternal.PerformStandaloneWorkstationSetupOnFirstStart(True);
		EndIf;
	EndIf;
	
	If ReportProgress Then
		TimeConsumingOperations.ReportProgress(5);
	EndIf;
	
	// 
	ListOfCriticalChanges = "";
	Try
		Catalogs.MetadataObjectIDs.RunDataUpdate(False, False, True, , ListOfCriticalChanges);
	Except
		// 
		// 
		If Not SubordinateDIBNodeSetup
		   And Common.SubsystemExists("StandardSubsystems.DataExchange") Then
			ModuleDataExchangeServer.EnableDataExchangeMessageImportRecurrenceBeforeStart();
		EndIf;
		Raise;
	EndTry;
	
	If ValueIsFilled(ListOfCriticalChanges) Then
		
		EventName = NStr("en = 'Metadata object IDs.Import of critical changes required';",
			Common.DefaultLanguageCode());
		
		WriteLogEvent(EventName, EventLogLevel.Error, , , ListOfCriticalChanges);
		
		// 
		// 
		If Not SubordinateDIBNodeSetup
		   And Common.SubsystemExists("StandardSubsystems.DataExchange") Then
			ModuleDataExchangeServer.EnableDataExchangeMessageImportRecurrenceBeforeStart();
		EndIf;
		
		ErrorTemplate =
			NStr("en = 'The infobase cannot be updated. Possible reasons:
			           |- The master node was updated incorrectly (the configuration version number might not be incremented,
			           | therefore the ""Metadata object IDs"" catalog was not populated).
			           |- Export of priority data (items of the ""Metadata object IDs"" catalog)
			           |was canceled.
			           |
			           |Update the master node again, register priority data for export,
			           |and repeat data synchronization:
			           |- In the master node, run the application with "" %1"" command-line option.
			           |%2';");
		
		If SubordinateDIBNodeSetup Then
			// 
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate,
				"/C" + " " + "StartInfobaseUpdate",
				NStr("en = '- Then retry creating a subordinate node.';"));
		Else
			// 
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate,
				"/C" + " " + "StartInfobaseUpdate",
				NStr("en = '- Then repeat data synchronization with this infobase: 
				           | first in the master node, then in the infobase (restart the infobase before the synchronization).';"));
		EndIf;
		
		Raise ErrorText;
	EndIf;
	
	If ReportProgress Then
		TimeConsumingOperations.ReportProgress(10);
	EndIf;
	
	If ModulePerformanceMonitor <> Undefined Then
		ModulePerformanceMonitor.EndTimeMeasurement("PriorityDataImportTime", BeginTime);
	EndIf;
	
EndProcedure

Procedure UpdateProgramOperationParametersBasedOnExecutionMode(ReportProgress)
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	
	If ValueIsFilled(SessionParameters.AttachedExtensions)
		And Not UpdateWithoutBackgroundJob() Then
		ErrorText =
			NStr("en = 'Cannot update application parameters. Reason:
			           |Attached configuration extensions are found.';");
		Raise ErrorText;
	EndIf;
	
	If Common.DataSeparationEnabled()
	   And Common.SeparatedDataUsageAvailable() Then
		ErrorText =
			NStr("en = 'Cannot update application parameters. Reason:
			           |Cannot perform the update in the data area.';");
		Raise ErrorText;
	EndIf;
	
	ModulePerformanceMonitor = Undefined;
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	// 
	// 
	// 
	// 
	UpdateApplicationParameters(ReportProgress);
	
	If ModulePerformanceMonitor <> Undefined Then
		ModulePerformanceMonitor.EndTimeMeasurement("MetadataCacheUpdateTime", BeginTime);
	EndIf;
	
EndProcedure

Procedure UpdateParametersOfExtensionVersionsTakingIntoAccountExecutionMode(ReportProgress)
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	If ReportProgress Then
		TimeConsumingOperations.ReportProgress(65);
	EndIf;
	
	If InfobaseUpdateInternal.IsStartInfobaseUpdateSet() Then
		InformationRegisters.ExtensionVersionParameters.ClearAllExtensionParameters();
	EndIf;
	
	If ReportProgress Then
		TimeConsumingOperations.ReportProgress(75);
	EndIf;
	
	InformationRegisters.ExtensionVersionParameters.FillAllExtensionParameters();
	InformationRegisters.ExtensionVersionParameters.MarkFillingOptionsExtensionsWork();
	
	If ReportProgress Then
		TimeConsumingOperations.ReportProgress(95);
	EndIf;
	
EndProcedure

// This method is required by ApplicationParameterChanges function.
Function NextVersion(Version)
	
	Array = StrSplit(Version, ".");
	
	Return CommonClientServer.ConfigurationVersionWithoutBuildNumber(
		Version) + "." + Format(Number(Array[3]) + 1, "NG=");
	
EndFunction

// For the ImportUpdateApplicationParameters procedures.
Procedure UpdateApplicationParameters(ReportProgress = False)
	
	If ReportProgress Then
		TimeConsumingOperations.ReportProgress(15);
	EndIf;
	
	If Not StandardSubsystemsCached.DisableMetadataObjectsIDs() Then
		Catalogs.MetadataObjectIDs.RunDataUpdate(False, False, False);
	EndIf;
	If ReportProgress Then
		TimeConsumingOperations.ReportProgress(25);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.UpdateAccessRestrictionParameters();
	EndIf;
	
	If ReportProgress Then
		TimeConsumingOperations.ReportProgress(45);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternal = Common.CommonModule("AccountingAuditInternal");
		ModuleAccountingAuditInternal.UpdateAccountingChecksParameters();
	EndIf;
	
	If ReportProgress Then
		TimeConsumingOperations.ReportProgress(55);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.UpdateDataExchangeRules();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.UpdateTemplatesCheckSum();
	EndIf;
	
	If ReportProgress Then
		TimeConsumingOperations.ReportProgress(65);
	EndIf;
	
	ParameterName = "StandardSubsystems.Core.AllApplicationParametersUpdateDate";
	StandardSubsystemsServer.SetApplicationParameter(ParameterName, CurrentSessionDate());
	
	If Common.SeparatedDataUsageAvailable()
	   And Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.SetAccessUpdate(True);
	EndIf;
	
EndProcedure

// This method is required by ApplicationParameter function and UpdateApplicationParameter procedure.
Function ApplicationParameterValueDescription(ParameterName, CheckIfCanUpdateSaaS = True)
	
	ValueDescription = ApplicationParameterStoredData(ParameterName);
	
	If TypeOf(ValueDescription) <> Type("Structure")
	 Or ValueDescription.Count() <> 2
	 Or Not ValueDescription.Property("Version")
	 Or Not ValueDescription.Property("Value") Then
		
		StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
		ValueDescription = New Structure("Version, Value");
		If CheckIfCanUpdateSaaS Then
			CheckIfCanUpdateSaaS(ParameterName, Null, "Receive");
		EndIf;
	EndIf;
	
	Return ValueDescription;
	
EndFunction

// 
// 
// 
//
Function ApplicationParameterStoredData(ParameterName)
	
	Query = New Query;
	Query.SetParameter("ParameterName", ParameterName);
	Query.Text =
	"SELECT
	|	ApplicationRuntimeParameters.ParameterStorage
	|FROM
	|	InformationRegister.ApplicationRuntimeParameters AS ApplicationRuntimeParameters
	|WHERE
	|	ApplicationRuntimeParameters.ParameterName = &ParameterName";
	
	Content = Undefined;
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Try
			Content = Selection.ParameterStorage.Get();
		Except
			// 
			// 
			Content = Undefined;
			ErrorInfo = ErrorInfo();
			Comment = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'When getting application parameter
				           |%1
				           |, an error of retrieving the value from the storage occurred:
				           |%2';"),
				ParameterName,
				ErrorProcessing.DetailErrorDescription(ErrorInfo));
			EventName = NStr("en = 'Application parameters.Get parameter';",
				Common.DefaultLanguageCode());
			WriteLogEvent(EventName, EventLogLevel.Information,,, Comment);
		EndTry;
	EndIf;
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
	Return Content;
	
EndFunction

// 
Procedure SetApplicationParameterStoredData(ParameterName, StoredData)
	
	RecordSet = ServiceRecordSet(InformationRegisters.ApplicationRuntimeParameters);
	RecordSet.Filter.ParameterName.Set(ParameterName);
	
	NewRecord = RecordSet.Add();
	NewRecord.ParameterName       = ParameterName;
	NewRecord.ParameterStorage = New ValueStorage(StoredData);
	
	RecordSet.Write();
	
EndProcedure

Procedure CheckIfCanUpdateSaaS(Val ParameterName, NewValue, Val Operation)
	
	If Not Common.DataSeparationEnabled()
	 Or Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	If StrEndsWith(ParameterName, ChangeStorageParameterNameClarification()) Then
		ParameterName = Mid(ParameterName, 1, StrLen(ParameterName)
			- StrLen(ChangeStorageParameterNameClarification()));
		If Operation = "Receive" Then
			Operation = "GettingChanges";
		ElsIf Operation = "Set" Then
			Operation = "AddChanges";
		EndIf;
	EndIf;
	
	// Writing the error context to the event log for the service administrator.
	ValueDescription = ApplicationParameterStoredData(ParameterName);
	
	ChangeStorageParameterName = ParameterName + ChangeStorageParameterNameClarification();
	LastChanges = ApplicationParameterStoredData(ChangeStorageParameterName);
	
	EventName = NStr("en = 'Application parameters.Not updated in shared mode';",
		Common.DefaultLanguageCode());
	
	Comment = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '1. Send the message to the technical support.
		           |2. Attempt to resolve the issue manually: run the application
		           |with ""%1"" command-line option
		           |on behalf of a user with service administrator rights
		           |(in shared mode).
		           |
		           |Invalid application parameter:';"),
		"/From1" + " " + "StartInfobaseUpdate");

	Comment = Comment + Chars.LF +
	"MetadataVersion = " + Metadata.Version + "
	|ParameterName = " + ParameterName + "
	|Operation = " + Operation + "
	|ValueDescription =
	|" + XMLString(New ValueStorage(ValueDescription)) + "
	|NewValue =
	|" + XMLString(New ValueStorage(NewValue)) + "
	|LastChanges =
	|" + XMLString(New ValueStorage(LastChanges));
	
	WriteLogEvent(EventName, EventLogLevel.Error,,, Comment);
	
	// Exception for the user.
	ErrorText =
		NStr("en = 'The application parameters are not updated in shared mode.
		           |Please contact the service administrator. See the Event log for details.';");
	
	Raise ErrorText;
	
EndProcedure

Function ChangeStorageParameterNameClarification()
	Return ":Changes";
EndFunction

// Parameters:
//  LastChanges - See ApplicationParameterChangesCollection
//
Function IsApplicationParameterChanges(LastChanges)
	
	If TypeOf(LastChanges)              <> Type("ValueTable")
	 Or LastChanges.Columns.Count() <> 2
	 Or LastChanges.Columns[0].Name       <> "ConfigurationVersion"
	 Or LastChanges.Columns[1].Name       <> "Changes" Then
		
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Function CanExecuteBackgroundJobs()
	
	If CurrentRunMode() = Undefined
	   And Common.FileInfobase() Then
		
		Session = GetCurrentInfoBaseSession();
		If Session.ApplicationName = "COMConnection"
		 Or Session.ApplicationName = "BackgroundJob" Then
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

Function UpdateWithoutBackgroundJob()
	
	If Not CanExecuteBackgroundJobs() Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Returns:
//  ValueTable:
//   * ConfigurationVersion - String
//   * Changes - Arbitrary
//
Function ApplicationParameterChangesCollection()

	Result = New ValueTable;
	Result.Columns.Add("ConfigurationVersion");
	Result.Columns.Add("Changes");

	Return Result;
	
EndFunction

// Creates a record set of a service register that does subscribe to events.
// 
// Parameters:
//  RegisterManager - InformationRegisterManager
//  
// Returns:
//  InformationRegisterRecordSet
//  
Function ServiceRecordSet(RegisterManager) Export
	
	RecordSet = RegisterManager.CreateRecordSet();
	RecordSet.AdditionalProperties.Insert("DontControlObjectsToDelete");
	RecordSet.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
	RecordSet.DataExchange.Recipients.AutoFill = False;
	RecordSet.DataExchange.Load = True;
	
	Return RecordSet;
	
EndFunction

#Region DeveloperToolUpdateAuxiliaryData

// Returns:
//  Structure:
//   * ShouldUpdate     - Boolean - an initial value is True.
//   * HasChanges - Boolean - the initial value is False.
//
Function NewUpdateParameterProperties(ShouldUpdate)
	
	NewProperties = New Structure;
	NewProperties.Insert("ShouldUpdate", ShouldUpdate);
	NewProperties.Insert("HasChanges", False);
	
	Return NewProperties;
	
EndFunction

Procedure ClearAPIsCache(HasChanges)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.ProgramInterfaceCache AS ProgramInterfaceCache";
	
	Block = New DataLock;
	Block.Add("InformationRegister.ProgramInterfaceCache");
	
	BeginTransaction();
	Try
		Block.Lock();
		
		If Not Query.Execute().IsEmpty() Then
			RecordSet = InformationRegisters.ProgramInterfaceCache.CreateRecordSet();
			RecordSet.Write();
			HasChanges = True;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf
