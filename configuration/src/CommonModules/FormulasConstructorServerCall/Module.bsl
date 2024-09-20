///////////////////////////////////////////////////////////////////////////////////////////////////////
// 
//  
// 
// 
// 
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Internal

Function BackgroundSearchData(Messages = Undefined) Export
	MessagesData = New Structure("DeserializedMessages, AllRefsTypeDetails");
	If Messages <> Undefined Then
		MessagesData.DeserializedMessages = DeserializedMessages(Messages);
	EndIf;
	
	MessagesData.AllRefsTypeDetails = Common.AllRefsTypeDetails();
	
	Return MessagesData;
EndFunction

#EndRegion

#Region Private

Function DeserializedMessages(Messages)
	Result = New Array;
	For Each Message In Messages Do
		Result.Add(Common.ValueFromXMLString(Message.Text));
	EndDo;
	Return Result;
EndFunction

#EndRegion
