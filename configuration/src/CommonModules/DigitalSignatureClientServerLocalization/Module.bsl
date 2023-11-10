///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

Procedure OnGetCertificatePresentation(Val Certificate, Val TimeAddition, Presentation) Export
	
	
EndProcedure

Procedure OnGetSubjectPresentation(Val Certificate, Presentation) Export
	
	
EndProcedure

Procedure OnGetExtendedCertificateSubjectProperties(Val Subject, Properties) Export
	
	
EndProcedure

Procedure OnGetExtendedCertificateIssuerProperties(Val Issuer, Properties) Export
	
	
EndProcedure

Procedure OnReceivingXMLEnvelope(Parameters, XMLEnvelope) Export
	
	
EndProcedure

Procedure OnGetDefaultEnvelopeVariant(XMLEnvelope) Export

	
EndProcedure

// 
// 
// Parameters:
//  CertificateAuthorityName - String -
//  Certificate  - BinaryData
//              - String
// 
// Returns:
//  Structure:
//   * InternalAddress - String -
//   * ExternalAddress - String -
//
Function RevocationListInternalAddress(CertificateAuthorityName, Certificate) Export
	
	Result = New Structure("ExternalAddress, InternalAddress");
	
	
	Return Result;
	
EndFunction

// Returns:
//  Undefined, Structure - 
//   * IsState - Boolean
//   * AllowedUncredited - Boolean
//   * ActionPeriods - 
//     **DateFrom - Date
//     **DateBy - 
//   * ValidityEndDate - 
//   * UpdateDate  - 
//   * FurtherSettings - Map
//
Function CertificationAuthorityData(SearchValues, AccreditedCertificationCenters) Export
	
	Result = Undefined;
	
	
	Return Result;
	
EndFunction

Procedure OnDefineRefToAppsGuide(Section, URL) Export
	
	
EndProcedure

Procedure OnDefiningRefToAppsTroubleshootingGuide(URL, SectionName = "") Export
	
	
EndProcedure



#EndRegion