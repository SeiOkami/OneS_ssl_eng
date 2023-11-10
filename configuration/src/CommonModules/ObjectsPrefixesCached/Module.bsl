///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Returns a table of prefix generating attributes specified in the overridable module.
//
Function PrefixGeneratingAttributes() Export
	
	Objects = New ValueTable;
	Objects.Columns.Add("Object");
	Objects.Columns.Add("Attribute");
	
	ObjectsPrefixesOverridable.GetPrefixGeneratingAttributes(Objects);
	
	ObjectsAttributes = New Map;
	
	For Each String In Objects Do
		ObjectsAttributes.Insert(String.Object.FullName(), String.Attribute);
	EndDo;
	
	Return New FixedMap(ObjectsAttributes);
	
EndFunction

#EndRegion
