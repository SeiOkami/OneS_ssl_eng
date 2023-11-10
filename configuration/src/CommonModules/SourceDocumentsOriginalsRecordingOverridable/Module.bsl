///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Defines configuration objects whose list forms contain commands of source document tracking,
//
// Parameters:
//  ListOfObjects - Array of String - object managers with the AddPrintCommands procedure.
//
Procedure OnDefineObjectsWithOriginalsAccountingCommands(ListOfObjects) Export
	
	

EndProcedure

// 
//
// Parameters:
//  ListOfObjects - Map of KeyAndValue:
//          * Key - MetadataObject
//          * Value - String - a description of the table where employees are stored.
//
Procedure WhenDeterminingMultiEmployeeDocuments(ListOfObjects) Export
	
	

EndProcedure

// Fills in the originals recording table
// If you leave the procedure body blank - states will be tracked by all print forms of attached objects.
// If you add objects attached to the originals recording subsystem and their print forms to the value table,
// states will be tracked only by them.
//  
// Parameters:
//   AccountingTableForOriginals - ValueTable - a collection of objects and templates to track originals:
//              * MetadataObject - MetadataObject
//              * Id - String - a template ID.
//
// Example:
//	 NewRow = OriginalsRecordingTable.Add();
//	 NewRow.MetadataObject = Metadata.Documents._DemoGoodsSales;
//	 NewRow.ID = "SalesInvoice";
//
Procedure FillInTheOriginalAccountingTable(AccountingTableForOriginals) Export	
	
	

EndProcedure

#EndRegion
