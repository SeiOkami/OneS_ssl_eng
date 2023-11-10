///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// Reads information on registers from the constant and generates a mapping for ListOfRegistersWithRefsToUsers.
//
Function RecordSetsWithRefsToUsersList() Export
	
	SetPrivilegedMode(True);
	MetadataDetails = RecordSetsWithRefsToUsers();
	
	MetadataList = New Map;
	For Each String In MetadataDetails Do
		MetadataList.Insert(Metadata[String.Collection][String.Object], String.Dimensions);
	EndDo;
	
	Return MetadataList;
	
EndFunction

#EndRegion

#Region Private

// Returns record sets containing fields that have
// CatalogRef.Users as a value type.
//
// Returns:
//   ValueTable:
//                         * Collection - String - a metadata collection name
//                         * Object - String - a metadata object name
//                         * Dimensions - Array of String - dimension names.
//
Function RecordSetsWithRefsToUsers()
	
	MetadataDetails = New ValueTable;
	MetadataDetails.Columns.Add("Collection", New TypeDescription("String"));
	MetadataDetails.Columns.Add("Object", New TypeDescription("String"));
	MetadataDetails.Columns.Add("Dimensions", New TypeDescription("Array"));
	
	For Each InformationRegister In Metadata.InformationRegisters Do
		AddToMetadataList(MetadataDetails, InformationRegister, "InformationRegisters");
	EndDo;
	
	For Each Sequence In Metadata.Sequences Do
		AddToMetadataList(MetadataDetails, Sequence, "Sequences");
	EndDo;
	
	Return MetadataDetails;
	
EndFunction

Procedure AddToMetadataList(Val MetadataList, Val ObjectMetadata, Val CollectionName)
	
	UserRefType = Type("CatalogRef.Users");
	
	Dimensions = New Array;
	For Each Dimension In ObjectMetadata.Dimensions Do 
		
		If (Dimension.Type.ContainsType(UserRefType)) Then
			Dimensions.Add(Dimension.Name);
		EndIf;
		
	EndDo;
	
	If Dimensions.Count() > 0 Then
		String = MetadataList.Add();
		String.Collection = CollectionName;
		String.Object = ObjectMetadata.Name;
		String.Dimensions = Dimensions;
	EndIf;
	
EndProcedure

#EndRegion