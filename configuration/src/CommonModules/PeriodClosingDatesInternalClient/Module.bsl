///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// For calling from the dashboard.

Procedure OpenPeriodEndClosingDates(OwnerForm) Export
	
	OpenForm("InformationRegister.PeriodClosingDates.Form.PeriodClosingDates",, OwnerForm);
	
EndProcedure	

Procedure OpenDataImportRestrictionDates(OwnerForm) Export
	
	FormParameters = New Structure("DataImportRestrictionDates", True);
	OpenForm("InformationRegister.PeriodClosingDates.Form.PeriodClosingDates", FormParameters, OwnerForm);
	
EndProcedure	

#EndRegion
