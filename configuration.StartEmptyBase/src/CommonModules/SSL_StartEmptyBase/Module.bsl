
// On add subsystem.
// 
// Parameters:
//  LongDesc - See InfobaseUpdateSSL.OnAddSubsystem
Procedure OnAddSubsystem(LongDesc) Export
	
	LongDesc.Name = "StandardSubsystemsLibrary";
	LongDesc.Version = Metadata.Version;
	LongDesc.RequiredSubsystems1.Add("StandardSubsystems");
	
EndProcedure

Procedure OnAddUpdateHandlers(Handlers) Export
		
EndProcedure

Procedure BeforeUpdateInfobase() Export
	
EndProcedure

Procedure AfterUpdateInfobase(Val PreviousVersion, Val CurrentVersion,
		Val CompletedHandlers, OutputUpdatesDetails, Val ExclusiveMode) Export
		
EndProcedure

Procedure OnPrepareUpdateDetailsTemplate(Val Template) Export
	
EndProcedure

Procedure OnDefineDataUpdateMode(DataUpdateMode, StandardProcessing) Export
	
EndProcedure

Procedure OnAddApplicationMigrationHandlers(Handlers) Export
	
	SSLSubsystemsIntegration.OnAddApplicationMigrationHandlers(Handlers);
	
EndProcedure

Procedure OnCompleteApplicationMigration(PreviousConfigurationName, PreviousConfigurationVersion, Parameters) Export
	
EndProcedure
