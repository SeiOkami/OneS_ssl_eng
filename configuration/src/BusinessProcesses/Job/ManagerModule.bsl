///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchEditObjects

// Returns object attributes that can be edited using the bulk attribute modification data processor.
// 
//
// Returns:
//  Array of String
//
Function AttributesToEditInBatchProcessing() Export

	Result = New Array;
	Result.Add("Author");
	Result.Add("Importance");
	Result.Add("Performer");
	Result.Add("CheckExecution");
	Result.Add("Supervisor");
	Result.Add("TaskDueDate");
	Result.Add("VerificationDueDate");
	Return Result;

EndFunction

// End StandardSubsystems.BatchEditObjects

// StandardSubsystems.BusinessProcessesAndTasks

// Gets a structure with description of a task execution form.
// The function is called when opening the task execution form.
//
// Parameters:
//   TaskRef                - TaskRef.PerformerTask -
//   BusinessProcessRoutePoint - BusinessProcessRoutePointRef.Job -
//
// Returns:
//   Structure:
//    * FormParameters - Structure:
//      ** Key - TaskRef.PerformerTask
//    * FormName - String -
//
Function TaskExecutionForm(TaskRef, BusinessProcessRoutePoint) Export

	Result = New Structure;
	Result.Insert("FormParameters", New Structure("Key", TaskRef));

	FormName = ?(BusinessProcessRoutePoint.Name = "Validate",
		Metadata.BusinessProcesses.Job.Forms.ActionCheck.FullName(),
		Metadata.BusinessProcesses.Job.Forms.ActionExecute.FullName());

	Result.Insert("FormName", FormName);

	Return Result;

EndFunction

// The function is called when forwarding a task.
//
// Parameters:
//   TaskRef  - TaskRef.PerformerTask - a forwarded task.
//   NewTaskRef  - TaskRef.PerformerTask - a task for a new assignee.
//
Procedure OnForwardTask(TaskRef, NewTaskRef) Export
	
	// 
	// 
	BusinessProcessObject = TaskRef.BusinessProcess.GetObject();
	LockDataForEdit(BusinessProcessObject.Ref);
	BusinessProcessObject.ExecutionResult = ExecutionResultOnForward(TaskRef)
		+ BusinessProcessObject.ExecutionResult;
	SetPrivilegedMode(True);
	BusinessProcessObject.Write();
	// ACC:1327-on

EndProcedure

// The function is called when a task is executed from a list form.
//
// Parameters:
//   TaskRef  - TaskRef.PerformerTask - Task.
//   BusinessProcessRef - BusinessProcessRef - a business process for which the TaskRef task is generated.
//   BusinessProcessRoutePoint - BusinessProcessRoutePointRef - Route point.
//
Procedure DefaultCompletionHandler(TaskRef, BusinessProcessRef, BusinessProcessRoutePoint) Export

	IsRoutePointComplete = (BusinessProcessRoutePoint = BusinessProcesses.Job.RoutePoints.Execute);
	IsRoutePointCheck = (BusinessProcessRoutePoint = BusinessProcesses.Job.RoutePoints.Validate);
	If Not IsRoutePointComplete And Not IsRoutePointCheck Then
		Return;
	EndIf;
	
	// Set default values for bulk task execution.
	BeginTransaction();
	Try
		BusinessProcessesAndTasksServer.LockBusinessProcesses(BusinessProcessRef);

		SetPrivilegedMode(True);
		JobObject = BusinessProcessRef.GetObject();
		LockDataForEdit(JobObject.Ref);

		If IsRoutePointComplete Then
			JobObject.Completed2 = True;
		ElsIf IsRoutePointCheck Then
			JobObject.Completed2 = True;
			JobObject.Accepted = True;
		EndIf;
		JobObject.Write(); // 

		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;

EndProcedure	

// End StandardSubsystems.BusinessProcessesAndTasks

// StandardSubsystems.AccessManagement

// Parameters:
//   Restriction - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
//
Procedure OnFillAccessRestriction(Restriction) Export

	Restriction.Text =
	"AttachAdditionalTables
	|ThisList AS Job
	|
	|LEFT JOIN InformationRegister.TaskPerformers AS TaskPerformers
	|ON
	|	TaskPerformers.PerformerRole = Job.Performer
	|	AND TaskPerformers.MainAddressingObject = Job.MainAddressingObject
	|	AND TaskPerformers.AdditionalAddressingObject = Job.AdditionalAddressingObject
	|
	|LEFT JOIN InformationRegister.TaskPerformers AS TaskSupervisors
	|ON
	|	TaskSupervisors.PerformerRole = Job.Supervisor
	|	AND TaskSupervisors.MainAddressingObject = Job.MainAddressingObjectSupervisor
	|	AND TaskSupervisors.AdditionalAddressingObject = Job.AdditionalAddressingObjectSupervisor
	|;
	|AllowRead
	|WHERE
	|	ValueAllowed(Author)
	|	OR ValueAllowed(Performer Not Catalog.PerformerRoles)
	|	OR ValueAllowed(TaskPerformers.Performer)
	|	OR ValueAllowed(Supervisor Not Catalog.PerformerRoles)
	|	OR ValueAllowed(TaskSupervisors.Performer)
	|;
	|AllowUpdateIfReadingAllowed
	|WHERE
	|	ValueAllowed(Author)";

EndProcedure

// End StandardSubsystems.AccessManagement

// StandardSubsystems.AttachableCommands

// Defined the list of commands for creating on the basis.
//
// Parameters:
//  GenerationCommands - See GenerateFromOverridable.BeforeAddGenerationCommands.GenerationCommands
//  Parameters - See GenerateFromOverridable.BeforeAddGenerationCommands.Parameters
//
Procedure AddGenerationCommands(GenerationCommands, Parameters) Export

EndProcedure

// For use in the AddCreateOnBasisCommands procedure of other object manager modules.
// Adds this object to the list of commands of creation on basis.
//
// Parameters:
//  GenerationCommands - See GenerateFromOverridable.BeforeAddGenerationCommands.GenerationCommands
//
// Returns:
//  ValueTableRow, Undefined - Details of the added command.
//
Function AddGenerateCommand(GenerationCommands) Export

	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleGeneration = Common.CommonModule("GenerateFrom");
		Command = ModuleGeneration.AddGenerationCommand(GenerationCommands,
			Metadata.BusinessProcesses.Job);
		If Command <> Undefined Then
			Command.FunctionalOptions = "UseBusinessProcessesAndTasks";
		EndIf;
		Return Command;
	EndIf;

	Return Undefined;

EndFunction

// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion

#EndIf

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Miscellaneous.

// Sets the state of the task form items.
//
// Parameters:
//  Form - ClientApplicationForm:
//   * Items - FormAllItems:
//    ** SubjectOf - FormFieldExtensionForALabelField
// 
Procedure SetTaskFormItemsState(Form) Export

	If Form.Items.Find("ExecutionResult") <> Undefined 
		And Form.Items.Find("ExecutionHistory") <> Undefined Then
		Form.Items.ExecutionHistory.Picture = CommonClientServer.CommentPicture(
			Form.JobExecutionResult);
	EndIf;

	Form.Items.SubjectOf.Hyperlink = Form.Object.SubjectOf <> Undefined And Not Form.Object.SubjectOf.IsEmpty();
	Form.SubjectString = Common.SubjectString(Form.Object.SubjectOf);

EndProcedure

Function ExecutionResultOnForward(Val TaskRef)

	StringFormat = "%1, %2 " + NStr("en = 'redirected the task';") + ":
																	   |%3
																	   |";

	Comment = TrimAll(TaskRef.ExecutionResult);
	Comment = ?(IsBlankString(Comment), "", Comment + Chars.LF);
	Result = StringFunctionsClientServer.SubstituteParametersToString(StringFormat, TaskRef.CompletionDate,
		TaskRef.Performer, Comment);
	Return Result;

EndFunction

#EndRegion

#EndIf