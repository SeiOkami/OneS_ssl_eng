///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// It is called upon changing business calendar data.
// If the separation is enabled, it runs in the shared mode.
//
// Parameters:
//  UpdateConditions - ValueTable:
//    * BusinessCalendarCode - String - a code of business calendar whose data is changed.
//    * Year                           - Number  - a calendar year, during which data is changed.
//
Procedure OnUpdateBusinessCalendars(UpdateConditions) Export
	
EndProcedure

// It is called upon changing data dependent on business calendars.
// If the separation is enabled, the procedure runs in data areas.
//
// Parameters:
//  UpdateConditions - ValueTable:
//    * BusinessCalendarCode - String - a code of business calendar whose data is changed.
//    * Year                           - Number  - a calendar year, during which data is changed.
//
Procedure OnUpdateDataDependentOnBusinessCalendars(UpdateConditions) Export
	
EndProcedure

// The procedure is called upon registering a deferred handler that updates data dependent on business calendars.
// Add metadata names of objects 
// to be locked for the period of business calendar update to ObjectsToLock.
//
// Parameters:
//  ObjectsToLock - Array - metadata names of objects to be blocked.
//
Procedure OnFillObjectsToBlockDependentOnBusinessCalendars(ObjectsToLock) Export
	
EndProcedure

// The procedure is called upon registering a deferred handler that updates data dependent on business calendars.
// Add metadata names of objects 
// to be locked for the period of business calendar update to ObjectsToChange.
//
// Parameters:
//  ObjectsToChange - Array - metadata names of objects to be changed.
//
Procedure OnFillObjectsToChangeDependentOnBusinessCalendars(ObjectsToChange) Export
	
EndProcedure

#EndRegion
