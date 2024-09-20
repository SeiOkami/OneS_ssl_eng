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

	Title = StringFunctionsClientServer.SubstituteParametersToString(NStr(
		"en = 'Preview: %1';"), Parameters.MailingDescription);

	If Parameters.TextType = Enums.EmailTextTypes.HTML Then
		Items.EmailTextPages.CurrentPage = Items.PageEmailTextHTML;
	Else
		Items.EmailTextPages.CurrentPage = Items.PageEmailTextPlainText;
	EndIf;

	Text = Parameters.Text;

	If IsTempStorageURL(Parameters.PicturesAddressForHTML) 
		And Parameters.TextType = Enums.EmailTextTypes.HTML Then
		PicturesForHTML = GetFromTempStorage(Parameters.PicturesAddressForHTML);
		Text = ReplacePicturesIDsWithPathToFiles(Text, PicturesForHTML);
	EndIf;

EndProcedure

#EndRegion

#Region Private

// Replaces the attachment image ID in the HTML text with the file path and creates an HTML document object.
//
// Parameters:
//  HTMLText     - String - the HTML text being processed.
//  TableOfFiles - ValueTable 
//
// Returns:
//  HTMLDocument   - 
//
&AtServerNoContext
Function ReplacePicturesIDsWithPathToFiles(HTMLText, TableOfFiles)

	HTMLDocument = HTMLDocumentObjectFromHTMLText(HTMLText);

	For Each AttachedFile In TableOfFiles Do

		For Each Picture In HTMLDocument.Images Do

			AttributePictureSource = Picture.Attributes.GetNamedItem("src");
			If AttributePictureSource = Undefined Then
				Continue;
			EndIf;

			If StrOccurrenceCount(AttributePictureSource.Value, AttachedFile.Id) > 0 Then
				
				NewAttributePicture = AttributePictureSource.CloneNode(False);
					If IsTempStorageURL(AttachedFile.AddressInTempStorage) Then
						BinaryData = GetFromTempStorage(AttachedFile.AddressInTempStorage);
						TextContent = Base64String(BinaryData);
						TextContent = "data:image/" + Mid(AttachedFile.Extension, 2) + ";base64,"
						+ Chars.LF + TextContent;
					Else
						TextContent = "";
					EndIf;

				NewAttributePicture.TextContent = TextContent;
				Picture.Attributes.SetNamedItem(NewAttributePicture);

				Break;

			EndIf;

		EndDo;

	EndDo;

	Return HTMLTextFromHTMLDocumentObject(HTMLDocument);

EndFunction

// Retrieves the Dochtml object from the HTML text.
//
// Parameters:
//  HTMLText - String
//
// Returns:
//   HTMLDocument - 
//
&AtServerNoContext
Function HTMLDocumentObjectFromHTMLText(HTMLText)

	Builder = New DOMBuilder;
	HTMLReader = New HTMLReader;

	NewHTMLText = HTMLText;
	PositionOpenXML = StrFind(NewHTMLText,"<?xml");

	If PositionOpenXML > 0 Then

		PositionCloseXML = StrFind(NewHTMLText,"?>");
		If PositionCloseXML > 0 Then

			NewHTMLText = Left(NewHTMLText,PositionOpenXML - 1) + Right(NewHTMLText,StrLen(NewHTMLText) - PositionCloseXML -1);

		EndIf;

	EndIf;

	HTMLReader.SetString(HTMLText);

	Return Builder.Read(HTMLReader);

EndFunction

// Retrieves HTML text from the Dochtml object.
//
// Parameters:
//  HTMLDocument - HTMLDocument - the document from which the text will be extracted.
//
// Returns:
//   String - 
//
&AtServerNoContext
Function HTMLTextFromHTMLDocumentObject(HTMLDocument)
	
	DOMWriter = New DOMWriter;
	HTMLWriter = New HTMLWriter;
	HTMLWriter.SetString();
	DOMWriter.Write(HTMLDocument,HTMLWriter);
	Return HTMLWriter.Close();
	
EndFunction

#EndRegion