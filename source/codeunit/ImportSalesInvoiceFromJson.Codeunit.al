codeunit 50100 "Import Sales Invoice From Json"
{
    procedure ImportSalesInvoiceFromJson()
    var
        InputToken: JsonToken;
    begin
        RequesrFileFromUser(InputToken);
        ImportSalesInvoice(InputToken);
    end;

    procedure RequesrFileFromUser(InputToken: JsonToken)
    var
        InputFile: Text;
        IStream: InStream;
        UploadLbl: Label 'Select File to Import';

    begin
        if UploadIntoStream(UploadLbl, '', '*.*|*.json', InputFile, IStream) then
            InputToken.ReadFrom(IStream);

    end;

    local procedure ImportSalesInvoice(InputToken: JsonToken)
    var
        OrderObject: JsonObject;
        ContentArray: JsonToken;
        ContentObject: JsonObject;
        ResourceArray: JsonToken;
        ResourceObject: JsonObject;
        SalesHeader: Record "Sales Header";

    begin
        if not InputToken.IsObject then
            exit;

        OrderObject := InputToken.AsObject();

        if OrderObject.Contains('resource') then
            if OrderObject.Get('resource', ResourceArray) then
                ResourceObject := ResourceArray.AsObject();
                if ResourceObject.Contains('content') then
                    if ResourceObject.Get('content', ContentArray) then
                        ContentObject := ContentArray.AsObject();
                        GetSalesHeaderDetails(OrderObject, ResourceObject, ContentObject, SalesHeader)
    end;

    local procedure GetSalesHeaderDetails(OrderObject: JsonObject; ResourceObject: JsonObject; ContentObject: JsonObject; SalesHeader: Record "Sales Header")
    var
        ValueToken: JsonToken;
        InputValue: JsonValue;
        DocumentType: Enum "Sales Document Type";
    begin
        SalesHeader.Init();
        // Überprüft den DocumentType und definiert hin
        if ResourceObject.Get('type', ValueToken) then begin
            InputValue := ValueToken.AsValue();
            if InputValue.AsCode() = 'INVOICE_NEW' then
                SalesHeader."Document Type" := SalesHeader."Document Type"::Invoice;     
        end;
        // Legt die Rechnungsnummer an
        if ContentObject.Get('invoiceNumber', ValueToken) then begin
            InputValue := ValueToken.AsValue();
            SalesHeader."No." := InputValue.AsCode();
        end;

        SalesHeader.Insert(true);
    end;
}