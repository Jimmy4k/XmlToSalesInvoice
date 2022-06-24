pageextension 50000 SalesInvoiceListExt extends "Sales Invoice List"
{
    layout
    {
        // Add changes to page layout here
    }
    
    actions
    {
        addfirst(processing)
        {
            action("Upload Json")
            {
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Image = Import;
                
                trigger OnAction()
                var
                    ImportFromJson: Codeunit "Import Sales Invoice From Json";
                begin
                    ImportFromJson.ImportSalesInvoiceFromJson();
                end;
            }
        }
    }
    
    var
        myInt: Integer;
}