///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Defines a list of catalogs available for import using the "Data import from file" subsystem.
//
// Parameters:
//  CatalogsToImport - ValueTable - a list of the catalogs, to which data can be imported:
//      * FullName          - String - a full catalog name (as in metadata).
//      * Presentation      - String - Catalog presentation in the selection list.
//      * AppliedImport - Boolean - if True, then the catalog uses its own import algorithm
//                                      and the functions are defined in the manager module.
//
Procedure OnDefineCatalogsForDataImport(CatalogsToImport) Export
	
	
	
EndProcedure

#EndRegion