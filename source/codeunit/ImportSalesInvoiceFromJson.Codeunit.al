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
        ResourceArray: JsonToken;
        ResourceObject: JsonObject;
        ContentArray: JsonToken;
        ContentObject: JsonObject;
        CustomerArray: JsonToken;
        CustomerObject: JsonObject;
        LineArray: JsonToken;
        LineObject: JsonObject;
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
        if ContentObject.Contains('customer') then
            if ContentObject.Get('customer', CustomerArray) then
                CustomerObject := CustomerArray.AsObject();
        if ResourceObject.Contains('lines') then
            if ResourceObject.Get('lines', LineArray) then
                LineObject := LineArray.AsObject();
        // Fügt den SalesHeader ein
        if GetSalesHeaderDetails(SalesHeader, OrderObject, ResourceObject, ContentObject, CustomerObject) then
            GetSalesLinesDetials(ContentObject, SalesHeader);
    end;

    local procedure GetSalesHeaderDetails(var SalesHeader: Record "Sales Header";OrderObject: JsonObject; ResourceObject: JsonObject; ContentObject: JsonObject; CustomerObjekt: JsonObject): Boolean
    var
        ValueToken: JsonToken;
        DocumentType: Enum "Sales Document Type";
        Cusotmer: Record Customer;
    begin
        SalesHeader.Init();
        // Überprüft den DocumentType und definiert hin
        if ResourceObject.Get('type', ValueToken) then begin
            if ValueToken.AsValue().AsCode() = 'INVOICE_NEW' then
                SalesHeader."Document Type" := SalesHeader."Document Type"::Invoice;
        end;

        // Legt die Rechnungsnummer an
        if ContentObject.Get('invoiceNumber', ValueToken) then begin
            SalesHeader."No." := ValueToken.AsValue().AsCode();
        end;

        SalesHeader.Insert(true);

        // Legt die Debitornr. an
        if ContentObject.Get('id', ValueToken) then begin
            // Prüft ob der Dibitor existiert
            if Cusotmer.Get(ValueToken.AsValue().AsCode()) then
                SalesHeader.Validate("Sell-to Customer No.", ValueToken.AsValue().AsCode())
            // wenn nicht vorhande, lege an und weise die No. zu
            else begin
                CreateCustomer(ContentObject, CustomerObjekt, Cusotmer, ValueToken);
                SalesHeader.Validate("Sell-to Customer No.", ValueToken.AsValue().AsCode());
            end;

        end;
        // Legt das Rechnunngsdatum an
        if ContentObject.Get('invoiceDate', ValueToken) then begin
            SalesHeader.Validate("Posting Date", ValueToken.AsValue().AsDate());
        end;

        // Legt den Status an // NOCH BEARBEITEN!!!
        if ContentObject.Get('status', ValueToken) then begin
            if ValueToken.AsValue().AsText() = 'PAID' then
                ;
        end;

        SalesHeader.Modify(true);

        exit(true);
    end;


    local procedure CreateCustomer(ContentObject: JsonObject; CustomerObjekt: JsonObject; Cusotmer: Record Customer; ValueToken: JsonToken)
    begin
        Cusotmer.Init();

        // Legt die Debitornr. an
        Cusotmer."No." := ValueToken.AsValue().AsCode();

        // Legt den Debitorname an
        if CustomerObjekt.get('companyName', ValueToken) then begin
            Cusotmer.Name := ValueToken.AsValue().AsText();
        end;
        // Legt die Adresse an
        if CustomerObjekt.Get('companyStreet', ValueToken) then begin
            Cusotmer.Address := ValueToken.AsValue().AsText();
        end;
        // Legt die City an
        if CustomerObjekt.Get('companyCity', ValueToken) then begin
            Cusotmer.City := ValueToken.AsValue().AsText();
        end;
        Cusotmer.Insert(true);
    end;

    local procedure GetSalesLinesDetials(ContentObject: JsonObject; SalesHeader: Record "Sales Header")
    var
        Item: Record Item;
        SalesLine: Record "Sales Line";
        LineArray: JsonToken;
        LineToken: JsonToken;
        LineObject: JsonObject;
        ValueToken: JsonToken;
        ItemNo: Code[20];
        LineQty: Decimal;
    begin
        if ContentObject.Contains('lines') then
            if ContentObject.Get('lines', LineArray) then
                foreach LineToken in LineArray.AsArray() do begin
                    LineObject := LineToken.AsObject();
                    if LineObject.Get('id', ValueToken) then
                        ItemNo := ValueToken.AsValue().AsCode();
                        // Prüft ob der Artikel existiert
                        if not Item.get(ItemNo) then
                            CreateNewItem(ContentObject, ItemNo);
                    if LineObject.Get('quantity', ValueToken) then
                        LineQty := ValueToken.AsValue().AsDecimal();


                        SalesLine.Init();
                        SalesLine."Document Type" := SalesHeader."Document Type";
                        SalesLine."Document No." := SalesHeader."No.";
                        SalesLine."Line No." := GetNextSalesLineNo(SalesHeader);
                        SalesLine.Insert(true);
                        SalesLine.Type := SalesLine.Type::Item;
                        SalesLine.Validate("No.", ItemNo);
                        SalesLine.Validate(Quantity, LineQty);
                        SalesLine.Modify(true);
                end;
    end;

    local procedure GetNextSalesLineNo(SalesHeader: Record "Sales Header"): Integer
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
            if SalesLine.FindLast() then
                exit(SalesLine."Line No." + 10000);
            exit(10000);
    end;

    local procedure CreateNewItem(ContentObject: JsonObject; ItemNo: Code[20])
        Item: Record Item;
    begin
        
    end;
}