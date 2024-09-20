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

// The procedure updates the register data during the full update of auxiliary data.
//
// Parameters:
//  HasChanges - Boolean - (return value) - if recorded,
//                  True is set, otherwise, it does not change.
//
Procedure UpdateRegisterData(HasChanges = Undefined) Export
	
	If Not AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
		Return;
	EndIf;
	
	If StandardSubsystemsServer.ThisIsSplitSessionModeWithNoDelimiters()
	   And CanExecuteBackgroundJobs() Then
		
		UpdateRegisterDataInBackground(HasChanges);
	Else
		UpdateRegisterDataNotInBackground(HasChanges);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

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

Procedure UpdateRegisterDataNotInBackground(HasChanges)
	
	AccessManagementInternal.ActiveAccessRestrictionParameters(Undefined,
		Undefined, True, False, False, HasChanges);
	
EndProcedure

Procedure UpdateRegisterDataInBackground(HasChanges)
	
	CurrentSession = GetCurrentInfoBaseSession();
	JobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Access management: Update access restriction parameters (from session %1 started on %2)';",
			Common.DefaultLanguageCode()),
		Format(CurrentSession.SessionNumber, "NG="),
		Format(CurrentSession.SessionStarted, "DLF=DT"));
	
	OperationParametersList = TimeConsumingOperations.BackgroundExecutionParameters(Undefined);
	OperationParametersList.BackgroundJobDescription = JobDescription;
	OperationParametersList.WithDatabaseExtensions = True;
	OperationParametersList.WaitCompletion = Undefined;
	
	ProcedureName = "InformationRegisters.AccessRestrictionParameters.HandlerForLongTermUpdateOperationInBackground";
	TimeConsumingOperation = TimeConsumingOperations.ExecuteInBackground(ProcedureName, Undefined, OperationParametersList);
	ErrorTitle = NStr("en = 'Cannot update access restriction parameters due to:';") + Chars.LF;
	
	If TimeConsumingOperation.Status <> "Completed2" Then
		If TimeConsumingOperation.Status = "Error" Then
			ErrorText = TimeConsumingOperation.DetailErrorDescription;
		ElsIf TimeConsumingOperation.Status = "Canceled" Then
			ErrorText = NStr("en = 'The background job is canceled.';");
		Else
			ErrorText = NStr("en = 'Background job error';");
		EndIf;
		Raise ErrorTitle + ErrorText;
	EndIf;
	
	Result = GetFromTempStorage(TimeConsumingOperation.ResultAddress);
	If TypeOf(Result) <> Type("Structure") Then
		ErrorText = NStr("en = 'Background job did not return the result';");
		Raise ErrorTitle + ErrorText;
	EndIf;
	
	If Result.SessionRestartRequired Then
		AccessManagementInternal.CheckWhetherTheMetadataIsUpToDate();
		StandardSubsystemsServer.InstallRequiresSessionRestart(Result.ErrorText);
		Raise ErrorTitle + Result.ErrorText;
	EndIf;
	
	If ValueIsFilled(Result.ErrorText) Then
		Raise ErrorTitle + Result.ErrorText;
	EndIf;
	
	If Result.HasChanges Then
		HasChanges = True;
	EndIf;
	
EndProcedure

// Parameters:
//  Parameters - Undefined
//  ResultAddress - String
//
Procedure HandlerForLongTermUpdateOperationInBackground(Parameters, ResultAddress) Export
	
	Result = New Structure;
	Result.Insert("HasChanges", False);
	Result.Insert("ErrorText", "");
	Result.Insert("SessionRestartRequired", False);
	
	Try
		UpdateRegisterDataNotInBackground(Result.HasChanges);
	Except
		ErrorInfo = ErrorInfo();
		If StandardSubsystemsServer.SessionRestartRequired(Result.ErrorText) Then
			Result.SessionRestartRequired = True;
		EndIf;
		If Not Result.SessionRestartRequired
		 Or Not StandardSubsystemsServer.ThisErrorRequirementRestartSession(ErrorInfo) Then
			Result.ErrorText = ErrorProcessing.DetailErrorDescription(ErrorInfo);
		EndIf;
	EndTry;
	
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

// Updates the version of access restriction texts.
//
// Parameters:
//  HasChanges - Boolean - (return value) - if changes are found
//                  True is set, otherwise, it is not changed.
//
Procedure UpdateAccessRestrictionTextsVersion(HasChanges = Undefined) Export
	
	If Common.DataSeparationEnabled()
	   And Not Common.SeparatedDataUsageAvailable() Then
		
		IBVersion = InfobaseUpdateInternal.IBVersion("StandardSubsystems", True);
	Else
		IBVersion = InfobaseUpdateInternal.IBVersion("StandardSubsystems");
	EndIf;
	
	TextsVersion = AccessRestrictionTextsVersion();
	
	BeginTransaction();
	Try
		HasCurrentChanges = False;
		
		StandardSubsystemsServer.UpdateApplicationParameter(
			"StandardSubsystems.AccessManagement.AccessRestrictionTextsVersion",
			TextsVersion, HasCurrentChanges);
		
		If CommonClientServer.CompareVersions(IBVersion, "3.0.3.168") < 0
		 Or CommonClientServer.CompareVersions(IBVersion, "3.1.1.1") > 0
		   And CommonClientServer.CompareVersions(IBVersion, "3.1.1.109") < 0
		 Or CommonClientServer.CompareVersions(IBVersion, "3.1.2.1") > 0
		   And CommonClientServer.CompareVersions(IBVersion, "3.1.2.249") < 0
		 Or CommonClientServer.CompareVersions(IBVersion, "3.1.3.1") > 0
		   And CommonClientServer.CompareVersions(IBVersion, "3.1.3.4") < 0
		 Or CommonClientServer.CompareVersions(IBVersion, "3.1.4.1") > 0
		   And CommonClientServer.CompareVersions(IBVersion, "3.1.4.376") < 0
		 Or CommonClientServer.CompareVersions(IBVersion, "3.1.5.1") > 0
		   And CommonClientServer.CompareVersions(IBVersion, "3.1.5.475") < 0
		 Or CommonClientServer.CompareVersions(IBVersion, "3.1.6.1") > 0
		   And CommonClientServer.CompareVersions(IBVersion, "3.1.6.275") < 0
		 Or CommonClientServer.CompareVersions(IBVersion, "3.1.7.1") > 0
		   And CommonClientServer.CompareVersions(IBVersion, "3.1.7.100") < 0 Then
			
			HasCurrentChanges = True;
		EndIf;
		
		StandardSubsystemsServer.AddApplicationParameterChanges(
			"StandardSubsystems.AccessManagement.AccessRestrictionTextsVersion",
			?(HasCurrentChanges,
			  New FixedStructure("HasChanges", True),
			  New FixedStructure()) );
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If HasCurrentChanges Then
		HasChanges = True;
	EndIf;
	
EndProcedure

// Updates auxiliary register data after changing
// rights based on access values saved to access restriction parameters.
//
Procedure ScheduleAccessUpdateByConfigurationChanges() Export
	
	SetPrivilegedMode(True);
	
	If AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
		
		LastChanges = StandardSubsystemsServer.ApplicationParameterChanges(
			"StandardSubsystems.AccessManagement.AccessRestrictionTextsVersion");
			
		If LastChanges = Undefined Then
			UpdateRequired = True;
		Else
			UpdateRequired = False;
			For Each ChangesPart In LastChanges Do
				
				If TypeOf(ChangesPart) = Type("FixedStructure")
				   And ChangesPart.Property("HasChanges")
				   And TypeOf(ChangesPart.HasChanges) = Type("Boolean") Then
					
					If ChangesPart.HasChanges Then
						UpdateRequired = True;
						Break;
					EndIf;
				Else
					UpdateRequired = True;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		If UpdateRequired Then
			AccessManagementInternal.ScheduleAccessRestrictionParametersUpdate(
				"ScheduleAccessUpdateByConfigurationChanges");
		EndIf;
	EndIf;
	
	IBVersion = InfobaseUpdateInternal.IBVersion("StandardSubsystems");
	
	If CommonClientServer.CompareVersions(IBVersion, "3.0.3.3") < 0
	 Or CommonClientServer.CompareVersions(IBVersion, "3.1.1.1") > 0
	   And CommonClientServer.CompareVersions(IBVersion, "3.1.1.109") < 0 Then
		
		ScheduleUpdate(False, True, "GoToVersionSSL3.0.3.3");
	EndIf;
	
	If CommonClientServer.CompareVersions(IBVersion, "3.0.3.76") < 0
	 Or CommonClientServer.CompareVersions(IBVersion, "3.1.2.1") > 0
	   And CommonClientServer.CompareVersions(IBVersion, "3.1.2.134") < 0 Then
		
		ScheduleUpdate(True, False, "GoToVersionSSL3.0.3.76");
	EndIf;
	
	If CommonClientServer.CompareVersions(IBVersion, "3.0.3.107") < 0
	 Or CommonClientServer.CompareVersions(IBVersion, "3.1.2.1") > 0
	   And CommonClientServer.CompareVersions(IBVersion, "3.1.2.169") < 0 Then
		
		ScheduleUpdate(False, True, "GoToVersionSSL3.0.3.107");
	EndIf;
	
	If CommonClientServer.CompareVersions(IBVersion, "3.0.3.168") < 0
	 Or CommonClientServer.CompareVersions(IBVersion, "3.1.2.1") > 0
	   And CommonClientServer.CompareVersions(IBVersion, "3.1.2.249") < 0
	 Or CommonClientServer.CompareVersions(IBVersion, "3.1.3.1") > 0
	   And CommonClientServer.CompareVersions(IBVersion, "3.1.3.4") < 0 Then
	
		ScheduleUpdate_00_00268406("GoToVersionSSL3.0.3.168");
	EndIf;
	
	If CommonClientServer.CompareVersions(IBVersion, "3.0.3.190") < 0
	 Or CommonClientServer.CompareVersions(IBVersion, "3.1.2.1") > 0
	   And CommonClientServer.CompareVersions(IBVersion, "3.1.2.269") < 0
	 Or CommonClientServer.CompareVersions(IBVersion, "3.1.3.1") > 0
	   And CommonClientServer.CompareVersions(IBVersion, "3.1.3.26") < 0 Then
		
		ScheduleUpdate_00_00263154("GoToVersionSSL3.0.3.190");
	EndIf;
	
	If CommonClientServer.CompareVersions(IBVersion, "3.1.4.1") > 0
	   And CommonClientServer.CompareVersions(IBVersion, "3.1.4.376") < 0
	 Or CommonClientServer.CompareVersions(IBVersion, "3.1.5.1") > 0
	   And CommonClientServer.CompareVersions(IBVersion, "3.1.5.188") < 0 Then
		
		InformationRegisters.UsedAccessKinds.WhenChangingTheUseOfAccessTypes();
		ScheduleUpdate(False, True, "GoToVersionSSL3.1.4.376");
	EndIf;
	
	If CommonClientServer.CompareVersions(IBVersion, "3.1.5.1") > 0
	   And CommonClientServer.CompareVersions(IBVersion, "3.1.5.475") < 0
	 Or CommonClientServer.CompareVersions(IBVersion, "3.1.6.1") > 0
	   And CommonClientServer.CompareVersions(IBVersion, "3.1.6.275") < 0
	 Or CommonClientServer.CompareVersions(IBVersion, "3.1.7.1") > 0
	   And CommonClientServer.CompareVersions(IBVersion, "3.1.7.100") < 0 Then
		
		InformationRegisters.UsedAccessKinds.WhenChangingTheUseOfAccessTypes();
		ScheduleUpdate_00_00463430("GoToVersionSSL3.1.5.475");
	EndIf;
	
EndProcedure

// For the UpdateRegisterDataByConfigurationChanges procedure.
Procedure ScheduleUpdate(DataAccessKeys, AllowedAccessKeys, LongDesc)
	
	If Not AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
		Return;
	EndIf;
	
	DataRestrictionsDetails = AccessManagementInternal.DataRestrictionsDetails();
	ExternalUsersEnabled = Constants.UseExternalUsers.Get();
	
	Lists = New Array;
	ListsForExternalUsers = New Array;
	For Each KeyAndValue In DataRestrictionsDetails Do
		Lists.Add(KeyAndValue.Key);
		If ExternalUsersEnabled Then
			ListsForExternalUsers.Add(KeyAndValue.Key);
		EndIf;
	EndDo;
	
	PlanningParameters = AccessManagementInternal.AccessUpdatePlanningParameters();
	
	PlanningParameters.DataAccessKeys = DataAccessKeys;
	PlanningParameters.AllowedAccessKeys = AllowedAccessKeys;
	PlanningParameters.ForExternalUsers = False;
	PlanningParameters.IsUpdateContinuation = True;
	PlanningParameters.LongDesc = LongDesc;
	AccessManagementInternal.ScheduleAccessUpdate(Lists, PlanningParameters);
	
	PlanningParameters.ForUsers = False;
	PlanningParameters.ForExternalUsers = True;
	PlanningParameters.LongDesc = LongDesc;
	AccessManagementInternal.ScheduleAccessUpdate(ListsForExternalUsers, PlanningParameters);
	
EndProcedure

// For the UpdateRegisterDataByConfigurationChanges procedure.
Procedure ScheduleUpdate_00_00268406(LongDesc)
	
	If Not AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
		Return;
	EndIf;
	
	TransactionID = New UUID;
	ActiveParameters = AccessManagementInternal.ActiveAccessRestrictionParameters(
		TransactionID, Undefined, False);
	
	Lists = New Array;
	ListsForExternalUsers = New Array;
	ExternalUsersEnabled = Constants.UseExternalUsers.Get();
	
	For Each LeadingList In ActiveParameters.LeadingLists Do
		ByValuesWithGroups = LeadingList.Value.ByValuesWithGroups;
		If ByValuesWithGroups = Undefined Then
			Continue;
		EndIf;
		AddLists0000268406(Lists, ByValuesWithGroups.ForUsers);
		If ExternalUsersEnabled Then
			AddLists0000268406(ListsForExternalUsers, ByValuesWithGroups.ForExternalUsers);
		EndIf;
	EndDo;
	
	PlanningParameters = AccessManagementInternal.AccessUpdatePlanningParameters();
	
	PlanningParameters.DataAccessKeys = True;
	PlanningParameters.AllowedAccessKeys = False;
	PlanningParameters.ForExternalUsers = False;
	PlanningParameters.IsUpdateContinuation = True;
	PlanningParameters.LongDesc = LongDesc;
	AccessManagementInternal.ScheduleAccessUpdate(Lists, PlanningParameters);
	
	PlanningParameters.ForUsers = False;
	PlanningParameters.ForExternalUsers = True;
	PlanningParameters.LongDesc = LongDesc;
	AccessManagementInternal.ScheduleAccessUpdate(ListsForExternalUsers, PlanningParameters);
	
EndProcedure

// For the ScheduleUpdate_00_00268406 procedure.
Procedure AddLists0000268406(Lists, DependentLists)
	
	If DependentLists = Undefined Then
		Return;
	EndIf;
	
	For Each DependentList In DependentLists Do
		MetadataObject = Common.MetadataObjectByFullName(DependentList);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		Lists.Add(DependentList);
	EndDo;
	
EndProcedure

// For the UpdateRegisterDataByConfigurationChanges procedure.
Procedure ScheduleUpdate_00_00263154(LongDesc)
	
	If Not AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
		Return;
	EndIf;
	
	PlanningParameters = AccessManagementInternal.AccessUpdatePlanningParameters(False);
	
	PlanningParameters.AllowedAccessKeys = False;
	PlanningParameters.IsUpdateContinuation = True;
	PlanningParameters.LongDesc = LongDesc;
	AccessManagementInternal.ScheduleAccessUpdate("Catalog.SetsOfAccessGroups",
		PlanningParameters);
	
EndProcedure

// For the procedure update the data of the register of configuration Changes.
Procedure ScheduleUpdate_00_00463430(LongDesc)
	
	If Not AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
		Return;
	EndIf;
	
	TransactionID = New UUID;
	ActiveParameters = AccessManagementInternal.ActiveAccessRestrictionParameters(
		TransactionID, Undefined, False);
	
	AdditionalContext = ActiveParameters.AdditionalContext;
	
	Lists = New Array;
	ListsForExternalUsers = New Array;
	ExternalUsersEnabled = Constants.UseExternalUsers.Get();
	
	AddLists_00_00463430(Lists, AdditionalContext.ForUsers);
	If ExternalUsersEnabled Then
		AddLists_00_00463430(ListsForExternalUsers,
			AdditionalContext.ForExternalUsers);
	EndIf;
	
	PlanningParameters = AccessManagementInternal.AccessUpdatePlanningParameters();
	
	PlanningParameters.DataAccessKeys = False;
	PlanningParameters.AllowedAccessKeys = True;
	PlanningParameters.ForExternalUsers = False;
	PlanningParameters.IsUpdateContinuation = True;
	PlanningParameters.LongDesc = LongDesc;
	AccessManagementInternal.ScheduleAccessUpdate(Lists, PlanningParameters);
	
	PlanningParameters.ForUsers = False;
	PlanningParameters.ForExternalUsers = True;
	PlanningParameters.LongDesc = LongDesc;
	AccessManagementInternal.ScheduleAccessUpdate(ListsForExternalUsers, PlanningParameters);
	
EndProcedure

// 
Procedure AddLists_00_00463430(Lists, AdditionalContext)
	
	ListsWithKeysRecordForDependentListsWithoutKeys =
		AdditionalContext.ListsWithKeysRecordForDependentListsWithoutKeys;
	
	For Each KeyAndValue In AdditionalContext.ListsWithDisabledRestriction Do
		If ListsWithKeysRecordForDependentListsWithoutKeys.Get(KeyAndValue.Key) = Undefined Then
			Continue;
		EndIf;
		MetadataObject = Common.MetadataObjectByFullName(KeyAndValue.Key);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		Lists.Add(MetadataObject.FullName());
	EndDo;
	
EndProcedure

// For the UpdateAccessRestrictionTextsVersion procedure.
Function AccessRestrictionTextsVersion()
	
	RestrictionsDetails = AccessManagementInternal.DataRestrictionsDetails();
	
	AllTexts = New ValueList;
	Separators = " 	" + Chars.LF + Chars.CR + Chars.NBSp + Chars.FF;
	For Each RestrictionDetails In RestrictionsDetails Do
		Restriction = RestrictionDetails.Value;
		Texts = New Array;
		Texts.Add(RestrictionDetails.Key);
		AddProperty(Texts, Restriction, Separators, "Text");
		AddProperty(Texts, Restriction, Separators, "TextForExternalUsers1");
		AddProperty(Texts, Restriction, Separators, "ByOwnerWithoutSavingAccessKeys");
		AddProperty(Texts, Restriction, Separators, "ByOwnerWithoutSavingAccessKeysForExternalUsers");
		AddProperty(Texts, Restriction, Separators, "TextInManagerModule");
		AllTexts.Add(StrConcat(Texts, Chars.LF), RestrictionDetails.Key);
	EndDo;
	AllTexts.SortByPresentation();
	
	WholeText = StrConcat(AllTexts.UnloadValues(), Chars.LF);
	
	Hashing = New DataHashing(HashFunction.SHA256);
	Hashing.Append(WholeText);
	
	Return Base64String(Hashing.HashSum);
	
EndFunction

// For the AccessRestrictionTextsVersion function.
Procedure AddProperty(Texts, Restriction, Separators, PropertyName)
	
	Value = Restriction[PropertyName];
	If TypeOf(Value) = Type("String") Then
		Text = StrConcat(StrSplit(Lower(Value), Separators, False), " ");
	Else
		Text = String(Value);
	EndIf;
	
	Texts.Add("	" + PropertyName + ": " + Text);
	
EndProcedure

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	// 
	Return;
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	EnableUniversalRecordLevelAccessRestriction();
	
	Parameters.ProcessingCompleted = True;
	
EndProcedure

Procedure EnableUniversalRecordLevelAccessRestriction() Export
	
	Constants.LimitAccessAtRecordLevelUniversally.Set(True);
	
EndProcedure

#EndRegion

#EndIf
