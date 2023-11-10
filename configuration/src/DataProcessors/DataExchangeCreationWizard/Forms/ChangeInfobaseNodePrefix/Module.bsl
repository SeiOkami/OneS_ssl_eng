///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("Prefix", NewIBPrefix);
	
	Items.ActiveUsers.Visible = 
		Common.SubsystemExists("StandardSubsystems.UsersSessions");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Setting the current navigation table.
	FillNavigationTable();
	
	// Selecting the first wizard step.
	SetNavigationNumber(1);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)

	If Items.PanelMain.CurrentPage = Items.PageWait Then
	
		WarningText = NStr("en = 'Undo renumbering?';");
		CommonClient.ShowArbitraryFormClosingConfirmation(
			ThisObject, Cancel, Exit, WarningText, "ForceCloseForm");
			
	EndIf;	
	
EndProcedure

#EndRegion 

#Region FormCommandHandlers

&AtClient
Procedure NextCommand(Command)

	ChangePrefixInExclusiveMode = False;
	ChangeNavigationNumber(+1);
	
EndProcedure

&AtClient
Procedure BackCommand(Command)
	
	ChangeNavigationNumber(-1);
	
EndProcedure

&AtClient
Procedure CommandInStart(Command)
	
    ChangeNavigationNumber(-2);
	
EndProcedure

&AtClient
Procedure DoneCommand(Command)
	
	ForceCloseForm = True;
	
	Close();
	
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	
	Close();
	
EndProcedure
	
&AtClient
Procedure RepeatInExclusiveMode(Command)
	
	ChangePrefixInExclusiveMode = True;
	ChangeNavigationNumber(-1);
	
EndProcedure

&AtClient
Procedure ActiveUsers(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.UsersSessions") Then
		
		FormNameActiveUsers = "ActiveUsers.Form.ActiveUsers";
		OpenForm("DataProcessor." + FormNameActiveUsers, , , , , , , FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;

EndProcedure

#EndRegion


#Region Private

&AtClient
Procedure ChangeNavigationNumber(Iterator_SSLy)
	
	ClearMessages();
	
	SetNavigationNumber(NavigationNumber + Iterator_SSLy);
	
EndProcedure

&AtClient
Procedure SetNavigationNumber(Val Value)
	
	IsMoveNext = (Value > NavigationNumber);
	
	NavigationNumber = Value;
	
	If NavigationNumber < 0 Then
		
		NavigationNumber = 0;
		
	EndIf;
	
	NavigationNumberOnChange(IsMoveNext);
	
EndProcedure

&AtClient
Procedure NavigationNumberOnChange(Val IsMoveNext)
	
	// Executing navigation event handlers.
	ExecuteNavigationEventHandlers(IsMoveNext);
	
	// Setting page view.
	NavigationRowsCurrent = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber));
	
	If NavigationRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'The page to display is not specified.';");
	EndIf;
	
	NavigationRowCurrent = NavigationRowsCurrent[0];
	
	Items.PanelMain.CurrentPage  = Items[NavigationRowCurrent.MainPageName];
	Items.NavigationPanel.CurrentPage = Items[NavigationRowCurrent.NavigationPageName];
	
	If Not IsBlankString(NavigationRowCurrent.DecorationPageName) Then
		
		Items.DecorationPanel.CurrentPage = Items[NavigationRowCurrent.DecorationPageName];
		
	EndIf;
	
	// Setting the default button.
	NextButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "NextCommand");
	
	If NextButton <> Undefined Then
		
		NextButton.DefaultButton = True;
		
	Else
		
		ConfirmButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "DoneCommand");
		
		If ConfirmButton <> Undefined Then
			
			ConfirmButton.DefaultButton = True;
			
		EndIf;
		
	EndIf;
	
	If IsMoveNext And NavigationRowCurrent.TimeConsumingOperation Then
		
		AttachIdleHandler("ExecuteTimeConsumingOperationHandler", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteNavigationEventHandlers(Val IsMoveNext)
	
	// Navigation event handlers.
	If IsMoveNext Then
		
		NavigationRows = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber - 1));
		
		If NavigationRows.Count() > 0 Then
			
			NavigationRow = NavigationRows[0];
			
			// OnNavigationToNextPage handler.
			If Not IsBlankString(NavigationRow.OnNavigationToNextPageHandlerName)
				And Not NavigationRow.TimeConsumingOperation Then
				
				ProcedureName = "[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", NavigationRow.OnNavigationToNextPageHandlerName);
				
				Cancel = False;
				
				Result = Eval(ProcedureName);
				
				If Cancel Then
					
					NavigationNumber = NavigationNumber - 1;
					Return;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	Else
		
		NavigationRows = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber + 1));
		
		If NavigationRows.Count() > 0 Then
			
			NavigationRow = NavigationRows[0];
			
			// OnNavigationToPreviousPage handler.
			If Not IsBlankString(NavigationRow.OnSwitchToPreviousPageHandlerName)
				And Not NavigationRow.TimeConsumingOperation Then
				
				ProcedureName = "[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", NavigationRow.OnSwitchToPreviousPageHandlerName);
				
				Cancel = False;
				
				Result = Eval(ProcedureName);
				
				If Cancel Then
					
					NavigationNumber = NavigationNumber + 1;
					Return;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	NavigationRowsCurrent = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber));
	
	If NavigationRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'The page to display is not specified.';");
	EndIf;
	
	NavigationRowCurrent = NavigationRowsCurrent[0];
	
	If NavigationRowCurrent.TimeConsumingOperation And Not IsMoveNext Then
		
		SetNavigationNumber(NavigationNumber - 1);
		Return;
	EndIf;
	
	// OnOpen handler
	If Not IsBlankString(NavigationRowCurrent.OnOpenHandlerName) Then
		
		ProcedureName = "[HandlerName](Cancel, SkipPage, IsMoveNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", NavigationRowCurrent.OnOpenHandlerName);
		
		Cancel = False;
		SkipPage = False;
		
		Result = Eval(ProcedureName);
		
		If Cancel Then
			
			NavigationNumber = NavigationNumber - 1;
			Return;
			
		ElsIf SkipPage Then
			
			If IsMoveNext Then
				
				SetNavigationNumber(NavigationNumber + 1);
				Return;
				
			Else
				
				SetNavigationNumber(NavigationNumber - 1);
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteTimeConsumingOperationHandler()
	
	NavigationRowsCurrent = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber));
	
	If NavigationRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'The page to display is not specified.';");
	EndIf;
	
	NavigationRowCurrent = NavigationRowsCurrent[0];
	
	// TimeConsumingOperationProcessing handler.
	If Not IsBlankString(NavigationRowCurrent.TimeConsumingOperationHandlerName) Then
		
		ProcedureName = "[HandlerName](Cancel, GoToNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", NavigationRowCurrent.TimeConsumingOperationHandlerName);
		
		Cancel = False;
		GoToNext = True;
		
		Result = Eval(ProcedureName);
		
		If Cancel Then
			
			NavigationNumber = NavigationNumber - 1;
			Return;
			
		ElsIf GoToNext Then
			
			SetNavigationNumber(NavigationNumber + 1);
			Return;
			
		EndIf;
		
	Else
		
		SetNavigationNumber(NavigationNumber + 1);
		Return;
		
	EndIf;
	
EndProcedure

&AtClient
Function GetFormButtonByCommandName(FormItem, CommandName)
	
	For Each Item In FormItem.ChildItems Do
		
		If TypeOf(Item) = Type("FormGroup") Then
			
			FormItemByCommandName = GetFormButtonByCommandName(Item, CommandName);
			
			If FormItemByCommandName <> Undefined Then
				
				Return FormItemByCommandName;
				
			EndIf;
			
		ElsIf TypeOf(Item) = Type("FormButton")
			And StrFind(Item.CommandName, CommandName) > 0 Then
			
			Return Item;
			
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtServer
Function SetExclusiveModeAtServer()
	
	Result = False;
	
	InfobaseSessions = GetInfoBaseSessions();
	CurrentUserSessionNumber = InfoBaseSessionNumber();
	ActiveSessionCount = 0;
	For Each IBSession In InfobaseSessions Do
		If IBSession.ApplicationName = "Designer"
			Or IBSession.SessionNumber = CurrentUserSessionNumber Then
			Continue;
		EndIf;
		ActiveSessionCount = ActiveSessionCount + 1;
	EndDo;
	
	ExclusiveModeSettingError = "";
	If ActiveSessionCount = 0 Then
		Try
			SetExclusiveMode(True);
			Result = True;
		Except
			ExclusiveModeSettingError = NStr("en = 'Technical details:';") + " " 
				+ ErrorProcessing.BriefErrorDescription(ErrorInfo());
		EndTry;
		If ExclusiveMode() Then
			SetExclusiveMode(False);
		EndIf;
	Else
		
		Items.ActiveUsers.Visible = True;
		Items.DecorationExplanationOnError.Visible = True;
		
		Items.ErrorDecoration.Title = NStr("en = 'Couldn''t change the prefix. There are active user sessions:';");
		Items.ActiveUsers.Title = StringFunctions.FormattedString(NStr("en = 'Active users (%1)';"), ActiveSessionCount);
		Items.DecorationExplanationOnError.Title = NStr("en = 'To continue, close their sessions.';")
		
	EndIf;
		
	Return Result;
			
EndFunction 

&AtServer
Procedure RemoveExclusiveModeOnServer()

	If ExclusiveMode() Then
		SetExclusiveMode(False);
	EndIf;
	
EndProcedure

&AtClient
Function Attachable_WaitingPageOnOpen(Cancel, SkipPage, Val IsMoveNext)

	If ChangePrefixInExclusiveMode Then
		If Not SetExclusiveModeAtServer() Then
			ChangeNavigationNumber(+1);
			Return Undefined;
		EndIf;
	EndIf;
	
	BackgroundJob = StartIBPrefixChangeInBackgroundJob();
		
	WaitSettings = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	WaitSettings.OutputIdleWindow = False;
		
	Handler = New NotifyDescription("AfterChangePrefix", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(BackgroundJob, Handler, WaitSettings);

	Return Undefined;
	
EndFunction

&AtServer
Function StartIBPrefixChangeInBackgroundJob()
	
	ProcedureParameters = New Structure("NewIBPrefix, ContinueNumbering", NewIBPrefix, True);
		
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Change prefix';");
	ExecutionParameters.WaitCompletion = 0;
		
	Return TimeConsumingOperations.ExecuteProcedure(ExecutionParameters,"ObjectsPrefixesInternal.ChangeIBPrefix", ProcedureParameters);
	
EndFunction

&AtClient
Procedure AfterChangePrefix(BackgroundJob, AdditionalParameters) Export 
	
	If BackgroundJob.Status = "Completed2" Then
				
		ChangeNavigationNumber(+2);
		RemoveExclusiveModeOnServer();
		Notify("ConstantsSet.DistributedInfobaseNodePrefix", NewIBPrefix);
				
	ElsIf BackgroundJob.Status = "Error" Then 
		
		Items.ActiveUsers.Visible = False;
		Items.DecorationExplanationOnError.Visible = False;
		
		Template = NStr("en = '%1
                       |
                       |Retry later or in exclusive mode';");
		
		Items.ErrorDecoration.Title = StringFunctionsClient.FormattedString(Template, BackgroundJob.BriefErrorDescription);
		ChangeNavigationNumber(+1);
		
	EndIf;

EndProcedure

&AtClient
Procedure FillNavigationTable()
	
	NavigationTable.Clear();
	
	Transition = NavigationTable.Add();
	Transition.NavigationNumber = 1;
	Transition.MainPageName     = "PageSetPrefix";
	Transition.NavigationPageName    = "NavigationStartPage";
	
	Transition = NavigationTable.Add();
	Transition.NavigationNumber = 2;
	Transition.MainPageName     = "PageWait";
	Transition.NavigationPageName    = "NavigationWaitPage";
	Transition.OnOpenHandlerName = "Attachable_WaitingPageOnOpen";
	
	Transition = NavigationTable.Add();
	Transition.NavigationNumber = 3;
	Transition.MainPageName     = "ErrorPage";
	Transition.NavigationPageName    = "PageNavigationError";
	
	Transition = NavigationTable.Add();
	Transition.NavigationNumber = 4;
	Transition.MainPageName     = "PageDone";
	Transition.NavigationPageName    = "NavigationEndPage";
		
EndProcedure

#EndRegion
