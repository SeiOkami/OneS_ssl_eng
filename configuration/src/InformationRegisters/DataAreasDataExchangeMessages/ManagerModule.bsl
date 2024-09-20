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

Procedure AddRecord(RecordStructure) Export
	
	DataExchangeInternal.AddRecordToInformationRegister(RecordStructure, "DataAreasDataExchangeMessages");
	
EndProcedure

Procedure DeleteRecord(RecordStructure) Export
	
	Record = InformationRegisters.DataAreasDataExchangeMessages.CreateRecordManager();
	FillPropertyValues(Record, RecordStructure);
	Record.Delete();
	
EndProcedure

#EndRegion

#EndIf