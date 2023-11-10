///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	// ACC:75-on The DataExchange.Import check must follow the change records in the Event log.
	WriteChangesToTheLog(ThisObject, Replacing);
	// ACC:75-on
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Filter.User.Use
	   And Not PeriodClosingDatesInternal.IsPeriodClosingAddressee(Filter.User.Value) Then
		// 
		AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	// 
	// 
	If DataExchange.Load Then
		If Not AdditionalProperties.Property("SkipPeriodClosingDatesVersionUpdate") Then
			PeriodClosingDatesInternal.UpdatePeriodClosingDatesVersionOnDataImport(ThisObject);
		EndIf;
		Return;
	EndIf;
	
	If Not AdditionalProperties.Property("SkipPeriodClosingDatesVersionUpdate") Then
		PeriodClosingDatesInternal.UpdatePeriodClosingDatesVersion();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure WriteChangesToTheLog(Var_ThisObject, Replacing)
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	Table = Unload();
	Table.Columns.Add("LineChangeType", New TypeDescription("Number"));
	Table.FillValues(1, "LineChangeType");
	
	If Replacing Then
		OldRecords = InformationRegisters.PeriodClosingDates.CreateRecordSet();
		For Each FilterElement In Filter Do
			If FilterElement.Use Then
				OldRecords.Filter[FilterElement.Name].Set(FilterElement.Value);
			EndIf;
		EndDo;
		OldRecords.Read();
		For Each OldRecord In OldRecords Do
			NewRow = Table.Add();
			FillPropertyValues(NewRow, OldRecord);
			NewRow.LineChangeType = -1;
		EndDo;
	EndIf;
	
	RegisterMetadata = Metadata.InformationRegisters.PeriodClosingDates;
	
	Fields = New ValueList;
	ColumnWidth_ = New Map;
	AddAField(Fields, ColumnWidth_, RegisterMetadata.Dimensions.Section, 20);
	AddAField(Fields, ColumnWidth_, RegisterMetadata.Dimensions.Object, 40);
	AddAField(Fields, ColumnWidth_, RegisterMetadata.Dimensions.User, 40);
	AddAField(Fields, ColumnWidth_, RegisterMetadata.Resources.PeriodEndClosingDate, 20);
	AddAField(Fields, ColumnWidth_, RegisterMetadata.Attributes.PeriodEndClosingDateDetails, 22);
	AddAField(Fields, ColumnWidth_, RegisterMetadata.Attributes.Comment, 20);
	
	FieldList = StrConcat(Fields.UnloadValues(), ",");
	Table.GroupBy(FieldList, "LineChangeType");
	
	AddedRows = Table.FindRows(New Structure("LineChangeType", 1));
	DeletedRows = Table.FindRows(New Structure("LineChangeType", -1));
	
	If Not ValueIsFilled(AddedRows)
	   And Not ValueIsFilled(DeletedRows) Then
		Return;
	EndIf;
	
	Title = New Array;
	Title.Add("");
	For Each Field In Fields Do
		Title.Add(AugmentedString(Field.Presentation,
			ColumnWidth_.Get(Field.Value)));
	EndDo;
	
	CommentLines = New Array;
	CommentLines.Add(StrConcat(Title, " | "));
	
	If ValueIsFilled(AddedRows) Then
		AddLines(CommentLines, AddedRows, Fields, ColumnWidth_, "+");
	EndIf;
	If ValueIsFilled(DeletedRows) Then
		AddLines(CommentLines, DeletedRows, Fields, ColumnWidth_, "-");
	EndIf;
	
	Comment = StrConcat(CommentLines, Chars.LF) + Chars.LF;
	
	WriteLogEvent(
		NStr("en = 'Period-end closing dates.Change registration';",
			Common.DefaultLanguageCode()),
		EventLogLevel.Information, RegisterMetadata,
		,
		Comment,
		EventLogEntryTransactionMode.Transactional);
	
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
EndProcedure

Procedure AddAField(Fields, ColumnWidth_, FieldMetadata, ColumnWidth);
	
	Fields.Add(FieldMetadata.Name, FieldMetadata.Presentation());
	ColumnWidth_.Insert(FieldMetadata.Name, ColumnWidth);
	
EndProcedure

Function AugmentedString(Value, ColumnWidth)
	
	String = String(Value);
	If Not ValueIsFilled(String) 
	   And TypeOf(Value) <> Type("String") Then
		String = "<> (" + String(TypeOf(Value)) + ")";
	EndIf;
	StringLength = StrLen(String);
	If TypeOf(ColumnWidth) <> Type("Number")
	 Or ColumnWidth <= StringLength Then
		Return String;
	EndIf;
	Spaces = "                                            ";
	Return String + Left(Spaces, ColumnWidth - StringLength);
	
EndFunction

Procedure AddLines(CommentLines, TableRows, Fields, ColumnWidth_, Operation)
	
	For Each TableRow In TableRows Do
		CommentLine = New Array;
		For Each Field In Fields Do
			CommentLine.Add(AugmentedString(TableRow[Field.Value],
				ColumnWidth_.Get(Field.Value)));
		EndDo;
		CommentLines.Add(Operation + "| " + StrConcat(CommentLine, " | "));
	EndDo;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf