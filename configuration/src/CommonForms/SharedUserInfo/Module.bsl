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
	
	Items.SharedUser.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'View of user information %1 is not available as it is a 
		           |service account provided for SaaS administrators.';"),
		Parameters.Key.Description);
	
EndProcedure

#EndRegion