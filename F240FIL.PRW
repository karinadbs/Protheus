#Include "Protheus.ch"
#Include "Totvs.ch"

/*/{Protheus.doc} F240FIL

    Complementa o filtro da seleção de títulos
    na rotina FINA240.

    Regras:

    01 - Crédito em Conta
         E2_FORBCO = Banco do Borderô

    30 - Boleto Próprio
         Left(E2_LINDIG,3) = Banco do Borderô

    31 - Boleto Outros Bancos
         Left(E2_LINDIG,3) <> Banco do Borderô

    41 - TED
         E2_FORBCO <> Banco do Borderô

    45 - PIX
         Sem filtro

    13 - Concessionárias
         Linha digitável com 48 posições

@author
@since 12.1.2510

/*/

User Function F240FIL()

    Local cFiltro := ""

    Do Case

        //==========================================================
        // 01 - Crédito em Conta
        //==========================================================
        Case AllTrim(cModPgto) == "01"

            cFiltro := ;
                " Empty(AllTrim(E2_CODBAR)) .And. " + ;
                " E2_FORBCO == '" + AllTrim(cPort240) + "' "

        //==========================================================
        // 30 - Boleto Próprio
        //==========================================================
        Case AllTrim(cModPgto) == "30"

            cFiltro := ;                
                " !Empty(AllTrim(E2_LINDIG)) .And. " + ;
                " Len(AllTrim(E2_LINDIG)) == 47 .AND. "+ ;
                " SubStr(AllTrim(E2_LINDIG),1,3) == '" + AllTrim(cPort240) + "' "

        //==========================================================
        // 31 - Boleto Outros Bancos
        //==========================================================
        Case AllTrim(cModPgto) == "31"

            cFiltro := ;
                " !Empty(AllTrim(E2_LINDIG)) .And. " + ;
                " Len(AllTrim(E2_LINDIG)) == 47 .AND. "+ ;
                " SubStr(AllTrim(E2_LINDIG),1,3) <> '" + AllTrim(cPort240) + "' "

        //==========================================================
        // 41 - TED
        //==========================================================
        Case AllTrim(cModPgto) == "41"

            cFiltro := ;
                "Empty(AllTrim(E2_CODBAR)) .And. " + ;
                " E2_FORBCO <> '" + AllTrim(cPort240) + "' .And. " + ;
                " !Empty(AllTrim(E2_FORBCO)) "

        //==========================================================
        // 45 - PIX
        //==========================================================
        Case AllTrim(cModPgto) == "45"

            cFiltro := ;
            "Empty(AllTrim(E2_CODBAR)) "

        //==========================================================
        // 13 - Concessionárias
        //==========================================================
        Case AllTrim(cModPgto) == "13"

            cFiltro := ;
                " Len(AllTrim(E2_LINDIG)) == 48 "


        //==========================================================
        // 11 - Concesssionarios e Tributos com codigo de barras
        //==========================================================
        Case AllTrim(cModPgto) == "11"

            cFiltro := ;
                " Len(AllTrim(E2_LINDIG)) == 48 "

    EndCase

Return cFiltro
