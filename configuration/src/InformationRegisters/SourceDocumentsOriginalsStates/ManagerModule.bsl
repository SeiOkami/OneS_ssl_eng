///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Records states of print form originals to the register after printing the form.
//
//	Parameters:
//  PrintObjects - ValueList - a document list.
//  PrintForms - ValueList - a description of templates and a presentation of print forms.
//  Written1 - Boolean - indicates that the document state is written to the register.
//
Procedure WriteDocumentOriginalsStatesAfterPrintForm(PrintObjects, PrintForms, Written1 = False) Export
	
	State = PredefinedValue("Catalog.SourceDocumentsOriginalsStates.FormPrinted");
	If ValueIsFilled(PrintObjects) Then
		If PrintObjects.Count() > 1 Then
			If PrintForms.Count() > 1 Then
				For Each Document In PrintObjects Do
					If SourceDocumentsOriginalsRecording.IsAccountingObject(Document.Value) Then
						WriteCommonDocumentOriginalState(Document.Value,State);
						TS = SourceDocumentsOriginalsRecording.TableOfEmployees(Document.Value); 
						If TS <> "" Then
							For Each Employee In Document.Value[TS] Do
								For Each Form In PrintForms Do 
									WriteDocumentOriginalStateByPrintForms(Document.Value, 
										Form.Value, Form.Presentation, State, False, Employee.Employee);
								EndDo;
							EndDo;
						Else
							For Each Form In PrintForms Do
								WriteDocumentOriginalStateByPrintForms(Document.Value, Form.Value, 
									Form.Presentation, State, False);
							EndDo;
						EndIf;
						Written1 = True;
					EndIf;
				EndDo;
			Else
				For Each Document In PrintObjects Do
					If SourceDocumentsOriginalsRecording.IsAccountingObject(Document.Value) Then
						TS = SourceDocumentsOriginalsRecording.TableOfEmployees(Document.Value); 
						If TS <> "" Then
							For Each Employee In Document.Value[TS] Do
								WriteDocumentOriginalStateByPrintForms(Document.Value, 
									PrintForms[0].Value,PrintForms[0].Presentation, State, False,
									Employee.Employee);
							EndDo;
						Else
							WriteDocumentOriginalStateByPrintForms(Document.Value, 
								PrintForms[0].Value, PrintForms[0].Presentation, State, False);	
						EndIf;
					WriteCommonDocumentOriginalState(Document.Value,State);
					Written1 = True;
					EndIf;
				EndDo;
			EndIf;
		Else
			Document = PrintObjects[0].Value;
			If SourceDocumentsOriginalsRecording.IsAccountingObject(Document) Then
				If PrintForms.Count() > 1 Then
					TS = SourceDocumentsOriginalsRecording.TableOfEmployees(Document); 
					If TS <> "" Then
						For Each Employee In Document[TS] Do
							For Each Form In PrintForms Do
								WriteDocumentOriginalStateByPrintForms(Document, Form.Value,
									Form.Presentation, State, False,Employee.Employee);
							EndDo;
						EndDo;
					Else
						For Each Form In PrintForms Do
							WriteDocumentOriginalStateByPrintForms(Document, Form.Value,
								Form.Presentation, State, False);
						EndDo;
					EndIf;
				Else
					TS = SourceDocumentsOriginalsRecording.TableOfEmployees(Document); 
					If TS <> "" Then
						For Each Employee In Document[TS] Do
							WriteDocumentOriginalStateByPrintForms(Document, PrintForms[0].Value,
								PrintForms[0].Presentation, State, False, Employee.Employee);
						EndDo;
					Else
						WriteDocumentOriginalStateByPrintForms(Document, PrintForms[0].Value,
							PrintForms[0].Presentation, State, False);
					EndIf;
				EndIf;
				WriteCommonDocumentOriginalState(Document,State);
				Written1 = True;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// Records the print form original state to the register after printing the form.
//
//	Parameters:
//  Document - DocumentRef - document reference.
//  PrintForm - String - a print form template name.
//  Presentation - String - a print form description.
//  State - String - a description of the print form original state
//            - CatalogRef - 
//  FromOutside - Boolean - indicates whether the form belongs to 1C:Enterprise.
//  Employee - CatalogRef -
//
Procedure WriteDocumentOriginalStateByPrintForms(Document, PrintForm, Presentation, State, 
	FromOutside, Employee = Undefined) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();	
	Try

		OriginalStateRecord = InformationRegisters.SourceDocumentsOriginalsStates.CreateRecordManager();
		OriginalStateRecord.Owner = Document.Ref;
		OriginalStateRecord.SourceDocument = PrintForm;
		If ValueIsFilled(Employee) Then
			LastFirstName = Employee.Description;
			Values = New Structure("Presentation, LASTFIRSTNAME", Presentation, LastFirstName);
			EmployeeView = StrFind(Presentation, LastFirstName);
			If EmployeeView = 0 Then
				OriginalStateRecord.SourceDocumentPresentation = StringFunctionsClientServer.InsertParametersIntoString(
					NStr("en = '[Presentation] [LastFirstName]';"), Values);
			Else
				OriginalStateRecord.SourceDocumentPresentation = Presentation;
			EndIf;
		Else
			OriginalStateRecord.SourceDocumentPresentation = Presentation;
		EndIf;
		OriginalStateRecord.State = Catalogs.SourceDocumentsOriginalsStates.FindByDescription(State);
		OriginalStateRecord.ChangeAuthor = Users.AuthorizedUser();
		OriginalStateRecord.OverallState = False;
		OriginalStateRecord.ExternalForm = FromOutside;
		OriginalStateRecord.LastChangeDate = CurrentSessionDate();
		OriginalStateRecord.Employee = Employee;
		OriginalStateRecord.Write();
		
		CommitTransaction();
		
	Except	
		
		RollbackTransaction();
		Raise;
	EndTry;

EndProcedure

// Records the overall state of the document original to the register.
//
//	Parameters:
//  Document - DocumentRef - document reference.
//  State - String - a description of the original state.
//
Procedure WriteCommonDocumentOriginalState(Document, State) Export

	SetPrivilegedMode(True);
	
	BeginTransaction();	
	Try
		
		Block = New DataLock();
		Item = Block.Add("InformationRegister.SourceDocumentsOriginalsStates");
		Item.Mode = DataLockMode.Exclusive;
		Block.Lock();

		OriginalStateRecord = InformationRegisters.SourceDocumentsOriginalsStates.CreateRecordManager();
		OriginalStateRecord.Owner = Document.Ref;
		OriginalStateRecord.SourceDocument = "";
		
		CheckOriginalStateRecord = InformationRegisters.SourceDocumentsOriginalsStates.CreateRecordSet();
		CheckOriginalStateRecord.Filter.Owner.Set(Document.Ref);
		CheckOriginalStateRecord.Filter.OverallState.Set(False);
		CheckOriginalStateRecord.Read();
		If CheckOriginalStateRecord.Count() > 1 Then
			For Each Record In CheckOriginalStateRecord Do
				If Record.ChangeAuthor <> Users.CurrentUser() Then
					OriginalStateRecord.ChangeAuthor = Undefined;
				Else
					OriginalStateRecord.ChangeAuthor = Users.CurrentUser();
				EndIf;
			EndDo;
		Else
			OriginalStateRecord.ChangeAuthor = Users.CurrentUser();
		EndIf;
		
		If CheckOriginalStateRecord.Count() > 0 Then
			If SourceDocumentsOriginalsRecording.PrintFormsStateSame(Document,State) Then
				OriginalStateRecord.State = Catalogs.SourceDocumentsOriginalsStates.FindByDescription(State);
			Else
				OriginalStateRecord.State = Catalogs.SourceDocumentsOriginalsStates.OriginalsNotAll;
			EndIf;
		Else
			OriginalStateRecord.State = Catalogs.SourceDocumentsOriginalsStates.FindByDescription(State);
		EndIf;
		

		OriginalStateRecord.OverallState = True;
		OriginalStateRecord.LastChangeDate = CurrentSessionDate();
		OriginalStateRecord.Write();
		
		CommitTransaction();
		
	Except	
		
		RollbackTransaction();
		Raise;
	EndTry;

EndProcedure

#EndRegion

#EndIf

