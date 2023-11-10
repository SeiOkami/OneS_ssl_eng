///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventsHandlers

// Opens the form of the log that records source document originals.
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)

	SourceDocumentsOriginalsRecordingClientOverridable.OnOpenOriginalsAccountingJournalForm();
	
EndProcedure

#EndRegion
