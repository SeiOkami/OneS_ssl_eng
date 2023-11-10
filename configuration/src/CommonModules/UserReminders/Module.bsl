///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Generates a reminder with arbitrary time or execution schedule.
//
// Parameters:
//  Text - String - Reminder text;
//  EventTime - Date - Date and time of the event, which needs a reminder.
//               - JobSchedule - Repeated event schedule.
//               - String - Name of the subject's attribute that contains the event time.
//  IntervalTillEvent - Number - time in seconds, prior to which it is necessary to remind of the event time;
//  SubjectOf - AnyRef - Reminder's subject.
//  Id - String - Describes the reminder's subject. For example, "Birthday".
//
Procedure SetReminder(Text, EventTime, IntervalTillEvent = 0, SubjectOf = Undefined, Id = Undefined) Export
	UserRemindersInternal.AttachArbitraryReminder(
		Text, EventTime, IntervalTillEvent, SubjectOf, Id);
EndProcedure

// Returns a list of reminders for the current user.
//
// Parameters:
//  SubjectOf - AnyRef
//          - Array - Reminder subject(s).
//  Id - String - Describes the reminder's subject. For example, "Birthday".
//
// Returns:
//    Array - Reminder collection as structures with fields repeating the fields of the UserReminders  information register.
//
Function FindReminders(Val SubjectOf = Undefined, Id = Undefined) Export
	
	QueryText =
	"SELECT
	|	*
	|FROM
	|	InformationRegister.UserReminders AS UserReminders
	|WHERE
	|	UserReminders.User = &User
	|	AND &IsFilterBySubject
	|	AND &FilterByID";
	
	IsFilterBySubject = "TRUE";
	If ValueIsFilled(SubjectOf) Then
		IsFilterBySubject = "UserReminders.Source IN(&SubjectOf)";
	EndIf;
	
	FilterByID = "TRUE";
	If ValueIsFilled(Id) Then
		FilterByID = "UserReminders.Id = &Id";
	EndIf;
	
	QueryText = StrReplace(QueryText, "&IsFilterBySubject", IsFilterBySubject);
	QueryText = StrReplace(QueryText, "&FilterByID", FilterByID);
	
	Query = New Query(QueryText);
	Query.SetParameter("User", Users.CurrentUser());
	Query.SetParameter("SubjectOf", SubjectOf);
	Query.SetParameter("Id", Id);
	
	RemindersTable = Query.Execute().Unload();
	RemindersTable.Sort("ReminderTime");
	
	Return Common.ValueTableToArray(RemindersTable);
	
EndFunction

// Deletes a user reminder.
//
// Parameters:
//  Reminder - Structure - Collection element returned by FindReminders().
//
Procedure DeleteReminder(Reminder) Export
	UserRemindersInternal.DisableReminder(Reminder, False);
EndProcedure

// Checks attribute changes for the subjects the user subscribed to.
// If necessary, changes the reminder time.
//
// Parameters:
//  Subjects - Array - Subjects whose reminder dates must be updated.
// 
Procedure UpdateRemindersForSubjects(Subjects) Export
	
	UserRemindersInternal.UpdateRemindersForSubjects(Subjects);
	
EndProcedure

// Checks if user reminders are enabled.
// 
// Returns:
//  Boolean - User reminders enablement flag.
//
Function UsedUserReminders() Export
	
	Return GetFunctionalOption("UseUserReminders") 
		And AccessRight("Update", Metadata.InformationRegisters.UserReminders);
	
EndFunction

// 
//
// Parameters:
//  Form - ClientApplicationForm -
//  PlacementParameters - See PlacementParameters
//
Procedure OnCreateAtServer(Form, PlacementParameters) Export
	
	UserRemindersInternal.OnCreateAtServer(Form, PlacementParameters);
	
EndProcedure

// 
// 
// Returns:
//  Structure:
//   * Group - FormGroup -
//   * NameOfAttributeWithEventDate - String -
//   * ReminderInterval - Number -
//   * ShouldAddFlag - Boolean - 
//                                
//                                
//                                
//
Function PlacementParameters() Export
	
	Return UserRemindersInternal.PlacementParameters();
	
EndFunction

// 
//
// Parameters:
//  Form - ClientApplicationForm -
//  CurrentObject       - CatalogObject
//                      - DocumentObject
//                      - ChartOfCharacteristicTypesObject
//                      - ChartOfAccountsObject
//                      - ChartOfCalculationTypesObject
//                      - BusinessProcessObject
//                      - TaskObject
//                      - ExchangePlanObject - the subject of the reminder.
//
Procedure OnReadAtServer(Form, CurrentObject) Export
	
	UserRemindersInternal.OnReadAtServer(Form, CurrentObject);
	
EndProcedure

// 
//
// Parameters:
//   Form - ClientApplicationForm -
//   Cancel - Boolean - indicates that the recording was rejected.
//   CurrentObject  - CatalogObject
//                  - DocumentObject
//                  - ChartOfCharacteristicTypesObject
//                  - ChartOfAccountsObject
//                  - ChartOfCalculationTypesObject
//                  - BusinessProcessObject
//                  - TaskObject
//                  - ExchangePlanObject - the subject of the reminder.
//   WriteParameters - Structure
//   ReminderText - String -
//                               
//  
Procedure OnWriteAtServer(Form, Cancel, CurrentObject, WriteParameters, ReminderText = "") Export
	
	UserRemindersInternal.OnWriteAtServer(Form, Cancel, CurrentObject, WriteParameters, ReminderText);
	
EndProcedure

#EndRegion
