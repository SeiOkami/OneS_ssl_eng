///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

////////////////////////////////////////////////////////////////////////////////
// Permission constructors.
//

// Returns the internal description of the permission to use the file system directory.
// For passing as a parameter to functions:
// SafeModeManager.RequestToUseExternalResources and
// SafeModeManager.RequestToCancelPermissionsToUseExternalResources.
//
// Parameters:
//  Address - String - a file system resource address.
//  DataReader - Boolean - indicates that it is required to grant permissions
//                          to read data from this file system directory.
//  DataWriter - Boolean - indicates that it is required to grant permissions
//                          to write data to the specified file system directory.
//  LongDesc - String - details on the reason to grant the permission.
//
// Returns:
//  XDTODataObject 
//
Function PermissionToUseFileSystemDirectory(Val Address, Val DataReader = False, Val DataWriter = False, Val LongDesc = "") Export
	
	Package = SafeModeManagerInternal.Package();
	Result = XDTOFactory.Create(XDTOFactory.Type(Package, "FileSystemAccess"));
	Result.Description = LongDesc;
	
	If StrEndsWith(Address, "\") Or StrEndsWith(Address, "/") Then
		Address = Left(Address, StrLen(Address) - 1);
	EndIf;
	
	Result.Path = Address;
	Result.AllowedRead = DataReader;
	Result.AllowedWrite = DataWriter;
	
	Return Result;
	
EndFunction

// Returns the internal description of the permission to use the temporary file directory.
// For passing as a parameter to functions:
// SafeModeManager.RequestToUseExternalResources and
// SafeModeManager.RequestToCancelPermissionsToUseExternalResources.
//
// Parameters:
//  DataReader - Boolean - indicates that it is required to grant a permission
//                          to read data from the temporary file directory.
//  DataWriter - Boolean - indicates that it is required to grant a permission
//                          to write data to the temporary file directory.
//  LongDesc - String - details on the reason to grant the permission.
//
// Returns:
//  XDTODataObject
//
Function PermissionToUseTempDirectory(Val DataReader = False, Val DataWriter = False, Val LongDesc = "") Export
	
	Return PermissionToUseFileSystemDirectory(TempDirectoryAlias(), DataReader, DataWriter);
	
EndFunction

// Returns the internal description of the permission to use the application directory.
// For passing as a parameter to functions:
// SafeModeManager.RequestToUseExternalResources and
// SafeModeManager.RequestToCancelPermissionsToUseExternalResources.
//
// Parameters:
//  DataReader - Boolean - indicates that it is required to grant a permission
//                          to read data from the application directory.
//  DataWriter - Boolean - indicates that it is required to grant a permission
//                          to write data to the application directory.
//  LongDesc - String - details on the reason to grant the permission.
//
// Returns:
//  XDTODataObject
//
Function PermissionToUseApplicationDirectory(Val DataReader = False, Val DataWriter = False, Val LongDesc = "") Export
	
	Return PermissionToUseFileSystemDirectory(ApplicationDirectoryAlias(), DataReader, DataWriter);
	
EndFunction

// Returns the internal description of the permission to use the COM class.
// For passing as a parameter to functions:
// SafeModeManager.RequestToUseExternalResources and
// SafeModeManager.RequestToCancelPermissionsToUseExternalResources.
//
// Parameters:
//  ProgID - String - ProgID of COM class, with which it is registered in the application.
//                    For example, "Excel.Application".
//  CLSID - String - a CLSID of a COM class, with which it is registered in the application.
//  ComputerName - String - a name of the computer where the specified object must be created.
//                           If the parameter is skipped, an object will be created on the computer where the
//                           current working process is running.
//  LongDesc - String - details on the reason to grant the permission.
//
// Returns:
//  XDTODataObject
//
Function PermissionToCreateCOMClass(Val ProgID, Val CLSID, Val ComputerName = "", Val LongDesc = "") Export
	
	Package = SafeModeManagerInternal.Package();
	Result = XDTOFactory.Create(XDTOFactory.Type(Package, "CreateComObject"));
	Result.Description = LongDesc;
	
	Result.ProgId = ProgID;
	Result.CLSID = String(CLSID);
	Result.ComputerName = ComputerName;
	
	Return Result;
	
EndFunction

// Returns the internal description of the permission to use the add-in distributed
// in the common configuration template.
// For passing as a parameter to functions:
// SafeModeManager.RequestToUseExternalResources and
// SafeModeManager.RequestToCancelPermissionsToUseExternalResources.
//
// Parameters:
//  TemplateName - String - a name of the common template in the configuration that stores the add-in.
//  LongDesc - String - details on the reason to grant the permission.
//
// Returns:
//  XDTODataObject
//
Function PermissionToUseAddIn(Val TemplateName, Val LongDesc = "") Export
	
	Package = SafeModeManagerInternal.Package();
	Result = XDTOFactory.Create(XDTOFactory.Type(Package, "AttachAddin"));
	Result.Description = LongDesc;
	
	Result.TemplateName = TemplateName;
	
	Return Result;
	
EndFunction

// Returns the internal description of the permission to use the application extension.
// For passing as a parameter to functions:
// SafeModeManager.RequestToUseExternalResources and
// SafeModeManager.RequestToCancelPermissionsToUseExternalResources.
//
// Parameters:
//  Name - String - a configuration extension name.
//  Checksum - String - a configuration extension checksum.
//  LongDesc - String - details on the reason to grant the permission.
//
// Returns:
//  XDTODataObject
//
Function PermissionToUseExternalModule(Val Name, Val Checksum, Val LongDesc = "") Export
	
	Package = SafeModeManagerInternal.Package();
	Result = XDTOFactory.Create(XDTOFactory.Type(Package, "ExternalModule"));
	Result.Description = LongDesc;
	
	Result.Name = Name;
	Result.Hash = Checksum;
	
	Return Result;
	
EndFunction

// Returns the internal description of the permission to use the operating system application.
// For passing as a parameter to functions:
// SafeModeManager.RequestToUseExternalResources and
// SafeModeManager.RequestToCancelPermissionsToUseExternalResources.
//
// Parameters:
//  CommandLinePattern - String - a template of an application command line.
//                                 For more information, see the platform documentation. 
//  LongDesc - String - details on the reason to grant the permission.
//
// Returns:
//  XDTODataObject
//
Function PermissionToUseOperatingSystemApplications(Val CommandLinePattern, Val LongDesc = "") Export
	
	Package = SafeModeManagerInternal.Package();
	Result = XDTOFactory.Create(XDTOFactory.Type(Package, "RunApplication"));
	Result.Description = LongDesc;
	
	Result.CommandMask = CommandLinePattern;
	
	Return Result;
	
EndFunction

// Returns the internal description of the permissions to use the Internet resource.
// For passing as a parameter to functions:
// SafeModeManager.RequestToUseExternalResources and
// SafeModeManager.RequestToCancelPermissionsToUseExternalResources.
//
// Parameters:
//  Protocol - String - a protocol used to interact with the resource. The following values are available:
//                      IMAP, POP3, SMTP, HTTP, HTTPS, FTP, FTPS, WS, WSS.
//  Address - String - a resource address without a specified protocol.
//  Port - Number - a number of the port that is used to interact with the resource.
//  LongDesc - String - details on the reason to grant the permission.
//
// Returns:
//  XDTODataObject
//
Function PermissionToUseInternetResource(Val Protocol, Val Address, Val Port = Undefined, Val LongDesc = "") Export
	
	If Port = Undefined Then
		StandardPorts = StandardInternetProtocolPorts();
		If StandardPorts.Property(Upper(Protocol)) <> Undefined Then
			Port = StandardPorts[Upper(Protocol)];
		EndIf;
	EndIf;
	
	Package = SafeModeManagerInternal.Package();
	Result = XDTOFactory.Create(XDTOFactory.Type(Package, "InternetResourceAccess"));
	Result.Description = LongDesc;
	
	Result.Protocol = Protocol;
	Result.Host = Address;
	Result.Port = Port;
	
	Return Result;
	
EndFunction

// Returns the internal description of the permissions for extended data processing (including the
// privileged mode) for external modules.
// For passing as a parameter to functions:
// SafeModeManager.RequestToUseExternalResources and
// SafeModeManager.RequestToCancelPermissionsToUseExternalResources.
//
// Parameters:
//  LongDesc - String - details on the reason to grant the permission.
//
// Returns:
//  XDTODataObject
//
Function PermissionToUsePrivilegedMode(Val LongDesc = "") Export
	
	Package = SafeModeManagerInternal.Package();
	Result = XDTOFactory.Create(XDTOFactory.Type(Package, "ExternalModulePrivilegedModeAllowed"));
	Result.Description = LongDesc;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions creating requests for permissions to use external resources.
//

// Creates a request to use external resources.
//
// Parameters:
//  NewPermissions - Array of See SafeModeManager.PermissionToUseExternalModule 
//                  - Array of See SafeModeManager.PermissionToUseAddIn  
//                  - Array of See SafeModeManager.PermissionToUseInternetResource  
//                  - Array of See SafeModeManager.PermissionToUseTempDirectory  
//                  - Array of See SafeModeManager.PermissionToUseApplicationDirectory  
//                  - Array of See SafeModeManager.PermissionToUseFileSystemDirectory  
//                  - Array of See SafeModeManager.PermissionToUsePrivilegedMode  
//					- Array of See SafeModeManager.PermissionToUseOperatingSystemApplications - 
//					  
//  Owner - AnyRef - a reference to the infobase object the
//    permissions being requested are logically connected with. For example, all permissions to access file storage volume directories are logically associated
//    with relevant FileStorageVolumes catalog items, all permissions to access data exchange
//    directories (or other resources according to the used exchange transport) are logically
//    associated with relevant exchange plan nodes, and so on. If a permission is logically
//    isolated (for example, if granting of a permission is controlled by the constant value with the Boolean type),
//    it is recommended that you use a reference to the MetadataObjectIDs catalog item.
//  ReplacementMode - Boolean - defines the replacement mode of permissions previously granted for this owner. If the
//    value is True, in addition to granting the requested permissions,
//    clearing all permissions that were previously requested for the owner are added to the request.
//
// Returns:
//  UUID -  
//     
//    
//
Function RequestToUseExternalResources(Val NewPermissions, Val Owner = Undefined, Val ReplacementMode = True) Export
	
	Return SafeModeManagerInternal.PermissionChangeRequest(
		Owner,
		ReplacementMode,
		NewPermissions);
	
EndFunction

// Creates a request for canceling permissions to use external resources.
//
// Parameters:
//  Owner - AnyRef - a reference to the infobase object the
//    permissions being canceled are logically connected with. For example, all permissions to access file storage volume directories are logically associated
//    with relevant FileStorageVolumes catalog items, all permissions to access data exchange
//    directories (or other resources according to the used exchange transport) are logically
//    associated with relevant exchange plan nodes, and so on. If a permission is logically
//    isolated (for example, if permissions being canceled are controlled by the constant value with the Boolean type),
//    it is recommended that you use a reference to the MetadataObjectIDs catalog item.
//  PermissionsToCancel - Array of See SafeModeManager.PermissionToUseExternalModule 
//                       - Array of See SafeModeManager.PermissionToUseAddIn  
//                       - Array of See SafeModeManager.PermissionToUseInternetResource  
//                       - Array of See SafeModeManager.PermissionToUseTempDirectory  
//                       - Array of See SafeModeManager.PermissionToUseApplicationDirectory  
//                       - Array of See SafeModeManager.PermissionToUseFileSystemDirectory  
//                       - Array of See SafeModeManager.PermissionToUsePrivilegedMode  
//					- Array of See SafeModeManager.PermissionToUseOperatingSystemApplications - 
//					  
//
// Returns:
//  UUID - 
//     
//    
//
Function RequestToCancelPermissionsToUseExternalResources(Val Owner, Val PermissionsToCancel) Export
	
	Return SafeModeManagerInternal.PermissionChangeRequest(
		Owner,
		False,
		,
		PermissionsToCancel);
	
EndFunction

// Creates a request for canceling all owner's permissions to use external resources.
//
// Parameters:
//  Owner - AnyRef - a reference to the infobase object the
//    permissions being canceled are logically connected with. For example, all permissions to access file storage volume directories are logically associated
//    with relevant FileStorageVolumes catalog items, all permissions to access data exchange
//    directories (or other resources according to the used exchange transport) are logically
//    associated with relevant exchange plan nodes, and so on. If a permission is logically
//    isolated (for example, if permissions being canceled are controlled by the constant value with the Boolean type),
//    it is recommended that you use a reference to the MetadataObjectIDs catalog item.
//
// Returns:
//  UUID - 
//     
//    
//
Function RequestToClearPermissionsToUseExternalResources(Val Owner) Export
	
	Return SafeModeManagerInternal.PermissionChangeRequest(
		Owner,
		True);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// 
// 
//

// Checks whether the safe mode is enabled ignoring the security profile safe mode
//  that is used as a security profile with the configuration privilege level.
//
// Returns:
//   Boolean - 
//
Function SafeModeSet() Export
	
	CurrentSafeMode = SafeMode();
	
	If TypeOf(CurrentSafeMode) = Type("String") Then
		
		If Not SwichingToPrivilegedModeAvailable() Then
			Return True; // If the safe mode is not enabled, switching to the privileged mode is always available.
		EndIf;
		
		Try
			InfobaseProfile = InfobaseSecurityProfile();
		Except
			Return True;
		EndTry;
		
		Return (CurrentSafeMode <> InfobaseProfile);
		
	ElsIf TypeOf(CurrentSafeMode) = Type("Boolean") Then
		
		Return CurrentSafeMode;
		
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Miscellaneous.
//

// Creates requests for application permission update.
//
// Parameters:
//  IncludingIBProfileCreationRequest - Boolean - include a request to create a security profile
//    for the current infobase to the result.
//
// Returns:
//  Array - 
//           
//
Function RequestsToUpdateApplicationPermissions(Val IncludingIBProfileCreationRequest = True) Export
	
	Return SafeModeManagerInternal.RequestsToUpdateApplicationPermissions(IncludingIBProfileCreationRequest);
	
EndFunction

// Returns checksums of add-in files from the bundle provided in the configuration template.
//
// Parameters:
//   TemplateName - String - a configuration template name.
//
// Returns:
//   FixedMap of KeyAndValue - 
//     * Key - String - file name,
//     * Value - String - checksum.
//
Function AddInBundleFilesChecksum(Val TemplateName) Export
	
	Return SafeModeManagerInternal.AddInBundleFilesChecksum(TemplateName);
	
EndFunction

#EndRegion

#Region Internal

Function UseSecurityProfiles() Export
	Return GetFunctionalOption("UseSecurityProfiles");
EndFunction

// Returns the name of the security profile that provides privileges for configuration code.
//
// Returns:
//   String
//
Function InfobaseSecurityProfile(CheckForUsage = False) Export
	
	If CheckForUsage And Not GetFunctionalOption("UseSecurityProfiles") Then
		Return "";
	EndIf;
	
	SetPrivilegedMode(True);
	
	SecurityProfile = Constants.InfobaseSecurityProfile.Get();
	
	If SecurityProfile = False Then
		Return "";
	EndIf;
	
	Return SecurityProfile;
	
EndFunction

#EndRegion

#Region Private

// Checks whether the privileged mode can be set from the current safe mode.
//
// Returns:
//   Boolean
//
Function SwichingToPrivilegedModeAvailable()
	
	SetPrivilegedMode(True);
	Return PrivilegedMode();
	
EndFunction

// Returns the predefined alias of the application directory.
//
// Returns:
//   String
//
Function ApplicationDirectoryAlias()
	
	Return "/bin";
	
EndFunction

// Returns the predefined alias of the temporary file directory.
//
Function TempDirectoryAlias()
	
	Return "/temp";
	
EndFunction

// Returns the standard ports of the Internet protocols that can be processed
// using the 1C:Enterprise language. Is used to determine the port
// if the applied code requests the permission but does not define the port.
//
// Returns:
//   FixedStructure:
//    * IMAP - Number - 143. 
//    * POP3 - Number - 110.
//    * SMTP - Number - 25.
//    * HTTP - Number - 80.
//    * HTTPS - Number - 443.
//    * FTP - Number - 21.
//    * FTPS - Number - 21.
//    * WS - Number - 80.
//    * WSS - Number - 443.
//
Function StandardInternetProtocolPorts()
	
	Result = New Structure();
	
	Result.Insert("IMAP",  143);
	Result.Insert("POP3",  110);
	Result.Insert("SMTP",  25);
	Result.Insert("HTTP",  80);
	Result.Insert("HTTPS", 443);
	Result.Insert("FTP",   21);
	Result.Insert("FTPS",  21);
	Result.Insert("WS",    80);
	Result.Insert("WSS",   443);
	
	Return New FixedStructure(Result);
	
EndFunction

#EndRegion

