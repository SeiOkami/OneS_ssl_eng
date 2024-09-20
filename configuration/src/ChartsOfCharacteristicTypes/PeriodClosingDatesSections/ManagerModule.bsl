///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// SaaSTechnology.ExportImportData

// Returns the catalog attributes that naturally form a catalog item key.
//
// Returns:
//  Array of String - Array of attribute names used to generate a natural key.
//
Function NaturalKeyFields() Export
	
	Result = New Array;
	Result.Add("Description");
	
	Return Result;
	
EndFunction

// End SaaSTechnology.ExportImportData

#EndRegion

#EndRegion

#Region Private

// Returns:
//  FixedStructure:
//    * NoSectionsAndObjects - Boolean
//    * AllSectionsWithoutObjects - Boolean
//    * SingleSection - ChartOfCharacteristicTypesRef.PeriodClosingDatesSections
//    * ShowSections - Boolean
//    * Sections - FixedMap of KeyAndValue:
//        ** Key - String
//        ** Value - FixedStructure:
//             *** Name - String
//             *** Presentation - String
//             *** Ref - ChartOfCharacteristicTypesRef.PeriodClosingDatesSections
//             *** ObjectsTypes - FixedArray
//    * SectionsWithoutObjects - FixedArray
//
Function ClosingDatesSectionsProperties() Export
	
	Sections = New ValueTable;
	Sections.Columns.Add("Name",           New TypeDescription("String",,,, New StringQualifiers(150)));
	Sections.Columns.Add("Id", New TypeDescription("UUID"));
	Sections.Columns.Add("Presentation", New TypeDescription("String"));
	Sections.Columns.Add("ObjectsTypes",  New TypeDescription("Array"));
	
	SSLSubsystemsIntegration.OnFillPeriodClosingDatesSections(Sections);
	PeriodClosingDatesOverridable.OnFillPeriodClosingDatesSections(Sections);
	
	ErrorTitle = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Error in procedure %1 of common module %2.';"),
		"OnFillPeriodClosingDatesSections", "PeriodClosingDatesOverridable")
		+ Chars.LF + Chars.LF;
	
	ClosingDatesSections     = New Map;
	SectionsWithoutObjects    = New Array;
	AllSectionsWithoutObjects = True;
	
	ClosingDatesObjectsTypes = New Map;
	Types = Metadata.ChartsOfCharacteristicTypes.PeriodClosingDatesSections.Type.Types();
	For Each Type In Types Do
		If Type = Type("EnumRef.PeriodClosingDatesPurposeTypes")
		 Or Type = Type("ChartOfCharacteristicTypesRef.PeriodClosingDatesSections")
		 Or Not Common.IsReference(Type) Then
			Continue;
		EndIf;
		ClosingDatesObjectsTypes.Insert(Type, True);
	EndDo;
	
	For Each Section In Sections Do
		If Not ValueIsFilled(Section.Name) Then
			Raise ErrorTitle + NStr("en = 'Name is required for the period-end closing date section.';");
		EndIf;
		
		If ClosingDatesSections.Get(Section.Name) <> Undefined Then
			Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '""%1"" period-end closing date section already has a name.';"),
				Section.Name);
		EndIf;
		
		If Not ValueIsFilled(Section.Id) And Section.Name <> "SingleDate" Then
			Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'ID is required for ""%1"" period-end closing date section.';"),
				Section.Name);
		EndIf;
		
		SectionReference = GetRef(Section.Id);
		
		If ClosingDatesSections.Get(SectionReference) <> Undefined Then
			SectionClosingDates = ClosingDatesSections.Get(SectionReference); // See SectionProperties
			Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'ID ""%1"" of ""%2"" period-end closing date section
				           |has already been assigned to ""%3"" section.';"),
				Section.Id, Section.Name, SectionClosingDates.Name);
		EndIf;
		
		ObjectsTypes = New Array;
		For Each Type In Section.ObjectsTypes Do
			AllSectionsWithoutObjects = False;
			If Not Common.IsReference(Type) Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Object type for ""%2"" period-end closing date section is defined as ""%1"". 
					           |But it is not a reference type.';"),
					String(Type), Section.Name);
			EndIf;
			If ClosingDatesObjectsTypes.Get(Type) = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Property ""Type"" in chart of characteristic types ""Period-end closing dates sections""
					           |requires ""%1"" object type of ""%2"" period-end closing dates section.';"),
					String(Type), Section.Name);
			EndIf;
			TypeMetadata = Metadata.FindByType(Type);
			FullName = TypeMetadata.FullName();
			ObjectManager = Common.ObjectManagerByFullName(FullName);
			TypeProperties = New Structure;
			TypeProperties.Insert("EmptyRef",  ObjectManager.EmptyRef());
			TypeProperties.Insert("FullName",     FullName);
			TypeProperties.Insert("Presentation", String(Type));
			ObjectsTypes.Add(New FixedStructure(TypeProperties));
		EndDo;
		
		SectionProperties = SectionProperties(SectionReference, Section.Name, Section.Presentation, New FixedArray(ObjectsTypes));
		SectionProperties = New FixedStructure(SectionProperties);
		ClosingDatesSections.Insert(SectionProperties.Name,    SectionProperties);
		ClosingDatesSections.Insert(SectionProperties.Ref, SectionProperties);
		
		If ObjectsTypes.Count() = 0 Then
			SectionsWithoutObjects.Add(Section.Name);
		EndIf;
	EndDo;
	
	// 
	SectionProperties = SectionProperties(EmptyRef());
	SectionProperties = New FixedStructure(SectionProperties);
	ClosingDatesSections.Insert(SectionProperties.Name,    SectionProperties);
	ClosingDatesSections.Insert(SectionProperties.Ref, SectionProperties);
	
	Properties = New Structure;
	Properties.Insert("Sections",               New FixedMap(ClosingDatesSections));
	Properties.Insert("SectionsWithoutObjects",    New FixedArray(SectionsWithoutObjects));
	Properties.Insert("AllSectionsWithoutObjects", AllSectionsWithoutObjects);
	Properties.Insert("NoSectionsAndObjects",  Sections.Count() = 0);
	Properties.Insert("SingleSection",    ?(Sections.Count() = 1,
	                                             ClosingDatesSections[Sections[0].Name].Ref,
	                                             EmptyRef()));
	Properties.Insert("ShowSections",     Properties.AllSectionsWithoutObjects
	                                           Or Not ValueIsFilled(Properties.SingleSection));
	
	Return New FixedStructure(Properties);
	
EndFunction

// Returns:
//   Structure:
//     * ObjectsTypes - FixedArray
//     * Presentation - String
//     * Ref - ChartOfCharacteristicTypesRef.PeriodClosingDatesSections
//     * Name - String
//
Function SectionProperties(Ref, Val Name = "", Val Presentation = "", Val ObjectsTypes = Undefined) Export
	
	SectionProperties = New Structure;
	SectionProperties.Insert("Name", Name);
	SectionProperties.Insert("Ref", Ref);
	SectionProperties.Insert("Presentation", ?(IsBlankString(Presentation), NStr("en = 'Common date';"), Presentation));
	SectionProperties.Insert("ObjectsTypes", ?(ObjectsTypes = Undefined, New FixedArray(New Array), ObjectsTypes));
	Return SectionProperties;

EndFunction

#EndRegion

#EndIf