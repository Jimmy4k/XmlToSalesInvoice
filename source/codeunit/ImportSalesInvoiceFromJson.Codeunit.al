codeunit 50000 "Import Sales Invoice From Json"
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
        SalesLine: Record "Sales Line";
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
            if GetSalesLinesDetials(SalesHeader, SalesLine, ContentObject) then begin
                Commit();
                PostingSalesInvoice(SalesHeader);
            end;
    end;

    local procedure GetSalesHeaderDetails(var SalesHeader: Record "Sales Header"; OrderObject: JsonObject; ResourceObject: JsonObject; ContentObject: JsonObject; CustomerObjekt: JsonObject): Boolean
    var
        ValueToken: JsonToken;
        DocumentType: Enum "Sales Document Type";
        Cusotmer: Record Customer;
        PaymentTems: Record "Payment Terms";
        PaymentMethod: Record "Payment Method";
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
            if Cusotmer.Get(ValueToken.AsValue().AsCode()) then begin
                if Cusotmer.Blocked = Cusotmer.Blocked::Invoice then
                    exit;
                SalesHeader.Validate("Sell-to Customer No.", ValueToken.AsValue().AsCode())
            end
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

        // Legt den Zahlungsbedienung und Zahlungsformen an
        if ContentObject.Get('status', ValueToken) then begin
            if ValueToken.AsValue().AsText() = 'PAID' then
                if PaymentTems.Get('PAID') then
                    SalesHeader.Validate("Payment Terms Code", PaymentTems.Code);
            if PaymentMethod.Get('PAID') then
                SalesHeader.Validate("Payment Method Code", PaymentMethod.Code);
        end;

        SalesHeader.Modify(true);

        exit(true);
    end;

    local procedure GetSalesLinesDetials(var SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line"; ContentObject: JsonObject): Boolean
    var
        Item: Record Item;
        LineArray: JsonToken;
        LineToken: JsonToken;
        LineObject: JsonObject;
        ValueToken: JsonToken;
        ItemNo: Code[20];
        LineQty: Decimal;
        UnitPrice: Decimal;
        VATBaseAmount: Decimal;

    begin
        if ContentObject.Contains('lines') then
            if ContentObject.Get('lines', LineArray) then
                foreach LineToken in LineArray.AsArray() do begin
                    LineObject := LineToken.AsObject();
                    if LineObject.Get('id', ValueToken) then
                        ItemNo := ValueToken.AsValue().AsCode();
                    // Prüft ob der Artikel existiert
                    if Item.get(ItemNo) then begin
                        // ist Item gesperrt = Abbruch
                        if Item.Blocked = true then
                            exit;
                    end
                    // sonst erstelle den Artikel
                    else
                        CreateNewItem(ContentObject, ItemNo);

                    if LineObject.Get('quantity', ValueToken) then
                        LineQty := ValueToken.AsValue().AsDecimal();
                    if LineObject.Get('unitPrice', ValueToken) then
                        UnitPrice := Round(ValueToken.AsValue().AsDecimal(), 2);
                    if LineObject.Get('total', ValueToken) then
                        VATBaseAmount := ValueToken.AsValue().AsDecimal();

                    SalesLine.Init();
                    SalesLine."Document Type" := SalesHeader."Document Type";
                    SalesLine."Document No." := SalesHeader."No.";
                    SalesLine."Line No." := GetNextSalesLineNo(SalesHeader);
                    SalesLine.Insert(true);
                    SalesLine.Type := SalesLine.Type::Item;
                    SalesLine.Validate("No.", ItemNo);
                    SalesLine.Validate(Quantity, LineQty);
                    SalesLine."Unit Price" := UnitPrice;
                    SalesLine.Modify(true);
                end;
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

    local procedure PostingSalesInvoice(SalesHeader: Record "Sales Header")
    var
        SalesPostYesNo: Codeunit "Sales-Post (Yes/No)";
    begin
        SalesPostYesNo.Run(SalesHeader);
    end;
}