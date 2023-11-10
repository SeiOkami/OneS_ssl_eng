///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Adds a record to the register by the passed structure values.
Procedure AddRecord(RecordStructure) Export
	
	If Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable() Then
		
		DataExchangeInternal.AddRecordToInformationRegister(RecordStructure, "DataAreasSuccessfulDataExchangeStates");
	Else
		DataExchangeInternal.AddRecordToInformationRegister(RecordStructure, "SuccessfulDataExchangesStates");
	EndIf;
	
EndProcedure

#EndRegion

#EndIf