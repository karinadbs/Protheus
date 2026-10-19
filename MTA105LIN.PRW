/*
+----------+----------+-------+--------------------------------------------------------------+------+------------+
| Funcao   |MTA105LIN | Autor | Karina Bittencourt                                           | Data | 24/08/2026 |
+----------+----------+-------+--------------------------------------------------------------+------+------------+
|Descricao: Validação do Centro de Custo na solicitação ao armazém                                               |
+---------------------+------------------------------------------------------------------------------------------+
|Uso especifico na Valenet                                                                                       |
+----------+----------+------------------------------------------------------------------------------------------+  
*/

#Include "Protheus.ch"
#Include "TopConn.ch"

User Function MTA105LIN()

    Local lVldUsu   := .F.
    Local nPosCCS   := aScan(aHeader, {|x| AllTrim(x[2]) == "CP_CC" })
    Local nPosCodSF := aScan(aHeader, {|x| AllTrim(x[2]) == "CP_USUFIN" })

    Local cCCSol    := Iif(nPosCCS > 0, AllTrim(aCols[n][nPosCCS]), "")
    Local cUsuSolF  := Iif(nPosCodSF > 0, aCols[n][nPosCodSF], "")

    // Captura o e-mail do usuário logado no Protheus
    Local cEmail    := AllTrim(UsrRetMail(RetCodUsr()))
    Local cCCUser   := ""
    Local cMatricula := ""

// 1. Busca o Centro de Custo do funcionário associado ao e-mail
    If !Empty(cEmail)
        BeginSql Alias "QRYCC"
            SELECT RA_CC
              FROM %table:SRA%
             WHERE RA_FILIAL = %xfilial:SRA%
               AND RA_EMAIL  = %exp:cEmail%
               AND D_E_L_E_T_ = ' '
        EndSql

        If !QRYCC->(Eof())
            cCCUser := AllTrim(QRYCC->RA_CC)
        EndIf
        QRYCC->(DbCloseArea())
    EndIf

// 2. Busca TODOS os centros de custo dos departamentos dos quais o funcionário é responsável
    If !Empty(cMatricula)
        BeginSql Alias "QRYCC"
            SELECT CTT_CC
              FROM %table:SRA% SRA
             INNER JOIN %table:CTT% CTT ON CTT.CTT_FILIAL = SRA.RA_FILIAL AND CTT.CTT_MAT = SRA.RA_MAT
             WHERE SRA.RA_FILIAL    = %xfilial:SRA%
               AND SRA.RA_MAT       = %exp:cMatricula%
               AND SRA.D_E_L_E_T_   = ' '
               AND CTT.D_E_L_E_T_   = ' '
        EndSql

        // Percorre todos os registros retornados
        While !QRYCC->(Eof())
            If !Empty(QRYCC->CTT_CC)
                // Se já houver CCs, adiciona o separador '|'
                If !Empty(cCCUser)
                    cCCUser += "|"
                EndIf
                cCCUser += AllTrim(QRYCC->CTT_CC)
            EndIf
            QRYCC->(DbSkip())
        EndDo
        QRYCC->(DbCloseArea())
    EndIf

    // Validações de regra de negócio
    If !Empty(cCCUser)
        // Regra 1: Permissão por CC fixo do usuário
        If cCCUser == cCCSol .Or. cCCUser $ "354120000|354100000|354000000|100000000"
            lVldUsu := .T.
        EndIf

        // Regra 2: Usuários de CCs específicos solicitando CCs do tipo "FIELD"
        If !lVldUsu .And. cCCUser $ "541110000|351312000"
            If CTT->(DbSeek(xFilial("CTT") + cCCSol))
                If "FIELD" $ Upper(CTT->CTT_DESC01)
                    lVldUsu := .T.
                EndIf
            EndIf
        EndIf
    EndIf


    If Empty(cCCSol)
        MsgInfo("Centro de custo obrigatório, precisa informar o centro de custo para a solicitação.", "Alerta Bloqueio Centro de Custo!")
        lVldUsu := .F.
    EndIf

    If Empty(cUsuSolF)
        MsgInfo("Usuário final obrigatório, precisa informar o usuário final da solicitação.", "Alerta Bloqueio Centro de Custo!")
        lVldUsu := .F.
    EndIf

    If !lVldUsu
        MsgInfo("Sua solicitação não poderá ser realizada, pois o centro de custo escolhido não está liberado para o usuário padrão da solicitação. Verifique com o time de estoque!", "Alerta Bloqueio Centro de Custo!")
    EndIf

    Return lVldUsu
