///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// Checks whether the security profiles can be set up for the current infobase.
//
// Returns: 
//   Boolean - 
//
Function CanSetUpSecurityProfiles() Export
	
	If SecurityProfilesUsageAvailable() Then
		
		Cancel = False;
		
		SSLSubsystemsIntegration.OnCheckCanSetupSecurityProfiles(Cancel);
		If Not Cancel Then
			SafeModeManagerOverridable.OnCheckCanSetupSecurityProfiles(Cancel);
		EndIf;
		
		Return Not Cancel;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// External modules.
//

// Returns external module attachment mode.
//
// Parameters:
//  ExternalModule - AnyRef - a reference that matches the external module for which
//    the attaching mode is requested.
//
// Returns:
//   String - 
//  
//
Function ExternalModuleAttachmentMode(Val ExternalModule) Export
	
	Return InformationRegisters.ExternalModulesAttachmentModes.ExternalModuleAttachmentMode(ExternalModule);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Security profile usage.
//

// Returns a namespace URI of an XDTO package used to describe permissions
// in security profiles.
//
// Returns:
//   String
//
Function Package() Export
	
	Return Metadata.XDTOPackages.ApplicationPermissions_1_0_0_2.Namespace;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Create permission requests.
//

// Creates requests to use external resources for the external module.
//
// Parameters:
//  ProgramModule - AnyRef - a reference that matches the external module for which permissions are being requested.
//  NewPermissions - Array of XDTODataObject - an array of XDTODataObjects that match internal details of external resource access permissions to be requested.
//    It is assumed that all XDTODataObjects passed 
//    as parameters are generated using the SafeModeManager.Permission*() functions.
//    When requesting permissions for external modules, permissions are added in replacement mode.
//
// Returns:
//   Array of UUID - 
//
Function PermissionsRequestForExternalModule(Val ProgramModule, Val NewPermissions = Undefined) Export
	
	Result = New Array();
	
	If NewPermissions = Undefined Then
		NewPermissions = New Array();
	EndIf;
	
	If NewPermissions.Count() > 0 Then
		
		// If there is no security profile, create it.
		If ExternalModuleAttachmentMode(ProgramModule) = Undefined Then
			Result.Add(RequestForSecurityProfileCreation(ProgramModule));
		EndIf;
		
		Result.Add(
			PermissionChangeRequest(
				ProgramModule, True, NewPermissions, Undefined, ProgramModule));
		
	Else
		
		// If there is a security profile, delete it.
		If ExternalModuleAttachmentMode(ProgramModule) <> Undefined Then
			Result.Add(RequestToDeleteSecurityProfile(ProgramModule));
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Security profile usage.
//

////////////////////////////////////////////////////////////////////////////////
// 
// 
//
// 
// 
// 
//

// Generates parameters for storing references in permission registers.
//
// Parameters:
//  Ref - AnyRef
//
// Returns:
//   Structure:
//                        * Type - CatalogRef.MetadataObjectIDs,
//                        * Id - UUID - a reference
//                           UUID.
//
Function PropertiesForPermissionRegister(Val Ref) Export
	
	Result = New Structure("Type,Id");
	
	If Ref = Catalogs.MetadataObjectIDs.EmptyRef() Then
		
		Result.Type = Catalogs.MetadataObjectIDs.EmptyRef();
		Result.Id = CommonClientServer.BlankUUID();
		
	Else
		
		Result.Type = Common.MetadataObjectID(Ref.Metadata());
		Result.Id = Ref.UUID();
		
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Applying the requests for permissions to use external resources.
//

Function PermissionsToUseExternalResourcesPresentation(Val ProgramModuleType, 
	Val ModuleID, Val OwnerType, Val OwnerID, Val Permissions) Export
	
	// 
	// 
	// 
	
	BeginTransaction();
	Try
		Manager = DataProcessors.ExternalResourcesPermissionsSetup.Create();
		
		Manager.AddRequestForPermissionsToUseExternalResources(
			ProgramModuleType,
			ModuleID,
			OwnerType,
			OwnerID,
			True,
			Permissions,
			New Array());
		
		Manager.CalculateRequestsApplication();
		
		RollbackTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	// ACC:326-
	
	Return Manager.Presentation(True);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddClientParametersOnStart.
Procedure OnAddClientParametersOnStart(Parameters, BeforeUpdateApplicationRunParameters = False) Export
	
	If BeforeUpdateApplicationRunParameters Then
		Parameters.Insert("DisplayPermissionSetupAssistant", False);
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Parameters.Insert("DisplayPermissionSetupAssistant", InteractivePermissionRequestModeUsed());
	If Not Parameters.DisplayPermissionSetupAssistant Then
		Return;
	EndIf;	
	
	If Not Users.IsFullUser() Then
		Return;
	EndIf;	
			
	Validation = ExternalResourcesPermissionsSetupServerCall.CheckApplyPermissionsToUseExternalResources();
	If Validation.CheckResult Then
		Parameters.Insert("CheckExternalResourceUsagePermissionsApplication", False);
	Else
		Parameters.Insert("CheckExternalResourceUsagePermissionsApplication", True);
		Parameters.Insert("PermissionsToUseExternalResourcesApplicabilityCheck", Validation);
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddClientParameters
Procedure OnAddClientParameters(Parameters) Export
	
	SetPrivilegedMode(True);
	Parameters.Insert("DisplayPermissionSetupAssistant", InteractivePermissionRequestModeUsed());
	
EndProcedure


// See ReportsOptionsOverridable.CustomizeReportsOptions.
Procedure OnSetUpReportsOptions(Settings) Export
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.ExternalResourcesInUse);
EndProcedure

#EndRegion

#Region Private

// Creates a request to create a security profile for the external module.
// For internal use only.
//
// Parameters:
//  ExternalModule - AnyRef - a reference that matches the external module for which
//    permissions are being requested (Undefined if permissions are requested for configurations, not for external modules).
//
// Returns:
//   UUID - 
//
Function RequestForSecurityProfileCreation(Val ProgramModule)
	
	StandardProcessing = True;
	Result = Undefined;
	Operation = Enums.SecurityProfileAdministrativeOperations.Creating;
	
	SSLSubsystemsIntegration.OnRequestToCreateSecurityProfile(
		ProgramModule, StandardProcessing, Result);
	
	If StandardProcessing Then
		SafeModeManagerOverridable.OnRequestToCreateSecurityProfile(
			ProgramModule, StandardProcessing, Result);
	EndIf;
	
	If StandardProcessing Then
		
		Result = InformationRegisters.RequestsForPermissionsToUseExternalResources.PermissionAdministrationRequest(
			ProgramModule, Operation);
		
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Security profile usage.
//

// Checks whether the security profiles can be used for the current infobase.
//
// Returns:
//   Boolean
//
Function SecurityProfilesUsageAvailable() Export
	
	If Common.FileInfobase(InfoBaseConnectionString()) Then
		Return False;
	EndIf;
	
	Cancel = False;
	
	SafeModeManagerOverridable.OnCheckSecurityProfilesUsageAvailability(Cancel);
	
	Return Not Cancel;
	
EndFunction

// Returns checksums of add-in files from the bundle provided in the configuration template.
//
// Parameters:
//  TemplateName - String - a configuration template name.
//
// Returns:
//   FixedMap of KeyAndValue:
//                         * Key - String - a file name,
//                         * Value - String - a checksum.
//
Function AddInBundleFilesChecksum(Val TemplateName) Export
	
	Result = New Map();
	
	NameStructure = StrSplit(TemplateName, ".");
	
	If NameStructure.Count() = 2 Then
		
		// This is a common template.
		Template = GetCommonTemplate(NameStructure[1]);
		
	ElsIf NameStructure.Count() = 4 Then
		
		// This is a metadata object template.
		ObjectManager = Common.ObjectManagerByFullName(NameStructure[0] + "." + NameStructure[1]);
		Template = ObjectManager.GetTemplate(NameStructure[3]);
		
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot generate a permission to use the add-in:
				  |incorrect name of the %1 template.';"), TemplateName);
	EndIf;
	
	If Template = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot create a permission to use the add-in supplied in the template %1:
				  | Template %1 is not found in the configuration.';"), TemplateName);
	EndIf;
	
	TemplateType = Metadata.FindByFullName(TemplateName).TemplateType;
	If TemplateType <> Metadata.ObjectProperties.TemplateType.BinaryData And TemplateType <> Metadata.ObjectProperties.TemplateType.AddIn Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot generate a permission to use the add-in:
				  |the %1 template does not contain binary data.';"), TemplateName);
	EndIf;
	
	TempFile = GetTempFileName("zip");
	Template.Write(TempFile);
	
	Archiver = New ZipFileReader(TempFile);
	UnpackDirectory = GetTempFileName() + "\";
	CreateDirectory(UnpackDirectory);
	
	ManifestFile = "";
	For Each ArchiveItem In Archiver.Items Do
		If Upper(ArchiveItem.Name) = "MANIFEST.XML" Then
			ManifestFile = UnpackDirectory + ArchiveItem.Name;
			Archiver.Extract(ArchiveItem, UnpackDirectory);
		EndIf;
	EndDo;
	
	If IsBlankString(ManifestFile) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot create a permission to use the add-in supplied in the template %1:
				  |The archive does not contain the MANIFEST.XML file.';"), TemplateName);
	EndIf;
	
	ReaderStream = New XMLReader();
	ReaderStream.OpenFile(ManifestFile);
	BundleDetails = XDTOFactory.ReadXML(ReaderStream, XDTOFactory.Type("http://v8.1c.ru/8.2/addin/bundle", "bundle"));
	For Each ComponentDetails In BundleDetails.component Do
		
		If ComponentDetails.type = "native" Or ComponentDetails.type = "com" Then
			
			ComponentFile = UnpackDirectory + ComponentDetails.path;
			
			Archiver.Extract(Archiver.Items.Find(ComponentDetails.path), UnpackDirectory);
			
			Hashing = New DataHashing(HashFunction.SHA1);
			Hashing.AppendFile(ComponentFile);
			Result.Insert(ComponentDetails.path, Base64String(Hashing.HashSum));
			
		EndIf;
		
	EndDo;
	
	ReaderStream.Close();
	Archiver.Close();
	
	Try
		DeleteFiles(UnpackDirectory);
	Except
		WriteLogEvent(NStr("en = 'Safe mode manager.Cannot create temporary file';", Common.DefaultLanguageCode()), 
			EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Try
		DeleteFiles(TempFile);
	Except
		WriteLogEvent(NStr("en = 'Safe mode manager.Cannot create temporary file';", Common.DefaultLanguageCode()), 
			EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return New FixedMap(Result);
	
EndFunction

// Generates a reference by data from the permission registers.
//
// Parameters:
//  Type - CatalogRef.MetadataObjectIDs
//  Id - UUID - a reference UUID.
//
// Returns:
//   AnyRef
//
Function ReferenceFormPermissionRegister(Val Type, Val Id) Export
	
	If Type = Catalogs.MetadataObjectIDs.EmptyRef() Then
		Return Type;
	EndIf;
		
	MetadataObject = Common.MetadataObjectByID(Type);
	Manager = Common.ObjectManagerByFullName(MetadataObject.FullName());
	
	If IsBlankString(Id) Then
		Return Manager.EmptyRef();
	Else
		Return Manager.GetRef(Id);
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Create permission requests.
//

// Creates a request for changing permissions to use external resources.
// For internal use only.
//
// Parameters:
//  Owner - AnyRef - an owner of permissions to use external resources.
//    (Undefined when requesting permissions for the configuration, not for configuration objects).
//  ReplacementMode - Boolean - replacement mode of permissions provided earlier for the permission owner.
//  PermissionsToAdd - Array of XDTODataObject - an array of XDTODataObjects that match internal details
//    of external resource access permissions to be requested. It is assumed that all XDTODataObjects passed
//    as parameters are generated using the SafeModeManager.Permission*() functions.
//  PermissionsToDelete - Array of XDTODataObject - an array of XDTODataObjects that match internal details
//    of external resource access permissions to be canceled. It is assumed that all XDTODataObjects passed
//    as parameters are generated using the SafeModeManager.Permission*() functions.
//  ProgramModule - AnyRef - a reference that matches the external module for which
//    permissions are being requested (Undefined if permissions are requested for configurations, not for external modules).
//
// Returns:
//   UUID - 
//
Function PermissionChangeRequest(Val Owner, Val ReplacementMode, Val PermissionsToAdd = Undefined, 
	Val PermissionsToDelete = Undefined, Val ProgramModule = Undefined) Export
	
	StandardProcessing = True;
	Result = Undefined;
	
	SSLSubsystemsIntegration.OnRequestPermissionsToUseExternalResources(
			ProgramModule, Owner, ReplacementMode, PermissionsToAdd, PermissionsToDelete, StandardProcessing, Result);
	
	If StandardProcessing Then
		
		SafeModeManagerOverridable.OnRequestPermissionsToUseExternalResources(
			ProgramModule, Owner, ReplacementMode, PermissionsToAdd, PermissionsToDelete, StandardProcessing, Result);
		
	EndIf;
	
	If StandardProcessing Then
		
		Result = InformationRegisters.RequestsForPermissionsToUseExternalResources.RequestToUsePermissions(
			ProgramModule, Owner, ReplacementMode, PermissionsToAdd, PermissionsToDelete);
		
	EndIf;
	
	Return Result;
	
EndFunction

// Creates a request to delete a security profile for the external module.
// For internal use only.
//
// Parameters:
//  ProgramModule - AnyRef - a reference that matches the external module for which
//    permissions are being requested (Undefined if permissions are requested for configurations, not for external modules).
//
// Returns:
//   UUID - 
//
Function RequestToDeleteSecurityProfile(Val ProgramModule) Export
	
	StandardProcessing = True;
	Result = Undefined;
	Operation = Enums.SecurityProfileAdministrativeOperations.Delete;
	
	SSLSubsystemsIntegration.OnRequestToDeleteSecurityProfile(
			ProgramModule, StandardProcessing, Result);
	
	If StandardProcessing Then
		SafeModeManagerOverridable.OnRequestToDeleteSecurityProfile(
			ProgramModule, StandardProcessing, Result);
	EndIf;
	
	If StandardProcessing Then
		
		Result = InformationRegisters.RequestsForPermissionsToUseExternalResources.PermissionAdministrationRequest(
			ProgramModule, Operation);
		
	EndIf;
	
	Return Result;
	
EndFunction

// Creates requests for application permission update.
//
// Parameters:
//  IncludingIBProfileCreationRequest - Boolean - include a request to create a security profile
//    for the current infobase to the result.
//
// Returns: 
//   Array of UUID - 
//                                       
//
Function RequestsToUpdateApplicationPermissions(Val IncludingIBProfileCreationRequest = True) Export
	
	Result = New Array();
	
	BeginTransaction();
	Try
		If IncludingIBProfileCreationRequest Then
			Result.Add(RequestForSecurityProfileCreation(Catalogs.MetadataObjectIDs.EmptyRef()));
		EndIf;
		
		FillPermissionsToUpdatesProtectionCenter(Result);
		SSLSubsystemsIntegration.OnFillPermissionsToAccessExternalResources(Result);
		SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources(Result);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Result;
	
EndFunction

Procedure FillPermissionsToUpdatesProtectionCenter(PermissionsRequests)
	
	Resolution = SafeModeManager.PermissionToUseInternetResource("HTTPS", "1cv8update.com",, 
		NStr("en = 'The ""Update protection center"" (UPC) site for checking legitimacy of the software usage and updating.';"));
	Permissions = New Array;
	Permissions.Add(Resolution);
	PermissionsRequests.Add(SafeModeManager.RequestToUseExternalResources(Permissions));

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Miscellaneous.
//

// Returns the module that is the external module manager.
//
// Parameters:
//  ExternalModule - AnyRef - a reference that matches the external module for which the manager is being requested.
//
// Returns:
//   CommonModule
//
Function ExternalModuleManager(Val ExternalModule) Export
	
	Managers = ExternalModulesManagers();
	For Each Manager In Managers Do
		ManagerContainers = Manager.ExternalModulesContainers();
		
		If TypeOf(ExternalModule) = Type("CatalogRef.MetadataObjectIDs") Then
			MetadataObject = Common.MetadataObjectByID(ExternalModule);
		Else
			MetadataObject = ExternalModule.Metadata();
		EndIf;
		
		If ManagerContainers.Find(MetadataObject) <> Undefined Then
			Return Manager;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

// Must be called when recording any internal data that cannot
// be changed in the safe mode.
//
Procedure OnSaveInternalData(Object) Export
	
	If SafeModeManager.SafeModeSet() Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t save %1. Safe mode is set: %2.';"),
			Object.Metadata().FullName(),
			SafeMode());
		
	EndIf;
	
EndProcedure

// Checks whether the interactive permission request mode is required.
//
// Returns:
//   Boolean
//
Function InteractivePermissionRequestModeUsed()
	
	If SecurityProfilesUsageAvailable() Then
		
		Return GetFunctionalOption("UseSecurityProfiles") And Constants.AutomaticallyConfigurePermissionsInSecurityProfiles.Get();
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

// Returns an array of the catalog managers that are external module containers.
//
// Returns:
//   Array of CatalogManager
//
Function ExternalModulesManagers()
	
	Managers = New Array;
	
	SSLSubsystemsIntegration.OnRegisterExternalModulesManagers(Managers);
	
	Return Managers;
	
EndFunction

#EndRegion
