
&After("OnAddSubsystems")
Procedure SSL_OnAddSubsystems(SubsystemsModules) Export
	
	SubsystemsModules.Add("SSL_StartEmptyBase");

EndProcedure
