///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

Function GetDumpsToDelete() Export
	Query = New Query;
	Query.Text = 
		"SELECT
		|	PlatformDumps.RegistrationDate,
		|	PlatformDumps.DumpOption,
		|	PlatformDumps.PlatformVersion,
		|	PlatformDumps.FileName
		|FROM
		|	InformationRegister.PlatformDumps AS PlatformDumps
		|WHERE
		|	PlatformDumps.FileName <> &FileName";
	
	Query.SetParameter("FileName", "");
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	DumpsToDelete = New Array;
	While SelectionDetailRecords.Next() Do
		DumpToDelete = New Structure;
		DumpToDelete.Insert("RegistrationDate", SelectionDetailRecords.RegistrationDate);
		DumpToDelete.Insert("DumpOption", SelectionDetailRecords.DumpOption);
		DumpToDelete.Insert("PlatformVersion", SelectionDetailRecords.PlatformVersion);
		DumpToDelete.Insert("FileName", SelectionDetailRecords.FileName);
		
		DumpsToDelete.Add(DumpToDelete);
	EndDo;

	Return DumpsToDelete;
EndFunction

Procedure ChangeRecord(Record) Export
	RecordManager = CreateRecordManager();
	RecordManager.RegistrationDate = Record.RegistrationDate;
	RecordManager.DumpOption = Record.DumpOption;
	RecordManager.PlatformVersion = Record.PlatformVersion;
	RecordManager.FileName = Record.FileName;
	RecordManager.Write();
EndProcedure

Function GetRegisteredDumps(Dumps) Export
	Query = New Query;
	Query.Text = 
		"SELECT
		|	PlatformDumps.FileName
		|FROM
		|	InformationRegister.PlatformDumps AS PlatformDumps
		|WHERE
		|	PlatformDumps.FileName IN(&Dumps)";
	
	Query.SetParameter("Dumps", Dumps);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	HasDumps = New Map;
	While SelectionDetailRecords.Next() Do
		HasDumps.Insert(SelectionDetailRecords.FileName, True);
	EndDo;
	
	Return HasDumps;
EndFunction

Function GetTopOptions(StartDate, EndDate, Count, Val PlatformVersion = Undefined, ShouldRenameColumns = False) Export
	StartDateSM = (StartDate - Date(1,1,1)) * 1000;
	EndDateSM = (EndDate - Date(1,1,1)) * 1000;
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1000
		|	DumpOption,
		|	OptionsCount
		|FROM
		|	(SELECT
		|		PlatformDumps.DumpOption AS DumpOption,
		|		COUNT(1) AS OptionsCount
		|	FROM
		|		InformationRegister.PlatformDumps AS PlatformDumps
		|	WHERE
		|		PlatformDumps.RegistrationDate BETWEEN &StartDateSM AND &EndDateSM
		|		AND &CondPlatformVersion
		|	GROUP BY
		|		PlatformDumps.DumpOption
		|	) AS Selection
		|ORDER BY
		|	OptionsCount DESC
		|";
		
	Query.Text = StrReplace(Query.Text, "1000", Format(Count, "NG=0"));
	Query.SetParameter("StartDateSM", StartDateSM);
	Query.SetParameter("EndDateSM", EndDateSM);
	If PlatformVersion <> Undefined Then
		PlatformVersionNumber = MonitoringCenterInternal.PlatformVersionToNumber(PlatformVersion);
		Query.Text = StrReplace(Query.Text, "&CondPlatformVersion", "PlatformDumps.PlatformVersion = &PlatformVersion");
		Query.SetParameter("PlatformVersion", PlatformVersionNumber);
	Else
		Query.Text = StrReplace(Query.Text, "&CondPlatformVersion", "TRUE");
	EndIf;
	TableOfDumps = Query.Execute().Unload();
	If ShouldRenameColumns Then	
		TableOfDumps.Columns[0].Name = "dumpVariant";
		TableOfDumps.Columns[1].Name = "quantity";
	EndIf;                                     
	Return TableOfDumps;
EndFunction

#EndRegion

#EndIf