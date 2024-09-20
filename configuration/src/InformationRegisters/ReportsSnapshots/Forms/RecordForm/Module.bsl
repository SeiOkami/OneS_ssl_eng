///////////////////////////////////////////////////////////////////////////////////////////////////////
// 
//  
// 
// 
// 
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlersForm
 
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	RecordStructure = Undefined;
	If Not Parameters.Property("RecordStructure", RecordStructure) Then
		Common.MessageToUser(NStr(
			"en = 'You can view a report snapshot only from the list of user report snapshots.';"), , , , Cancel);
		Return;
	EndIf;

	FillPropertyValues(ThisObject, RecordStructure);

	SetPrivilegedMode(True);

	Record = InformationRegisters.ReportsSnapshots.CreateRecordManager();
	FillPropertyValues(Record, Parameters.RecordStructure);
	Record.Read();
	If Not Record.Selected() Then
		Common.MessageToUser(NStr("en = 'No record is found by the specified parameters.';"), , , , Cancel);
	ElsIf Record.ReportUpdateError Then
		Common.MessageToUser(NStr("en = 'Report snapshot is not generated.';"), , , , Cancel);
	EndIf;
	If Cancel Then
		Return;
	EndIf;

	ReportResult = Record.ReportResult.Get();
	If TypeOf(ReportResult) = Type("SpreadsheetDocument") Then
		TabDocument.Put(ReportResult);
	Else
		Common.MessageToUser(NStr(
			"en = 'An error occurred when reading the report snapshot: the data is incorrect.';"), , , , Cancel);
	EndIf;

	If Not Cancel Then
		Record.LastViewedDate = CurrentSessionDate();
		Record.Write();
	EndIf;

	SetPrivilegedMode(False);

EndProcedure

#EndRegion