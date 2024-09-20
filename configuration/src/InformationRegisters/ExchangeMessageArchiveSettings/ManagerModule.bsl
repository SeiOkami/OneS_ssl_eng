///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Function GetSettings(InfobaseNode) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Settings.InfobaseNode AS InfobaseNode,
		|	Settings.FilesCount AS FilesCount,
		|	Settings.StoreOnDisk AS StoreOnDisk,
		|	Settings.FullPath AS FullPath,
		|	Settings.ShouldCompressFiles AS ShouldCompressFiles
		|FROM
		|	InformationRegister.ExchangeMessageArchiveSettings AS Settings
		|WHERE
		|	Settings.InfobaseNode = &InfobaseNode";
	
	Query.SetParameter("InfobaseNode", InfobaseNode);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Result = New Structure("FilesCount,StoreOnDisk,FullPath,ShouldCompressFiles");
		FillPropertyValues(Result, Selection);
		Return Result;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

#EndRegion

#EndIf