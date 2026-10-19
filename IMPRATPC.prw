#Include "PROTHEUS.CH"
#Include "RWMAKE.ch"
#Include "TBICONN.ch"

/*
+----------+----------+-------+--------------------------------------------------------------+------+------------+
| Funcao   |MTA105LIN | Autor | Karina Bittencourt                                           | Data | 06/10/2026 |
+----------+----------+-------+--------------------------------------------------------------+------+------------+
|Descricao: Adiciona importação do rateio de centro de custos no Pedido de Compras                               |
+---------------------+------------------------------------------------------------------------------------------+
|Uso especifico na Valenet                                                                                       |
+----------+----------+------------------------------------------------------------------------------------------+  
*/

User Function ImpRatPC()

    Local aPerg    := {}
    Local oProcess := NIL

    // Chama a tela de selecao de arquivo
    aPerg := FPergunta()

    // Valida se o arquivo foi informado
    If !Empty(aPerg) .And. Len(aPerg) >= 1 .And. !Empty(AllTrim(aPerg[1]))
        oProcess := MsNewProcess():New( { | lEnd | FProc( @lEnd, aPerg, oProcess ) }, "Processando a Planilha", "Aguarde, atualizando ...", .F. )
        oProcess:Activate()
    EndIf

Return

//--------------------------------------
Static Function FPergunta()
    Local aPergs := {}
    Local aRet   := {}

    aAdd(aPergs, {6, "Buscar arquivo:", Space(70), "", "", "", 70, .T., "Todos os arquivos (*.CSV) |*.CSV"})
    
    If ParamBox(aPergs, "Importacao de Rateio - Selecao de Arquivo", @aRet)
        Return aRet
    EndIf

Return {}

//--------------------------------------
Static Function FProc(lEnd, aPerg, oProcess)
 
    Local aItens        := {}
    Local aRows         := {}
    Local nTotal        := 0
    Local hIni          := Time()
    Local hFim          := ''
    Local nLinha        := 0
    Local nI            := 0
    Local nTotalPerc    := 0

    // Campos da chave primária herdados do cabeçalho/item do Pedido (SC7)
    Local cNumPC        := PadR(SC7->C7_NUM, TamSX3("CH_PEDIDO")[1])
    Local cItemPC       := PadR(SC7->C7_ITEM, TamSX3("CH_ITEMPD")[1])
    Local cForn         := PadR(SC7->C7_FORNECE, TamSX3("CH_FORNECE")[1])
    Local cLoja         := PadR(SC7->C7_LOJA, TamSX3("CH_LOJA")[1])

    Local cItemRat      := ""
    Local cCCusto       := ""
    Local cConta        := ""
    Local cItemCTA      := ""
    Local cClVL         := ""
    Local nPerc         := 0
    Local cArq          := AllTrim(aPerg[1])
    Local cLinha        := ""
    Local cTexto        := ""
    Local nHdl          := 0
    Local lOldDel       := .F.

    Private lMsErroAuto := .F.       

    // Valida se a SC7 está posicionada corretamente
    If Empty(AllTrim(cNumPC)) .Or. Empty(AllTrim(cItemPC))
        MsgStop("Nenhum Pedido/Item de Compra posicionado na SC7!", "Atencao")
        Return
    EndIf

    nHdl := FT_FUse(cArq)

    If nHdl == -1
        Aviso("Erro", OemToAnsi("Nao foi possivel abrir o arquivo: " + cArq), {"OK"})
        Return
    EndIf

    FT_FGoTop()
    nTotal := FT_FLastRec()

    If ValType(oProcess) == "O"
        oProcess:SetRegua1(nTotal)
        oProcess:IncRegua1("Lendo planilha...")
    EndIf

    // Pula a linha do cabeçalho
    FT_FSkip()

    // 1. LEITURA E POPULAÇÃO DOS DADOS NO VETOR aRows
    While !FT_FEof()
        cLinha := FT_FReadLn()
        nLinha++
        
        If ValType(oProcess) == "O"
            oProcess:IncRegua2("Lendo linha " + cValToChar(nLinha))
        EndIf

        If !Empty(AllTrim(cLinha))
            aItens := {}
            cTexto := ';' + cLinha
            While (At(";", cTexto) > 0)
                cTexto := Substr(cTexto, At(";", cTexto) + 1, Len(cTexto))
                aAdd(aItens, IIf(At(";", cTexto) > 0, Substr(cTexto, 1, At(";", cTexto) - 1), cTexto))
            EndDo

            // CSV Mapeado: [1] Perc | [2] CC | [3] Conta | [4] Item Cta | [5] ClVL
            If Len(aItens) >= 5
                aAdd(aRows, { ;
                    Val(StrTran(AllTrim(aItens[1]), ",", ".")), ;
                    AllTrim(aItens[2]), ;
                    AllTrim(aItens[3]), ;
                    AllTrim(aItens[4]), ;
                    AllTrim(aItens[5])  ;
                })
            EndIf
        EndIf

        FT_FSkip()
    EndDo

    FT_FUse()

    If Len(aRows) == 0
        Aviso("Atencao", "Nenhum registro valido encontrado no arquivo CSV.", {"OK"})
        Return
    EndIf

    // 2. VALIDAÇÃO DO PERCENTUAL TOTAL (100%)
    For nI := 1 To Len(aRows)
        nTotalPerc += aRows[nI][1]
    Next nI

    If Round(nTotalPerc, 2) != 100.00
        Aviso("Atencao", OemToAnsi("A soma dos percentuais na planilha e de " + cValToChar(nTotalPerc) + "%. O total deve ser exatamente 100%."), {"OK"})
        Return
    EndIf

    // 3. GRAVAÇÃO E TRATAMENTO NA TABELA SCH
    If ValType(oProcess) == "O"
        oProcess:SetRegua1(Len(aRows))
        oProcess:IncRegua1("Atualizando rateio na SCH...")
    EndIf

    // Desativa o filtro de deletados para encontrar registros ocultos
    lOldDel := Set(_SET_DELETED, .F.)

    Begin Transaction

        dbSelectArea("SCH")
        SCH->(dbSetOrder(1)) // CH_FILIAL + CH_PEDIDO + CH_FORNECE + CH_LOJA + CH_ITEM + CH_ITEMRAT

        // Marca como deletados os itens atuais de rateio deste pedido
        If SCH->(dbSeek(xFilial("SCH") + cNumPC + cForn + cLoja + cItemPC))
            While !SCH->(Eof()) .And. ;
                  SCH->CH_FILIAL == xFilial("SCH") .And. ;
                  SCH->CH_PEDIDO == cNumPC .And. ;
                  SCH->CH_FORNECE == cForn .And. ;
                  SCH->CH_LOJA == cLoja .And. ;
                  SCH->CH_ITEMPD == cItemPC
                
                If RecLock("SCH", .F.)
                    SCH->(dbDelete())
                    SCH->(MsUnlock())
                EndIf
                SCH->(dbSkip())
            EndDo
        EndIf

        // Grava ou Restaura os novos registros lidos
        For nI := 1 To Len(aRows)
            If ValType(oProcess) == "O"
                oProcess:IncRegua2("Gravando item " + cValToChar(nI) + " de " + cValToChar(Len(aRows)))
            EndIf

            cItemRat := StrZero(nI, TamSX3("CH_ITEM")[1])
            nPerc    := aRows[nI][1]
            cCCusto  := PadR(aRows[nI][2], TamSX3("CH_CC")[1])
            cConta   := PadR(aRows[nI][3], TamSX3("CH_CONTA")[1])
            cItemCTA := PadR(aRows[nI][4], TamSX3("CH_ITEMCTA")[1])
            cClVL    := PadR(aRows[nI][5], TamSX3("CH_CLVL")[1])

            // Busca usando a chave primária completa do banco (6 campos)
            If SCH->(dbSeek(xFilial("SCH") + cNumPC + cForn + cLoja + cItemPC + cItemRat))
                RecLock("SCH", .F.)
                If SCH->(Deleted())
                    SCH->(dbRecall()) // Restaura limpando o D_E_L_E_T_
                EndIf
            Else
                RecLock("SCH", .T.) // Registro novo
            EndIf

            SCH->CH_FILIAL  := xFilial("SCH")
            SCH->CH_PEDIDO  := cNumPC
            SCH->CH_FORNECE := cForn
            SCH->CH_LOJA    := cLoja
            SCH->CH_ITEMPD    := cItemPC
            SCH->CH_ITEM := cItemRat
            SCH->CH_PERC    := nPerc
            SCH->CH_CC      := cCCusto
            SCH->CH_CONTA := cConta
            SCH->CH_ITEMCTA := cItemCTA
            SCH->CH_CLVL    := cClVL
            
            SCH->(MsUnlock())
        Next nI

    End Transaction

    Set(_SET_DELETED, lOldDel)

    hFim := Time()
    MsgInfo("Dados importados com sucesso!" + CRLF + "Inicio: " + hIni + CRLF + "Fim: " + hFim, "Sucesso")

Return
