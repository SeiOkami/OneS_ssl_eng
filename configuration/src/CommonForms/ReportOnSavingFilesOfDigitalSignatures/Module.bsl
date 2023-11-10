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
	
	Text = Parameters.Text;
	DirectoryWithFiles = Parameters.DirectoryWithFiles;
	
	Items.FormOpenFilesFolder.Visible = ValueIsFilled(DirectoryWithFiles);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OpenFilesFolder(Command)
	
	FileSystemClient.OpenExplorer(DirectoryWithFiles);
	
EndProcedure

#EndRegion
