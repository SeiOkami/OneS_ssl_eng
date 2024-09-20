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

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	CurrentFolder = Common.ObjectAttributesValues(Ref,
		"Description, Parent, DeletionMark");
	
	If Ref = PredefinedValue("Catalog.FilesFolders.Templates")
		And CurrentFolder.Parent <> Catalogs.FilesFolders.EmptyRef() Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot move folder ""%1"".';"), CurrentFolder.Description);
	EndIf;
	
	If IsNew() Or CurrentFolder.Parent <> Parent Then
		// Check rights to a source folder.
		If Not FilesOperationsInternal.HasRight("FoldersModification", CurrentFolder.Parent) Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Insufficient rights to move files from the ""%1"" folder.';"),
				String(?(ValueIsFilled(CurrentFolder.Parent), CurrentFolder.Parent, NStr("en = 'Folders';"))));
		EndIf;
		// Check rights to a destination folder.
		If Not FilesOperationsInternal.HasRight("FoldersModification", Parent) Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Insufficient rights to add subfolders to the ""%1"" folder.';"),
				String(?(ValueIsFilled(Parent), Parent, NStr("en = 'Folders';"))));
		EndIf;
	EndIf;
	
	If DeletionMark And CurrentFolder.DeletionMark <> True Then
		
		// Checking the "Deletion mark" right.
		If Not FilesOperationsInternal.HasRight("FoldersModification", Ref) Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Insufficient rights to change the ""%1"" file folder.';"),
				String(Ref));
		EndIf;
	EndIf;
	
	If DeletionMark <> CurrentFolder.DeletionMark And Not Ref.IsEmpty() Then
		// Filtering files and trying to mark them for deletion.
		Query = New Query;
		Query.Text = 
			"SELECT
			|	Files.Ref,
			|	Files.BeingEditedBy
			|FROM
			|	Catalog.Files AS Files
			|WHERE
			|	Files.FileOwner = &Ref";
		
		Query.SetParameter("Ref", Ref);
		
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			If ValueIsFilled(Selection.BeingEditedBy) Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
				                     NStr("en = 'Cannot delete the %1 folder as it contains the ""%2"" file that is locked for editing.';"),
				                     String(Ref),
				                     String(Selection.Ref));
			EndIf;

			FileObject1 = Selection.Ref.GetObject();
			FileObject1.Lock();
			FileObject1.SetDeletionMark(DeletionMark);
		EndDo;
	EndIf;
	
	AdditionalProperties.Insert("PreviousIsNew", IsNew());
	
	If Not IsNew() Then
		
		If Description <> CurrentFolder.Description Then // Folder is renamed.
			FolderWorkingDirectory         = FilesOperationsInternalServerCall.FolderWorkingDirectory(Ref);
			FolerParentWorkingDirectory = FilesOperationsInternalServerCall.FolderWorkingDirectory(CurrentFolder.Parent);
			If FolerParentWorkingDirectory <> "" Then
				
				// 
				FolerParentWorkingDirectory = CommonClientServer.AddLastPathSeparator(
					FolerParentWorkingDirectory);
				
				InheritedFolerWorkingDirectoryPrevious = FolerParentWorkingDirectory
					+ CurrentFolder.Description + GetPathSeparator();
					
				If InheritedFolerWorkingDirectoryPrevious = FolderWorkingDirectory Then
					
					NewFolderWorkingDirectory = FolerParentWorkingDirectory
						+ Description + GetPathSeparator();
					
					FilesOperationsInternal.SaveFolderWorkingDirectory(Ref, NewFolderWorkingDirectory);
				EndIf;
			EndIf;
		EndIf;
		
		If Parent <> CurrentFolder.Parent Then // Folder is moved to another folder.
			FolderWorkingDirectory               = FilesOperationsInternalServerCall.FolderWorkingDirectory(Ref);
			FolerParentWorkingDirectory       = FilesOperationsInternalServerCall.FolderWorkingDirectory(CurrentFolder.Parent);
			NewFolderParentWorkingDirectory = FilesOperationsInternalServerCall.FolderWorkingDirectory(Parent);
			
			If FolerParentWorkingDirectory <> "" Or NewFolderParentWorkingDirectory <> "" Then
				
				InheritedFolerWorkingDirectoryPrevious = FolerParentWorkingDirectory;
				
				If FolerParentWorkingDirectory <> "" Then
					InheritedFolerWorkingDirectoryPrevious = FolerParentWorkingDirectory
						+ CurrentFolder.Description + GetPathSeparator();
				EndIf;
				
				// Working directory is created automatically from a parent.
				If InheritedFolerWorkingDirectoryPrevious = FolderWorkingDirectory Then
					If NewFolderParentWorkingDirectory <> "" Then
						
						NewFolderWorkingDirectory = NewFolderParentWorkingDirectory
							+ Description + GetPathSeparator();
						
						FilesOperationsInternal.SaveFolderWorkingDirectory(Ref, NewFolderWorkingDirectory);
					Else
						FilesOperationsInternal.CleanUpWorkingDirectory(Ref);
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	WorkingDirectory = Undefined;
	
	If AdditionalProperties.Property("WorkingDirectory", WorkingDirectory) Or AdditionalProperties.PreviousIsNew Then
		
		If WorkingDirectory = "" Then
			FilesOperationsInternal.CleanUpWorkingDirectory(Ref);
		ElsIf WorkingDirectory <> Undefined Then
			FilesOperationsInternal.SaveFolderWorkingDirectory(Ref, WorkingDirectory);
		Else
			FolderWorkingDirectory = FilesOperationsInternalServerCall.FolderWorkingDirectory(Parent);
			If FolderWorkingDirectory <> "" Then
				
				// 
				FolderWorkingDirectory = CommonClientServer.AddLastPathSeparator(
					FolderWorkingDirectory);
				
				FolderWorkingDirectory = FolderWorkingDirectory
					+ Description + GetPathSeparator();
				
				FilesOperationsInternal.SaveFolderWorkingDirectory(Ref, FolderWorkingDirectory);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	CreationDate = CurrentSessionDate();
	EmployeeResponsible = Users.AuthorizedUser();
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	FoundProhibitedCharsArray = CommonClientServer.FindProhibitedCharsInFileName(Description);
	If FoundProhibitedCharsArray.Count() <> 0 Then
		Cancel = True;
		
		Text = NStr("en = 'The folder name contains characters that are not allowed ( \ / : * ? "" < > | .. )';");
		Common.MessageToUser(Text, ThisObject, "Description");
	EndIf;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf