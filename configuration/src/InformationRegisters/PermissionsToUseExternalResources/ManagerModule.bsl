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

// Generates a permission key (to be used in registers, in which the granted
// permission details are stored).
//
// Parameters:
//  Resolution - XDTODataObject
//
// Returns:
//   String
//
Function PermissionKey(Val Resolution) Export
	
	Hashing = New DataHashing(HashFunction.MD5);
	Hashing.Append(Common.XDTODataObjectToXMLString(Resolution));
	
	AddOn = PermissionAddition(Resolution);
	If ValueIsFilled(AddOn) Then
		Hashing.Append(Common.ValueToXMLString(AddOn));
	EndIf;
	
	Var_Key = XDTOFactory.Create(XDTOFactory.Type("http://www.w3.org/2001/XMLSchema", "hexBinary"), Hashing.HashSum).LexicalValue;
	
	If StrLen(Var_Key) > 32 Then
		Raise NStr("en = 'Key length exceeded';");
	EndIf;
	
	Return Var_Key;
	
EndFunction

// Generates a permission addition.
//
// Parameters:
//  Resolution - XDTODataObject
//
// Returns:
//   Arbitrary
//
Function PermissionAddition(Val Resolution) Export
	
	If Resolution.Type() = XDTOFactory.Type(SafeModeManagerInternal.Package(), "AttachAddin") Then
		Return SafeModeManagerInternal.AddInBundleFilesChecksum(Resolution.TemplateName);
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Returns the current slice of granted permissions.
//
// Parameters:
//  ByOwners - Boolean - if True, the return table will contain information on permission owners.
//    Otherwise, the current slice will be collapsed by owner.
//  NoDetails1 - Boolean - If True, the slice is returned with its permissions having the Description field cleared.
//
// Returns:
//   ValueTable:
//   * ProgramModuleType - CatalogRef.MetadataObjectIDs
//   * ModuleID - UUID
//   * OwnerType - CatalogRef.MetadataObjectIDs
//   * OwnerID - UUID
//   * Type - String - an XDTO type name describing permissions.
//   * Permissions - Map of KeyAndValue:
//       ** Key - See InformationRegister.PermissionsToUseExternalResources.PermissionKey
//       ** Value - XDTODataObject - XDTO permission details.
//   * PermissionsAdditions - Map of KeyAndValue - permission addition details:
//       ** Key - See InformationRegister.PermissionsToUseExternalResources.PermissionKey
//       ** Value - See InformationRegister.PermissionsToUseExternalResources.PermissionAddition
//
Function PermissionsSlice(Val ByOwners = True, Val NoDetails1 = False) Export
	
	Result = New ValueTable();
	
	Result.Columns.Add("ProgramModuleType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	Result.Columns.Add("ModuleID", New TypeDescription("UUID"));
	If ByOwners Then
		Result.Columns.Add("OwnerType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
		Result.Columns.Add("OwnerID", New TypeDescription("UUID"));
	EndIf;
	Result.Columns.Add("Type", New TypeDescription("String"));
	Result.Columns.Add("Permissions", New TypeDescription("Map"));
	Result.Columns.Add("PermissionsAdditions", New TypeDescription("Map"));
	
	Selection = Select();
	
	While Selection.Next() Do
		
		Resolution = Common.XDTODataObjectFromXMLString(Selection.PermissionBody);
		
		FilterByTable = New Structure();
		FilterByTable.Insert("ProgramModuleType", Selection.ProgramModuleType);
		FilterByTable.Insert("ModuleID", Selection.ModuleID);
		If ByOwners Then
			FilterByTable.Insert("OwnerType", Selection.OwnerType);
			FilterByTable.Insert("OwnerID", Selection.OwnerID);
		EndIf;
		FilterByTable.Insert("Type", Resolution.Type().Name);
		
		String = DataProcessors.ExternalResourcesPermissionsSetup.PermissionsTableRow(
			Result, FilterByTable);
		
		PermissionBody = Selection.PermissionBody;
		PermissionKey = Selection.PermissionKey;
		PermissionAddition = Selection.PermissionAddition;
		
		If NoDetails1 Then
			
			If ValueIsFilled(Resolution.Description) Then
				
				Resolution.Description = "";
				PermissionBody = Common.XDTODataObjectToXMLString(Resolution);
				PermissionKey = PermissionKey(Resolution);
				
			EndIf;
			
		EndIf;
		
		String.Permissions.Insert(PermissionKey, PermissionBody);
		
		If ValueIsFilled(PermissionAddition) Then
			String.PermissionsAdditions.Insert(PermissionKey, PermissionAddition);
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Writes a permission to the register.
//
// Parameters:
//  ProgramModuleType - CatalogRef.MetadataObjectIDs,
//  ModuleID - UUID,
//  OwnerType - CatalogRef.MetadataObjectIDs,
//  OwnerID - UUID,
//  PermissionKey - String - a permission key,
//  Resolution - XDTODataObject - XDTO permission presentation,
//  PermissionAddition - 
//
Procedure AddPermission(Val ProgramModuleType, Val ModuleID, Val OwnerType, Val OwnerID, Val PermissionKey, Val Resolution, Val PermissionAddition = Undefined) Export
	
	Manager = CreateRecordManager();
	Manager.ProgramModuleType = ProgramModuleType;
	Manager.ModuleID = ModuleID;
	Manager.OwnerType = OwnerType;
	Manager.OwnerID = OwnerID;
	Manager.PermissionKey = PermissionKey;
	
	Manager.Read();
	
	If Manager.Selected() Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The extension to be added already exists:
				|%1, %2, %3, %4, %5.';"),
			String(ProgramModuleType),
			String(ModuleID),
			String(OwnerType),
			String(OwnerID),
			PermissionKey);
		
	Else
		
		Manager.ProgramModuleType = ProgramModuleType;
		Manager.ModuleID = ModuleID;
		Manager.OwnerType = OwnerType;
		Manager.OwnerID = OwnerID;
		Manager.PermissionKey = PermissionKey;
		Manager.PermissionBody = Common.XDTODataObjectToXMLString(Resolution);
		
		If ValueIsFilled(PermissionAddition) Then
			Manager.PermissionAddition = Common.ValueToXMLString(PermissionAddition);
		EndIf;
		
		Manager.Write(False);
		
	EndIf;
	
EndProcedure

// Deletes the permission from the register.
//
// Parameters:
//  ProgramModuleType - CatalogRef.MetadataObjectIDs,
//  ModuleID - UUID,
//  OwnerType - CatalogRef.MetadataObjectIDs,
//  OwnerID - UUID,
//  PermissionKey - String - a permission key,
//  Resolution - XDTODataObject - XDTO permission presentation.
//
Procedure DeletePermission(Val ProgramModuleType, Val ModuleID, Val OwnerType, Val OwnerID, Val PermissionKey, Val Resolution) Export
	
	Manager = CreateRecordManager();
	Manager.ProgramModuleType = ProgramModuleType;
	Manager.ModuleID = ModuleID;
	Manager.OwnerType = OwnerType;
	Manager.OwnerID = OwnerID;
	Manager.PermissionKey = PermissionKey;
	
	Manager.Read();
	
	If Manager.Selected() Then
		
		If Manager.PermissionBody <> Common.XDTODataObjectToXMLString(Resolution) Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Position of permissions by keys:
	                  |%1, %2, %3, %4, %5.';"),
				String(ProgramModuleType),
				String(ModuleID),
				String(OwnerType),
				String(OwnerID),
				PermissionKey);
				
		EndIf;
		
		Manager.Delete();
		
	Else
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Attempt to delete an extension that does not exist:
                  |%1, %2, %3, %4, %5.';"),
			String(ProgramModuleType),
			String(ModuleID),
			String(OwnerType),
			String(OwnerID),
			PermissionKey);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf

