///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Basis = New Structure("Basis,Command", CommandParameter, "ForwardMail");
	OpeningParameters = New Structure("Basis", Basis);
	OpenForm("Document.OutgoingEmail.ObjectForm", OpeningParameters);
	CommandExecuteParameters.Source.Close();
	
EndProcedure

#EndRegion