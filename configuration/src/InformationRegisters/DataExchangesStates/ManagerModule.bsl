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

// Adds a record to the register by the passed structure values.
Procedure AddRecord(RecordStructure) Export
	
	If Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable() Then
		
		DataExchangeInternal.AddRecordToInformationRegister(RecordStructure, "DataAreaDataExchangeStates");
	Else
		DataExchangeInternal.AddRecordToInformationRegister(RecordStructure, "DataExchangesStates");
	EndIf;
	
EndProcedure

Procedure UpdateRecord(RecordStructure) Export
	
	If Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable() Then
		
		DataExchangeInternal.UpdateInformationRegisterRecord(RecordStructure, "DataAreaDataExchangeStates");
	Else
		DataExchangeInternal.UpdateInformationRegisterRecord(RecordStructure, "DataExchangesStates");
	EndIf;
	
EndProcedure

#EndRegion

#EndIf