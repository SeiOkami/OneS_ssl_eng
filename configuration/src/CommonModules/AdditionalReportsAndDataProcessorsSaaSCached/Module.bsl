///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

Function RegulatingConstants() Export
	
	Result = New Array();
	Result.Add("IndependentUsageOfAdditionalReportsAndDataProcessorsSaaS");
	Result.Add("AdditionalReportAndDataProcessorFolderUsageSaaS");
	
	Return New FixedArray(Result);
	
EndFunction

Function AttributesToControl() Export
	
	Result = New Array();
	Result.Add("SafeMode");
	Result.Add("DataProcessorStorage");
	Result.Add("ObjectName");
	Result.Add("Version");
	Result.Add("Kind");
	Result.Add("DeletionMark");
	
	Return New FixedArray(Result);
	
EndFunction

Function ExtendedLockReasonsDetails() Export
	
	Reasons = Enums.ReasonsForDisablingAdditionalReportsAndDataProcessorsSaaS;
	
	Result = New Map();
	Result.Insert(Reasons.LockByServiceAdministrator, 
		NStr("en = 'Usage of additional data processor is prohibited by the SaaS administrator.';"));
	Result.Insert(Reasons.LockByOwner, 
		NStr("en = 'Usage of additional data processor is prohibited by the data processor owner.';"));
	Result.Insert(Reasons.ConfigurationVersionUpdate, 
		NStr("en = 'Usage of additional data processor is temporarily unavailable. Try again in a few minutes. We apologize for the inconvenience.';"));
	
	Return New FixedMap(Result);
	
EndFunction

#EndRegion