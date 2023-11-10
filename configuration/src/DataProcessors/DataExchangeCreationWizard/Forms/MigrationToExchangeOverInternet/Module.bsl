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
	
	Parameters.Property("ExchangeNode", ExchangeNode);
	
	// 
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Settings.MigrationToWebService_Step AS MigrationToWebService_Step,
		|	Settings.MigrationToWebService_DataArea AS DataArea,
		|	Settings.MigrationToWebService_Endpoint AS Endpoint,
		|	Settings.MigrationToWebService_PeerEndpoint AS CorrespondentEndpoint
		|FROM
		|	InformationRegister.CommonInfobasesNodesSettings AS Settings
		|WHERE
		|	Settings.InfobaseNode = &InfobaseNode";
	
	Query.SetParameter("InfobaseNode", ExchangeNode);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		CurrentStep = Selection.MigrationToWebService_Step + 1;
		FillPropertyValues(ThisForm, Selection, "DataArea,Endpoint,CorrespondentEndpoint");
		
	EndIf;
		
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// 
	TableOfTransitionsByScenario();
	
	// 
	SetNavigationNumber(1);
	
	PopulateTableOfTransitionSteps();
	
	RefreshStepsDisplay();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	WarningText = NStr("en = 'Do you want to close the wizard?';");
	CommonClient.ShowArbitraryFormClosingConfirmation(
		ThisObject, Cancel, Exit, WarningText, "ForceCloseForm");
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Not Exit
		And CurrentStep > 0 Then
		
		Notify("FormMigrationToExchangeOverInternetWizardClosed");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure NextCommand(Command)
	
	ChangeNavigationNumber(+1);
	
EndProcedure

&AtClient
Procedure BackCommand(Command)
	
	ChangeNavigationNumber(-1);
	
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
	
	// 
	ExecuteNavigationEventHandlers(IsMoveNext);
	
	// 
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
	
	// 
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
	
	// 
	If IsMoveNext Then
		
		NavigationRows = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber - 1));
		
		If NavigationRows.Count() > 0 Then
			
			NavigationRow = NavigationRows[0];
			
			// 
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
			
			// 
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
	
	// 
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
	
	// 
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

&AtClient
Function Attachable_NavigationPage_OnOpen(Cancel, SkipPage, Val IsMoveNext)
	
	If CurrentStep = 1 Then
		OnStartGetApplicationList();
	ElsIf CurrentStep = 2 Then
		OnStartDisconnectingFromSM();
	ElsIf CurrentStep = 3 Then
		OnStartSettingUpPeerNode();
	ElsIf CurrentStep = 4 Then
		OnStartNodeSetup();
	EndIf;
	
EndFunction

#Region GettingSettings

&AtClient
Procedure OnStartGetApplicationList()
	
	HandlerParameters = Undefined;
	ContinueWait = False;
	
	OnStartGettingApplicationsListAtServer(HandlerParameters, ContinueWait, ExchangeNode, DataArea);
		
	If ContinueWait Then
		DataExchangeClient.InitIdleHandlerParameters(IdleHandlerParameters);
			
		AttachIdleHandler("OnWaitForGetApplicationList",
			IdleHandlerParameters.CurrentInterval, True);
	
	Else
		OnCompleteGettingApplicationsList();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForGetApplicationList()
	
	ContinueWait = False;
	OnWaitGettingApplicationsListAtServer(HandlerParameters, ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
		
		AttachIdleHandler("OnWaitForGetApplicationList",
			IdleHandlerParameters.CurrentInterval, True);
	Else
		IdleHandlerParameters = Undefined;
		OnCompleteGettingApplicationsList();
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure OnWaitGettingApplicationsListAtServer(HandlerParameters, ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ModuleSetupWizard.OnWaitForGetApplicationList(
		HandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnStartGettingApplicationsListAtServer(HandlerParameters, ContinueWait, Node, DataArea)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	WizardParameters = New Structure("Mode", "ConfiguredExchanges");
	
	ModuleSetupWizard.OnStartGetApplicationList(WizardParameters,
		HandlerParameters, ContinueWait);
	
EndProcedure

&AtClient
Procedure OnCompleteGettingApplicationsList()
	
	GoToNext = True;
	OnCompleteGettingApplicationsListAtServer(GoToNext);
	
	If GoToNext Then
		CurrentStep = CurrentStep + 1;
		RefreshStepsDisplay();
		OnStartDisconnectingFromSM();
	Else
		SetNavigationNumber(1);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnCompleteGettingApplicationsListAtServer(GoToNext)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		GoToNext = False;
		Return;
	EndIf;
	
	CompletionStatus = Undefined;
	ModuleSetupWizard.OnCompleteGettingApplicationsList(HandlerParameters, CompletionStatus);
		
	If CompletionStatus.Cancel Then
		
		Common.MessageToUser(CompletionStatus.ErrorMessage);
		GoToNext = False;
		
	Else
		
		ApplicationsTable = CompletionStatus.Result;
		ApplicationRow = ApplicationsTable.Find(ExchangeNode, "Peer");
		If Not ApplicationRow = Undefined Then
			
			Endpoint = ApplicationRow.Endpoint;
			DataArea = ApplicationRow.DataArea;
			CorrespondentEndpoint = ApplicationRow.CorrespondentEndpoint;
			
			// 
			RecordStructure = New Structure;
			RecordStructure.Insert("InfobaseNode"					, ExchangeNode);
			RecordStructure.Insert("MigrationToWebService_PeerEndpoint"	, CorrespondentEndpoint);
			RecordStructure.Insert("MigrationToWebService_DataArea"				, DataArea);
			RecordStructure.Insert("MigrationToWebService_Endpoint"				, Endpoint);
			RecordStructure.Insert("MigrationToWebService_Step"							, CurrentStep);			
			
			DataExchangeInternal.UpdateInformationRegisterRecord(RecordStructure, "CommonInfobasesNodesSettings");
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region DisconnectingFromSM

&AtClient
Procedure OnStartDisconnectingFromSM()
	
	ContinueWait = True;
	
	OnStartDisconnectingFromSMAtServer(ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.InitIdleHandlerParameters(
			IdleHandlerParameters);
			
		AttachIdleHandler("OnWaitDisconnectingFromSM",
			IdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteDisconnectingFromSM();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnStartDisconnectingFromSMAtServer(ContinueWait)
	
	Settings = New Structure;
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangeNode);
			
	Settings.Insert("ExchangePlanName",				ExchangePlanName);
	Settings.Insert("CorrespondentDataArea",	DataArea);
	
	ModuleDisconnectingFromSM = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
		
	If ModuleDisconnectingFromSM = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ModuleDisconnectingFromSM.OnStartDisconnectingFromSM(Settings, HandlerParameters, ContinueWait);
	
EndProcedure

&AtClient
Procedure OnWaitDisconnectingFromSM()
	
	ContinueWait = False;
	OnWaitDisconnectingFromSMAtServer(HandlerParameters, ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
		
		AttachIdleHandler("OnWaitDisconnectingFromSM",
			IdleHandlerParameters.CurrentInterval, True);
	Else
		IdleHandlerParameters = Undefined;  
		OnCompleteDisconnectingFromSM();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteDisconnectingFromSM()
	
	ErrorMessage = "";
	GoToNext = True;
	
	OnCompleteDisconnectingFromSMAtServer(GoToNext, ErrorMessage);
	
	If GoToNext Then
		CurrentStep = CurrentStep + 1;
		RefreshStepsDisplay();
		OnStartSettingUpPeerNode();
	Else
		SetNavigationNumber(1);
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure OnWaitDisconnectingFromSMAtServer(HandlerParameters, ContinueWait)
	
	ModuleMigrationWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleMigrationWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ContinueWait = False;
	ModuleMigrationWizard.OnWaitDisconnectingFromSM(HandlerParameters, ContinueWait);
	
EndProcedure

&AtServer
Procedure OnCompleteDisconnectingFromSMAtServer(GoToNext, ErrorMessage)
	
	ModuleMigrationWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleMigrationWizard = Undefined Then
		GoToNext = False;
		Return;
	EndIf;
	
	CompletionStatus = Undefined;
	
	ModuleMigrationWizard.OnCompleteDisconnectingFromSM(HandlerParameters, CompletionStatus);
		
	If CompletionStatus.Cancel Then
		
		Common.MessageToUser(CompletionStatus.ErrorMessage);
		GoToNext = False;
		
	Else
		
		CommitTransitionStep();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region PeerNodeSetup

&AtClient
Procedure OnStartSettingUpPeerNode()
	
	TimeConsumingOperation = OnStartSettingUpPeerNodeAtServer();
	
	CompletionNotification2 = New NotifyDescription("NodePeerInfobaseSetupCompletion", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CompletionNotification2, IdleParameters());
		
EndProcedure

&AtServer
Function OnStartSettingUpPeerNodeAtServer()
	
	Return TimeConsumingOperations.ExecuteProcedure(, 
		"DataProcessors.DataExchangeCreationWizard.ChangeTransportOfPeerNodeOnWS",
		ExchangeNode,
		Endpoint,
		CorrespondentEndpoint,
		DataArea);
	
EndFunction

&AtClient
Procedure NodePeerInfobaseSetupCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then  // 
		Return;
	EndIf;
		
	If Result.Status = "Error" Then
		CommonClient.MessageToUser(Result.BriefErrorDescription);
		SetNavigationNumber(1);
	Else	
		CurrentStep = CurrentStep + 1;
		RefreshStepsDisplay();
		CommitTransitionStep();
		OnStartNodeSetup();
	EndIf;
	
EndProcedure

#EndRegion

#Region ConfiguringNode

&AtClient
Procedure OnStartNodeSetup()
	
	TimeConsumingOperation = OnStartSettingUpNodeAtServer();
	
	CompletionNotification2 = New NotifyDescription("NodeSetupCompletion", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CompletionNotification2, IdleParameters());
		
EndProcedure

&AtServer
Function OnStartSettingUpNodeAtServer()
	
	Return TimeConsumingOperations.ExecuteProcedure(, 
		"DataProcessors.DataExchangeCreationWizard.ChangeNodeTransportInWS",
		ExchangeNode,
		CorrespondentEndpoint,
		DataArea);
	
EndFunction

&AtClient
Procedure NodeSetupCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then  // 
		Return;
	EndIf;
		
	If Result.Status = "Error" Then
		CommonClient.MessageToUser(Result.BriefErrorDescription);
		SetNavigationNumber(1);
	Else	
		CurrentStep = CurrentStep + 1;
		RefreshStepsDisplay();
		ClearUpTransitionStepsInRegister();
		AttachIdleHandler("AfterAllStepsCompleted",1,True); // 
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterAllStepsCompleted()
	
	ChangeNavigationNumber(+1);
	
EndProcedure

#EndRegion

&AtServer
Procedure CommitTransitionStep()
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode"		, ExchangeNode);
	RecordStructure.Insert("MigrationToWebService_Step"				, CurrentStep);
	DataExchangeInternal.UpdateInformationRegisterRecord(RecordStructure, "CommonInfobasesNodesSettings");

EndProcedure

&AtServer
Procedure ClearUpTransitionStepsInRegister()
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode"					, ExchangeNode);
	RecordStructure.Insert("MigrationToWebService_PeerEndpoint"	, Undefined);
	RecordStructure.Insert("MigrationToWebService_Endpoint"				, Undefined);
	RecordStructure.Insert("MigrationToWebService_DataArea"				, 0);
	RecordStructure.Insert("MigrationToWebService_Step"							, 0);			
	
	DataExchangeInternal.UpdateInformationRegisterRecord(RecordStructure, "CommonInfobasesNodesSettings");
				
EndProcedure

&AtClient
Function IdleParameters()
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.MessageText = "";
	IdleParameters.OutputProgressBar = False;
	IdleParameters.ExecutionProgressNotification = Undefined;
	IdleParameters.UserNotification.Show = True;
	IdleParameters.OutputIdleWindow = False;
	IdleParameters.OutputMessages = False;
	Return IdleParameters;

EndFunction

&AtClient
Procedure TableOfTransitionsByScenario()
	
	NavigationTable.Clear();
	
	Transition = NavigationTable.Add();
	Transition.NavigationNumber = 1;
	Transition.MainPageName	 	= "StartPage";
	Transition.NavigationPageName	= "NavigationStartPage";
	
	Transition = NavigationTable.Add();
	Transition.NavigationNumber = 2;
	Transition.MainPageName	 	= "PageMigration";
	Transition.NavigationPageName	= "NavigationWaitPage";
	Transition.OnOpenHandlerName = "Attachable_NavigationPage_OnOpen";

	Transition = NavigationTable.Add();
	Transition.NavigationNumber = 3;
	Transition.MainPageName	 	= "EndPage";
	Transition.NavigationPageName	= "NavigationEndPage";
	
EndProcedure

&AtClient
Function AddTransitionStep(Name1, Panel, Label, Current, Success)
	
	StageString = SetupSteps.Add();
	StageString.Name1         = Name1;
	StageString.Label          = Label;
	StageString.Panel           = Panel;
	StageString.PageSuccessfully  = Success;
	StageString.PageCurrent  = Current;
	
	Return StageString;
	
EndFunction

&AtClient
Procedure PopulateTableOfTransitionSteps()
	
	SetupSteps.Clear();
	
	AddTransitionStep("GettingSettings",
		Items.PanelGetSettings.Name,
		Items.DecorationGettingSettings.Name,
		Items.PageSettingsAcquisitionCurrent.Name,
		Items.PageGettingSettingsSucceeded.Name);
		
	AddTransitionStep("DisconnectingFromSM",
		Items.PanelDisconnectFromServiceManager.Name,
		Items.DecorationDisconnectFromServiceManager.Name,
		Items.PageDisconnectionFromServiceManagerCurrent.Name,
		Items.PageDisconnectedFromServiceManagerSucceeded.Name);
		
	AddTransitionStep("PeerNodeSetting",
		Items.PanelPeerNodeSetup.Name,
		Items.DecorationPeerNodeSetup.Name,
		Items.PagePeerNodeSetupCurr.Name,
		Items.PagePeerNodeSetupSucceeded.Name);

	AddTransitionStep("ConfiguringNode",
		Items.NodeSetupPanel.Name,
		Items.DecorationNodeSetup.Name,
		Items.PageNodeSetupCurrent.Name,
		Items.PageNodeSetupSucceeded.Name);
		   	
EndProcedure

&AtClient
Procedure RefreshStepsDisplay()
	
	LineNumber = 1;
	For Each String In SetupSteps Do
		
		Panel = Items[String.Panel];
		
		If LineNumber = CurrentStep Then
			Items[String.Panel].CurrentPage = Items[String.PageCurrent];
			Items[String.Label].Font = New Font(,,True);
		ElsIf LineNumber < CurrentStep Then
			Items[String.Panel].CurrentPage = Items[String.PageSuccessfully];
			Items[String.Label].Font = New Font;
		Else
			Items[String.Label].Font = New Font;
		EndIf; 
		
		LineNumber = LineNumber + 1;
		
	EndDo;
	
EndProcedure

#EndRegion

