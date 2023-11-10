
&ChangeAndValidate("UpdateApplicationParametersInBackground")
Function SSL_UpdateApplicationParametersInBackground(WaitCompletion, FormIdentifier, ReportProgress) Export

	OperationParametersList = TimeConsumingOperations.BackgroundExecutionParameters(FormIdentifier);
	OperationParametersList.BackgroundJobDescription = NStr("en = 'Update application parameters in background';");
	OperationParametersList.NoExtensions = True;
	OperationParametersList.WaitCompletion = WaitCompletion;
	
	#Insert
	OperationParametersList.NoExtensions = False;
	#EndInsert

	If Common.DebugMode()
	   And Not ValueIsFilled(SessionParameters.AttachedExtensions) Then
		ReportProgress = False;
	EndIf;

	If ValueIsFilled(SessionParameters.AttachedExtensions)
	   And Not CanExecuteBackgroundJobs() Then

		ErrorText =
			NStr("en = 'Application parameters with attached configuration extensions
			           |can be updated only in a background job without configuration extensions
			           |
			           |In a file infobase, a background job cannot be started
			           |from another background job, or from a COM connection.
			           |
			           |To update, you need either to update interactively
			           |starting up 1C:Enterprise or temporarily disable configuration extensions.';");
		Raise ErrorText;
	EndIf;

	Return TimeConsumingOperations.ExecuteInBackground(
		"InformationRegisters.ApplicationRuntimeParameters.ApplicationParametersUpdateLongRunningOperationHandler",
		ReportProgress, OperationParametersList);

EndFunction