///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Writes an object version (unless it is a document version) to the infobase.
//
// Parameters:
//  Source - CatalogObject - an infobase object to be written;
//  Cancel    - Boolean - indicates whether the object record is canceled.
//
Procedure WriteObjectVersion(Source, Cancel) Export
	
	// 
	// 
	If Source.DataExchange.Load And Source.DataExchange.Sender = Undefined Then
		Return;
	EndIf;
	
	ObjectsVersioning.WriteObjectVersion(Source, False);
	
EndProcedure

// Writes a document version to the infobase.
//
// Parameters:
//  Source        - DocumentObject - infobase object to be written;
//  Cancel           - Boolean - flag specifying whether writing the document is canceled.
//  WriteMode     - DocumentWriteMode - specifies whether writing, posting, or canceling is performed.
//                                           Changing the parameter value modifies the write mode.
//  PostingMode - DocumentPostingMode - defines whether the real time posting is performed.
//                                               Changing the parameter value modifies the posting mode.
//
Procedure WriteDocumentVersion(Source, Cancel, WriteMode, PostingMode) Export
	
	// 
	// 
	If Source.DataExchange.Load And Source.DataExchange.Sender = Undefined Then
		Return;
	EndIf;

	ObjectsVersioning.WriteObjectVersion(Source, WriteMode);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers.

// For internal use only.
//
Procedure DeleteVersionAuthorInfo(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	InformationRegisters.ObjectsVersions.DeleteVersionAuthorInfo(Source.Ref);
	
EndProcedure

#EndRegion
