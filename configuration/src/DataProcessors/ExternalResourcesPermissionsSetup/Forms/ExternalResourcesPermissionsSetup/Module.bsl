///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Variables

&AtClient
Var StorageAddress;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	StorageAddressAtServer = Parameters.StorageAddress;
	RequestsProcessingResult = GetFromTempStorage(StorageAddressAtServer);
	
	If GetFunctionalOption("UseSecurityProfiles") And Constants.AutomaticallyConfigurePermissionsInSecurityProfiles.Get() Then
		If Parameters.CheckMode Then
			Items.PagesHeader.CurrentPage = Items.ObsoletePermissionsCancellationRequiredInClusterHeaderPage;
		ElsIf Parameters.RecoveryMode Then
			Items.PagesHeader.CurrentPage = Items.SettingsInClusterToSetOnRecoveryHeaderPage;
		Else
			Items.PagesHeader.CurrentPage = Items.ChangesInClusterRequiredHeaderPage;
		EndIf;
	Else
		Items.PagesHeader.CurrentPage = Items.SettingsInClusterToSetOnEnableHeaderPage;
	EndIf;
	
	RequestsApplyingScenario = RequestsProcessingResult.Scenario;
	
	If RequestsApplyingScenario.Count() = 0 Then
		ChangesInSecurityProfilesRequired = False;
		Return;
	EndIf;
	
	PermissionsPresentation = RequestsProcessingResult.Presentation;
	
	ChangesInSecurityProfilesRequired = True;
	InfobaseAdministrationParametersRequired = False;
	For Each ScenarioStep In RequestsApplyingScenario Do
		If ScenarioStep.Operation = Enums.SecurityProfileAdministrativeOperations.Purpose
				Or ScenarioStep.Operation = Enums.SecurityProfileAdministrativeOperations.AssignmentDeletion Then
			InfobaseAdministrationParametersRequired = True;
			Break;
		EndIf;
	EndDo;
	
	AdministrationParameters = StandardSubsystemsServer.AdministrationParameters();
	
	If Common.SeparatedDataUsageAvailable() Then
		
		IBUser = InfoBaseUsers.FindByName(AdministrationParameters.InfobaseAdministratorName);
		If IBUser <> Undefined Then
			IBAdministratorID = IBUser.UUID;
		EndIf;
		
	EndIf;
	
	AttachmentType = AdministrationParameters.AttachmentType;
	ServerClusterPort = AdministrationParameters.ClusterPort;
	
	ServerAgentAddress = AdministrationParameters.ServerAgentAddress;
	ServerAgentPort = AdministrationParameters.ServerAgentPort;
	
	AdministrationServerAddress = AdministrationParameters.AdministrationServerAddress;
	AdministrationServerPort = AdministrationParameters.AdministrationServerPort;
	
	NameInCluster = AdministrationParameters.NameInCluster;
	ClusterAdministratorName = AdministrationParameters.ClusterAdministratorName;
	
	IBUser = InfoBaseUsers.FindByName(AdministrationParameters.InfobaseAdministratorName);
	If IBUser <> Undefined Then
		IBAdministratorID = IBUser.UUID;
	EndIf;
	
	Users.FindAmbiguousIBUsers(Undefined, IBAdministratorID);
	IBAdministrator = Catalogs.Users.FindByAttribute("IBUserID", IBAdministratorID);
	
	Items.AdministrationGroup.Visible = InfobaseAdministrationParametersRequired;
	Items.RestartRequiredWarningGroup.Visible = InfobaseAdministrationParametersRequired;
	
	Items.FormAllow.Title = NStr("en = 'Next >';");
	Items.FormBack.Visible = False;
	
	VisibilityManagement();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
#If MobileClient Then
	ShowMessageBox(, NStr("en = 'The report is unavailable in mobile client. Start thin client or web client.';"));
	Cancel = True;
	Return;
#EndIf
	
#If WebClient Then
	ShowErrorOperationNotSupportedInWebClient();
	Return;
#EndIf
	
	If ChangesInSecurityProfilesRequired Then
		
		StorageAddress = StorageAddressAtServer;
		
	Else
		
		Close(DialogReturnCode.Ignore);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If InfobaseAdministrationParametersRequired Then
		
		If Not ValueIsFilled(IBAdministrator) Then
			Return;
		EndIf;
		
		FieldName = "IBAdministrator";
		IBUser = GetIBAdministrator();
		If IBUser = Undefined Then
			Common.MessageToUser(NStr("en = 'This user is not allowed to access the infobase.';"),,
				FieldName,,Cancel);
			Return;
		EndIf;
		
		If Not Users.IsFullUser(IBUser, True) Then
			Common.MessageToUser(NStr("en = 'This user has no administrative rights.';"),,
				FieldName,,Cancel);
			Return;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ConnectionTypeOnChange(Item)
	
	VisibilityManagement();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Next(Command)
	
	If Items.GroupPages.CurrentPage = Items.PermissionsPage Then
		
		ErrorText = "";
		Items.ErrorGroup.Visible = False;
		Items.FormAllow.Title = NStr("en = 'Set up permissions in server cluster';");
		Items.GroupPages.CurrentPage = Items.ConnectionPage;
		Items.FormBack.Visible = True;
		
	ElsIf Items.GroupPages.CurrentPage = Items.ConnectionPage Then
		
		ErrorText = "";
		Try
			
			ApplyPermissions();
			FinishApplyingRequests(StorageAddress);
			WaitForSettingsApplyingInCluster();
			
		Except
			ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo()); 
			Items.ErrorGroup.Visible = True;
		EndTry;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Back(Command)
	
	If Items.GroupPages.CurrentPage = Items.ConnectionPage Then
		Items.GroupPages.CurrentPage = Items.PermissionsPage;
		Items.FormBack.Visible = False;
		Items.FormAllow.Title = NStr("en = 'Next >';");
	EndIf;
	
EndProcedure

&AtClient
Procedure ReregisterCOMConnector(Command)
	
	CommonClient.RegisterCOMConnector();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure VisibilityManagement()
	
	If AttachmentType = "COM" Then
		Items.ClusterConnectionParametersByProtocolsPages.CurrentPage = Items.COMClusterConnectionParametersPage;
		COMConnectorVersionErrorGroupVisibility = True;
	Else
		Items.ClusterConnectionParametersByProtocolsPages.CurrentPage = Items.RASClusterConnectionParametersPage;
		COMConnectorVersionErrorGroupVisibility = False;
	EndIf;
	
	Items.COMConnectorVersionErrorGroup.Visible = COMConnectorVersionErrorGroupVisibility;
	
EndProcedure

&AtServer
Procedure ShowErrorOperationNotSupportedInWebClient()
	
	Items.PagesGlobal.CurrentPage = Items.OperationNotSupportedInWebClientPage;
	
EndProcedure

&AtServer
Function GetIBAdministrator()
	
	If Not ValueIsFilled(IBAdministrator) Then
		Return Undefined;
	EndIf;
	
	Return InfoBaseUsers.FindByUUID(
		IBAdministrator.IBUserID);
	
EndFunction

&AtServerNoContext
Function InfobaseUserName(Val User)
	
	If ValueIsFilled(User) Then
		
		IBUserID = Common.ObjectAttributeValue(User, "IBUserID");
		IBUser = InfoBaseUsers.FindByUUID(IBUserID);
		Return IBUser.Name;
		
	Else
		
		Return "";
		
	EndIf;
	
EndFunction

&AtClient
Procedure ApplyPermissions()
	
	ApplyPermissionsAtServer(StorageAddress);
	
EndProcedure

&AtServer
Function StartApplyingRequests(Val StorageAddress)
	
	Result = GetFromTempStorage(StorageAddress);
	RequestsApplyingScenario = Result.Scenario;
	
	OperationKinds = New Structure();
	For Each EnumerationValue In Metadata.Enums.SecurityProfileAdministrativeOperations.EnumValues Do
		OperationKinds.Insert(EnumerationValue.Name, Enums.SecurityProfileAdministrativeOperations[EnumerationValue.Name]);
	EndDo;
	
	Return New Structure("OperationKinds, RequestsApplyingScenario, InfobaseAdministrationParametersRequired",
		OperationKinds, RequestsApplyingScenario, InfobaseAdministrationParametersRequired);
	
EndFunction

&AtServer
Procedure FinishApplyingRequests(Val StorageAddress)
	
	DataProcessors.ExternalResourcesPermissionsSetup.CommitRequests(GetFromTempStorage(StorageAddress).State);
	SaveAdministrationParameters();
	
EndProcedure

&AtServer
Procedure SaveAdministrationParameters()
	
	AdministrationParametersToSave = New Structure();
	
	// 
	AdministrationParametersToSave.Insert("AttachmentType", AttachmentType);
	AdministrationParametersToSave.Insert("ServerAgentAddress", ServerAgentAddress);
	AdministrationParametersToSave.Insert("ServerAgentPort", ServerAgentPort);
	AdministrationParametersToSave.Insert("AdministrationServerAddress", AdministrationServerAddress);
	AdministrationParametersToSave.Insert("AdministrationServerPort", AdministrationServerPort);
	AdministrationParametersToSave.Insert("ClusterPort", ServerClusterPort);
	AdministrationParametersToSave.Insert("ClusterAdministratorName", ClusterAdministratorName);
	AdministrationParametersToSave.Insert("ClusterAdministratorPassword", "");
	
	// 
	AdministrationParametersToSave.Insert("NameInCluster", NameInCluster);
	AdministrationParametersToSave.Insert("InfobaseAdministratorName", InfobaseUserName(IBAdministrator));
	AdministrationParametersToSave.Insert("InfobaseAdministratorPassword", "");
	
	StandardSubsystemsServer.SetAdministrationParameters(AdministrationParametersToSave);
	
EndProcedure

&AtClient
Procedure WaitForSettingsApplyingInCluster()
	
	Close(DialogReturnCode.OK);
	
EndProcedure

&AtServer
Procedure ApplyPermissionsAtServer(StorageAddress)
	
	ApplyingParameters = StartApplyingRequests(StorageAddress);
	
	OperationKinds = ApplyingParameters.OperationKinds;
	Scenario = ApplyingParameters.RequestsApplyingScenario;
	IBAdministrationParametersRequired = ApplyingParameters.InfobaseAdministrationParametersRequired;
	
	ClusterAdministrationParameters = ClusterAdministration.ClusterAdministrationParameters();
	ClusterAdministrationParameters.AttachmentType = AttachmentType;
	ClusterAdministrationParameters.ServerAgentAddress = ServerAgentAddress;
	ClusterAdministrationParameters.ServerAgentPort = ServerAgentPort;
	ClusterAdministrationParameters.AdministrationServerAddress = AdministrationServerAddress;
	ClusterAdministrationParameters.AdministrationServerPort = AdministrationServerPort;
	ClusterAdministrationParameters.ClusterPort = ServerClusterPort;
	ClusterAdministrationParameters.ClusterAdministratorName = ClusterAdministratorName;
	ClusterAdministrationParameters.ClusterAdministratorPassword = ClusterAdministratorPassword;
	
	If IBAdministrationParametersRequired Then
		IBAdministrationParameters = ClusterAdministration.ClusterInfobaseAdministrationParameters();
		IBAdministrationParameters.NameInCluster = NameInCluster;
		IBAdministrationParameters.InfobaseAdministratorName = InfobaseUserName(IBAdministrator);
		IBAdministrationParameters.InfobaseAdministratorPassword = IBAdministratorPassword;
	Else
		IBAdministrationParameters = Undefined;
	EndIf;
	
	ApplyPermissionsChangesInSecurityProfilesInServerCluster(
		OperationKinds, Scenario, ClusterAdministrationParameters, IBAdministrationParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 
//

// Applies the security profile permission changes in server cluster by the scenario.
//
// Parameters:
//  OperationKinds - Structure - Describes values of the SecurityProfileAdministrativeOperations enumeration:
//                   * Key - String - an enumeration value name,
//                   * Value - EnumRef.SecurityProfileAdministrativeOperations,
//  PermissionsApplyingScenario - Array of Structure - a scenario of applying changes in permissions to
//    use security profiles in the server cluster. Array values are structures
//    with the following fields:
//                   * Operation - EnumRef.SecurityProfileAdministrativeOperations - an operation to
//                      be executed,
//                   * Profile - String - a security profile name,
//                   * Permissions - See ClusterAdministration.SecurityProfileProperties
//  ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//  InfobaseAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//
&AtServerNoContext
Procedure ApplyPermissionsChangesInSecurityProfilesInServerCluster(Val OperationKinds, Val PermissionsApplyingScenario, Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters = Undefined)
	
	IBAdministrationParametersRequired = (InfobaseAdministrationParameters <> Undefined);
	
	ClusterAdministration.CheckAdministrationParameters(
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters,
		True,
		IBAdministrationParametersRequired);
	
	For Each ScenarioItem In PermissionsApplyingScenario Do
		
		If ScenarioItem.Operation = OperationKinds.Creating Then
			
			If ClusterAdministration.SecurityProfileExists(ClusterAdministrationParameters, ScenarioItem.Profile) Then
				
				Common.MessageToUser(
					StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Security profile %1 already exists in the server cluster. Settings in the security profile will be replaced…';"), ScenarioItem.Profile));
				
				ClusterAdministration.SetSecurityProfileProperties(ClusterAdministrationParameters, ScenarioItem.Permissions);
				
			Else
				
				ClusterAdministration.CreateSecurityProfile(ClusterAdministrationParameters, ScenarioItem.Permissions);
				
			EndIf;
			
		ElsIf ScenarioItem.Operation = OperationKinds.Purpose Then
			
			ClusterAdministration.SetInfobaseSecurityProfile(ClusterAdministrationParameters, InfobaseAdministrationParameters, ScenarioItem.Profile);
			
		ElsIf ScenarioItem.Operation = OperationKinds.RefreshEnabled Then
			
			ClusterAdministration.SetSecurityProfileProperties(ClusterAdministrationParameters, ScenarioItem.Permissions);
			
		ElsIf ScenarioItem.Operation = OperationKinds.Delete Then
			
			If ClusterAdministration.SecurityProfileExists(ClusterAdministrationParameters, ScenarioItem.Profile) Then
				
				ClusterAdministration.DeleteSecurityProfile(ClusterAdministrationParameters, ScenarioItem.Profile);
				
			Else
				
				Common.MessageToUser(
					StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Security profile %1 does not exist in the server cluster. Security profile might have been deleted earlier…';"), ScenarioItem.Profile));
				
			EndIf;
			
		ElsIf ScenarioItem.Operation = OperationKinds.AssignmentDeletion Then
			
			ClusterAdministration.SetInfobaseSecurityProfile(ClusterAdministrationParameters, InfobaseAdministrationParameters, "");
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion