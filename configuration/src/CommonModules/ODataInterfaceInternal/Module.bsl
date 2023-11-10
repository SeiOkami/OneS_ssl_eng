///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// Returns a metadata object by reference type.
//
// Parameters:
//  RefType - Type,
//
// Returns:
//   MetadataObject
//
Function MetadataObjectByRefType(Val RefType) Export
	
	BusinessProcess = BusinessProcessesRoutePointsRefs().Get(RefType);
	If BusinessProcess = Undefined Then
		Ref = New(RefType);
		RefMetadata = Ref.Metadata();
	Else
		RefMetadata = Metadata.BusinessProcesses[BusinessProcess];
	EndIf;
	
	Return RefMetadata;
	
EndFunction

// Returns the flag indicating whether this is a reference object.
//
// Parameters:
//  TypeToCheck - Type - Data type being checked.
//
// Returns:
//   Boolean - 
//
Function IsReferenceType(Val TypeToCheck) Export
	
	Return RefTypesDetails().ContainsType(TypeToCheck);
	
EndFunction

// Checks that the type contains a set of reference types.
//
// Parameters:
//  TypeDescription - TypeDescription
//
// Returns:
//   Boolean
//
Function IsRefsTypesSet(Val TypeDescription) Export
	
	If TypeDescription.Types().Count() < 2 Then
		Return False;
	EndIf;
	
	TypesDetailsSerialization = XDTOSerializer.WriteXDTO(TypeDescription);
	
	If TypesDetailsSerialization.TypeSet.Count() > 0 Then
		
		ContainsRefsSets = False;
		
		For Each TypesSet In TypesDetailsSerialization.TypeSet Do
			
			If TypesSet.NamespaceURI = "http://v8.1c.ru/8.1/data/enterprise/current-config" Then
				
				If TypesSet.LocalName = "AnyRef"
						Or TypesSet.LocalName = "CatalogRef"
						Or TypesSet.LocalName = "DocumentRef"
						Or TypesSet.LocalName = "BusinessProcessRef"
						Or TypesSet.LocalName = "TaskRef"
						Or TypesSet.LocalName = "ChartOfAccountsRef"
						Or TypesSet.LocalName = "ExchangePlanRef"
						Or TypesSet.LocalName = "ChartOfCharacteristicTypesRef"
						Or TypesSet.LocalName = "ChartOfCalculationTypesRef" Then
					
					ContainsRefsSets = True;
					Break;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		Return ContainsRefsSets;
		
	Else
		Return False;
	EndIf;
	
EndFunction

// Checks whether the passed metadata object is a sequence.
//
// Parameters:
//  MetadataObject - Metadata object being checked.
//
// Returns:
//   Boolean
//
Function IsSequenceRecordSet(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, ODataInterfaceInternalCached.MetadataClassesInConfigurationModel().Sequences);
	
EndFunction

// Checks whether the passed metadata object is a recalculation.
//
// Parameters:
//  MetadataObject - Metadata object being checked.
//
// Returns:
//   Boolean
//
Function IsRecalculationRecordSet(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, ODataInterfaceInternalCached.MetadataClassesInConfigurationModel().Recalculations);
	
EndFunction

// Checks whether the passed metadata object is a record set.
//
// Parameters:
//  MetadataObject - Metadata object being checked.
//
// Returns:
//   Boolean
//
Function IsRecordSet(Val MetadataObject) Export
	
	MetadataClasses = ODataInterfaceInternalCached.MetadataClassesInConfigurationModel();
	Return IsClassMetadataObject(MetadataObject, MetadataClasses.InformationRegisters)
		Or IsClassMetadataObject(MetadataObject, MetadataClasses.AccumulationRegisters)
		Or IsClassMetadataObject(MetadataObject, MetadataClasses.AccountingRegisters)
		Or IsClassMetadataObject(MetadataObject, MetadataClasses.CalculationRegisters)
		Or IsSequenceRecordSet(MetadataObject) 
		Or IsRecalculationRecordSet(MetadataObject);
	
EndFunction

// Returns:
//  MetadataObject - role.
//
Function ODataInterfaceRole() Export
	
	Return Metadata.Roles.RemoteODataAccess;
	
EndFunction

#Region EventsHandlers

Procedure BeforeExportData(Container) Export
	
	Content = GetStandardODataInterfaceContent();
	CompositionToSerialize = New Array();
	
	For Each CompositionItem In Content Do
		CompositionToSerialize.Add(CompositionItem.FullName());
	EndDo;
	
	FileName = Container.CreateCustomFile("xml", DataTypeForStandardODataInterfaceComposition());
	
	WriteStream = New XMLWriter();
	WriteStream.OpenFile(FileName);
	
	Serializer = XDTOSerializer;
	WriteStream.WriteStartElement("Data");
	
	NamespacesPrefixes = NamespacesPrefixes();
	For Each NamespacesPrefix In NamespacesPrefixes Do
		WriteStream.WriteNamespaceMapping(NamespacesPrefix.Value, NamespacesPrefix.Key);
	EndDo;
	
	Serializer.WriteXML(WriteStream, CompositionToSerialize, XMLTypeAssignment.Explicit);
	
	WriteStream.WriteEndElement();
	WriteStream.Close();
	
EndProcedure

Procedure BeforeImportData(Container) Export
	
	FileName = Container.GetCustomFile(DataTypeForStandardODataInterfaceComposition());
	
	ReaderStream = New XMLReader();
	ReaderStream.OpenFile(FileName);
	ReaderStream.MoveToContent();
	
	If ReaderStream.NodeType <> XMLNodeType.StartElement
			Or ReaderStream.Name <> "Data" Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid XML file format. Start of ""%1"" element is expected.';"), "Data");
		
	EndIf;
	
	If Not ReaderStream.Read() Then
		Raise NStr("en = 'Invalid XML file format. File end is detected.';");
	EndIf;
	
	Content = XDTOSerializer.ReadXML(ReaderStream);
	ReaderStream.Close();
	
	If Content.Count() > 0 Then
		
		For Position = -Content.UBound() To 0 Do
			
			If Common.MetadataObjectByFullName(Content[-Position]) = Undefined Then
				Content.Delete(-Position);
			EndIf;
			
		EndDo;
		
		SetStandardODataInterfaceContent(Content);
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

// Returns type details that contain all reference types of metadata objects
// in the configuration.
//
// Returns:
//   TypeDescription
//
Function RefTypesDetails()
	
	AnyXDTORefTypeDetails = XDTOFactory.Create(XDTOFactory.Type("http://v8.1c.ru/8.1/data/core", "TypeDescription"));
	AnyXDTORefTypeDetails.TypeSet.Add(XDTOSerializer.WriteXDTO(New XMLExpandedName(
		"http://v8.1c.ru/8.1/data/enterprise/current-config", "AnyRef")));
	AnyRefTypeDetails = XDTOSerializer.ReadXDTO(AnyXDTORefTypeDetails);
	
	Return AnyRefTypeDetails;
	
EndFunction

// Returns references of business processes route points.
//
// Returns:
//   FixedMap of KeyAndValue:
//                        * Key - Type - BusinessProcessRoutePointRef type
//                        * Value - String - a business process name.
//
Function BusinessProcessesRoutePointsRefs()
	
	BusinessProcessesRoutePointsRefs = New Map();
	For Each BusinessProcess In Metadata.BusinessProcesses Do
		BusinessProcessesRoutePointsRefs.Insert(Type("BusinessProcessRoutePointRef." + BusinessProcess.Name), BusinessProcess.Name);
	EndDo;
	
	Return New FixedMap(BusinessProcessesRoutePointsRefs);
	
EndFunction

Function ConfigurationModelObjectProperties(Val Model, Val MetadataObject) Export
	
	If TypeOf(MetadataObject) = Type("MetadataObject") Then
		Name = MetadataObject.Name;
		FullName = MetadataObject.FullName();
	Else
		FullName = MetadataObject;
		Name = StrSplit(FullName, ".").Get(1);
	EndIf;
	
	For Each ModelClass In Model Do
		ObjectDetails = ModelClass.Value.Get(Name);
		If ObjectDetails <> Undefined Then
			If FullName = ObjectDetails.FullName Then
				Return ObjectDetails;
			EndIf;
		EndIf;
	EndDo;
	Return Undefined;
	
EndFunction

Function IsClassMetadataObject(Val MetadataObject, Val Class) Export
	
	If TypeOf(MetadataObject) = Type("MetadataObject") Then
		Name = MetadataObject.Name;
		FullName = MetadataObject.FullName();
	Else
		FullName = MetadataObject;
		Name = StrSplit(FullName, ".").Get(1);
	EndIf;
	
	ModelGroup = ODataInterfaceInternalCached.ConfigurationDataModelDetails().Get(Class);
	
	ObjectDetails = ModelGroup.Get(Name);
	
	If ObjectDetails <> Undefined Then
		
		Return FullName = ObjectDetails.FullName;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

Function DataTypeForStandardODataInterfaceComposition()
	
	Return "StandardODataInterfaceContent"; // Not localizable.
	
EndFunction

Function NamespacesPrefixes()
	
	Result = New Map();
	
	Result.Insert("http://www.w3.org/2001/XMLSchema", "xs");
	Result.Insert("http://www.w3.org/2001/XMLSchema-instance", "xsi");
	Result.Insert("http://v8.1c.ru/8.1/data/core", "v8");
	Result.Insert("http://v8.1c.ru/8.1/data/enterprise", "ns");
	Result.Insert("http://v8.1c.ru/8.1/data/enterprise/current-config", "cc");
	Result.Insert("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1", "dmp");
	
	Return New FixedMap(Result);
	
EndFunction

#EndRegion