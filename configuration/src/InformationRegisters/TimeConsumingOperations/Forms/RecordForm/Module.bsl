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
	
	ReadOnly = True;
	
	ProcessID = Record.ProcessID;
	ThreadID   = Record.ThreadID;
	JobID  = Record.JobID;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	Items.FormEnableEditing.Enabled = False;
	
EndProcedure

#EndRegion
