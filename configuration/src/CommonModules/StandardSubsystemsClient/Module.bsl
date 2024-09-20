///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Sets the application main window caption using the value of the
// ApplicationCaption constant and application caption by default.
//
// Parameters:
//   OnStart - Boolean - True if the procedure is called on the application start.
//
Procedure SetAdvancedApplicationCaption(OnStart = False) Export
	
	ClientParameters = ?(OnStart, ClientParametersOnStart(),
		ClientRunParameters());
		
	If CommonClient.SeparatedDataUsageAvailable() Then
		CaptionPresentation = ClientParameters.ApplicationCaption;
		ConfigurationPresentation = ClientParameters.DetailedInformation;
		
		If IsBlankString(TrimAll(CaptionPresentation)) Then
			If ClientParameters.Property("DataAreaPresentation") Then
				TitleTemplate1 = "%1 / %2";
				ApplicationCaption = StringFunctionsClientServer.SubstituteParametersToString(TitleTemplate1, ClientParameters.DataAreaPresentation,
					ConfigurationPresentation);
			Else
				TitleTemplate1 = "%1";
				ApplicationCaption = StringFunctionsClientServer.SubstituteParametersToString(TitleTemplate1, ConfigurationPresentation);
			EndIf;
		Else
			TitleTemplate1 = "%1 / %2";
			ApplicationCaption = StringFunctionsClientServer.SubstituteParametersToString(TitleTemplate1,
				TrimAll(CaptionPresentation), ConfigurationPresentation);
		EndIf;
	Else
		TitleTemplate1 = "%1 / %2";
		ApplicationCaption = StringFunctionsClientServer.SubstituteParametersToString(TitleTemplate1, NStr("en = 'Separators are not set';"), ClientParameters.DetailedInformation);
	EndIf;
	
	If Not CommonClient.DataSeparationEnabled()
	   And ClientParameters.Property("OperationsWithExternalResourcesLocked") Then
		ApplicationCaption = "[" + NStr("en = 'COPY';") + "]" + " " + ApplicationCaption;
	EndIf;
	
	CommonClientOverridable.ClientApplicationCaptionOnSet(ApplicationCaption, OnStart);
	
	ClientApplication.SetCaption(ApplicationCaption);
	
EndProcedure

// Show the question form.
//
// Parameters:
//   NotifyDescriptionOnCompletion - NotifyDescription - description of the procedures to be called after the question window
//                                                        is closed with the following parameters:
//                                                          QuestionResult - Structure:
//                                                            Value - a user selection result: a system enumeration
//                                                                       value or a value
//                                                                       associated with the clicked button. If the dialog
//                                                                       is closed by a timeout - value
//                                                                       Timeout.
//                                                            DontAskAgain - Boolean - a user
//                                                                                                  selection result in
//                                                                                                  the check box with the same name.
//                                                          AdditionalParameters - Structure 
//    
//   
//                                 - ValueList     - 
//                                        
//                                                  
//                                                  
//                                                  
//                                       
//
//   See StandardSubsystemsClient.QuestionToUserParameters.
//
Procedure ShowQuestionToUser(NotifyDescriptionOnCompletion, QueryText, Buttons, AdditionalParameters = Undefined) Export
	
	Parameters = QuestionToUserParameters();
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		FillPropertyValues(Parameters, AdditionalParameters);
	EndIf;
	
	DialogReturnCodes = New Map;
	DialogReturnCodes.Insert(DialogReturnCode.Yes, "DialogReturnCode.Yes");
	DialogReturnCodes.Insert(DialogReturnCode.No, "DialogReturnCode.None");
	DialogReturnCodes.Insert(DialogReturnCode.OK, "DialogReturnCode.OK");
	DialogReturnCodes.Insert(DialogReturnCode.Cancel, "DialogReturnCode.Cancel");
	DialogReturnCodes.Insert(DialogReturnCode.Retry, "DialogReturnCode.Retry");
	DialogReturnCodes.Insert(DialogReturnCode.Abort, "DialogReturnCode.Abort");
	DialogReturnCodes.Insert(DialogReturnCode.Ignore, "DialogReturnCode.Ignore");
	DialogReturnCodes.Insert(DialogReturnCode.Timeout, "DialogReturnCode.Timeout");
	
	ButtonsPresentations = New Map;
	ButtonsPresentations.Insert(DialogReturnCode.Yes, NStr("en = 'Yes';"));
	ButtonsPresentations.Insert(DialogReturnCode.No, NStr("en = 'No';"));
	ButtonsPresentations.Insert(DialogReturnCode.OK, NStr("en = 'OK';"));
	ButtonsPresentations.Insert(DialogReturnCode.Cancel, NStr("en = 'Cancel';"));
	ButtonsPresentations.Insert(DialogReturnCode.Retry, NStr("en = 'Repeat';"));
	ButtonsPresentations.Insert(DialogReturnCode.Abort, NStr("en = 'Abort';"));
	ButtonsPresentations.Insert(DialogReturnCode.Ignore, NStr("en = 'Ignore';"));
	ButtonsPresentations.Insert(DialogReturnCode.Timeout, NStr("en = 'Timeout';"));
	
	QuestionDialogModes = New Map;
	QuestionDialogModes.Insert(QuestionDialogMode.YesNo, "QuestionDialogMode.YesNo");
	QuestionDialogModes.Insert(QuestionDialogMode.YesNoCancel, "QuestionDialogMode.YesNoCancel");
	QuestionDialogModes.Insert(QuestionDialogMode.OK, "QuestionDialogMode.OK");
	QuestionDialogModes.Insert(QuestionDialogMode.OKCancel, "QuestionDialogMode.OKCancel");
	QuestionDialogModes.Insert(QuestionDialogMode.RetryCancel, "QuestionDialogMode.RetryCancel");
	QuestionDialogModes.Insert(QuestionDialogMode.AbortRetryIgnore, "QuestionDialogMode.AbortRetryIgnore");
	
	DialogButtons = Buttons;
	
	If TypeOf(Buttons) = Type("ValueList") Then
		DialogButtons = CommonClient.CopyRecursive(Buttons);
		For Each Button In DialogButtons Do
			If Button.Presentation = "" Then
				Button.Presentation = ButtonsPresentations[Button.Value];
			EndIf;
			If TypeOf(Button.Value) = Type("DialogReturnCode") Then
				Button.Value = DialogReturnCodes[Button.Value];
			EndIf;
		EndDo;
	EndIf;
	
	If TypeOf(Buttons) = Type("QuestionDialogMode") Then
		DialogButtons = QuestionDialogModes[Buttons];
	EndIf;
	
	If TypeOf(Parameters.DefaultButton) = Type("DialogReturnCode") Then
		Parameters.DefaultButton = DialogReturnCodes[Parameters.DefaultButton];
	EndIf;
	
	If TypeOf(Parameters.TimeoutButton) = Type("DialogReturnCode") Then
		Parameters.TimeoutButton = DialogReturnCodes[Parameters.TimeoutButton];
	EndIf;
	
	Parameters.Insert("Buttons", DialogButtons);
	Parameters.Insert("MessageText", QueryText);
	
	OpenForm("CommonForm.DoQueryBox", Parameters, , , , , NotifyDescriptionOnCompletion);
	
EndProcedure

// Returns a new structure with additional parameters for the ShowQuestionToUser procedure.
//
// Returns:
//  Structure:
//    * DefaultButton             - Arbitrary - defines the default button by the button type or by the value associated
//                                                     with it.
//    * Timeout                       - Number        - a period of time in seconds in which the question
//                                                     window waits for user to respond.
//    * TimeoutButton                - Arbitrary - a button (by button type or value associated with it) 
//                                                     on which the timeout
//                                                     remaining seconds are displayed.
//    * Title                     - String       - a question title. 
//    * PromptDontAskAgain - Boolean - If True, a check box with the same name is available in the window.
//    * NeverAskAgain    - Boolean       - a value set by the user in the matching
//                                                     check box.
//    * LockWholeInterface      - Boolean       - If True, the question window opens locking all
//                                                     other opened windows including the main one.
//    * Picture                      - Picture     - a picture displayed in the question window.
//    * CheckBoxText                   - String       - text of the "Do not ask again" check box.
//
Function QuestionToUserParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("DefaultButton", Undefined);
	Parameters.Insert("Timeout", 0);
	Parameters.Insert("TimeoutButton", Undefined);
	Parameters.Insert("Title", ClientApplication.GetCaption());
	Parameters.Insert("PromptDontAskAgain", True);
	Parameters.Insert("NeverAskAgain", False);
	Parameters.Insert("LockWholeInterface", False);
	Parameters.Insert("Picture", PictureLib.DoQueryBox32);
	Parameters.Insert("CheckBoxText", "");
	
	Return Parameters;
	
EndFunction	

// Is called if there is a need to open the list of active users
// to see who is logged on to the system now.
//
// Parameters:
//    FormParameters - Structure        - see details of the Parameters parameter of OpenForm method in the syntax assistant.
//    FormOwner  - ClientApplicationForm - see details of the Owner parameter of OpenForm method in the syntax assistant.
//
Procedure OpenActiveUserList(FormParameters = Undefined, FormOwner = Undefined) Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.UsersSessions") Then
		
		FormName = "";
		ModuleIBConnectionsClient = CommonClient.CommonModule("IBConnectionsClient");
		ModuleIBConnectionsClient.OnDefineActiveUserForm(FormName);
		OpenForm(FormName, FormParameters, FormOwner);
		
	Else
		
		ShowMessageBox(,
			NStr("en = 'To open the list of active users, on the main menu, click
				       |All functions—Standard—Active users.';"));
		
	EndIf;
	
EndProcedure

// See StandardSubsystemsServer.IsBaseConfigurationVersion
Function IsBaseConfigurationVersion() Export
	
	Return ClientParameter("IsBaseConfigurationVersion");
	
EndFunction

// See StandardSubsystemsServer.IsTrainingPlatform
Function IsTrainingPlatform() Export
	
	Return ClientParameter("IsTrainingPlatform");
	
EndFunction

#Region ApplicationEventsProcessing

// Disables the exit confirmation.
//
Procedure SkipExitConfirmation() Export
	
	ApplicationParameters.Insert("StandardSubsystems.SkipExitConfirmation", True);
	
EndProcedure

// Performs the standard actions before the user starts working
// with a data area or with an infobase in the local mode.
//
// Is intended for calling modules of the managed or ordinary application from the BeforeStart handler.
//
// Parameters:
//  CompletionNotification - NotifyDescription - Is skipped if managed or ordinary application modules are called from the BeforeStart 
//                         handler. In other cases, after the application started up, the notification with a parameter of the Structure type
//                         is called. The structure fields are:
//                         > Cancel - Boolean - False if the application started successfully, True if authorization is not
//                         executed;
//                         > Restart - Boolean - if the application should be restarted;
//                         > AdditionalParametersOfCommandLine - String - for restart.
//
Procedure BeforeStart(Val CompletionNotification = Undefined) Export
	
	BeginTime = CurrentUniversalDateInMilliseconds();
	
	If ApplicationParameters = Undefined Then
		ApplicationParameters = New Map;
	EndIf;
	
	ApplicationParameters.Insert("StandardSubsystems.PerformanceMonitor.StartTime1", BeginTime);
	
	If CompletionNotification <> Undefined Then
		CommonClientServer.CheckParameter("StandardSubsystemsClient.BeforeStart", 
			"CompletionNotification", CompletionNotification, Type("NotifyDescription"));
	EndIf;
	
	SignInToDataArea();
	
	ActionsBeforeStart(CompletionNotification);
	
	If Not ApplicationStartupLogicDisabled()
	   And Not CommonClient.SubsystemExists("OnlineUserSupport.CoreISL") Then
		Return;
	EndIf;
	
	Try
		ModuleOnlineUserSupportClientServer =
			CommonClient.CommonModule("OnlineUserSupportClientServer");
	Except
		If ApplicationStartupLogicDisabled() Then
			Return;
		EndIf;
		Raise;
	EndTry;
	
	ISLVersion = ModuleOnlineUserSupportClientServer.LibraryVersion();
	// 
	// 
	If CommonClientServer.CompareVersions(ISLVersion, "2.7.1.0") > 0 Then
		ModuleLicensingClientClient = CommonClient.CommonModule("LicensingClientClient");
		ModuleLicensingClientClient.AttachLicensingClientSettingsRequest();
	EndIf;
	
EndProcedure

// Performs the standard actions when the user starts working
// with a data area or with an infobase in the local mode.
//
// Is intended for calling modules of the managed or ordinary application from the OnStart handler.
//
// Parameters:
//  CompletionNotification - NotifyDescription - Is skipped if managed or ordinary application modules are called from the OnStart 
//                         handler. In other cases, after the application started up, the notification with a parameter of the Structure type
//                         is called. The structure fields are:
//                         > Cancel - Boolean - False if the application started successfully, True if authorization is not
//                         executed;
//                         > Restart - Boolean - if the application should be restarted;
//                         > AdditionalParametersOfCommandLine - String - for restart.
//
//  ContinuousExecution - Boolean - For internal use only.
//                          For proceeding from the BeforeStart
//                          handler executed in the interactive processing mode.
//
Procedure OnStart(Val CompletionNotification = Undefined, ContinuousExecution = True) Export
	
	If InteractiveHandlerBeforeStartInProgress() Then
		Return;
	EndIf;
	
	If ApplicationStartupLogicDisabled() Then
		Return;
	EndIf;
	
	If CompletionNotification <> Undefined Then
		CommonClientServer.CheckParameter("StandardSubsystemsClient.OnStart", 
			"CompletionNotification", CompletionNotification, Type("NotifyDescription"));
	EndIf;
	CommonClientServer.CheckParameter("StandardSubsystemsClient.OnStart", 
		"ContinuousExecution", ContinuousExecution, Type("Boolean"));
	
	ActionsOnStart(CompletionNotification, ContinuousExecution);
	
EndProcedure

// Performs the standard actions when the user logs off
// from a data area or exits the application in the local mode.
//
// Is intended for calling modules of the managed or ordinary application from the BeforeExit handler.
//
// Parameters:
//  Cancel                - Boolean - a return value. A flag indicates whether the exit must be canceled 
//                         for the BeforeExit event handler, both for program
//                         or for interactive cases. If the user
//                         interaction was successful, the application exit can be continued.
//  WarningText  - String - see BeforeExit() in the Syntax Assistant.
//
Procedure BeforeExit(Cancel = False, WarningText = "") Export
	
	If Not DisplayWarningsBeforeShuttingDownTheSystem(Cancel) Then
		Return;
	EndIf;
	
	Warnings = WarningsBeforeSystemShutdown(Cancel);
	If Warnings.Count() = 0 Then
		If Not ClientParameter("AskConfirmationOnExit") Then
			Return;
		EndIf;
		WarningText = NStr("en = 'Do you want to exit the application?';");
		Cancel = True;
	Else
		Cancel = True;
		WarningArray = New Array;
		For Each Warning In Warnings Do
			WarningArray.Add(Warning.WarningText);
		EndDo;
		If Not IsBlankString(WarningText) Then
			WarningText = WarningText + Chars.LF;
		EndIf;
		WarningText = WarningText + StrConcat(WarningArray, Chars.LF);
		AttachIdleHandler("ShowExitWarning", 0.1, True);
	EndIf;
	SetClientParameter("ExitWarnings", Warnings);
	
EndProcedure

// 
//
// Parameters:
//  ChoicePurpose - CollaborationSystemUsersChoicePurpose
//  Form - ClientApplicationForm
//  ConversationID - CollaborationSystemConversationID
//  Parameters - Structure
//  SelectedForm - String
//  StandardProcessing - Boolean
//
Procedure CollaborationSystemUsersChoiceFormGetProcessing(ChoicePurpose,
			Form, ConversationID, Parameters, SelectedForm, StandardProcessing) Export
	
	// 
	If CommonClient.SubsystemExists("StandardSubsystems.Conversations") Then
		ModuleConversationsInternalClient = CommonClient.CommonModule("ConversationsInternalClient");
		ModuleConversationsInternalClient.OnGetCollaborationSystemUsersChoiceForm(ChoicePurpose,
			Form, ConversationID, Parameters, SelectedForm, StandardProcessing);
	EndIf;
	// 
		
EndProcedure

// Returns a structure parameters for showing the warnings before exit the application.
// To use in CommonClientOverridable.BeforeExit.
//
// Returns:
//  Structure:
//    WarningText - String - a text displayed in the window of web browser (or thin client) when closing the application.
//                                    For example, "There are edited files that are not placed to the application".
//                                    Other parameters determine the appearance of the warning form
//                                    opened after confirmation in the web browser window (or thin client).
//    CheckBoxText - String - if specified, a check box with the specified text is displayed in the warning form. 
//                                    For example, "Finish file editing (5)".
//    NoteText - String - a text to be shown on the top of the managed item (check box or hyperlink).
//                                    For example, "Edited files are not placed in the application".
//    HyperlinkText - String - if specified, a hyperlink is displayed with the specified text.
//                                    For example, "Edited files (5)".
//    ExtendedTooltip - String - a text of the tooltip to be shown to the right from the managed item (check box or
//                                    hyperlink). For example, "Click to go to the list of files 
//                                    opened for editing".
//    Priorities - Number - a relative order in the list of warnings on the form (the greater, the higher).
//    OutputSingleWarning - Boolean - if True, this warning is the only one
//                                         warning to be shown in the warning list. That is such a warning is incompatible with any other.
//    ActionIfFlagSet - a structure:
//      * Form          - String    -
//                                     
//      * FormParameters - Structure - Arbitrary structure of form open parameters. 
//    
//      * Form          - String    - path to the form that should be opened by clicking on the hyperlink.
//                                     For Example, " Processing.Files.Editable files".
//      * FormParameters - Structure - Arbitrary structure of form open parameters.
//      * ApplicationWarningForm - String - a path to the form to be opened
//                                        instead of the standard form if the current 
//                                        warning is the only one in the list.
//                                        For example, "DataProcessor.Files.FilesToEdit".
//      * ApplicationWarningFormParameters - Structure - an arbitrary structure of
//                                                 parameters for the form described above.
//      * WindowOpeningMode - FormWindowOpeningMode - a mode of opening the Form or ApplicationWarningForm forms.
// 
Function WarningOnExit() Export
	
	ActionIfFlagSet = New Structure;
	ActionIfFlagSet.Insert("Form", "");
	ActionIfFlagSet.Insert("FormParameters", Undefined);
	
	ActionOnClickHyperlink = New Structure;
	ActionOnClickHyperlink.Insert("Form", "");
	ActionOnClickHyperlink.Insert("FormParameters", Undefined);
	ActionOnClickHyperlink.Insert("ApplicationWarningForm", "");
	ActionOnClickHyperlink.Insert("ApplicationWarningFormParameters", Undefined);
	ActionOnClickHyperlink.Insert("WindowOpeningMode", Undefined);
	
	WarningParameters = New Structure;
	WarningParameters.Insert("CheckBoxText", "");
	WarningParameters.Insert("NoteText", "");
	WarningParameters.Insert("WarningText", "");
	WarningParameters.Insert("ExtendedTooltip", "");
	WarningParameters.Insert("HyperlinkText", "");
	WarningParameters.Insert("ActionIfFlagSet", ActionIfFlagSet);
	WarningParameters.Insert("ActionOnClickHyperlink", ActionOnClickHyperlink);
	WarningParameters.Insert("Priority", 0);
	WarningParameters.Insert("OutputSingleWarning", False);
	
	Return WarningParameters;
	
EndFunction

// Returns the values of parameters required for the operation of the client code
// when starting configuration for one server call (to minimize client-server interaction
// and reduce startup time). 
// Using this function, you can access parameters in client code called from the event handlers:
// - ПередНачаломРаботыСистемы,
// - OnStart.
//
// In these handlers, when starting the application, do not use cache reset commands
// of modules that reuse return values because this can lead to
// unpredictable errors and unneeded server calls.
// 
// Returns:
//   FixedStructure -  
//                            
//
//
Function ClientParametersOnStart() Export
	
	Return StandardSubsystemsClientCached.ClientParametersOnStart();
	
EndFunction

// Returns parameters values required for the operation of the client code configuration
// without additional server calls.
// 
// Returns:
//   FixedStructure - 
//                            
//
Function ClientRunParameters() Export
	
	Return StandardSubsystemsClientCached.ClientRunParameters();
	
EndFunction

#EndRegion

#Region ForCallsFromOtherSubsystems

// 
// 
// 
// 
// Parameters:
//  NameOfAlert - See ServerNotifications.SendServerNotification.NameOfAlert
//  Result     - See ServerNotifications.SendServerNotification.Result
//
// Example:
//	
//		
//	
//	
//		
//	
//		
//	
//
Procedure OnReceiptServerNotification(NameOfAlert, Result) Export
	
	If NameOfAlert = "StandardSubsystems.Core.FunctionalOptionsModified" Then
		DetachIdleHandler("RefreshInterfaceOnFunctionalOptionToggle");
		AttachIdleHandler("RefreshInterfaceOnFunctionalOptionToggle", 5*60, True);
		
	ElsIf NameOfAlert = "StandardSubsystems.Core.CachedValuesOutdated" Then
		RefreshReusableValues();
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region Internal

Function ApplicationStartCompleted() Export
	
	ParameterName = "StandardSubsystems.ApplicationStartCompleted";
	If ApplicationParameters[ParameterName] = True Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Function ClientParameter(ParameterName = Undefined) Export
	
	GlobalParameterName = "StandardSubsystems.ClientParameters";
	ClientParameters = ApplicationParameters[GlobalParameterName];
	
	If ClientParameters = Undefined Then
		// 
		StandardSubsystemsClientCached.ClientParametersOnStart();
		ClientParameters = ApplicationParameters[GlobalParameterName];
	EndIf;
	
	If ParameterName = Undefined Then
		Return ClientParameters;
	Else
		Return ClientParameters[ParameterName];
	EndIf;
	
EndFunction

Procedure SetClientParameter(ParameterName, Value) Export
	GlobalParameterName = "StandardSubsystems.ClientParameters";
	ApplicationParameters[GlobalParameterName].Insert(ParameterName, Value);
EndProcedure

Procedure FillClientParameters(ClientParameters) Export
	
	ParameterName = "StandardSubsystems.ClientParameters";
	If TypeOf(ApplicationParameters[ParameterName]) <> Type("Structure") Then
		ApplicationParameters[ParameterName] = New Structure;
		ApplicationParameters[ParameterName].Insert("DataSeparationEnabled");
		ApplicationParameters[ParameterName].Insert("FileInfobase");
		ApplicationParameters[ParameterName].Insert("IsBaseConfigurationVersion");
		ApplicationParameters[ParameterName].Insert("IsTrainingPlatform");
		ApplicationParameters[ParameterName].Insert("IsExternalUserSession");
		ApplicationParameters[ParameterName].Insert("IsFullUser");
		ApplicationParameters[ParameterName].Insert("IsSystemAdministrator");
		ApplicationParameters[ParameterName].Insert("AuthorizedUser");
		ApplicationParameters[ParameterName].Insert("AskConfirmationOnExit");
		ApplicationParameters[ParameterName].Insert("SeparatedDataUsageAvailable");
		ApplicationParameters[ParameterName].Insert("StandaloneModeParameters");
		ApplicationParameters[ParameterName].Insert("PersonalFilesOperationsSettings");
		ApplicationParameters[ParameterName].Insert("LockedFilesCount");
		ApplicationParameters[ParameterName].Insert("IBBackupOnExit");
		ApplicationParameters[ParameterName].Insert("DisplayPermissionSetupAssistant");
		ApplicationParameters[ParameterName].Insert("SessionTimeOffset");
		ApplicationParameters[ParameterName].Insert("UniversalTimeCorrection");
		ApplicationParameters[ParameterName].Insert("StandardTimeOffset");
		ApplicationParameters[ParameterName].Insert("ClientDateOffset");
		ApplicationParameters[ParameterName].Insert("DefaultLanguageCode");
	EndIf;
	If Not ApplicationParameters[ParameterName].Property("PerformanceMonitor")
	   And ClientParameters.Property("PerformanceMonitor") Then
		ApplicationParameters[ParameterName].Insert("PerformanceMonitor");
	EndIf;
	
	FillPropertyValues(ApplicationParameters[ParameterName], ClientParameters);
	
EndProcedure

// After the warning, calls the procedure with the following parameters: Result, AdditionalParameters.
//
// Parameters:
//  Parameters           - Structure - containing the property:
//                          ContinuationHandler - NotifyDescription - that
//                          contains a procedure with two parameters:
//                            Result, AdditionalParameters.
//
//  WarningDetails - Undefined - warning is not required.
//  WarningDetails - String - a warning text that should be shown.
//  WarningDetails - Structure:
//       * WarningText - String - a warning text that should be shown.
//       * Buttons              - ValueList - for the ShowQuestionToUser procedure.
//       * QuestionParameters    - Structure - contains a subset of the properties
//                                 to be overridden from among ones that
//                                 returned by the QuestionToUserParameters function.
//
Procedure ShowMessageBoxAndContinue(Parameters, WarningDetails) Export
	
	NotificationWithResult = Parameters.ContinuationHandler;
	
	If WarningDetails = Undefined Then
		ExecuteNotifyProcessing(NotificationWithResult);
		Return;
	EndIf;
	
	Buttons = New ValueList;
	QuestionParameters = QuestionToUserParameters();
	QuestionParameters.PromptDontAskAgain = False;
	QuestionParameters.LockWholeInterface = True;
	QuestionParameters.Picture = PictureLib.Warning32;
	
	If Parameters.Cancel Then
		Buttons.Add("ExitApp", NStr("en = 'End session';"));
		QuestionParameters.DefaultButton = "ExitApp";
	Else
		Buttons.Add("Continue", NStr("en = 'Continue';"));
		Buttons.Add("ExitApp",  NStr("en = 'End session';"));
		QuestionParameters.DefaultButton = "Continue";
	EndIf;
	
	If TypeOf(WarningDetails) = Type("Structure") Then
		WarningText = WarningDetails.WarningText;
		Buttons = WarningDetails.Buttons;
		FillPropertyValues(QuestionParameters, WarningDetails.QuestionParameters);
	Else
		WarningText = WarningDetails;
	EndIf;
	
	ClosingNotification1 = New NotifyDescription("ShowMessageBoxAndContinueCompletion", ThisObject, Parameters);
	ShowQuestionToUser(ClosingNotification1, WarningText, Buttons, QuestionParameters);
	
EndProcedure

// Returns a name of the executable file depending on the client type.
//
// Returns:
//  String
//
Function ApplicationExecutableFileName(GetDesignerFileName = False) Export
	
	FileNameTemplate = "1cv8[TrainingPlatform].exe";
	
#If ThinClient Then
	If Not GetDesignerFileName Then
		FileNameTemplate = "1cv8c[TrainingPlatform].exe";
	EndIf;	
#EndIf
	
	Return StrReplace(FileNameTemplate, "[TrainingPlatform]", ?(IsTrainingPlatform(), "t", ""));
	
EndFunction

// Sets or cancels managed form reference storing in a global variable.
// Required when a reference to a form is passed through AdditionalParameters
// in the NotifyDescription object that does not lock the release of a closed form.
//
Procedure SetFormStorageOption(Form, Location) Export
	
	Store = ApplicationParameters["StandardSubsystems.TemporaryManagedFormsRefStorage"];
	If Store = Undefined Then
		Store = New Map;
		ApplicationParameters.Insert("StandardSubsystems.TemporaryManagedFormsRefStorage", Store);
	EndIf;
	
	If Location Then
		Store.Insert(Form, New Structure("Form", Form));
	ElsIf Store.Get(Form) <> Undefined Then
		Store.Delete(Form);
	EndIf;
	
EndProcedure

// Checks that the current data is not defined and not a group.
// Intended for dynamic list form table handlers.
//
// Parameters:
//  TableOrCurrentData - FormTable - a dynamic list form table to check the current data.
//                          - Undefined
//                          - FormDataStructure
//                          - Structure - 
//
// Returns:
//  Boolean
//
Function IsDynamicListItem(TableOrCurrentData) Export
	
	If TypeOf(TableOrCurrentData) = Type("FormTable") Then
		CurrentData = TableOrCurrentData.CurrentData;
	Else
		CurrentData = TableOrCurrentData;
	EndIf;
	
	If TypeOf(CurrentData) <> Type("FormDataStructure")
	   And TypeOf(CurrentData) <> Type("Structure") Then
		Return False;
	EndIf;
	
	If CurrentData.Property("RowGroup") Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Checks whether startup procedures are unsafe disabled for the purposes of automated tests.
//
// Returns:
//  Boolean
//
Function ApplicationStartupLogicDisabled() Export
	Return StrFind(LaunchParameter, "DisableSystemStartupLogic") > 0;
EndFunction

// 
//
// Returns:
//  Structure:
//   * Key - String -
//   * Value - MetadataObjectStyleItem
//
Function StyleItems() Export
	
	StyleItems = New Structure;
	
	ClientRunParameters = ClientRunParameters();
	For Each StyleItem In ClientRunParameters.StyleItems Do
#If ThickClientOrdinaryApplication Then
		StyleItems.Insert(StyleItem.Key, StyleItem.Value.Get());
#Else
		StyleItems.Insert(StyleItem.Key, StyleItem.Value);
#EndIf
	EndDo;
	
	Return StyleItems;
	
EndFunction

// Modifies the notification without result to the notification with result
//
// Returns:
//  NotifyDescription
//
Function NotificationWithoutResult(NotificationWithResult) Export
	
	Return New NotifyDescription("NotifyWithEmptyResult", ThisObject, NotificationWithResult);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// 

// See SSLSubsystemsIntegrationClient.BeforeRecurringClientDataSendToServer
Procedure BeforeRecurringClientDataSendToServer(Parameters) Export
	
	ParameterName = "StandardSubsystems.Core.DynamicUpdateControl";
	If Not ServerNotificationsClient.TimeoutExpired(ParameterName) Then
		Return;
	EndIf;
	
	// ИзмененаКонфигурацияИлиРасширения
	Parameters.Insert(ParameterName, True);
	
EndProcedure

// See CommonClientOverridable.AfterRecurringReceiptOfClientDataOnServer
Procedure AfterRecurringReceiptOfClientDataOnServer(Results) Export
	
	ParameterName = "StandardSubsystems.Core.DynamicUpdateControl";
	Result = Results.Get(ParameterName);
	If Result = Undefined Then
		Return;
	EndIf;
	
	// ConfigurationOrExtensionsWasModified
	ShowUserNotification(
		NStr("en = 'Application update is installed';"),
		"e1cib/app/CommonForm.DynamicUpdateControl",
		Result, PictureLib.Warning32,
		UserNotificationStatus.Important,
		"TheProgramUpdateIsInstalled");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Display runtime result.

// Expands nodes of the specified tree on the form.
//
// Parameters:
//   Form                     - ClientApplicationForm - a form where the control item with a value tree is placed.
//   FormItemName          - String           - a name of the item with a form table (value tree) and the associated with it
//                                                  form attribute (should match).
//   TreeRowID - Arbitrary     - an ID of the tree row to be expanded.
//                                                  If "*" is passed, only top-level nodes are expanded.
//                                                  If Undefined is passed, tree rows are not expanded.
//                                                  By default: "*".
//   ExpandWithSubordinates   - Boolean           - If True, all subordinate nodes should also be expanded.
//                                                  Default value is False.
//
Procedure ExpandTreeNodes(Form, FormItemName, TreeRowID = "*", ExpandWithSubordinates = False) Export
	
	TableItem = Form.Items[FormItemName];
	If TreeRowID = "*" Then
		Nodes = Form[FormItemName].GetItems();
		For Each Node In Nodes Do
			TableItem.Expand(Node.GetID(), ExpandWithSubordinates);
		EndDo;
	Else
		TableItem.Expand(TreeRowID, ExpandWithSubordinates);
	EndIf;
	
EndProcedure

// Notifies the forms opening and dynamic lists about mass changes in objects of various types,
// using Notify and NotifyChange global context methods.
//
// Parameters:
//  ModifiedObjectTypes - See StandardSubsystemsServer.PrepareFormChangeNotification
//  FormNotificationParameter - Arbitrary - a message parameter for the Notify method.
//
Procedure NotifyFormsAboutChange(ModifiedObjectTypes, FormNotificationParameter = Undefined) Export
	
	For Each ObjectType In ModifiedObjectTypes Do
		Notify(ObjectType.Value.EventName, 
			?(FormNotificationParameter <> Undefined, FormNotificationParameter, New Structure), 
			ObjectType.Value.EmptyRef);
		NotifyChanged(ObjectType.Key);
	EndDo;
	
EndProcedure

// Opens the object list form with positioning on the object.
//
// Parameters:
//   Ref - AnyRef - an object to be shown in the list.
//   ListFormName - String - a list form name.
//       If Undefined the transfer will automatically defined requires Server call).
//   FormParameters - Structure - additional list form opening parameters.
//
Procedure ShowInList(Ref, ListFormName, FormParameters = Undefined) Export
	If Ref = Undefined Then
		Return;
	EndIf;
	
	If ListFormName = Undefined Then
		FullName = StandardSubsystemsServerCall.FullMetadataObjectName(TypeOf(Ref));
		If FullName = Undefined Then
			Return;
		EndIf;
		ListFormName = FullName + ".ListForm";
	EndIf;
	
	If FormParameters = Undefined Then
		FormParameters = New Structure;
	EndIf;
	
	FormParameters.Insert("CurrentRow", Ref);
	
	Form = GetForm(ListFormName, FormParameters, , True);
	Form.Open();
	Form.ExecuteNavigation(Ref);
EndProcedure

// Displays the text, which users can copy.
//
// Parameters:
//   Handler - NotifyDescription - description of the procedure to be called after showing the message.
//       Returns a value like ShowQuestionToUser().
//   Text     - String - an information text.
//   Title - String - window title. "Details" by default.
//
Procedure ShowDetailedInfo(Handler, Text, Title = Undefined) Export
	DialogSettings = New Structure;
	DialogSettings.Insert("PromptDontAskAgain", False);
	DialogSettings.Insert("Picture", Undefined);
	DialogSettings.Insert("ShowPicture", False);
	DialogSettings.Insert("CanCopy", True);
	DialogSettings.Insert("DefaultButton", 0);
	DialogSettings.Insert("HighlightDefaultButton", False);
	DialogSettings.Insert("Title", Title);
	
	If Not ValueIsFilled(DialogSettings.Title) Then
		DialogSettings.Title = NStr("en = 'Details';");
	EndIf;
	
	Buttons = New ValueList;
	Buttons.Add(0, NStr("en = 'Close';"));
	
	ShowQuestionToUser(Handler, Text, Buttons, DialogSettings);
EndProcedure

// The file header for technical support.
//
// Returns:
//  String
//
Function SupportInformation() Export
	
	Text = NStr("en = 'Application name: [ApplicationName1] 
	                   |Application version: [ApplicationVersion]
	                   |1C:Enterprise platform version: [PlatformVersion][PlatformBitness]
	                   |Standard Subsystems Library version: [SSLVersion]
	                   |Operating system: [OperatingSystem]
	                   |RAM: [RAM]
	                   |COM connector: [COMConnectorName]
	                   |Base configuration: [IsBaseConfigurationVersion]
	                   |Full user: [IsFullUser]
	                   |Training platform: [IsTrainingPlatform]
	                   |Configuration changed: [ConfigurationChanged]';") + Chars.LF;
	
	Parameters = ?(ApplicationStartCompleted(), ClientRunParameters(), ClientParametersOnStart());
	SystemInfo = New SystemInfo;
	TextUnavailable = NStr("en = 'unavailable';");
	
	Text = StrReplace(Text, "[ApplicationName1]", 
		?(Parameters.Property("DetailedInformation"), Parameters.DetailedInformation, TextUnavailable));
	Text = StrReplace(Text, "[ApplicationVersion]", 
		?(Parameters.Property("ConfigurationVersion"), Parameters.ConfigurationVersion, TextUnavailable));
	Text = StrReplace(Text, "[PlatformVersion]", SystemInfo.AppVersion);
	Text = StrReplace(Text, "[PlatformBitness]", SystemInfo.PlatformType);
	Text = StrReplace(Text, "[SSLVersion]", StandardSubsystemsServerCall.LibraryVersion());
	Text = StrReplace(Text, "[OperatingSystem]", SystemInfo.OSVersion);
	Text = StrReplace(Text, "[RAM]", SystemInfo.RAM);
	Text = StrReplace(Text, "[COMConnectorName]", CommonClientServer.COMConnectorName());
	Text = StrReplace(Text, "[IsBaseConfigurationVersion]", IsBaseConfigurationVersion());
	Text = StrReplace(Text, "[IsFullUser]", UsersClient.IsFullUser());
	Text = StrReplace(Text, "[IsTrainingPlatform]", IsTrainingPlatform());
	Text = StrReplace(Text, "[ConfigurationChanged]", 
		?(Parameters.Property("SettingsOfUpdate"), Parameters.SettingsOfUpdate.ConfigurationChanged, TextUnavailable));
	
	Return Text;
	
EndFunction

#If Not WebClient And Not MobileClient Then

// System application directory, for example "C:\Windows\System32".
// It is used only in Windows OS.
//
// Returns:
//  String
//
Function SystemApplicationsDirectory() Export
	
	ShellObject = New COMObject("Shell.Application");
	
	SystemInfo = New SystemInfo;
	If SystemInfo.PlatformType = PlatformType.Windows_x86 Then 
		// 
		// 
		FolderObject = ShellObject.Namespace(41);
	ElsIf SystemInfo.PlatformType = PlatformType.Windows_x86_64 Then 
		// 
		FolderObject = ShellObject.Namespace(37);
	EndIf;
	
	Return FolderObject.Self.Path + "\";
	
EndFunction

#EndIf

// 
// 
// 
// 
// 
// Parameters:
//  Notification - NotifyDescription -
//  Result  - Arbitrary -
//               
//
Procedure StartProcessingNotification(Notification, Result = Undefined) Export
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	Context.Insert("Result", Result);
	
	Stream = New MemoryStream;
	Stream.BeginGetSize(New NotifyDescription(
		"StartProcessingNotificationCompletion", ThisObject, Context));
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// BeforeStart

// 
Procedure ActionsBeforeStart(CompletionNotification)
	
	Parameters = ProcessingParametersBeforeStartSystem();
	
	// 
	Parameters.Insert("Cancel", False);
	Parameters.Insert("Restart", False);
	Parameters.Insert("AdditionalParametersOfCommandLine", "");
	
	// 
	Parameters.Insert("InteractiveHandler", Undefined); // NotifyDescription
	Parameters.Insert("ContinuationHandler",   Undefined); // NotifyDescription
	Parameters.Insert("ContinuousExecution", True);
	Parameters.Insert("RetrievedClientParameters", New Structure);
	Parameters.Insert("ModuleOfLastProcedure", "");
	Parameters.Insert("NameOfLastProcedure", "");
	InstallLatestProcedure(Parameters, "StandardSubsystemsClient", "BeforeStart");
	
	// 
	Parameters.Insert("CompletionNotification", CompletionNotification);
	Parameters.Insert("CompletionProcessing", New NotifyDescription(
		"ActionsBeforeStartCompletionHandler", ThisObject));
	
	UpdateClientParameters(Parameters, True, CompletionNotification <> Undefined);
	
	// 
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsBeforeStartInIntegrationProcedure", ThisObject));
	
	If ApplicationStartupLogicDisabled() Then
		Try
			// Check the right to disable the startup logic. Specify server parameters.
			ClientProperties = New Structure;
			FillInTheClientParametersOnTheServer(ClientProperties);
			StandardSubsystemsServerCall.CheckDisableStartupLogicRight(ClientProperties);
			If ClientProperties.Property("ErrorThereIsNoRightToDisableTheSystemStartupLogic") Then
				UsersInternalClient.InstallInteractiveDataProcessorOnInsufficientRightsToSignInError(
					Parameters, ClientProperties.ErrorThereIsNoRightToDisableTheSystemStartupLogic);
			EndIf;
		Except
			ErrorText = ErrorProcessing.DetailErrorDescription(ErrorInfo());
			StandardSubsystemsServerCall.WriteErrorToEventLogOnStartOrExit(
				False, "Run", ErrorText);
			UsersInternalClient.InstallInteractiveDataProcessorOnInsufficientRightsToSignInError(
				Parameters, ErrorText);
		EndTry;
		If BeforeStartInteractiveHandler(Parameters) Then
			Return;
		EndIf;
		HideDesktopOnStart(True, True);
		Return;
	EndIf;
	
	// 
	// 
	Try
		CommonClient.SubsystemExists("StandardSubsystems.Core");
	Except
		HandleErrorBeforeStart(Parameters, ErrorInfo(), True);
	EndTry;
	If BeforeStartInteractiveHandler(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. Continues the execution of BeforeStart procedure.
Procedure ActionsBeforeStartInIntegrationProcedure(NotDefined, Context) Export
	
	Parameters = ProcessingParametersBeforeStartSystem();
	InstallLatestProcedure(Parameters, "StandardSubsystemsClient",
		"ActionsBeforeStartInIntegrationProcedure");
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsBeforeStartInIntegrationProcedureModules", ThisObject));
	
	Parameters.Insert("CurrentModuleIndex", 0);
	Parameters.Insert("AddedModules", New Array);
	Try
		Parameters.Insert("Modules", New Array);
		SSLSubsystemsIntegrationClient.BeforeStart(Parameters);
		Parameters.Insert("AddedModules", Parameters.Modules);
		Parameters.Delete("Modules");
	Except
		HandleErrorBeforeStart(Parameters, ErrorInfo(), True);
	EndTry;
	If BeforeStartInteractiveHandler(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. Continues the execution of BeforeStart procedure.
Procedure ActionsBeforeStartInIntegrationProcedureModules(NotDefined, Context) Export
	
	While True Do
		
		Parameters = ProcessingParametersBeforeStartSystem();
		InstallLatestProcedure(Parameters, "StandardSubsystemsClient",
			"ActionsBeforeStartInIntegrationProcedureModules");
		
		If Not ContinueActionsBeforeStart(Parameters) Then
			Return;
		EndIf;
		
		If Parameters.CurrentModuleIndex >= Parameters.AddedModules.Count() Then
			ActionsBeforeStartInOverridableProcedure(Undefined, Undefined);
			Return;
		EndIf;
	
		ModuleDetails = Parameters.AddedModules[Parameters.CurrentModuleIndex];
		Parameters.CurrentModuleIndex = Parameters.CurrentModuleIndex + 1;
		
		Try
			If TypeOf(ModuleDetails) <> Type("Structure") Then
				CurrentModule = ModuleDetails;
				CurrentModule.BeforeStart(Parameters);
			Else
				CurrentModule = ModuleDetails.Module;
				If ModuleDetails.Number = 2 Then
					CurrentModule.BeforeStart2(Parameters);
				ElsIf ModuleDetails.Number = 3 Then
					CurrentModule.BeforeStart3(Parameters);
				ElsIf ModuleDetails.Number = 4 Then
					CurrentModule.BeforeStart4(Parameters);
				ElsIf ModuleDetails.Number = 5 Then
					CurrentModule.BeforeStart5(Parameters);
				EndIf;
			EndIf;
		Except
			HandleErrorBeforeStart(Parameters, ErrorInfo(), True);
		EndTry;
		If BeforeStartInteractiveHandler(Parameters) Then
			Return;
		EndIf;
		
	EndDo;
	
EndProcedure

// For internal use only. Continues the execution of BeforeStart procedure.
Procedure ActionsBeforeStartInOverridableProcedure(NotDefined, Context)
	
	Parameters = ProcessingParametersBeforeStartSystem();
	InstallLatestProcedure(Parameters, "StandardSubsystemsClient",
		"ActionsBeforeStartInOverridableProcedure");
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsBeforeStartInOverridableProcedureModules", ThisObject));
	
	Parameters.InteractiveHandler = Undefined;
	
	Parameters.Insert("CurrentModuleIndex", 0);
	Parameters.Insert("AddedModules", New Array);
	
	If CommonClient.SeparatedDataUsageAvailable() Then
		Try
			Parameters.Insert("Modules", New Array);
			CommonClientOverridable.BeforeStart(Parameters);
			Parameters.Insert("AddedModules", Parameters.Modules);
			Parameters.Delete("Modules");
		Except
			HandleErrorBeforeStart(Parameters, ErrorInfo());
		EndTry;
		If BeforeStartInteractiveHandler(Parameters) Then
			Return;
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. Continues the execution of BeforeStart procedure.
Procedure ActionsBeforeStartInOverridableProcedureModules(NotDefined, Context) Export
	
	While True Do
		
		Parameters = ProcessingParametersBeforeStartSystem();
		InstallLatestProcedure(Parameters, "StandardSubsystemsClient",
			"ActionsBeforeStartInOverridableProcedureModules");
		
		If Not ContinueActionsBeforeStart(Parameters) Then
			Return;
		EndIf;
		
		If Parameters.CurrentModuleIndex >= Parameters.AddedModules.Count() Then
			ActionsBeforeStartAfterAllProcedures(Undefined, Undefined);
			Return;
		EndIf;
		
		CurrentModule = Parameters.AddedModules[Parameters.CurrentModuleIndex];
		Parameters.CurrentModuleIndex = Parameters.CurrentModuleIndex + 1;
		
		Try
			CurrentModule.BeforeStart(Parameters);
		Except
			HandleErrorBeforeStart(Parameters, ErrorInfo());
		EndTry;
		If BeforeStartInteractiveHandler(Parameters) Then
			Return;
		EndIf;
		
	EndDo;
	
EndProcedure

// For internal use only. Continues the execution of BeforeStart procedure.
Procedure ActionsBeforeStartAfterAllProcedures(NotDefined, Context)
	
	Parameters = ProcessingParametersBeforeStartSystem();
	InstallLatestProcedure(Parameters, "StandardSubsystemsClient",
		"ActionsBeforeStartAfterAllProcedures");
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationHandler", Parameters.CompletionProcessing);
	
	Try
		SetInterfaceFunctionalOptionParametersOnStart();
	Except
		HandleErrorBeforeStart(Parameters, ErrorInfo(), True);
	EndTry;
	If BeforeStartInteractiveHandler(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. The BeforeStart procedure completion.
Procedure ActionsBeforeStartCompletionHandler(NotDefined, Context) Export
	
	Parameters = ProcessingParametersBeforeStartSystem(True);
	
	Parameters.ContinuationHandler = Undefined;
	Parameters.CompletionProcessing  = Undefined;
	
	ApplicationStartParameters = ApplicationParameters["StandardSubsystems.ApplicationStartParameters"];
	ApplicationStartParameters.Delete("RetrievedClientParameters");
	ApplicationParameters["StandardSubsystems.ApplicationStartCompleted"] = True;
	
	If Parameters.CompletionNotification <> Undefined Then
		Result = New Structure;
		Result.Insert("Cancel", Parameters.Cancel);
		Result.Insert("Restart", Parameters.Restart);
		Result.Insert("AdditionalParametersOfCommandLine", Parameters.AdditionalParametersOfCommandLine);
		ExecuteNotifyProcessing(Parameters.CompletionNotification, Result);
		Return;
	EndIf;
	
	If Parameters.Cancel Then
		If Parameters.Restart <> True Then
			Terminate();
		ElsIf ValueIsFilled(Parameters.AdditionalParametersOfCommandLine) Then
			Terminate(Parameters.Restart, Parameters.AdditionalParametersOfCommandLine);
		Else
			Terminate(Parameters.Restart);
		EndIf;
		
	ElsIf Not Parameters.ContinuousExecution Then
		If ApplicationStartParameters.Property("ProcessingParameters") Then
			ApplicationStartParameters.Delete("ProcessingParameters");
		EndIf;
		AttachIdleHandler("OnStartIdleHandler", 0.1, True);
	EndIf;
	
EndProcedure

// For internal use only.
Function ProcessingParametersBeforeStartSystem(Delete = False)
	
	ParameterName = "StandardSubsystems.ApplicationStartParameters";
	Properties = ApplicationParameters[ParameterName];
	If Properties = Undefined Then
		Properties = New Structure;
		ApplicationParameters.Insert(ParameterName, Properties);
	EndIf;
	
	PropertyName = "ProcessingParametersBeforeStartSystem";
	If Properties.Property(PropertyName) Then
		Parameters = Properties[PropertyName];
	Else
		Parameters = New Structure;
		Properties.Insert(PropertyName, Parameters);
	EndIf;
	
	If Delete Then
		Properties.Delete(PropertyName);
	EndIf;
	
	Return Parameters;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// OnAppStart

// 
Procedure ActionsOnStart(CompletionNotification, ContinuousExecution)
	
	Parameters = ProcessingParametersOnStartSystem();
	
	// 
	Parameters.Insert("Cancel", False);
	Parameters.Insert("Restart", False);
	Parameters.Insert("AdditionalParametersOfCommandLine", "");
	
	// 
	Parameters.Insert("InteractiveHandler", Undefined); // NotifyDescription
	Parameters.Insert("ContinuationHandler",   Undefined); // NotifyDescription
	Parameters.Insert("ContinuousExecution", ContinuousExecution);
	
	// 
	Parameters.Insert("CompletionNotification", CompletionNotification);
	Parameters.Insert("CompletionProcessing", New NotifyDescription(
		"ActionsOnStartCompletionHandler", ThisObject));
	
	// 
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsOnStartInIntegrationProcedure", ThisObject));
	
	If Not ApplicationStartCompleted() Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An unexpected error occurred during the application startup.
			           |
			           |Technical details:
			           |Invalid call %1 during the application startup. First, you need to complete the %2 procedure.
			           |One of the event handlers might have not called the notification to continue.
			           |The last called procedure is %3.';"),
			"StandardSubsystemsClient.OnStart",
			"StandardSubsystemsClient.BeforeStart",
			FullNameOfLastProcedureBeforeStartingSystem());
		Try
			Raise ErrorText;
		Except
			HandleErrorOnStart(Parameters, ErrorInfo(), True);
		EndTry;
		If OnStartInteractiveHandler(Parameters) Then
			Return;
		EndIf;
	EndIf;
	
	Try
		SetAdvancedApplicationCaption(True); // 
		
		If Not ProcessStartParameters() Then
			Parameters.Cancel = True;
			ExecuteNotifyProcessing(Parameters.CompletionProcessing);
			Return;
		EndIf;
	Except
		HandleErrorOnStart(Parameters, ErrorInfo(), True);
	EndTry;
	If OnStartInteractiveHandler(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. Continues the execution of OnStart procedure.
Procedure ActionsOnStartInIntegrationProcedure(NotDefined, Context) Export
	
	Parameters = ProcessingParametersOnStartSystem();
	
	If Not ContinueActionsOnStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsOnStartInIntegrationProcedureModules", ThisObject));
	
	Parameters.Insert("CurrentModuleIndex", 0);
	Parameters.Insert("AddedModules", New Array);
	Try
		Parameters.Insert("Modules", New Array);
		SSLSubsystemsIntegrationClient.OnStart(Parameters);
		Parameters.Insert("AddedModules", Parameters.Modules);
		Parameters.Delete("Modules");
	Except
		HandleErrorOnStart(Parameters, ErrorInfo());
	EndTry;
	If OnStartInteractiveHandler(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. Continues the execution of OnStart procedure.
Procedure ActionsOnStartInIntegrationProcedureModules(NotDefined, Context) Export
	
	While True Do
		Parameters = ProcessingParametersOnStartSystem();
		
		If Not ContinueActionsOnStart(Parameters) Then
			Return;
		EndIf;
		
		If Parameters.CurrentModuleIndex >= Parameters.AddedModules.Count() Then
			ActionsOnStartInOverridableProcedure(Undefined, Undefined);
			Return;
		EndIf;
		
		ModuleDetails = Parameters.AddedModules[Parameters.CurrentModuleIndex];
		Parameters.CurrentModuleIndex = Parameters.CurrentModuleIndex + 1;
		
		Try
			If TypeOf(ModuleDetails) <> Type("Structure") Then
				CurrentModule = ModuleDetails;
				CurrentModule.OnStart(Parameters);
			Else
				CurrentModule = ModuleDetails.Module;
				If ModuleDetails.Number = 2 Then
					CurrentModule.OnStart2(Parameters);
				ElsIf ModuleDetails.Number = 3 Then
					CurrentModule.OnStart3(Parameters);
				ElsIf ModuleDetails.Number = 4 Then
					CurrentModule.OnStart4(Parameters);
				EndIf;
			EndIf;
		Except
			HandleErrorOnStart(Parameters, ErrorInfo());
		EndTry;
		If OnStartInteractiveHandler(Parameters) Then
			Return;
		EndIf;
		
	EndDo;
	
EndProcedure

// For internal use only. Continues the execution of OnStart procedure.
Procedure ActionsOnStartInOverridableProcedure(NotDefined, Context)
	
	Parameters = ProcessingParametersOnStartSystem();
	
	If Not ContinueActionsOnStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsOnStartInOverridableProcedureModules", ThisObject));
	
	Parameters.Insert("CurrentModuleIndex", 0);
	Parameters.Insert("AddedModules", New Array);
	Try
		Parameters.Insert("Modules", New Array);
		CommonClientOverridable.OnStart(Parameters);
		Parameters.Insert("AddedModules", Parameters.Modules);
		Parameters.Delete("Modules");
	Except
		HandleErrorOnStart(Parameters, ErrorInfo());
	EndTry;
	If OnStartInteractiveHandler(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. Continues the execution of OnStart procedure.
Procedure ActionsOnStartInOverridableProcedureModules(NotDefined, Context) Export
	
	While True Do
		
		Parameters = ProcessingParametersOnStartSystem();
		
		If Not ContinueActionsOnStart(Parameters) Then
			Return;
		EndIf;
		
		If Parameters.CurrentModuleIndex >= Parameters.AddedModules.Count() Then
			ActionsOnStartAfterAllProcedures(Undefined, Undefined);
			Return;
		EndIf;
		
		CurrentModule = Parameters.AddedModules[Parameters.CurrentModuleIndex];
		Parameters.CurrentModuleIndex = Parameters.CurrentModuleIndex + 1;
		
		Try
			CurrentModule.OnStart(Parameters);
		Except
			HandleErrorOnStart(Parameters, ErrorInfo());
		EndTry;
		If OnStartInteractiveHandler(Parameters) Then
			Return;
		EndIf;
		
	EndDo;
	
EndProcedure

// For internal use only. Continues the execution of OnStart procedure.
Procedure ActionsOnStartAfterAllProcedures(NotDefined, Context)
	
	Parameters = ProcessingParametersOnStartSystem();
	
	If Not ContinueActionsOnStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationHandler", Parameters.CompletionProcessing);
	
	Try
		SSLSubsystemsIntegrationClient.AfterStart();
		CommonClientOverridable.AfterStart();
	Except
		HandleErrorOnStart(Parameters, ErrorInfo());
	EndTry;
	If OnStartInteractiveHandler(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. The OnStart procedure completion.
Procedure ActionsOnStartCompletionHandler(NotDefined, Context) Export
	
	Parameters = ProcessingParametersOnStartSystem(True);
	
	Parameters.ContinuationHandler = Undefined;
	Parameters.CompletionProcessing  = Undefined;
	
	If Not Parameters.Cancel Then
		ApplicationStartParameters = ApplicationParameters["StandardSubsystems.ApplicationStartParameters"];
		If ApplicationStartParameters.Property("SkipClearingDesktopHiding") Then
			ApplicationStartParameters.Delete("SkipClearingDesktopHiding");
		EndIf;
		HideDesktopOnStart(False);
	EndIf;
	
	If Parameters.CompletionNotification <> Undefined Then
		
		Result = New Structure;
		Result.Insert("Cancel", Parameters.Cancel);
		Result.Insert("Restart", Parameters.Restart);
		Result.Insert("AdditionalParametersOfCommandLine", Parameters.AdditionalParametersOfCommandLine);
		ExecuteNotifyProcessing(Parameters.CompletionNotification, Result);
		Return;
		
	Else
		If Parameters.Cancel Then
			If Parameters.Restart <> True Then
				Terminate();
				
			ElsIf ValueIsFilled(Parameters.AdditionalParametersOfCommandLine) Then
				Terminate(Parameters.Restart, Parameters.AdditionalParametersOfCommandLine);
			Else
				Terminate(Parameters.Restart);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// For internal use only.
Function ProcessingParametersOnStartSystem(Delete = False)
	
	ParameterName = "StandardSubsystems.ApplicationStartParameters";
	Properties = ApplicationParameters[ParameterName];
	If Properties = Undefined Then
		Properties = New Structure;
		ApplicationParameters.Insert(ParameterName, Properties);
	EndIf;
	
	PropertyName = "ProcessingParametersOnStartSystem";
	If Properties.Property(PropertyName) Then
		Parameters = Properties[PropertyName];
	Else
		Parameters = New Structure;
		Properties.Insert(PropertyName, Parameters);
	EndIf;
	
	If Delete Then
		Properties.Delete(PropertyName);
	EndIf;
	
	Return Parameters;
	
EndFunction

// Processes the application start parameters.
//
// Returns:
//   Boolean   - 
//
Function ProcessStartParameters()

	If IsBlankString(LaunchParameter) Then
		Return True;
	EndIf;
	
	// The parameter can be separated with the semicolons symbol (;).
	StartupParameters = StrSplit(LaunchParameter, ";", False);
	
	Cancel = False;
	SSLSubsystemsIntegrationClient.LaunchParametersOnProcess(StartupParameters, Cancel);
	CommonClientOverridable.LaunchParametersOnProcess(StartupParameters, Cancel);
	
	Return Not Cancel;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// BeforeExit

// For internal use only. 
// 
// Parameters:
//  ReCreate - Boolean
//
// Returns:
//   Structure:
//     Cancel - Boolean
//     Warning - Array Of See StandardSubsystemsClient.WarningOnExit.
//     InteractiveHandler - NotifyDescription, Undefined
//     ContinuationHandler - NotifyDescription, Undefined
//     ContinuousExecution - Boolean
//     CompletionProcessing - NotifyDescription
//
Function ParametersOfActionsBeforeShuttingDownTheSystem(ReCreate = False) Export
	
	ParameterName = "StandardSubsystems.ParametersOfActionsBeforeShuttingDownTheSystem";
	If ReCreate Or ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New Structure);
	EndIf;
	Parameters = ApplicationParameters[ParameterName];
	
	If Not ReCreate Then
		Return Parameters;
	EndIf;
	
	// 
	Parameters.Insert("Cancel", False);
	Parameters.Insert("Warnings", ClientParameter("ExitWarnings"));
	
	// 
	Parameters.Insert("InteractiveHandler", Undefined); // NotifyDescription
	Parameters.Insert("ContinuationHandler",   Undefined); // NotifyDescription
	Parameters.Insert("ContinuousExecution", True);
	
	// 
	Parameters.Insert("CompletionProcessing", New NotifyDescription(
		"ActionsBeforeExitCompletionHandler", StandardSubsystemsClient));
	Return Parameters;
	
EndFunction	
	
// For internal use only. Continues the execution of BeforeExit procedure.
//
// Parameters:
//   Parameters - See StandardSubsystemsClient.ParametersOfActionsBeforeShuttingDownTheSystem
//
Procedure ActionsBeforeExit(Parameters) Export
	
	Parameters.Insert("ContinuationHandler", Parameters.CompletionProcessing);
	
	If CommonClient.SeparatedDataUsageAvailable() Then
		Try
			OpenMessageFormOnExit(Parameters);
		Except
			HandleErrorOnStartOrExit(Parameters, ErrorInfo(), "End");
		EndTry;
		If InteractiveHandlerBeforeExit(Parameters) Then
			Return;
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. The BeforeExit procedure completion.
//
// Parameters:
//   NotDefined - Undefined
//   Parameters - See StandardSubsystemsClient.ParametersOfActionsBeforeShuttingDownTheSystem
//
Procedure ActionsBeforeExitCompletionHandler(NotDefined, Parameters) Export
	
	Parameters = ParametersOfActionsBeforeShuttingDownTheSystem();
	Parameters.ContinuationHandler = Undefined;
	Parameters.CompletionProcessing  = Undefined;
	ParameterName = "StandardSubsystems.SkipQuitSystemAfterWarningsHandled";
	
	If Not Parameters.Cancel
	   And Not Parameters.ContinuousExecution
	   And ApplicationParameters.Get(ParameterName) = Undefined Then
		
		ParameterName = "StandardSubsystems.SkipExitConfirmation";
		ApplicationParameters.Insert(ParameterName, True);
		Exit();
	EndIf;
	
EndProcedure

// For internal use only. The BeforeExit procedure completion.
// 
// Parameters:
//  NotDefined - Undefined
//  ContinuationHandler - NotifyDescription
//
Procedure ActionsBeforeExitAfterErrorProcessing(NotDefined, ContinuationHandler) Export
	
	Parameters = ParametersOfActionsBeforeShuttingDownTheSystem();
	Parameters.ContinuationHandler = ContinuationHandler;
	
	If Parameters.Cancel Then
		Parameters.Cancel = False;
		ExecuteNotifyProcessing(Parameters.CompletionProcessing);
	Else
		ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions for application start and exit.

// See CommonClientOverridable.BeforeStart.
Procedure BeforeStart2(Parameters) Export
	
	// 
	// 
	// 
	// 
	
	ClientParameters = ClientParametersOnStart();
	
	If ClientParameters.Property("ShowDeprecatedPlatformVersion") Then
		Parameters.InteractiveHandler = New NotifyDescription(
			"Check1CEnterpriseVersionOnStartup", ThisObject);
	ElsIf ClientParameters.Property("InvalidPlatformVersionUsed") Then
		Parameters.InteractiveHandler = New NotifyDescription(
			"WarnAboutInvalidPlatformVersion", ThisObject);
	EndIf;
	
EndProcedure

// 
Procedure Check1CEnterpriseVersionOnStartup(Parameters, Context) Export
	
	ClientParameters = ClientParametersOnStart();
	
	SystemInfo = New SystemInfo;
	Current             = SystemInfo.AppVersion;
	Min         = ClientParameters.MinPlatformVersion;
	If StrFind(LaunchParameter, "UpdateAndExit") > 0
		And CommonClientServer.CompareVersions(Current, Min) < 0
		And CommonClient.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		MessageText =
			NStr("en = 'Cannot update the application.
				|
				|The current 1C:Enterprise version %1 is not supported.
				|Update 1C:Enterprise to version %2 or later';");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, Current, Min);
		ModuleConfigurationUpdateClient = CommonClient.CommonModule("ConfigurationUpdateClient");
		ModuleConfigurationUpdateClient.WriteDownTheErrorOfTheNeedToUpdateThePlatform(MessageText);
	EndIf;
	
	ClosingNotification1 = New NotifyDescription("AfterClosingDeprecatedPlatformVersionForm", ThisObject, Parameters);
	If CommonClient.SubsystemExists("OnlineUserSupport.GetApplicationUpdates") Then
		StandardProcessing = True;
		ModuleGetApplicationUpdatesClient = CommonClient.CommonModule("GetApplicationUpdatesClient");
		ModuleGetApplicationUpdatesClient.WhenCheckingPlatformVersionAtStartup(ClosingNotification1, StandardProcessing);
		If Not StandardProcessing Then
			Return;
		EndIf;
	EndIf;
	
	If CommonClientServer.CompareVersions(Current, Min) < 0 Then
		If UsersClient.IsFullUser(True) Then
			MessageText =
				NStr("en = 'Cannot start the application.
				           |1C:Enterprise platform update is required.';");
		Else
			MessageText =
				NStr("en = 'Cannot start the application.
				           |1C:Enterprise platform update is required. Contact the administrator.';");
		EndIf;
	Else
		If UsersClient.IsFullUser(True) Then
			MessageText =
				NStr("en = 'It is recommended that you close the application and update the 1C:Enterprise platform version.
				         |The new 1C:Enterprise platform version includes bug fixes that improve the application stability.
				         |You can also continue using the current version.
				         |The minimum required platform version is %1.';");
		Else
			MessageText = 
				NStr("en = 'It is recommended that you close the application and contact the administrator to update the 1C:Enterprise platform version.
				         |The new platform version includes bug fixes that improve the application stability.
				         |You can also continue using the current version.
				         |The minimum required platform version is %1.';");
		EndIf;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("MessageText", MessageText);
	FormParameters.Insert("RecommendedPlatformVersion", ClientParameters.RecommendedPlatformVersion);
	FormParameters.Insert("MinPlatformVersion", ClientParameters.MinPlatformVersion);
	FormParameters.Insert("OpenByScenario", True);
	FormParameters.Insert("SkipExit", True);
	
	Form = OpenForm("DataProcessor.PlatformUpdateRecommended.Form.PlatformUpdateRecommended", FormParameters,
		, , , , ClosingNotification1);	
	If Form = Undefined Then
		AfterClosingDeprecatedPlatformVersionForm("Continue", Parameters);
	EndIf;
	
EndProcedure

// For internal use only. Continues the execution of CheckPlatformVersionOnStart procedure.
Procedure AfterClosingDeprecatedPlatformVersionForm(Result, Parameters) Export
	
	If Result <> "Continue" Then
		Parameters.Cancel = True;
	Else
		Parameters.RetrievedClientParameters.Insert("ShowDeprecatedPlatformVersion");
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// 
Procedure WarnAboutInvalidPlatformVersion(Parameters, Context) Export

	ClosingNotification1 = New NotifyDescription("AfterCloseInvalidPlatformVersionForm", ThisObject, Parameters);
	
	Form = OpenForm("DataProcessor.PlatformUpdateRecommended.Form.PlatformUpdateIsRequired", ,
		, , , , ClosingNotification1); 
	
	If Form = Undefined Then
		AfterCloseInvalidPlatformVersionForm("Continue", Parameters);
	EndIf;
	
EndProcedure

// For internal use only. Continue the procedure to check the version of the platform on Startup.
Procedure AfterCloseInvalidPlatformVersionForm(Result, Parameters) Export
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// See CommonClientOverridable.BeforeStart.
Procedure BeforeStart3(Parameters) Export
	
	// 
	// 
	
	ClientParameters = ClientParametersOnStart();
	
	If Not ClientParameters.Property("ReconnectMasterNode") Then
		Return;
	EndIf;
	
	Parameters.InteractiveHandler = New NotifyDescription(
		"MasterNodeReconnectionInteractiveHandler", ThisObject);
	
EndProcedure

// See CommonClientOverridable.BeforeStart.
Procedure BeforeStart4(Parameters) Export
	
	// 
	// 
	
	ClientParameters = ClientParametersOnStart();
	
	If Not ClientParameters.Property("SelectInitialRegionalIBSettings") Then
		Return;
	EndIf;
	
	Parameters.InteractiveHandler = New NotifyDescription(
		"InteractiveInitialRegionalInfobaseSettingsProcessing", ThisObject, Parameters);
	
EndProcedure

// For internal use only. Continues the execution of CheckReconnectToMasterNodeRequired procedure.
Procedure MasterNodeReconnectionInteractiveHandler(Parameters, Context) Export
	
	ClientParameters = ClientParametersOnStart();
	
	If ClientParameters.ReconnectMasterNode = False Then
		Parameters.Cancel = True;
		ShowMessageBox(
			NotificationWithoutResult(Parameters.ContinuationHandler),
			NStr("en = 'Cannot sign in because the connection to the master node is lost.
			           |Please contact the administrator.';"),
			15);
		Return;
	EndIf;
	
	Form = OpenForm("CommonForm.ReconnectToMasterNode",,,,,,
		New NotifyDescription("ReconnectToMasterNodeAfterCloseForm", ThisObject, Parameters));
	
	If Form = Undefined Then
		ReconnectToMasterNodeAfterCloseForm(New Structure("Cancel", True), Parameters);
	EndIf;
	
EndProcedure

// For internal use only. Continuation of the BeforeStart4 procedure.
Procedure InteractiveInitialRegionalInfobaseSettingsProcessing(Parameters, Context) Export
	
	ClientParameters = ClientParametersOnStart();
	
	If ClientParameters.SelectInitialRegionalIBSettings = False Then
		Parameters.Cancel = True;
		ShowMessageBox(
			NotificationWithoutResult(Parameters.ContinuationHandler),
			NStr("en = 'Cannot sign in because configuring the regional settings is required.
			           |Please contact the administrator.';"),
			15);
		Return;
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportClient = CommonClient.CommonModule("NationalLanguageSupportClient");
		NotifyDescription = New NotifyDescription("AfterCloseInitialRegionalInfobaseSettingsChoiceForm", ThisObject, Parameters);
		ModuleNationalLanguageSupportClient.OpenTheRegionalSettingsForm(NotifyDescription);
	Else
		AfterCloseInitialRegionalInfobaseSettingsChoiceForm(New Structure("Cancel", True), Parameters);
	EndIf;
	
EndProcedure

// For internal use only. Continues the execution of CheckReconnectToMasterNodeRequired procedure.
Procedure ReconnectToMasterNodeAfterCloseForm(Result, Parameters) Export
	
	If TypeOf(Result) <> Type("Structure") Or Result.Cancel Then
		Parameters.Cancel = True;
	Else
		Parameters.RetrievedClientParameters.Insert("ReconnectMasterNode");
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// For internal use only. Continuation of the BeforeStart4 procedure.
Procedure AfterCloseInitialRegionalInfobaseSettingsChoiceForm(Result, Parameters) Export
	
	If TypeOf(Result) <> Type("Structure") Or Result.Cancel Then
		Parameters.Cancel = True;
	Else
		Parameters.RetrievedClientParameters.Insert("SelectInitialRegionalIBSettings");
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Hides the desktop when the application starts using flag
// that prevents form creation on the desktop.
// Makes the desktop visible and updates it when possible
// if the desktop is hidden.
//
// Parameters:
//  Hide - Boolean - pass False to make desktop
//           visible if it is hidden.
//
//  AlreadyDoneAtServer - Boolean - pass True if the method was already executed
//           in the StandardSubsystemsServerCall module and it should not be
//           executed again here but only set the flag showing that desktop
//           is hidden and it will be shown lately.
//
Procedure HideDesktopOnStart(Hide = True, AlreadyDoneAtServer = False) Export
	
	ApplicationStartParameters = ApplicationParameters["StandardSubsystems.ApplicationStartParameters"];
	
	If Hide Then
		If Not ApplicationStartParameters.Property("HideDesktopOnStart") Then
			ApplicationStartParameters.Insert("HideDesktopOnStart");
			If Not AlreadyDoneAtServer Then
				StandardSubsystemsServerCall.HideDesktopOnStart();
			EndIf;
			RefreshInterface();
		EndIf;
	Else
		If ApplicationStartParameters.Property("HideDesktopOnStart") Then
			ApplicationStartParameters.Delete("HideDesktopOnStart");
			If Not AlreadyDoneAtServer Then
				StandardSubsystemsServerCall.HideDesktopOnStart(False);
			EndIf;
			CommonClient.RefreshApplicationInterface();
		EndIf;
	EndIf;
	
EndProcedure

// For internal use only.
Procedure NotifyWithEmptyResult(NotificationWithResult) Export
	
	ExecuteNotifyProcessing(NotificationWithResult);
	
EndProcedure

// For internal use only.
Procedure StartInteractiveHandlerBeforeExit() Export
	
	ApplicationStartParameters = ApplicationParameters["StandardSubsystems.ApplicationStartParameters"];
	If Not ApplicationStartParameters.Property("ExitProcessingParameters") Then
		Return;
	EndIf;
	
	Parameters = ApplicationStartParameters.ExitProcessingParameters;
	ApplicationStartParameters.Delete("ExitProcessingParameters");
	
	InteractiveHandler = Parameters.InteractiveHandler;
	Parameters.InteractiveHandler = Undefined;
	ExecuteNotifyProcessing(InteractiveHandler, Parameters);
	
EndProcedure

// For internal use only.
//
// Parameters:
//  Result - DialogReturnCode 
//            - Undefined
//  AdditionalParameters - Structure
//
Procedure AfterClosingWarningFormOnExit(Result, AdditionalParameters) Export
	
	Parameters = ParametersOfActionsBeforeShuttingDownTheSystem();
	
	If AdditionalParameters.FormOption = "DoQueryBox" Then
		
		If Result = Undefined Or Result.Value <> DialogReturnCode.Yes Then
			Parameters.Cancel = True;
		EndIf;
		
	ElsIf AdditionalParameters.FormOption = "StandardForm" Then
	
		If Result = True Or Result = Undefined Then
			Parameters.Cancel = True;
		EndIf;
		
	Else // AppliedForm
		If Result = True Or Result = Undefined Or Result = DialogReturnCode.No Then
			Parameters.Cancel = True;
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// See CommonClientOverridable.AfterStart.
Procedure AfterStart() Export
	
	If MustShowRAMSizeRecommendations() Then
		AttachIdleHandler("ShowRAMRecommendation", 10, True);
	EndIf;
	
	If DisplayWarningsBeforeShuttingDownTheSystem(False) Then
		// 
		// 
		WarningsBeforeSystemShutdown(False); 
	EndIf;
	
EndProcedure

Function DisplayWarningsBeforeShuttingDownTheSystem(Cancel)
	
	If ApplicationStartupLogicDisabled() Then
		Return False;
	EndIf;
	
	ApplicationStartParameters = ApplicationParameters["StandardSubsystems.ApplicationStartParameters"];
	
	If ApplicationStartParameters.Property("HideDesktopOnStart") Then
		// 
		// 
		// 
		// 
		// 
		// 
		// 
		// 
#If Not WebClient Then
		Cancel = True;
#EndIf
		Return False;
	EndIf;
	
	// In thick client (standard application) mode, warning list is not displayed.
#If ThickClientOrdinaryApplication Then
	Return False;
#EndIf
	
	If ApplicationParameters["StandardSubsystems.SkipExitConfirmation"] = True Then
		Return False;
	EndIf;
	
	If Not CommonClient.SeparatedDataUsageAvailable() Then
		Return False;
	EndIf;
	Return True;
	
EndFunction
	
Function WarningsBeforeSystemShutdown(Cancel)
	
	Warnings = New Array;
	SSLSubsystemsIntegrationClient.BeforeExit(Cancel, Warnings);
	CommonClientOverridable.BeforeExit(Cancel, Warnings);
	Return Warnings;

EndFunction

////////////////////////////////////////////////////////////////////////////////
// For the MetadataObjectIDs catalog.

// For internal use only.
Procedure MetadataObjectIDsListFormListValueChoice(Form, Item, Value, StandardProcessing) Export
	
	If Not Form.SelectMetadataObjectsGroups
	   And Item.CurrentData <> Undefined
	   And Not Item.CurrentData.DeletionMark
	   And Not ValueIsFilled(Item.CurrentData.Parent) Then
		
		StandardProcessing = False;
		
		If Item.Representation = TableRepresentation.Tree Then
			If Item.Expanded(Item.CurrentRow) Then
				Item.GroupBy(Item.CurrentRow);
			Else
				Item.Expand(Item.CurrentRow);
			EndIf;
			
		ElsIf Item.Representation = TableRepresentation.HierarchicalList Then
			
			If Item.CurrentParent <> Item.CurrentRow Then
				Item.CurrentParent = Item.CurrentRow;
			Else
				CurrentRow = Item.CurrentRow;
				Item.CurrentParent = Undefined;
				Item.CurrentRow = CurrentRow;
			EndIf;
		Else
			ShowMessageBox(,
				NStr("en = 'Cannot select a group of metadata objects.
				           |Please select a metadata object.';"));
		EndIf;
	EndIf;
	
EndProcedure

#Region TheParametersOfTheClientToTheServer

Procedure FillInTheClientParametersOnTheServer(Parameters) Export
	
	Parameters.Insert("LaunchParameter", LaunchParameter);
	Parameters.Insert("InfoBaseConnectionString", InfoBaseConnectionString());
	Parameters.Insert("IsWebClient", IsWebClient());
	Parameters.Insert("IsLinuxClient", CommonClient.IsLinuxClient());
	Parameters.Insert("IsMacOSClient", CommonClient.IsMacOSClient());
	Parameters.Insert("IsWindowsClient", CommonClient.IsWindowsClient());
	Parameters.Insert("IsMobileClient", IsMobileClient());
	Parameters.Insert("ClientUsed", ClientUsed());
	Parameters.Insert("BinDir", CurrentAppllicationDirectory());
	Parameters.Insert("ClientID", ClientID());
	Parameters.Insert("HideDesktopOnStart", False);
	Parameters.Insert("RAM", CommonClient.RAMAvailableForClientApplication());
	Parameters.Insert("MainDisplayResolotion", MainDisplayResolotion());
	Parameters.Insert("SystemInfo", ClientSystemInfo());
	
	// 
	Parameters.Insert("CurrentDateOnClient", CurrentDate()); // 
	Parameters.Insert("CurrentUniversalDateInMillisecondsOnClient", CurrentUniversalDateInMilliseconds());
	
EndProcedure

// Returns:
//   See Common.ClientUsed
//
Function ClientUsed()
	
	ClientUsed = "";
	#If ThinClient Then
		ClientUsed = "ThinClient";
	#ElsIf ThickClientManagedApplication Then
		ClientUsed = "ThickClientManagedApplication";
	#ElsIf ThickClientOrdinaryApplication Then
		ClientUsed = "ThickClientOrdinaryApplication";
	#ElsIf WebClient Then
		BrowserDetails = CurrentBrowser();
		If IsBlankString(BrowserDetails.Version) Then
			ClientUsed = StringFunctionsClientServer.SubstituteParametersToString("WebClient.%1", BrowserDetails.Name1);
		Else
			ClientUsed = StringFunctionsClientServer.SubstituteParametersToString("WebClient.%1.%2", BrowserDetails.Name1, StrSplit(BrowserDetails.Version, ".")[0]);
		EndIf;
	#EndIf
	
	Return ClientUsed;
	
EndFunction

Function CurrentBrowser()
	
	Result = New Structure("Name1,Version", "Other", "");
	
	SystemInfo = New SystemInfo;
	String = SystemInfo.UserAgentInformation;
	String = StrReplace(String, ",", ";");

	// Opera
	Id = "Opera";
	Position = StrFind(String, Id, SearchDirection.FromEnd);
	If Position > 0 Then
		String = Mid(String, Position + StrLen(Id));
		Result.Name1 = "Opera";
		Id = "Version/";
		Position = StrFind(String, Id);
		If Position > 0 Then
			String = Mid(String, Position + StrLen(Id));
			Result.Version = TrimAll(String);
		Else
			String = TrimAll(String);
			If StrStartsWith(String, "/") Then
				String = Mid(String, 2);
			EndIf;
			Result.Version = TrimL(String);
		EndIf;
		Return Result;
	EndIf;

	// IE
	Id = "MSIE"; // v11-
	Position = StrFind(String, Id);
	If Position > 0 Then
		Result.Name1 = "IE";
		String = Mid(String, Position + StrLen(Id));
		Position = StrFind(String, ";");
		If Position > 0 Then
			String = TrimL(Left(String, Position - 1));
			Result.Version = String;
		EndIf;
		Return Result;
	EndIf;

	Id = "Trident"; // v11+
	Position = StrFind(String, Id);
	If Position > 0 Then
		Result.Name1 = "IE";
		String = Mid(String, Position + StrLen(Id));
		
		Id = "rv:";
		Position = StrFind(String, Id);
		If Position > 0 Then
			String = Mid(String, Position + StrLen(Id));
			Position = StrFind(String, ")");
			If Position > 0 Then
				String = TrimL(Left(String, Position - 1));
				Result.Version = String;
			EndIf;
		EndIf;
		Return Result;
	EndIf;

	// Chrome
	Id = "Chrome/";
	Position = StrFind(String, Id);
	If Position > 0 Then
		Result.Name1 = "Chrome";
		String = Mid(String, Position + StrLen(Id));
		Position = StrFind(String, " ");
		If Position > 0 Then
			String = TrimL(Left(String, Position - 1));
			Result.Version = String;
		EndIf;
		Return Result;
	EndIf;

	// Safari
	Id = "Safari/";
	If StrFind(String, Id) > 0 Then
		Result.Name1 = "Safari";
		Id = "Version/";
		Position = StrFind(String, Id);
		If Position > 0 Then
			String = Mid(String, Position + StrLen(Id));
			Position = StrFind(String, " ");
			If Position > 0 Then
				Result.Version = TrimAll(Left(String, Position - 1));
			EndIf;
		EndIf;
		Return Result;
	EndIf;

	// Firefox
	Id = "Firefox/";
	Position = StrFind(String, Id);
	If Position > 0 Then
		Result.Name1 = "Firefox";
		String = Mid(String, Position + StrLen(Id));
		If Not IsBlankString(String) Then
			Result.Version = TrimAll(String);
		EndIf;
		Return Result;
	EndIf;
	
	Return Result;
	
EndFunction

Function CurrentAppllicationDirectory()
	
	#If WebClient Or MobileClient Then
		BinDir = "";
	#Else
		BinDir = BinDir();
	#EndIf
	
	Return BinDir;
	
EndFunction

Function MainDisplayResolotion()
	
	ClientDisplaysInformation = GetClientDisplaysInformation();
	If ClientDisplaysInformation.Count() > 0 Then
		DPI = ClientDisplaysInformation[0].DPI; // ACC:1353 - 
		MainDisplayResolotion = ?(DPI = 0, 72, DPI);
	Else
		MainDisplayResolotion = 72;
	EndIf;
	
	Return MainDisplayResolotion;
	
EndFunction

Function ClientID()
	
	SystemInfo = New SystemInfo;
	Return SystemInfo.ClientID;
	
EndFunction

Function IsWebClient()
	
#If WebClient Then
	Return True;
#Else
	Return False;
#EndIf
	
EndFunction

Function IsMobileClient()
	
#If MobileClient Then
	Return True;
#Else
	Return False;
#EndIf
	
EndFunction

// Returns:
//   See Common.ClientSystemInfo
//
Function ClientSystemInfo()
	
	Result = New Structure(
		"OSVersion,
		|AppVersion,
		|ClientID,
		|UserAgentInformation,
		|RAM,
		|Processor,
		|PlatformType");
	
	SystemInfo = New SystemInfo;
	FillPropertyValues(Result, SystemInfo);
	Result.PlatformType = CommonClientServer.NameOfThePlatformType(SystemInfo.PlatformType);
	
	Return New FixedStructure(Result);
	
EndFunction

#EndRegion

// 
//
// Parameters:
//  Size - Number
//  Context - Structure:
//   * Notification - NotifyDescription
//   * Result  - Arbitrary
//
Procedure StartProcessingNotificationCompletion(Size, Context) Export
	
	ExecuteNotifyProcessing(Context.Notification, Context.Result);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

Procedure SignInToDataArea()
	
	If IsBlankString(LaunchParameter) Then
		Return;
	EndIf;
	
	StartupParameters = StrSplit(LaunchParameter, ";", False);
	
	If StartupParameters.Count() = 0 Then
		Return;
	EndIf;
	
	StartParameterValue = Upper(StartupParameters[0]);
	
	If StartParameterValue <> Upper("SignInToDataArea") Then
		Return;
	EndIf;
	
	If StartupParameters.Count() < 2 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Specify a separator value (a number) in startup parameter %1.';"),
			"SignInToDataArea");
	EndIf;
	
	Try
		SeparatorValue = Number(StartupParameters[1]);
	Except
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'A separator value in parameter %1 must be a number.';"),
			"SignInToDataArea");
	EndTry;
	
	StandardSubsystemsServerCall.SignInToDataArea(SeparatorValue);
	
EndProcedure

// Updates the client parameters after interactive data processing on application start.
Procedure UpdateClientParameters(Parameters, InitialCall = False, RefreshReusableValues = True)
	
	If InitialCall Then
		ParameterName = "StandardSubsystems.ApplicationStartParameters";
		If ApplicationParameters[ParameterName] = Undefined Then
			ApplicationParameters.Insert(ParameterName, New Structure);
		EndIf;
		ParameterName = "StandardSubsystems.ApplicationStartCompleted";
		If ApplicationParameters[ParameterName] = Undefined Then
			ApplicationParameters.Insert(ParameterName, False);
		EndIf;
	ElsIf Parameters.CountOfReceivedClientParameters = Parameters.RetrievedClientParameters.Count() Then
		Return;
	EndIf;
	
	Parameters.Insert("CountOfReceivedClientParameters", Parameters.RetrievedClientParameters.Count());
	
	ApplicationParameters["StandardSubsystems.ApplicationStartParameters"].Insert(
		"RetrievedClientParameters", Parameters.RetrievedClientParameters);
	
	If RefreshReusableValues Then
		RefreshReusableValues();
	EndIf;
	
EndProcedure

// Checks the result of the interactive processing. If False, calls the exit handler.
// If a new received client parameter is added, it updates the client operation parameters.
//
// Parameters:
//   Parameters - See CommonClientOverridable.BeforeStart.Parameters.
//
// Returns:
//   Boolean - 
//            
//
Function ContinueActionsBeforeStart(Parameters)
	
	If Parameters.Cancel Then
		ExecuteNotifyProcessing(Parameters.CompletionProcessing);
		Return False;
	EndIf;
	
	UpdateClientParameters(Parameters);
	
	Return True;
	
EndFunction

// Processes the error found when calling the OnStart event handler.
//
// Parameters:
//   Parameters          - See CommonClientOverridable.OnStart.Parameters.
//   ErrorInfo - ErrorInfo - an error description.
//   Shutdown   - Boolean - If True is set, you will not be able to continue operation in case of startup error.
//
Procedure HandleErrorBeforeStart(Parameters, ErrorInfo, Shutdown = False)
	
	HandleErrorOnStartOrExit(Parameters, ErrorInfo, "Run", Shutdown);
	
EndProcedure

// Checks the result of the BeforeStart event handler and executes the notification handler.
//
// Parameters:
//   Parameters - See CommonClientOverridable.BeforeStart.Parameters.
//
// Returns:
//   Boolean - 
//            
//            
//
Function BeforeStartInteractiveHandler(Parameters)
	
	ApplicationStartParameters = ApplicationParameters["StandardSubsystems.ApplicationStartParameters"];
	
	If Parameters.InteractiveHandler = Undefined Then
		If Parameters.Cancel Then
			ExecuteNotifyProcessing(Parameters.CompletionProcessing);
			Return True;
		EndIf;
		Return False;
	EndIf;
	
	UpdateClientParameters(Parameters);
	
	If Not Parameters.ContinuousExecution Then
		InteractiveHandler = Parameters.InteractiveHandler;
		Parameters.InteractiveHandler = Undefined;
		InstallLatestProcedure(Parameters,,, InteractiveHandler);
		ExecuteNotifyProcessing(InteractiveHandler, Parameters);
		
	Else
		// 
		// 
		// 
		// 
		ApplicationStartParameters.Insert("ProcessingParameters", Parameters);
		HideDesktopOnStart();
		ApplicationStartParameters.Insert("SkipClearingDesktopHiding");
		
		If Parameters.CompletionNotification = Undefined Then
			// 
			// 
			If Not ApplicationStartupLogicDisabled() Then
				SetInterfaceFunctionalOptionParametersOnStart();
			EndIf;
		Else
			// 
			// 
			AttachIdleHandler("OnStartIdleHandler", 0.1, True);
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

Procedure InstallLatestProcedure(Parameters, ModuleName = "", ProcedureName = "", NotifyDescription = Undefined)
	
	If NotifyDescription = Undefined Then
		Parameters.ModuleOfLastProcedure = ModuleName;
		Parameters.NameOfLastProcedure = ProcedureName;
	Else
		Parameters.ModuleOfLastProcedure = NotifyDescription.Module;
		Parameters.NameOfLastProcedure = NotifyDescription.ProcedureName;
	EndIf;
	
EndProcedure

Function FullNameOfLastProcedureBeforeStartingSystem() Export
	
	Properties = ApplicationParameters["StandardSubsystems.ApplicationStartParameters"];
	If Properties = Undefined
	 Or Not Properties.Property("ProcessingParametersBeforeStartSystem") Then
		Return "";
	EndIf;
	Parameters = Properties.ProcessingParametersBeforeStartSystem;
	
	If TypeOf(Parameters.ModuleOfLastProcedure) = Type("CommonModule") Then
		NamesOfClientModules = StandardSubsystemsServerCall.NamesOfClientModules();
		For Each NameOfClientModule In NamesOfClientModules Do
			Try
				CurrentModule = CommonClient.CommonModule(NameOfClientModule);
			Except
				CurrentModule = Undefined;
			EndTry;
			If CurrentModule = Parameters.ModuleOfLastProcedure Then
				ModuleName = NameOfClientModule;
				Break;
			EndIf;
		EndDo;
	ElsIf TypeOf(Parameters.ModuleOfLastProcedure) = Type("ClientApplicationForm") Then
		ModuleName = Parameters.ModuleOfLastProcedure.FormName;
	Else
		ModuleName = String(Parameters.ModuleOfLastProcedure);
	EndIf;
	
	Return String(ModuleName) + "." + Parameters.NameOfLastProcedure;
	
EndFunction

// Checks the result of the interactive processing. If False, calls the exit handler.
//
// Parameters:
//   Parameters - See CommonClientOverridable.OnStart.Parameters.
//
// Returns:
//   Boolean - 
//            
//
Function ContinueActionsOnStart(Parameters)
	
	If Parameters.Cancel Then
		ExecuteNotifyProcessing(Parameters.CompletionProcessing);
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Processes the error found when calling the OnStart event handler.
//
// Parameters:
//   Parameters          - See CommonClientOverridable.OnStart.Parameters.
//   ErrorInfo - ErrorInfo - an error description.
//   Shutdown   - Boolean - If True is set, you will not be able to continue operation in case of startup error.
//
Procedure HandleErrorOnStart(Parameters, ErrorInfo, Shutdown = False)
	
	HandleErrorOnStartOrExit(Parameters, ErrorInfo, "Run", Shutdown);
	
EndProcedure

// Checks the result of the OnStart event handler and executes the notification handler.
//
// Parameters:
//   Parameters - See CommonClientOverridable.OnStart.Parameters.
//
// Returns:
//   Boolean - 
//            
//
Function OnStartInteractiveHandler(Parameters)
	
	If Parameters.InteractiveHandler = Undefined Then
		If Parameters.Cancel Then
			ExecuteNotifyProcessing(Parameters.CompletionProcessing);
			Return True;
		EndIf;
		Return False;
	EndIf;
	
	InteractiveHandler = Parameters.InteractiveHandler;
	
	Parameters.ContinuousExecution = False;
	Parameters.InteractiveHandler = Undefined;
	
	ExecuteNotifyProcessing(InteractiveHandler, Parameters);
	
	Return True;
	
EndFunction

Function InteractiveHandlerBeforeStartInProgress()
	
	If ApplicationParameters = Undefined Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An unexpected error occurred during the application startup.
			           |
			           |Technical details:
			           |Invalid call %1 during the application startup. First, you need to complete the %2 procedure.';"),
			"StandardSubsystemsClient.OnStart",
			"StandardSubsystemsClient.BeforeStart");
		Raise ErrorText;
	EndIf;	

	ApplicationStartParameters = ApplicationParameters["StandardSubsystems.ApplicationStartParameters"]; // Structure
	If Not ApplicationStartParameters.Property("ProcessingParameters") Then
		Return False;
	EndIf;
	
	Parameters = ApplicationStartParameters.ProcessingParameters;
	InstallLatestProcedure(Parameters, "StandardSubsystemsClient",
		"InteractiveHandlerBeforeStartInProgress");
	If Parameters.InteractiveHandler = Undefined Then
		Return False;
	EndIf;
	
	AttachIdleHandler("TheHandlerWaitsToStartInteractiveProcessingBeforeTheSystemStartsWorking", 0.1, True);
	Parameters.ContinuousExecution = False;
	
	Return True;
	
EndFunction

Procedure StartInteractiveProcessingBeforeStartingTheSystem() Export
	
	ApplicationStartParameters = ApplicationParameters["StandardSubsystems.ApplicationStartParameters"]; // Structure
	
	Parameters = ApplicationStartParameters.ProcessingParameters;
	InteractiveHandler = Parameters.InteractiveHandler;
	Parameters.InteractiveHandler = Undefined;
	InstallLatestProcedure(Parameters,,, InteractiveHandler);
	
	ExecuteNotifyProcessing(InteractiveHandler, Parameters);
	
	ApplicationStartParameters.Delete("ProcessingParameters");
	
EndProcedure

Function InteractiveHandlerBeforeExit(Parameters)
	
	If Parameters.InteractiveHandler = Undefined Then
		If Parameters.Cancel Then
			ExecuteNotifyProcessing(Parameters.CompletionProcessing);
			Return True;
		EndIf;
		Return False;
	EndIf;
	
	If Not Parameters.ContinuousExecution Then
		InteractiveHandler = Parameters.InteractiveHandler;
		Parameters.InteractiveHandler = Undefined;
		ExecuteNotifyProcessing(InteractiveHandler, Parameters);
		
	Else
		// 
		// 
		ApplicationParameters["StandardSubsystems.ApplicationStartParameters"].Insert("ExitProcessingParameters", Parameters);
		Parameters.ContinuousExecution = False;
		AttachIdleHandler(
			"BeforeExitInteractiveHandlerIdleHandler", 0.1, True);
	EndIf;
	
	Return True;
	
EndFunction

// Displays a user message form or a message.
Procedure OpenMessageFormOnExit(Parameters)
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("FormOption", "DoQueryBox");
	
	ResponseHandler = New NotifyDescription("AfterClosingWarningFormOnExit",
		ThisObject, AdditionalParameters);
		
	Warnings = Parameters.Warnings;
	Parameters.Delete("Warnings");
	
	FormParameters = New Structure;
	FormParameters.Insert("Warnings", Warnings);
	
	FormName = "CommonForm.ExitWarnings";
	
	If Warnings.Count() = 1 And IsBlankString(Warnings[0].CheckBoxText) Then
		AdditionalParameters.Insert("FormOption", "AppliedForm");
		OpenApplicationWarningForm(Parameters, ResponseHandler, Warnings[0], FormName, FormParameters);
	Else	
		AdditionalParameters.Insert("FormOption", "StandardForm");
		FormOpenParameters = New Structure;
		FormOpenParameters.Insert("FormName", FormName);
		FormOpenParameters.Insert("FormParameters", FormParameters);
		FormOpenParameters.Insert("ResponseHandler", ResponseHandler);
		FormOpenParameters.Insert("WindowOpeningMode", Undefined);
		Parameters.InteractiveHandler = New NotifyDescription(
			"WarningInteractiveHandlerOnExit", ThisObject, FormOpenParameters);
	EndIf;
	
EndProcedure

// Continues the execution of OpenOnExitMessageForm procedure.
Procedure WarningInteractiveHandlerOnExit(Parameters, FormOpenParameters) Export
	
	OpenForm(
		FormOpenParameters.FormName,
		FormOpenParameters.FormParameters, , , , ,
		FormOpenParameters.ResponseHandler,
		FormOpenParameters.WindowOpeningMode);
	
EndProcedure

// Continues the execution of ShowMessageBoxAndContinue procedure.
Procedure ShowMessageBoxAndContinueCompletion(Result, Parameters) Export
	
	If Result <> Undefined Then
		If Result.Value = "ExitApp" Then
			Parameters.Cancel = True;
		ElsIf Result.Value = "Restart" Or Result.Value = DialogReturnCode.Timeout Then
			Parameters.Cancel = True;
			Parameters.Restart = True;
		EndIf;
	EndIf;
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Generates representation of a single question.
//
//	If UserWarning has the HyperlinkText property, IndividualOpeningForm is opened from
//	the Structure of the question.
//	If UserWarning has the CheckBoxText property,
//	the CommonForm.QuestionBeforeExit form will be opened.
//
// Parameters:
//  Parameters - See StandardSubsystemsClient.ParametersOfActionsBeforeShuttingDownTheSystem.
//  ResponseHandler - NotifyDescription - to continue once the user answered the question.
//  UserWarning - See StandardSubsystemsClient.WarningOnExit.
//  FormName - String - a name of the common form with questions.
//  FormParameters - Structure - parameters for the form with questions.
//
Procedure OpenApplicationWarningForm(Parameters, ResponseHandler, UserWarning, FormName, FormParameters)
	
	HyperlinkText = "";
	If Not UserWarning.Property("HyperlinkText", HyperlinkText) Then
		Return;
	EndIf;
	If IsBlankString(HyperlinkText) Then
		Return;
	EndIf;
	
	ActionOnClickHyperlink = Undefined;
	If Not UserWarning.Property("ActionOnClickHyperlink", ActionOnClickHyperlink) Then
		Return;
	EndIf;
	
	ActionHyperlink = UserWarning.ActionOnClickHyperlink;
	Form = Undefined;
	
	If ActionHyperlink.Property("ApplicationWarningForm", Form) Then
		FormParameters = Undefined;
		If ActionHyperlink.Property("ApplicationWarningFormParameters", FormParameters) Then
			If TypeOf(FormParameters) = Type("Structure") Then 
				FormParameters.Insert("ApplicationShutdown", True);
			ElsIf FormParameters = Undefined Then 
				FormParameters = New Structure;
				FormParameters.Insert("ApplicationShutdown", True);
			EndIf;
			
			FormParameters.Insert("YesButtonTitle",  NStr("en = 'Exit';"));
			FormParameters.Insert("NoButtonTitle", NStr("en = 'Cancel';"));
			
		EndIf;
		FormOpenParameters = New Structure;
		FormOpenParameters.Insert("FormName", Form);
		FormOpenParameters.Insert("FormParameters", FormParameters);
		FormOpenParameters.Insert("ResponseHandler", ResponseHandler);
		FormOpenParameters.Insert("WindowOpeningMode", ActionHyperlink.WindowOpeningMode);
		Parameters.InteractiveHandler = New NotifyDescription(
			"WarningInteractiveHandlerOnExit", ThisObject, FormOpenParameters);
		
	ElsIf ActionHyperlink.Property("Form", Form) Then 
		FormParameters = Undefined;
		If ActionHyperlink.Property("FormParameters", FormParameters) Then
			If TypeOf(FormParameters) = Type("Structure") Then 
				FormParameters.Insert("ApplicationShutdown", True);
			ElsIf FormParameters = Undefined Then 
				FormParameters = New Structure;
				FormParameters.Insert("ApplicationShutdown", True);
			EndIf;
		EndIf;
		FormOpenParameters = New Structure;
		FormOpenParameters.Insert("FormName", Form);
		FormOpenParameters.Insert("FormParameters", FormParameters);
		FormOpenParameters.Insert("ResponseHandler", ResponseHandler);
		FormOpenParameters.Insert("WindowOpeningMode", ActionHyperlink.WindowOpeningMode);
		Parameters.InteractiveHandler = New NotifyDescription(
			"WarningInteractiveHandlerOnExit", ThisObject, FormOpenParameters);
		
	EndIf;
	
EndProcedure

// If Shutdown = True is specified, abort the further execution of the client code and shut down the application.
//
Procedure HandleErrorOnStartOrExit(Parameters, ErrorInfo, Event, Shutdown = False)
	
	If Event = "Run" Then
		If Shutdown Then
			Parameters.Cancel = True;
			Parameters.ContinuationHandler = Parameters.CompletionProcessing;
		EndIf;
	Else
		Parameters.ContinuationHandler = New NotifyDescription(
			"ActionsBeforeExitAfterErrorProcessing", ThisObject, Parameters.ContinuationHandler);
	EndIf;
	
	StandardSubsystemsServerCall.WriteErrorToEventLogOnStartOrExit(
		Shutdown, Event, ErrorProcessing.DetailErrorDescription(ErrorInfo));	
		
	WarningText = ErrorProcessing.BriefErrorDescription(ErrorInfo) + Chars.LF + Chars.LF
		+ NStr("en = 'Technical information has been saved to the event log.';");
		
	If Event = "Run" And Shutdown Then
		WarningText = NStr("en = 'Cannot start the application:';")
			+ Chars.LF + Chars.LF + WarningText;
	EndIf;
	
	InteractiveHandler = New NotifyDescription("ShowMessageBoxAndContinue", ThisObject, WarningText);
	Parameters.InteractiveHandler = InteractiveHandler;
	
EndProcedure

Procedure SetInterfaceFunctionalOptionParametersOnStart()
	
	ApplicationStartParameters = ApplicationParameters["StandardSubsystems.ApplicationStartParameters"];
	
	If TypeOf(ApplicationStartParameters) <> Type("Structure")
	 Or Not ApplicationStartParameters.Property("InterfaceOptions") Then
		// 
		Return;
	EndIf;
	
	If ApplicationStartParameters.Property("InterfaceOptionsSet") Then
		Return;
	EndIf;
	
	InterfaceOptions = New Structure(ApplicationStartParameters.InterfaceOptions);
	
	// Parameters of the functional options are set only if they are specified
	If InterfaceOptions.Count() > 0 Then
		SetInterfaceFunctionalOptionParameters(InterfaceOptions);
	EndIf;
	
	ApplicationStartParameters.Insert("InterfaceOptionsSet");
	
EndProcedure

Function MustShowRAMSizeRecommendations()
	ClientParameters = ClientParametersOnStart();
	Return ClientParameters.MustShowRAMSizeRecommendations;
EndFunction

Procedure NotifyLowMemory() Export
	RecommendedSize = ClientParametersOnStart().RecommendedRAM;
	
	Title = NStr("en = 'Application performance degraded';");
	Text = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Consider increasing RAM size to %1 GB.';"), RecommendedSize);
	
	ShowUserNotification(Title, 
		"e1cib/app/DataProcessor.SpeedupRecommendation",
		Text, PictureLib.Warning32, UserNotificationStatus.Important);
EndProcedure

#EndRegion
