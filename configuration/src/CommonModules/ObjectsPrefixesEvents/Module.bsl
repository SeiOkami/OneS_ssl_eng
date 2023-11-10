///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Sets a subscription source prefix based on a company prefix. 
// A subscription source must contain the
// required header attribute Company with the CatalogRef.Company type.
//
// Parameters:
//  Source - Arbitrary - a subscription event source.
//             Any object from the set [Catalog, Document, Chart of characteristic types, Business process, or Task].
//  StandardProcessing - Boolean - a standard subscription processing flag.
//  Prefix - String - a prefix of an object to be changed.
//
Procedure SetCompanyPrefix(Source, StandardProcessing, Prefix) Export
	
	SetPrefix(Source, Prefix, False, True);
	
EndProcedure

// Sets a subscription source prefix according to an infobase prefix.
// Source attributes are not restricted.
//
// Parameters:
//  Source - Arbitrary - a subscription event source.
//             Any object from the set [Catalog, Document, Chart of characteristic types, Business process, or Task].
//  StandardProcessing - Boolean - a standard subscription processing flag.
//  Prefix - String - a prefix of an object to be changed.
//
Procedure SetInfobasePrefix(Source, StandardProcessing, Prefix) Export
	
	SetPrefix(Source, Prefix, True, False);
	
EndProcedure

// Sets a subscription source prefix based on an infobase prefix and a company prefix.
// A subscription source must contain the
// required header attribute Company with the CatalogRef.Company type.
//
// Parameters:
//  Source - Arbitrary - a subscription event source.
//             Any object from the set [Catalog, Document, Chart of characteristic types, Business process, or Task].
//  StandardProcessing - Boolean - a standard subscription processing flag.
//  Prefix - String - a prefix of an object to be changed.
//
Procedure SetInfobaseAndCompanyPrefix(Source, StandardProcessing, Prefix) Export
	
	SetPrefix(Source, Prefix, True, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For catalogs.

// Checks whether the Company attribute of a catalog item was changed.
// If the Company attribute was changed, resets the item's Code.
// It is required to assign a new code to the item.
//
// Parameters:
//  Source - CatalogObject - a subscription event source.
//  Cancel    - Boolean - a cancellation flag.
// 
Procedure CheckCatalogCodeByCompany(Source, Cancel) Export
	
	CheckObjectCodeByCompany(Source);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Business process tasks.

// Checks whether the business process Date is modified.
// If the date is not included in the previous period, the business process number is reset to zero.
// It is required to assign a new number to the business process.
//
// Parameters:
//  Source - BusinessProcessObject - a subscription event source.
//  Cancel    - Boolean - a cancellation flag.
// 
Procedure CheckBusinessProcessNumberByDate(Source, Cancel) Export
	
	CheckObjectNumberByDate(Source);
	
EndProcedure

// Checks whether the business process Date and Company were changed.
// If the date is not included in the previous period or the Company attribute was changed, resets the business process number.
// It is required to assign a new number to the business process.
//
// Parameters:
//  Source - BusinessProcessObject - a subscription event source.
//  Cancel    - Boolean - a cancellation flag.
// 
Procedure CheckBusinessProcessNumberByDateAndCompany(Source, Cancel) Export
	
	CheckObjectNumberByDateAndCompany(Source);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For documents.

// Checks whether the document Date is modified.
// If the date is not included in the previous period, the document number is reset to zero.
// It is required to assign a new number to the document.
//
// Parameters:
//  Source - DocumentObject - a subscription event source.
//  Cancel    - Boolean - a cancellation flag.
//  WriteMode - DocumentWriteMode - the current document write mode is passed in this parameter.
//  PostingMode - DocumentPostingMode - the current posting mode is passed in this parameter.
//
Procedure CheckDocumentNumberByDate(Source, Cancel, WriteMode, PostingMode) Export
	
	CheckObjectNumberByDate(Source);
	
EndProcedure

// Checks whether the document Date and Company were changed.
// If the date is not included in the previous period or the Company attribute was changed, resets the document number.
// It is required to assign a new number to the document.
//
// Parameters:
//  Source - DocumentObject - a subscription event source.
//  Cancel    - Boolean - a cancellation flag.
//  WriteMode - DocumentWriteMode - the current document write mode is passed in this parameter.
//  PostingMode - DocumentPostingMode - the current posting mode is passed in this parameter.
// 
Procedure CheckDocumentNumberByDateAndCompany(Source, Cancel, WriteMode, PostingMode) Export
	
	CheckObjectNumberByDateAndCompany(Source);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Get a prefix.

// Returns a prefix of the current infobase.
//
// Parameters:
//    InfobasePrefix - String - a return value. Contains an infobase prefix.
//
Procedure OnDetermineInfobasePrefix(InfobasePrefix) Export
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		InfobasePrefix = ModuleDataExchangeServer.InfobasePrefix();
	Else
		InfobasePrefix = "";
	EndIf;
	
EndProcedure

// Returns a company prefix.
//
// Parameters:
//  Organization - DefinedType.Organization -
//  CompanyPrefix - String - a company prefix.
//
Procedure OnDetermineCompanyPrefix(Val Organization, CompanyPrefix) Export
	
	If Metadata.DefinedTypes.Organization.Type.ContainsType(Type("String")) Then
		CompanyPrefix = "";
		Return;
	EndIf;
		
	FunctionalOptionName = "CompanyPrefixes";
	FunctionalOptionParameterName = "Organization";
	
	
	
	CompanyPrefix = GetFunctionalOption(FunctionalOptionName, 
		New Structure(FunctionalOptionParameterName, Organization));
	
EndProcedure

#EndRegion

#Region Private

Procedure SetPrefix(Source, Prefix, SetInfobasePrefix, SetCompanyPrefix)
	
	InfobasePrefix = "";
	CompanyPrefix        = "";
	
	If SetInfobasePrefix Then
		
		OnDetermineInfobasePrefix(InfobasePrefix);
		
		SupplementStringWithZerosOnLeft(InfobasePrefix, 2);
	EndIf;
	
	If SetCompanyPrefix Then
		
		If CompanyAttributeAvailable(Source) Then
			
			OnDetermineCompanyPrefix(
				Source[CompanyAttributeName(Source.Metadata())], CompanyPrefix);
			// If an empty reference to a company is specified.
			If CompanyPrefix = False Then
				
				CompanyPrefix = "";
				
			EndIf;
			
		EndIf;
		
		SupplementStringWithZerosOnLeft(CompanyPrefix, 2);
	EndIf;
	
	PrefixTemplate = "[COMP][IB]-[Prefix]";
	PrefixTemplate = StrReplace(PrefixTemplate, "[COMP]", CompanyPrefix);
	PrefixTemplate = StrReplace(PrefixTemplate, "[IB]", InfobasePrefix);
	PrefixTemplate = StrReplace(PrefixTemplate, "[Prefix]", Prefix);
	
	Prefix = PrefixTemplate;
	
EndProcedure

Procedure SupplementStringWithZerosOnLeft(String, StringLength)
	
	String = StringFunctionsClientServer.SupplementString(String, StringLength, "0", "Left");
	
EndProcedure

Procedure CheckObjectNumberByDate(Object)
	
	If Object.DataExchange.Load Or Object.IsNew() Then
		Return;
	EndIf;
	
	ObjectMetadata = Object.Metadata();
	
	QueryText = 
	"SELECT
	|	ObjectHeader.Date AS Date
	|FROM
	|	&MetadataTableName AS ObjectHeader
	|WHERE
	|	ObjectHeader.Ref = &Ref";
	
	QueryText = StrReplace(QueryText, "&MetadataTableName", ObjectMetadata.FullName());
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Object.Ref);
	Selection = Query.Execute().Select();
	Selection.Next();
	
	If Not ObjectsPrefixesInternal.ObjectDatesOfSamePeriod(Selection.Date, Object.Date, Object.Ref) Then
		
		Object.Number = "";
		
	EndIf;
	
EndProcedure

Procedure CheckObjectNumberByDateAndCompany(Object)
	
	If Object.DataExchange.Load Or Object.IsNew() Then
		Return;
	EndIf;
	
	If ObjectsPrefixesInternal.ObjectDateOrCompanyChanged(Object.Ref, Object.Date,
		Object[CompanyAttributeName(Object.Metadata())]) Then
		
		Object.Number = "";
		
	EndIf;
	
EndProcedure

Procedure CheckObjectCodeByCompany(Object)
	
	If Object.DataExchange.Load Or Object.IsNew() Or Not CompanyAttributeAvailable(Object) Then
		Return;
	EndIf;
	
	If ObjectsPrefixesInternal.ObjectCompanyChanged(Object.Ref,	
		Object[CompanyAttributeName(Object.Metadata())]) Then
		
		Object.Code = "";
		
	EndIf;
	
EndProcedure

Function CompanyAttributeAvailable(Object)
	
	// Function return value.
	Result = True;
	
	ObjectMetadata = Object.Metadata();
	
	If   (Common.IsCatalog(ObjectMetadata)
		Or Common.IsChartOfCharacteristicTypes(ObjectMetadata))
		And ObjectMetadata.Hierarchical Then
		
		CompanyAttributeName = CompanyAttributeName(ObjectMetadata);
		
		CompanyAttribute1 = ObjectMetadata.Attributes.Find(CompanyAttributeName);
		
		If CompanyAttribute1 = Undefined Then
			
			If Common.IsStandardAttribute(ObjectMetadata.StandardAttributes, CompanyAttributeName) Then
				
				// 
				Return True;
				
			EndIf;
			
			MessageString = NStr("en = 'The %2 attribute is not defined for the %1 metadata object.';");
			MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, ObjectMetadata.FullName(), CompanyAttributeName);
			Raise MessageString;
		EndIf;
			
		If CompanyAttribute1.Use = Metadata.ObjectProperties.AttributeUse.ForFolder And Not Object.IsFolder Then
			
			Result = False;
			
		ElsIf CompanyAttribute1.Use = Metadata.ObjectProperties.AttributeUse.ForItem And Object.IsFolder Then
			
			Result = False;
			
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

// For internal use.
Function CompanyAttributeName(Object) Export
	
	If TypeOf(Object) = Type("MetadataObject") Then
		FullName = Object.FullName();
	Else
		FullName = Object;
	EndIf;
	
	Attribute = ObjectsPrefixesCached.PrefixGeneratingAttributes().Get(FullName);
	
	If Attribute <> Undefined Then
		Return Attribute;
	EndIf;
	
	Return "Organization";
	
EndFunction

#EndRegion
